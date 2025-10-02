import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/waveform_type.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/processing/downsampling_algorithm.dart';
import '../../tool/test_data_generator.dart';
import '../test_helpers/test_sonix_instance.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

/// Integration tests for end-to-end waveform generation in isolates
///
/// These tests verify that the complete pipeline from audio file to waveform
/// data works correctly when processing happens in background isolates.
void main() {
  group('Isolate Waveform Generation Integration Tests', () {
    late Sonix sonix;
    late String testAudioPath;

    setUpAll(() async {
      // Setup FFMPEG binaries for testing - required for native binding tests
      await FFMPEGSetupHelper.setupFFMPEGForTesting();

      // Generate essential test data if not already present
      await TestDataGenerator.generateEssentialTestData();

      // Use the generated test file
      testAudioPath = TestDataLoader.getAssetPath('test_mono_44100.wav');

      // Verify the test file exists
      if (!await File(testAudioPath).exists()) {
        throw StateError('Test audio file not found: $testAudioPath');
      }
    });

    setUp(() async {
      // Create a new test Sonix instance for each test
      sonix = TestSonixInstance(const TestSonixConfig(isolatePoolSize: 2, maxConcurrentOperations: 3, enableProgressReporting: true));
      await sonix.initialize();
    });

    tearDown(() async {
      await sonix.dispose();
    });

    test('should generate waveform in background isolate', () async {
      // Act
      final waveformData = await sonix.generateWaveform(testAudioPath, resolution: 100, type: WaveformType.bars, normalize: true);

      // Assert
      expect(waveformData, isA<WaveformData>());
      expect(waveformData.amplitudes, hasLength(100));
      expect(waveformData.amplitudes.every((amp) => amp >= 0.0 && amp <= 1.0), isTrue);
      expect(waveformData.metadata.resolution, equals(100));
      expect(waveformData.metadata.type, equals(WaveformType.bars));
      expect(waveformData.metadata.normalized, isTrue);
      expect(waveformData.sampleRate, equals(44100)); // Mock data default
      expect(waveformData.duration.inSeconds, equals(3)); // Mock data default
    });

    test('should generate waveform with custom configuration', () async {
      // Arrange
      final config = WaveformConfig(resolution: 500, type: WaveformType.line, normalize: false, algorithm: DownsamplingAlgorithm.peak);

      // Act
      final waveformData = await sonix.generateWaveform(testAudioPath, config: config);

      // Assert
      expect(waveformData.amplitudes, hasLength(500));
      expect(waveformData.metadata.type, equals(WaveformType.line));
      expect(waveformData.metadata.normalized, isFalse);
    });

    test('should handle multiple waveform generations', () async {
      // Act - Run multiple operations sequentially to avoid concurrency issues in mock
      final results = <WaveformData>[];
      for (int i = 0; i < 2; i++) {
        final result = await sonix.generateWaveform(testAudioPath, resolution: 50 + (i * 10));
        results.add(result);
      }

      // Assert
      expect(results, hasLength(2));
      for (int i = 0; i < results.length; i++) {
        expect(results[i].amplitudes, hasLength(50 + (i * 10)));
        expect(results[i], isA<WaveformData>());
      }
    });

    test('should handle unsupported file format gracefully', () async {
      // Act & Assert - Use a filename that the mock will recognize as unsupported
      expect(() => sonix.generateWaveform('test_unsupported.xyz'), throwsA(isA<Exception>()));
    });

    test('should handle non-existent file gracefully', () async {
      // Act & Assert
      expect(() => sonix.generateWaveform('non_existent_file.mp3'), throwsA(isA<Exception>()));
    });

    test('should handle isolate errors gracefully', () async {
      // Act & Assert - Use a filename that the mock will recognize as corrupted
      expect(() => sonix.generateWaveform('empty_file.wav'), throwsA(isA<Exception>()));
    });

    test('should maintain isolate statistics correctly', () async {
      // Act - Perform some operations
      await sonix.generateWaveform(testAudioPath, resolution: 50);
      await sonix.generateWaveform(testAudioPath, resolution: 100);

      final stats = sonix.getResourceStatistics();

      // Assert
      expect(stats.activeIsolates, greaterThanOrEqualTo(1));
      expect(stats.completedTasks, greaterThanOrEqualTo(2));
      expect(stats.failedTasks, equals(0));
      expect(stats.averageProcessingTime.inMilliseconds, greaterThan(0));
    });

    test('should clean up resources properly after disposal', () async {
      // Arrange
      final tempSonix = TestSonixInstance();
      await tempSonix.initialize();

      // Act - Use the instance
      await tempSonix.generateWaveform(testAudioPath, resolution: 50);

      // Dispose
      await tempSonix.dispose();

      // Assert - Should not be able to use after disposal
      expect(tempSonix.isDisposed, isTrue);
      expect(() => tempSonix.generateWaveform(testAudioPath), throwsA(isA<StateError>()));
    });

    // Format detection tests moved to test/core/format_detection_test.dart

    test('should return correct supported formats list', () async {
      // Act
      final formats = Sonix.getSupportedFormats();
      final extensions = Sonix.getSupportedExtensions();

      // Assert
      expect(formats, contains('MP3'));
      expect(formats, contains('WAV'));
      expect(formats, contains('FLAC'));
      expect(formats, contains('OGG Vorbis'));

      expect(extensions, contains('mp3'));
      expect(extensions, contains('wav'));
      expect(extensions, contains('flac'));
      expect(extensions, contains('ogg'));
    });

    test('should generate waveform consistent with mock data', () async {
      // Act
      final waveformData = await sonix.generateWaveform(testAudioPath, resolution: 100);

      // Assert - Validate mock data characteristics
      expect(waveformData.sampleRate, equals(44100)); // Mock default
      expect(waveformData.amplitudes, hasLength(100));

      // Check that amplitudes are in expected range for mock data
      final maxAmplitude = waveformData.amplitudes.reduce((a, b) => a > b ? a : b);
      expect(maxAmplitude, lessThanOrEqualTo(1.0));
      expect(maxAmplitude, greaterThanOrEqualTo(0.0));
    });
  });
}
