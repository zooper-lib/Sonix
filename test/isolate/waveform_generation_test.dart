/// Integration tests for isolate infrastructure and communication
///
/// These tests verify the core isolate management, resource tracking, and
/// error handling functionality without focusing on audio processing details.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/sonix_api.dart';
import 'package:sonix/src/config/sonix_config.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import '../test_helpers/test_sonix_instance.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  setUpAll(() async {
    // Setup FFMPEG binaries for testing
    await FFMPEGSetupHelper.setupFFMPEGForTesting();
  });

  group('Isolate Infrastructure Tests', () {
    late Sonix sonix;

    setUp(() async {
      // Create a new test Sonix instance for each test
      sonix = TestSonixInstance(const TestSonixConfig(isolatePoolSize: 1, maxConcurrentOperations: 2, enableProgressReporting: true));
      await sonix.initialize();
    });

    tearDown(() async {
      await sonix.dispose();
    });

    test('should initialize Sonix correctly', () async {
      // Act & Assert
      expect(sonix.isDisposed, isFalse);

      final stats = sonix.getResourceStatistics();
      expect(stats.activeIsolates, greaterThanOrEqualTo(0));
      expect(stats.queuedTasks, equals(0));
      expect(stats.completedTasks, equals(0));
    });

    // Format detection tests moved to test/core/format_detection_test.dart

    test('should return correct supported formats list', () async {
      // Act - Use static methods since these are utility functions
      final formats = Sonix.getSupportedFormats();
      final extensions = Sonix.getSupportedExtensions();

      // Assert
      expect(formats, contains('MP3'));
      expect(formats, contains('WAV'));
      expect(formats, contains('FLAC'));
      expect(formats, contains('OGG Vorbis'));
      expect(formats, contains('MP4/AAC'));

      expect(extensions, contains('mp3'));
      expect(extensions, contains('wav'));
      expect(extensions, contains('flac'));
      expect(extensions, contains('ogg'));
      expect(extensions, contains('mp4'));
    });

    test('should handle isolate task errors gracefully', () async {
      // Act & Assert
      expect(() => sonix.generateWaveform('non_existent_file.mp3'), throwsA(isA<Exception>()));
    });

    test('should handle isolate task with unsupported format', () async {
      // Arrange
      final unsupportedFile = 'test_unsupported.xyz';
      await File(unsupportedFile).writeAsString('This is not an audio file');

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

    test('should prevent isolate operations after disposal', () async {
      // Arrange
      final tempSonix = TestSonixInstance();
      await tempSonix.initialize();

      // Act - Dispose
      await tempSonix.dispose();

      // Assert - Should not be able to use after disposal
      expect(tempSonix.isDisposed, isTrue);
      expect(() => tempSonix.generateWaveform('test.wav'), throwsA(isA<StateError>()));
    });

    test('should maintain isolate statistics correctly during operations', () async {
      // Arrange
      final initialStats = sonix.getResourceStatistics();

      // Act - Try to perform an operation (will fail but should update stats)
      try {
        await sonix.generateWaveform('non_existent.wav');
      } catch (e) {
        // Expected to fail
      }

      final finalStats = sonix.getResourceStatistics();

      // Assert - Stats should be maintained
      expect(finalStats.activeIsolates, greaterThanOrEqualTo(initialStats.activeIsolates));
    });

    test('should create isolate manager with correct configuration', () async {
      // Arrange
      final customConfig = SonixConfig(isolatePoolSize: 3, maxConcurrentOperations: 5, maxMemoryUsage: 200 * 1024 * 1024);

      final customSonix = Sonix(customConfig);

      try {
        await customSonix.initialize();

        // Assert
        expect(customSonix.config.isolatePoolSize, equals(3));
        expect(customSonix.config.maxConcurrentOperations, equals(5));
        expect(customSonix.config.maxMemoryUsage, equals(200 * 1024 * 1024));
      } finally {
        await customSonix.dispose();
      }
    });

    test('should handle multiple dispose calls gracefully', () async {
      // Arrange
      final tempSonix = Sonix();
      await tempSonix.initialize();

      // Act - Dispose multiple times
      await tempSonix.dispose();
      await tempSonix.dispose(); // Should not throw
      await tempSonix.dispose(); // Should not throw

      // Assert
      expect(tempSonix.isDisposed, isTrue);
    });

    test('should optimize resources without errors', () async {
      // Act - Should not throw
      sonix.optimizeResources();

      // Assert - Instance should still be functional
      expect(sonix.isDisposed, isFalse);
      final stats = sonix.getResourceStatistics();
      expect(stats, isNotNull);
    });
  });
}
