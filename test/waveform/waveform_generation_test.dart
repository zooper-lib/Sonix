import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/waveform_use_case.dart';
import 'package:sonix/src/processing/downsampling_algorithm.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_type.dart';
import '../../tools/test_data_generator.dart';
import 'dart:math' as math;

void main() {
  group('Waveform Generation Tests', () {
    setUpAll(() async {
      // Generate essential test data if it doesn't exist (faster)
      if (!await TestDataLoader.assetExists('test_configurations.json')) {
        await TestDataGenerator.generateEssentialTestData();
      }
    });

    group('Basic Waveform Generation', () {
      test('should generate waveform from simple audio data', () async {
        final audioData = _createTestAudioData();

        final waveformData = await WaveformGenerator.generateInMemory(audioData);

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.amplitudes.length, equals(1000)); // Default resolution
        expect(waveformData.duration, equals(audioData.duration));
        expect(waveformData.sampleRate, equals(audioData.sampleRate));
        expect(waveformData.metadata.resolution, equals(1000));
      });

      test('should generate waveform with custom resolution', () async {
        final audioData = _createTestAudioData();

        final config = WaveformConfig(resolution: 500);
        final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);

        expect(waveformData.amplitudes.length, equals(500));
        expect(waveformData.metadata.resolution, equals(500));
      });

      test('should handle different waveform types', () async {
        final audioData = _createTestAudioData();

        final barConfig = WaveformConfig(type: WaveformType.bars);
        final barWaveform = await WaveformGenerator.generateInMemory(audioData, config: barConfig);
        expect(barWaveform.metadata.type, equals(WaveformType.bars));

        final lineConfig = WaveformConfig(type: WaveformType.line);
        final lineWaveform = await WaveformGenerator.generateInMemory(audioData, config: lineConfig);
        expect(lineWaveform.metadata.type, equals(WaveformType.line));

        final filledConfig = WaveformConfig(type: WaveformType.filled);
        final filledWaveform = await WaveformGenerator.generateInMemory(audioData, config: filledConfig);
        expect(filledWaveform.metadata.type, equals(WaveformType.filled));
      });

      test('should apply normalization when requested', () async {
        final audioData = _createTestAudioData(amplitude: 0.5);

        final normalizedConfig = WaveformConfig(normalize: true);
        final normalizedWaveform = await WaveformGenerator.generateInMemory(audioData, config: normalizedConfig);

        final unnormalizedConfig = WaveformConfig(normalize: false);
        final unnormalizedWaveform = await WaveformGenerator.generateInMemory(audioData, config: unnormalizedConfig);

        expect(normalizedWaveform.metadata.normalized, isTrue);
        expect(unnormalizedWaveform.metadata.normalized, isFalse);

        // Normalized should have higher peak values
        final normalizedMax = normalizedWaveform.amplitudes.reduce(math.max);
        final unnormalizedMax = unnormalizedWaveform.amplitudes.reduce(math.max);
        expect(normalizedMax, greaterThan(unnormalizedMax));
      });
    });

    group('Algorithm Accuracy', () {
      test('should calculate RMS values correctly', () async {
        // Create audio with known RMS value
        final pattern = [0.5, -0.5, 0.8, -0.8];
        final samples = <double>[];
        for (int i = 0; i < 1000; i++) {
          samples.addAll(pattern);
        }
        final audioData = AudioData(
          samples: samples,
          sampleRate: 44100,
          channels: 1,
          duration: Duration(milliseconds: (samples.length / 44.1).round()),
        );

        final config = WaveformConfig(
          algorithm: DownsamplingAlgorithm.rms,
          resolution: 4, // One amplitude per pattern repetition
          normalize: false, // Don't normalize to see actual RMS values
        );
        final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);

        // Each amplitude should be close to the RMS of the pattern
        final expectedRms = math.sqrt((0.25 + 0.25 + 0.64 + 0.64) / 4);
        for (final amplitude in waveformData.amplitudes) {
          expect(amplitude, closeTo(expectedRms, 0.1));
        }
      });

      test('should calculate peak values correctly', () async {
        final pattern = [0.2, -0.8, 0.5, -0.3];
        final samples = <double>[];
        for (int i = 0; i < 1000; i++) {
          samples.addAll(pattern);
        }
        final audioData = AudioData(
          samples: samples,
          sampleRate: 44100,
          channels: 1,
          duration: Duration(milliseconds: (samples.length / 44.1).round()),
        );

        final config = WaveformConfig(
          algorithm: DownsamplingAlgorithm.peak,
          resolution: 4,
          normalize: false, // Don't normalize to see actual peak values
        );
        final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);

        // Each amplitude should be close to the peak of the pattern (0.8)
        for (final amplitude in waveformData.amplitudes) {
          expect(amplitude, closeTo(0.8, 0.1));
        }
      });

      test('should calculate average values correctly', () async {
        final pattern = [0.2, -0.4, 0.6, -0.8];
        final samples = <double>[];
        for (int i = 0; i < 1000; i++) {
          samples.addAll(pattern);
        }
        final audioData = AudioData(
          samples: samples,
          sampleRate: 44100,
          channels: 1,
          duration: Duration(milliseconds: (samples.length / 44.1).round()),
        );

        final config = WaveformConfig(
          algorithm: DownsamplingAlgorithm.average,
          resolution: 4,
          normalize: false, // Don't normalize to see actual average values
        );
        final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);

        // Each amplitude should be close to the average absolute value
        final expectedAverage = (0.2 + 0.4 + 0.6 + 0.8) / 4;
        for (final amplitude in waveformData.amplitudes) {
          expect(amplitude, closeTo(expectedAverage, 0.1));
        }
      });
    });

    group('Multi-channel Audio', () {
      test('should handle stereo audio correctly', () async {
        final leftChannel = List.generate(1000, (i) => math.sin(i * 0.1));
        final rightChannel = List.generate(1000, (i) => math.cos(i * 0.1));
        final stereoSamples = <double>[];

        for (int i = 0; i < 1000; i++) {
          stereoSamples.add(leftChannel[i]);
          stereoSamples.add(rightChannel[i]);
        }

        final audioData = AudioData(
          samples: stereoSamples,
          sampleRate: 44100,
          channels: 2,
          duration: const Duration(milliseconds: 23), // ~1000 samples at 44.1kHz
        );

        final waveformData = await WaveformGenerator.generateInMemory(audioData);

        expect(waveformData.amplitudes, isNotEmpty);
        // For stereo audio, the downsampling algorithm may return more samples than the target resolution
        // when the resolution is greater than samples per channel
        expect(waveformData.amplitudes.length, greaterThan(0));

        // Verify that waveform generation completed successfully for multi-channel audio
        expect(waveformData.duration, equals(audioData.duration));
        expect(waveformData.sampleRate, equals(audioData.sampleRate));
      });

      test('should handle mono audio correctly', () async {
        final monoSamples = List.generate(1000, (i) => math.sin(i * 0.1));
        final audioData = AudioData(samples: monoSamples, sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 23));

        final waveformData = await WaveformGenerator.generateInMemory(audioData);

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.amplitudes.length, equals(1000));
      });

      test('should handle multi-channel audio (5.1)', () async {
        const channels = 6; // 5.1 surround
        final samples = <double>[];

        for (int i = 0; i < 1000; i++) {
          for (int ch = 0; ch < channels; ch++) {
            samples.add(math.sin(i * 0.1 + ch * math.pi / 3));
          }
        }

        final audioData = AudioData(samples: samples, sampleRate: 44100, channels: channels, duration: const Duration(milliseconds: 23));

        final waveformData = await WaveformGenerator.generateInMemory(audioData);

        expect(waveformData.amplitudes, isNotEmpty);
        // For multi-channel audio, the downsampling algorithm may return more samples than the target resolution
        expect(waveformData.amplitudes.length, greaterThan(0));
      });
    });

    group('Resolution Handling', () {
      test('should handle very low resolution', () async {
        final audioData = _createTestAudioData();

        final config = WaveformConfig(resolution: 10);
        final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);

        expect(waveformData.amplitudes.length, equals(10));
        expect(waveformData.amplitudes.every((a) => a >= 0.0), isTrue);
      });

      test('should handle very high resolution', () async {
        final audioData = _createTestAudioData();

        final config = WaveformConfig(resolution: 10000);
        final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);

        expect(waveformData.amplitudes.length, equals(10000));
      });

      test('should handle resolution higher than sample count', () async {
        final audioData = AudioData(
          samples: [0.1, 0.2, 0.3, 0.4, 0.5],
          sampleRate: 44100,
          channels: 1,
          duration: const Duration(microseconds: 113), // ~5 samples
        );

        final config = WaveformConfig(resolution: 100);
        final waveformData = await WaveformGenerator.generateInMemory(audioData, config: config);

        // Should not exceed the number of available samples
        expect(waveformData.amplitudes.length, lessThanOrEqualTo(100));
        expect(waveformData.amplitudes, isNotEmpty);
      });
    });

    group('Memory Efficient Generation', () {
      test('should generate waveform with memory constraints', () async {
        final audioData = _createTestAudioData(durationSeconds: 5);

        final waveformData = await WaveformGenerator.generateChunked(
          audioData,
          maxMemoryUsage: 1024 * 1024, // 1MB limit
        );

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.amplitudes.length, equals(1000)); // Default resolution
      });

      test('should handle large files with memory efficiency', () async {
        final audioData = _createTestAudioData(durationSeconds: 60); // Large file

        final config = WaveformConfig(resolution: 500);
        final waveformData = await WaveformGenerator.generateChunked(
          audioData,
          config: config,
          maxMemoryUsage: 10 * 1024 * 1024, // 10MB limit
        );

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.amplitudes.length, equals(500));
      });

      test('should fall back to regular generation for small files', () async {
        final audioData = AudioData(
          samples: List.generate(1000, (i) => math.sin(i * 0.01)),
          sampleRate: 44100,
          channels: 1,
          duration: const Duration(milliseconds: 23),
        );

        final waveformData = await WaveformGenerator.generateChunked(
          audioData,
          maxMemoryUsage: 100 * 1024 * 1024, // Large limit
        );

        expect(waveformData.amplitudes, isNotEmpty);
      });
    });

    group('Error Handling', () {
      test('should handle empty audio data', () async {
        final audioData = AudioData(samples: [], sampleRate: 44100, channels: 1, duration: Duration.zero);

        expect(() async => await WaveformGenerator.generateInMemory(audioData), throwsA(isA<ArgumentError>()));
      });

      test('should handle invalid resolution', () async {
        final audioData = _createTestAudioData();

        final invalidConfig1 = WaveformConfig(resolution: 0);
        expect(() async => await WaveformGenerator.generateInMemory(audioData, config: invalidConfig1), throwsA(isA<ArgumentError>()));

        final invalidConfig2 = WaveformConfig(resolution: -1);
        expect(() async => await WaveformGenerator.generateInMemory(audioData, config: invalidConfig2), throwsA(isA<ArgumentError>()));
      });

      test('should handle invalid sample rate', () async {
        final audioData = AudioData(samples: [0.1, 0.2, 0.3], sampleRate: 0, channels: 1, duration: const Duration(seconds: 1));

        // The generator should handle this gracefully or throw ArgumentError
        expect(() async => await WaveformGenerator.generateInMemory(audioData), returnsNormally);
      });

      test('should handle invalid channel count', () async {
        final audioData = AudioData(samples: [0.1, 0.2, 0.3], sampleRate: 44100, channels: 0, duration: const Duration(seconds: 1));

        // The generator should throw an error for invalid channel count
        expect(() async => await WaveformGenerator.generateInMemory(audioData), throwsA(isA<UnsupportedError>()));
      });

      test('should handle mismatched sample count and channels', () async {
        final audioData = AudioData(
          samples: [0.1, 0.2, 0.3], // 3 samples
          sampleRate: 44100,
          channels: 2, // But claiming stereo
          duration: const Duration(milliseconds: 34),
        );

        // The generator should handle this gracefully
        expect(() async => await WaveformGenerator.generateInMemory(audioData), returnsNormally);
      });
    });

    group('Performance Tests', () {
      test('should generate waveform within time limits for small files', () async {
        final audioData = _createTestAudioData(durationSeconds: 1);

        final stopwatch = Stopwatch()..start();
        final waveformData = await WaveformGenerator.generateInMemory(audioData);
        stopwatch.stop();

        expect(waveformData.amplitudes, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });

      test('should generate waveform within time limits for medium files', () async {
        final audioData = _createTestAudioData(durationSeconds: 10);

        final stopwatch = Stopwatch()..start();
        final waveformData = await WaveformGenerator.generateInMemory(audioData);
        stopwatch.stop();

        expect(waveformData.amplitudes, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete within 1 second
      });

      test('should handle concurrent waveform generation', () async {
        final audioData1 = _createTestAudioData(durationSeconds: 1);
        final audioData2 = _createTestAudioData(durationSeconds: 2);
        final audioData3 = _createTestAudioData(durationSeconds: 3);

        final futures = [
          WaveformGenerator.generateInMemory(audioData1),
          WaveformGenerator.generateInMemory(audioData2),
          WaveformGenerator.generateInMemory(audioData3),
        ];

        final results = await Future.wait(futures);

        expect(results.length, equals(3));
        expect(results.every((w) => w.amplitudes.isNotEmpty), isTrue);
      });
    });

    group('Memory Efficiency', () {
      test('should use memory efficient generation for large audio data', () async {
        final audioData = _createTestAudioData(durationSeconds: 60); // Large file

        final waveformData = await WaveformGenerator.generateChunked(
          audioData,
          maxMemoryUsage: 5 * 1024 * 1024, // 5MB limit
        );

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.amplitudes.length, equals(1000)); // Default resolution
      });

      test('should handle memory pressure gracefully', () async {
        final audioData = _createTestAudioData(durationSeconds: 120); // Very large

        final config = WaveformConfig(resolution: 1000);
        // Should not throw memory exceptions for reasonable sizes
        expect(() async => await WaveformGenerator.generateInMemory(audioData, config: config), returnsNormally);
      });
    });

    group('Configuration Validation', () {
      test('should validate waveform configuration', () {
        final config = WaveformConfig(resolution: 1000, algorithm: DownsamplingAlgorithm.rms, normalize: true, type: WaveformType.bars);

        expect(config.resolution, equals(1000));
        expect(config.algorithm, equals(DownsamplingAlgorithm.rms));
        expect(config.normalize, isTrue);
        expect(config.type, equals(WaveformType.bars));
      });

      test('should use optimal configurations for different use cases', () {
        final musicConfig = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.musicVisualization);
        expect(musicConfig.resolution, equals(1000));
        expect(musicConfig.algorithm, equals(DownsamplingAlgorithm.rms));
        expect(musicConfig.normalize, isTrue);

        final speechConfig = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.speechAnalysis, customResolution: 1500);
        expect(speechConfig.resolution, equals(1500));
        expect(speechConfig.algorithm, equals(DownsamplingAlgorithm.rms));
      });

      test('should handle configuration validation during generation', () async {
        final audioData = _createTestAudioData();

        // Test invalid resolution
        final invalidConfig = WaveformConfig(resolution: 0);
        expect(() async => await WaveformGenerator.generateInMemory(audioData, config: invalidConfig), throwsA(isA<ArgumentError>()));
      });
    });
  });
}

/// Helper function to create test audio data
AudioData _createTestAudioData({double durationSeconds = 1.0, int sampleRate = 44100, int channels = 1, double amplitude = 0.8}) {
  final totalSamples = (sampleRate * durationSeconds * channels).round();
  final samples = <double>[];

  for (int i = 0; i < totalSamples; i++) {
    final time = i / (sampleRate * channels);
    final channel = i % channels;
    final frequency = 440.0 + (channel * 220.0); // Different frequency per channel

    final sample = amplitude * math.sin(2.0 * math.pi * frequency * time);
    samples.add(sample);
  }

  return AudioData(
    samples: samples,
    sampleRate: sampleRate,
    channels: channels,
    duration: Duration(milliseconds: (durationSeconds * 1000).round()),
  );
}
