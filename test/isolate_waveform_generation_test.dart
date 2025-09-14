/// Integration tests for end-to-end waveform generation in isolates
///
/// These tests verify that the complete pipeline from audio file to waveform
/// data works correctly when processing happens in background isolates.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_algorithms.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('Isolate Waveform Generation Integration Tests', () {
    late SonixInstance sonix;
    late String testAudioPath;

    setUpAll(() async {
      // Create a test audio file (simple WAV format for testing)
      testAudioPath = await _createTestAudioFile();
    });

    setUp(() async {
      // Create a new Sonix instance for each test
      sonix = SonixInstance(SonixConfig(isolatePoolSize: 2, maxConcurrentOperations: 3, enableProgressReporting: true));
      await sonix.initialize();
    });

    tearDown(() async {
      await sonix.dispose();
    });

    tearDownAll(() async {
      // Clean up test files
      if (await File(testAudioPath).exists()) {
        await File(testAudioPath).delete();
      }
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
      expect(waveformData.sampleRate, greaterThan(0));
      expect(waveformData.duration.inMilliseconds, greaterThan(0));
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

    test('should handle multiple concurrent waveform generations', () async {
      // Act - Start multiple concurrent operations
      final futures = List.generate(3, (index) => sonix.generateWaveform(testAudioPath, resolution: 50 + (index * 10)));

      final results = await Future.wait(futures);

      // Assert
      expect(results, hasLength(3));
      for (int i = 0; i < results.length; i++) {
        expect(results[i].amplitudes, hasLength(50 + (i * 10)));
        expect(results[i], isA<WaveformData>());
      }
    });

    test('should provide streaming waveform generation with progress updates', () async {
      // Arrange
      final progressUpdates = <WaveformProgress>[];

      // Act
      await for (final progress in sonix.generateWaveformStream(testAudioPath, resolution: 200)) {
        progressUpdates.add(progress);

        if (progress.isComplete) {
          break;
        }
      }

      // Assert
      expect(progressUpdates, isNotEmpty);

      // Check that we received progress updates
      final nonCompleteUpdates = progressUpdates.where((p) => !p.isComplete).toList();
      expect(nonCompleteUpdates, isNotEmpty);

      // Check that progress values are valid
      for (final update in nonCompleteUpdates) {
        expect(update.progress, inInclusiveRange(0.0, 1.0));
        expect(update.statusMessage, isNotNull);
      }

      // Check final result
      final finalUpdate = progressUpdates.last;
      expect(finalUpdate.isComplete, isTrue);
      expect(finalUpdate.progress, equals(1.0));
      expect(finalUpdate.partialData, isA<WaveformData>());
      expect(finalUpdate.partialData!.amplitudes, hasLength(200));
    });

    test('should handle unsupported file format gracefully', () async {
      // Arrange
      final unsupportedFile = await _createUnsupportedFile();

      try {
        // Act & Assert
        expect(() => sonix.generateWaveform(unsupportedFile), throwsA(isA<UnsupportedFormatException>()));
      } finally {
        // Clean up
        if (await File(unsupportedFile).exists()) {
          await File(unsupportedFile).delete();
        }
      }
    });

    test('should handle non-existent file gracefully', () async {
      // Act & Assert
      expect(() => sonix.generateWaveform('non_existent_file.mp3'), throwsA(isA<FileAccessException>()));
    });

    test('should handle isolate errors gracefully', () async {
      // Arrange - Create an empty file that will cause decoding to fail
      final emptyFile = 'test_empty.wav';
      await File(emptyFile).writeAsBytes([]);

      try {
        // Act & Assert
        expect(() => sonix.generateWaveform(emptyFile), throwsA(isA<DecodingException>()));
      } finally {
        // Clean up
        if (await File(emptyFile).exists()) {
          await File(emptyFile).delete();
        }
      }
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
      final tempSonix = SonixInstance();
      await tempSonix.initialize();

      // Act - Use the instance
      await tempSonix.generateWaveform(testAudioPath, resolution: 50);

      // Dispose
      await tempSonix.dispose();

      // Assert - Should not be able to use after disposal
      expect(tempSonix.isDisposed, isTrue);
      expect(() => tempSonix.generateWaveform(testAudioPath), throwsA(isA<StateError>()));
    });

    test('should validate format support correctly', () async {
      // Act & Assert
      expect(Sonix.isFormatSupported('test.wav'), isTrue);
      expect(Sonix.isFormatSupported('test.mp3'), isTrue);
      expect(Sonix.isFormatSupported('test.flac'), isTrue);
      expect(Sonix.isFormatSupported('test.ogg'), isTrue);
      expect(Sonix.isFormatSupported('test.opus'), isTrue);
      expect(Sonix.isFormatSupported('test.xyz'), isFalse);
      expect(Sonix.isFormatSupported('test'), isFalse);
    });

    test('should return correct supported formats list', () async {
      // Act
      final formats = Sonix.getSupportedFormats();
      final extensions = Sonix.getSupportedExtensions();

      // Assert
      expect(formats, contains('MP3'));
      expect(formats, contains('WAV'));
      expect(formats, contains('FLAC'));
      expect(formats, contains('OGG Vorbis'));
      expect(formats, contains('Opus'));

      expect(extensions, contains('mp3'));
      expect(extensions, contains('wav'));
      expect(extensions, contains('flac'));
      expect(extensions, contains('ogg'));
      expect(extensions, contains('opus'));
    });
  });
}

/// Create a simple test audio file (WAV format)
Future<String> _createTestAudioFile() async {
  final fileName = 'test_audio.wav';

  // Create a simple WAV file with sine wave data
  // WAV header (44 bytes) + some sample data
  final header = <int>[
    // RIFF header
    0x52, 0x49, 0x46, 0x46, // "RIFF"
    0x24, 0x08, 0x00, 0x00, // File size - 8 (2084 bytes)
    0x57, 0x41, 0x56, 0x45, // "WAVE"
    // fmt chunk
    0x66, 0x6D, 0x74, 0x20, // "fmt "
    0x10, 0x00, 0x00, 0x00, // Chunk size (16)
    0x01, 0x00, // Audio format (PCM)
    0x01, 0x00, // Number of channels (1)
    0x44, 0xAC, 0x00, 0x00, // Sample rate (44100)
    0x88, 0x58, 0x01, 0x00, // Byte rate
    0x02, 0x00, // Block align
    0x10, 0x00, // Bits per sample (16)
    // data chunk
    0x64, 0x61, 0x74, 0x61, // "data"
    0x00, 0x08, 0x00, 0x00, // Data size (2048 bytes)
  ];

  // Generate some sample audio data (sine wave)
  final sampleData = <int>[];
  for (int i = 0; i < 1024; i++) {
    // Generate 16-bit sine wave samples
    final sample = (32767 * 0.5 * (i / 1024.0)).round();
    sampleData.add(sample & 0xFF); // Low byte
    sampleData.add((sample >> 8) & 0xFF); // High byte
  }

  final fileData = [...header, ...sampleData];
  await File(fileName).writeAsBytes(fileData);

  return fileName;
}

/// Create an unsupported file for testing error handling
Future<String> _createUnsupportedFile() async {
  final fileName = 'test_unsupported.xyz';
  await File(fileName).writeAsString('This is not an audio file');
  return fileName;
}
