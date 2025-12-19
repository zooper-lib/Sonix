/// Tests for isolate-based waveform generation
///
/// These tests verify the isolate runner and basic Sonix functionality
/// without focusing on audio processing details.
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

    setUp(() {
      // Create a new test Sonix instance for each test
      sonix = TestSonixInstance();
    });

    tearDown(() {
      sonix.dispose();
    });

    test('should create Sonix correctly', () {
      // Act & Assert
      expect(sonix.isDisposed, isFalse);
      expect(sonix.config, isNotNull);
    });

    test('should return correct supported formats list', () {
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

    test('should handle non-existent file errors', () async {
      // Act & Assert
      expect(() => sonix.generateWaveform('non_existent_file.mp3'), throwsA(isA<Exception>()));
    });

    test('should handle unsupported format', () async {
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

    test('should prevent operations after disposal', () {
      // Arrange
      final tempSonix = TestSonixInstance();

      // Act - Dispose
      tempSonix.dispose();

      // Assert - Should not be able to use after disposal
      expect(tempSonix.isDisposed, isTrue);
      expect(() => tempSonix.generateWaveform('test.wav'), throwsA(isA<StateError>()));
    });

    test('should create Sonix with correct configuration', () {
      // Arrange
      final customConfig = SonixConfig(maxMemoryUsage: 200 * 1024 * 1024);

      final customSonix = Sonix(customConfig);

      try {
        // Assert
        expect(customSonix.config.maxMemoryUsage, equals(200 * 1024 * 1024));
      } finally {
        customSonix.dispose();
      }
    });

    test('should handle multiple dispose calls gracefully', () {
      // Arrange
      final tempSonix = Sonix();

      // Act - Dispose multiple times
      tempSonix.dispose();
      tempSonix.dispose(); // Should not throw
      tempSonix.dispose(); // Should not throw

      // Assert
      expect(tempSonix.isDisposed, isTrue);
    });
  });
}
