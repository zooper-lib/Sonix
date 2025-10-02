import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_type.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/waveform_use_case.dart';
import 'package:sonix/src/processing/downsampling_algorithm.dart';
import 'package:sonix/src/processing/scaling_curve.dart';
import 'dart:math' as math;

void main() {
  group('WaveformGenerator', () {
    late AudioData testAudioData;

    setUp(() {
      // Create test audio data with sine wave
      final samples = List.generate(1000, (i) => math.sin(i * 0.1) * 0.8);
      testAudioData = AudioData(samples: samples, sampleRate: 44100, channels: 1, duration: const Duration(seconds: 1));
    });

    group('Basic Generation', () {
      test('should generate waveform with default config', () async {
        final result = await WaveformGenerator.generateInMemory(testAudioData);

        expect(result.amplitudes.length, equals(1000)); // Default resolution
        expect(result.duration, equals(testAudioData.duration));
        expect(result.sampleRate, equals(testAudioData.sampleRate));
        expect(result.metadata.type, equals(WaveformType.bars));
        expect(result.metadata.normalized, isTrue);
      });

      test('should generate waveform with custom resolution', () async {
        final config = const WaveformConfig(resolution: 500);
        final result = await WaveformGenerator.generateInMemory(testAudioData, config: config);

        expect(result.amplitudes.length, equals(500));
        expect(result.metadata.resolution, equals(500));
      });

      test('should apply different algorithms', () async {
        final rmsConfig = const WaveformConfig(algorithm: DownsamplingAlgorithm.rms, resolution: 100);
        final peakConfig = const WaveformConfig(algorithm: DownsamplingAlgorithm.peak, resolution: 100);

        final rmsResult = await WaveformGenerator.generateInMemory(testAudioData, config: rmsConfig);
        final peakResult = await WaveformGenerator.generateInMemory(testAudioData, config: peakConfig);

        expect(rmsResult.amplitudes.length, equals(100));
        expect(peakResult.amplitudes.length, equals(100));

        // Results should be different due to different algorithms
        expect(rmsResult.amplitudes, isNot(equals(peakResult.amplitudes)));
      });

      test('should handle normalization settings', () async {
        final normalizedConfig = const WaveformConfig(normalize: true);
        final unnormalizedConfig = const WaveformConfig(normalize: false);

        final normalizedResult = await WaveformGenerator.generateInMemory(testAudioData, config: normalizedConfig);
        final unnormalizedResult = await WaveformGenerator.generateInMemory(testAudioData, config: unnormalizedConfig);

        expect(normalizedResult.metadata.normalized, isTrue);
        expect(unnormalizedResult.metadata.normalized, isFalse);

        // Normalized result should have max value of 1.0 (or close to it)
        final maxNormalized = normalizedResult.amplitudes.reduce(math.max);
        expect(maxNormalized, closeTo(1.0, 0.1));
      });

      test('should apply smoothing when enabled', () async {
        final smoothConfig = const WaveformConfig(enableSmoothing: true, smoothingWindowSize: 5, resolution: 100);
        final noSmoothConfig = const WaveformConfig(enableSmoothing: false, resolution: 100);

        final smoothResult = await WaveformGenerator.generateInMemory(testAudioData, config: smoothConfig);
        final noSmoothResult = await WaveformGenerator.generateInMemory(testAudioData, config: noSmoothConfig);

        expect(smoothResult.amplitudes.length, equals(100));
        expect(noSmoothResult.amplitudes.length, equals(100));

        // Smoothed result should be different
        expect(smoothResult.amplitudes, isNot(equals(noSmoothResult.amplitudes)));
      });
    });

    group('Configuration Validation', () {
      test('should throw on invalid resolution', () async {
        final invalidConfig = const WaveformConfig(resolution: 0);

        expect(() => WaveformGenerator.generateInMemory(testAudioData, config: invalidConfig), throwsArgumentError);
      });

      test('should throw on negative scaling factor', () async {
        final invalidConfig = const WaveformConfig(scalingFactor: -1.0);

        expect(() => WaveformGenerator.generateInMemory(testAudioData, config: invalidConfig), throwsArgumentError);
      });

      test('should throw on invalid smoothing window size', () async {
        final invalidConfig = const WaveformConfig(
          enableSmoothing: true,
          smoothingWindowSize: 2, // Even number
        );

        expect(() => WaveformGenerator.generateInMemory(testAudioData, config: invalidConfig), throwsArgumentError);
      });

      test('should throw on empty audio data', () async {
        final emptyAudioData = AudioData(samples: const [], sampleRate: 44100, channels: 1, duration: Duration.zero);

        expect(() => WaveformGenerator.generateInMemory(emptyAudioData), throwsArgumentError);
      });
    });

    group('Scaling Curves', () {
      test('should apply different scaling curves', () async {
        final linearConfig = const WaveformConfig(scalingCurve: ScalingCurve.linear, resolution: 100);
        final logConfig = const WaveformConfig(scalingCurve: ScalingCurve.logarithmic, resolution: 100);

        final linearResult = await WaveformGenerator.generateInMemory(testAudioData, config: linearConfig);
        final logResult = await WaveformGenerator.generateInMemory(testAudioData, config: logConfig);

        // Results should be different due to different scaling
        expect(linearResult.amplitudes, isNot(equals(logResult.amplitudes)));
      });

      test('should apply scaling factor', () async {
        final config = const WaveformConfig(
          scalingFactor: 0.5,
          normalize: false, // Disable normalization to see scaling effect
          resolution: 100,
        );

        final result = await WaveformGenerator.generateInMemory(testAudioData, config: config);

        // All values should be scaled down
        final maxValue = result.amplitudes.reduce(math.max);
        expect(maxValue, lessThan(0.8)); // Original max was ~0.8, should be scaled down
      });
    });

    group('Memory Efficient Generation', () {
      test('should generate waveform with memory constraints', () async {
        final result = await WaveformGenerator.generateChunked(
          testAudioData,
          maxMemoryUsage: 1024, // Very small memory limit
        );

        expect(result.amplitudes.isNotEmpty, isTrue);
        expect(result.duration, equals(testAudioData.duration));
      });

      test('should use regular generation for small files', () async {
        final smallAudioData = AudioData(
          samples: List.generate(100, (i) => math.sin(i * 0.1)),
          sampleRate: 44100,
          channels: 1,
          duration: const Duration(milliseconds: 100),
        );

        final result = await WaveformGenerator.generateChunked(
          smallAudioData,
          maxMemoryUsage: 10 * 1024 * 1024, // Large memory limit
        );

        expect(result.amplitudes.isNotEmpty, isTrue);
      });
    });

    group('Optimal Configurations', () {
      test('should provide music visualization config', () {
        final config = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.musicVisualization);

        expect(config.algorithm, equals(DownsamplingAlgorithm.rms));
        expect(config.scalingCurve, equals(ScalingCurve.logarithmic));
        expect(config.enableSmoothing, isTrue);
        expect(config.normalize, isTrue);
      });

      test('should provide speech analysis config', () {
        final config = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.speechAnalysis);

        expect(config.algorithm, equals(DownsamplingAlgorithm.rms));
        expect(config.scalingCurve, equals(ScalingCurve.linear));
        expect(config.enableSmoothing, isFalse);
        expect(config.resolution, equals(2000));
      });

      test('should provide peak detection config', () {
        final config = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.peakDetection);

        expect(config.algorithm, equals(DownsamplingAlgorithm.peak));
        expect(config.scalingCurve, equals(ScalingCurve.linear));
        expect(config.enableSmoothing, isFalse);
      });

      test('should provide memory efficient config', () {
        final config = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.memoryEfficient);

        expect(config.algorithm, equals(DownsamplingAlgorithm.average));
        expect(config.resolution, equals(200));
        expect(config.enableSmoothing, isFalse);
      });

      test('should allow custom resolution override', () {
        final config = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.musicVisualization, customResolution: 500);

        expect(config.resolution, equals(500));
      });
    });

    group('WaveformConfig', () {
      test('should create config with default values', () {
        const config = WaveformConfig();

        expect(config.resolution, equals(1000));
        expect(config.type, equals(WaveformType.bars));
        expect(config.normalize, isTrue);
        expect(config.algorithm, equals(DownsamplingAlgorithm.rms));
      });

      test('should support copyWith method', () {
        const original = WaveformConfig(resolution: 500);
        final modified = original.copyWith(normalize: false);

        expect(modified.resolution, equals(500)); // Unchanged
        expect(modified.normalize, isFalse); // Changed
        expect(original.normalize, isTrue); // Original unchanged
      });
    });
  });
}
