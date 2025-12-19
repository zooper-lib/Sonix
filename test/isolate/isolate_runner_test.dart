/// Tests for the IsolateRunner class
///
/// These tests verify that the IsolateRunner correctly spawns isolates,
/// processes audio files, handles errors, and properly reconstructs exceptions.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/isolate/isolate_runner.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/downsampling_algorithm.dart';
import 'package:sonix/src/models/waveform_type.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  setUpAll(() async {
    await FFMPEGSetupHelper.setupFFMPEGForTesting();
  });

  group('IsolateRunner', () {
    late IsolateRunner runner;
    late String testAudioPath;

    setUp(() {
      runner = const IsolateRunner();
      testAudioPath = 'test/assets/test_mono_44100.wav';
    });

    group('constructor', () {
      test('should create instance with const constructor', () {
        const instance = IsolateRunner();
        expect(instance, isA<IsolateRunner>());
      });

      test('should allow multiple instances', () {
        const runner1 = IsolateRunner();
        const runner2 = IsolateRunner();
        expect(runner1, isA<IsolateRunner>());
        expect(runner2, isA<IsolateRunner>());
      });
    });

    group('run', () {
      test('should generate waveform data in background isolate', () async {
        // Arrange
        final config = WaveformConfig(resolution: 100);

        // Act
        final result = await runner.run(testAudioPath, config);

        // Assert
        expect(result, isA<WaveformData>());
        expect(result.amplitudes, hasLength(100));
        expect(result.amplitudes.every((amp) => amp >= 0.0 && amp <= 1.0), isTrue);
      });

      test('should respect resolution parameter', () async {
        // Arrange
        final config1 = WaveformConfig(resolution: 50);
        final config2 = WaveformConfig(resolution: 200);

        // Act
        final result1 = await runner.run(testAudioPath, config1);
        final result2 = await runner.run(testAudioPath, config2);

        // Assert
        expect(result1.amplitudes, hasLength(50));
        expect(result2.amplitudes, hasLength(200));
      });

      test('should respect waveform type', () async {
        // Arrange
        final barsConfig = WaveformConfig(resolution: 100, type: WaveformType.bars);
        final lineConfig = WaveformConfig(resolution: 100, type: WaveformType.line);

        // Act
        final barsResult = await runner.run(testAudioPath, barsConfig);
        final lineResult = await runner.run(testAudioPath, lineConfig);

        // Assert
        expect(barsResult.metadata.type, equals(WaveformType.bars));
        expect(lineResult.metadata.type, equals(WaveformType.line));
      });

      test('should respect normalization setting', () async {
        // Arrange
        final normalizedConfig = WaveformConfig(resolution: 100, normalize: true);
        final unnormalizedConfig = WaveformConfig(resolution: 100, normalize: false);

        // Act
        final normalizedResult = await runner.run(testAudioPath, normalizedConfig);
        final unnormalizedResult = await runner.run(testAudioPath, unnormalizedConfig);

        // Assert
        expect(normalizedResult.metadata.normalized, isTrue);
        expect(unnormalizedResult.metadata.normalized, isFalse);

        // Normalized result should have max amplitude close to 1.0
        if (normalizedResult.amplitudes.isNotEmpty) {
          final maxNormalized = normalizedResult.amplitudes.reduce((a, b) => a > b ? a : b);
          expect(maxNormalized, closeTo(1.0, 0.01));
        }
      });

      test('should respect downsampling algorithm', () async {
        // Arrange
        final rmsConfig = WaveformConfig(resolution: 100, algorithm: DownsamplingAlgorithm.rms);
        final peakConfig = WaveformConfig(resolution: 100, algorithm: DownsamplingAlgorithm.peak);
        final avgConfig = WaveformConfig(resolution: 100, algorithm: DownsamplingAlgorithm.average);

        // Act - all should complete without error
        final rmsResult = await runner.run(testAudioPath, rmsConfig);
        final peakResult = await runner.run(testAudioPath, peakConfig);
        final avgResult = await runner.run(testAudioPath, avgConfig);

        // Assert - all should produce valid waveform data
        expect(rmsResult.amplitudes, hasLength(100));
        expect(peakResult.amplitudes, hasLength(100));
        expect(avgResult.amplitudes, hasLength(100));
      });

      test('should include correct metadata in result', () async {
        // Arrange
        final config = WaveformConfig(resolution: 150, type: WaveformType.bars, normalize: true, algorithm: DownsamplingAlgorithm.rms);

        // Act
        final result = await runner.run(testAudioPath, config);

        // Assert
        expect(result.metadata.resolution, equals(150));
        expect(result.metadata.type, equals(WaveformType.bars));
        expect(result.metadata.normalized, isTrue);
      });

      test('should include audio metadata in result', () async {
        // Arrange
        final config = WaveformConfig(resolution: 100);

        // Act
        final result = await runner.run(testAudioPath, config);

        // Assert
        expect(result.sampleRate, greaterThan(0));
        expect(result.duration, greaterThan(Duration.zero));
      });

      test('should handle concurrent runs', () async {
        // Arrange
        final config = WaveformConfig(resolution: 50);
        const runner1 = IsolateRunner();
        const runner2 = IsolateRunner();
        const runner3 = IsolateRunner();

        // Act - Run multiple isolates concurrently
        final futures = [runner1.run(testAudioPath, config), runner2.run(testAudioPath, config), runner3.run(testAudioPath, config)];
        final results = await Future.wait(futures);

        // Assert - All should complete successfully
        expect(results, hasLength(3));
        for (final result in results) {
          expect(result, isA<WaveformData>());
          expect(result.amplitudes, hasLength(50));
        }
      });
    });

    group('error handling', () {
      test('should throw FileNotFoundException for non-existent file', () async {
        // Arrange
        final config = WaveformConfig(resolution: 100);

        // Act & Assert
        expect(() => runner.run('non_existent_file.mp3', config), throwsA(isA<SonixException>()));
      });

      test('should throw SonixException for invalid format', () async {
        // Arrange
        final config = WaveformConfig(resolution: 100);
        final invalidFile = 'test/assets/invalid_format.xyz';

        // Act & Assert
        expect(() => runner.run(invalidFile, config), throwsA(isA<SonixException>()));
      });

      test('should throw exception for corrupted file', () async {
        // Arrange
        final config = WaveformConfig(resolution: 100);
        final corruptedFile = 'test/assets/corrupted_header.mp3';

        // Skip if file doesn't exist
        if (!await File(corruptedFile).exists()) {
          return;
        }

        // Act & Assert
        expect(() => runner.run(corruptedFile, config), throwsA(isA<SonixException>()));
      });

      test('should throw exception for empty file', () async {
        // Arrange
        final config = WaveformConfig(resolution: 100);
        final emptyFile = 'test/assets/empty_file.mp3';

        // Skip if file doesn't exist
        if (!await File(emptyFile).exists()) {
          return;
        }

        // Act & Assert
        expect(() => runner.run(emptyFile, config), throwsA(isA<SonixException>()));
      });

      test('should preserve stack trace in errors', () async {
        // Arrange
        final config = WaveformConfig(resolution: 100);

        // Act
        try {
          await runner.run('non_existent_file.mp3', config);
          fail('Expected exception to be thrown');
        } catch (e, stackTrace) {
          // Assert
          expect(stackTrace, isNotNull);
          expect(stackTrace.toString(), isNotEmpty);
        }
      });
    });

    group('different audio formats', () {
      test('should process WAV file', () async {
        final config = WaveformConfig(resolution: 100);
        final result = await runner.run('test/assets/test_mono_44100.wav', config);
        expect(result.amplitudes, hasLength(100));
      });

      test('should process MP3 file', () async {
        final mp3File = 'test/assets/Double-F the King - Your Blessing.mp3';
        if (!await File(mp3File).exists()) return;

        final config = WaveformConfig(resolution: 100);
        final result = await runner.run(mp3File, config);
        expect(result.amplitudes, hasLength(100));
      });

      test('should process FLAC file', () async {
        final flacFile = 'test/assets/Double-F the King - Your Blessing.flac';
        if (!await File(flacFile).exists()) return;

        final config = WaveformConfig(resolution: 100);
        final result = await runner.run(flacFile, config);
        expect(result.amplitudes, hasLength(100));
      });

      test('should process OGG file', () async {
        final oggFile = 'test/assets/Double-F the King - Your Blessing.ogg';
        if (!await File(oggFile).exists()) return;

        final config = WaveformConfig(resolution: 100);
        final result = await runner.run(oggFile, config);
        expect(result.amplitudes, hasLength(100));
      });

      test('should process Opus file', () async {
        final opusFile = 'test/assets/Double-F the King - Your Blessing.opus';
        if (!await File(opusFile).exists()) return;

        final config = WaveformConfig(resolution: 100);
        final result = await runner.run(opusFile, config);
        expect(result.amplitudes, hasLength(100));
      });

      test('should process MP4/M4A file', () async {
        final mp4File = 'test/assets/Double-F the King - Your Blessing.mp4';
        if (!await File(mp4File).exists()) return;

        final config = WaveformConfig(resolution: 100);
        final result = await runner.run(mp4File, config);
        expect(result.amplitudes, hasLength(100));
      });
    });

    group('edge cases', () {
      test('should handle very low resolution', () async {
        final config = WaveformConfig(resolution: 1);
        final result = await runner.run(testAudioPath, config);
        expect(result.amplitudes, hasLength(1));
      });

      test('should handle high resolution', () async {
        final config = WaveformConfig(resolution: 5000);
        final result = await runner.run(testAudioPath, config);
        expect(result.amplitudes, hasLength(5000));
      });

      test('should produce deterministic results', () async {
        // Running the same config twice should produce identical results
        final config = WaveformConfig(resolution: 100);

        final result1 = await runner.run(testAudioPath, config);
        final result2 = await runner.run(testAudioPath, config);

        expect(result1.amplitudes, equals(result2.amplitudes));
      });
    });
  });
}
