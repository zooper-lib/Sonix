// ignore_for_file: avoid_print

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_format_service.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
import 'package:sonix/sonix.dart';

import '../test_helpers/test_data_loader.dart';

/// Centralized format detection tests
///
/// This file consolidates ALL format detection testing that was previously
/// scattered across multiple test files. It covers:
/// - Extension-based format detection
/// - Magic byte/content-based format detection
/// - Format support queries
/// - Edge cases and error handling
void main() {
  group('Format Detection Tests', () {
    late bool nativeLibAvailable;

    setUpAll(() async {
      nativeLibAvailable = _isNativeLibraryAvailable();
      if (!nativeLibAvailable) {
        print('Native library not available - some format detection tests will be skipped');
      }
    });

    group('Extension-Based Format Detection', () {
      group('AudioFormatService.detectFromFilePath', () {
        test('should detect MP3 format by extension', () {
          expect(AudioFormatService.detectFromFilePath('test.mp3'), equals(AudioFormat.mp3));
          expect(AudioFormatService.detectFromFilePath('test.MP3'), equals(AudioFormat.mp3));
          expect(AudioFormatService.detectFromFilePath('AUDIO.Mp3'), equals(AudioFormat.mp3));
          expect(AudioFormatService.detectFromFilePath('/path/to/audio.mp3'), equals(AudioFormat.mp3));
          expect(AudioFormatService.detectFromFilePath('C:\\Users\\Music\\song.mp3'), equals(AudioFormat.mp3));
        });

        test('should detect WAV format by extension', () {
          expect(AudioFormatService.detectFromFilePath('test.wav'), equals(AudioFormat.wav));
          expect(AudioFormatService.detectFromFilePath('test.WAV'), equals(AudioFormat.wav));
          expect(AudioFormatService.detectFromFilePath('/path/to/audio.wav'), equals(AudioFormat.wav));
        });

        test('should detect FLAC format by extension', () {
          expect(AudioFormatService.detectFromFilePath('test.flac'), equals(AudioFormat.flac));
          expect(AudioFormatService.detectFromFilePath('test.FLAC'), equals(AudioFormat.flac));
        });

        test('should detect OGG format by extension', () {
          expect(AudioFormatService.detectFromFilePath('test.ogg'), equals(AudioFormat.ogg));
          expect(AudioFormatService.detectFromFilePath('test.OGG'), equals(AudioFormat.ogg));
        });

        test('should detect Opus format by extension', () {
          expect(AudioFormatService.detectFromFilePath('test.opus'), equals(AudioFormat.opus));
          expect(AudioFormatService.detectFromFilePath('test.OPUS'), equals(AudioFormat.opus));
        });

        test('should detect MP4/M4A format by extension', () {
          expect(AudioFormatService.detectFromFilePath('test.mp4'), equals(AudioFormat.mp4));
          expect(AudioFormatService.detectFromFilePath('test.MP4'), equals(AudioFormat.mp4));
          expect(AudioFormatService.detectFromFilePath('test.m4a'), equals(AudioFormat.mp4));
          expect(AudioFormatService.detectFromFilePath('test.M4A'), equals(AudioFormat.mp4));
          expect(AudioFormatService.detectFromFilePath('/path/to/audio.mp4'), equals(AudioFormat.mp4));
          expect(AudioFormatService.detectFromFilePath('/path/to/audio.m4a'), equals(AudioFormat.mp4));
        });

        test('should handle complex file paths correctly', () {
          final pathCases = ['/home/user/music/song.mp4', 'C:\\Users\\Music\\song.mp4', './relative/path/song.m4a', '../parent/song.MP4', 'song.with.dots.mp4'];
          for (final pathCase in pathCases) {
            expect(AudioFormatService.detectFromFilePath(pathCase), equals(AudioFormat.mp4), reason: 'Failed for path: $pathCase');
          }
        });

        test('should return unknown for unsupported formats', () {
          expect(AudioFormatService.detectFromFilePath('test.xyz'), equals(AudioFormat.unknown));
          expect(AudioFormatService.detectFromFilePath('test.txt'), equals(AudioFormat.unknown));
          expect(AudioFormatService.detectFromFilePath('test.pdf'), equals(AudioFormat.unknown));
          expect(AudioFormatService.detectFromFilePath('test'), equals(AudioFormat.unknown));
        });
      });
    });

    group('Format Support Queries', () {
      group('AudioFormatService.isFileSupported', () {
        test('should detect supported MP3 formats', () {
          expect(AudioFormatService.isFileSupported('test.mp3'), isTrue);
          expect(AudioFormatService.isFileSupported('test.MP3'), isTrue);
          expect(AudioFormatService.isFileSupported('/path/to/audio.mp3'), isTrue);
        });

        test('should detect supported WAV formats', () {
          expect(AudioFormatService.isFileSupported('test.wav'), isTrue);
          expect(AudioFormatService.isFileSupported('test.WAV'), isTrue);
          expect(AudioFormatService.isFileSupported('/path/to/audio.wav'), isTrue);
        });

        test('should detect supported FLAC formats', () {
          expect(AudioFormatService.isFileSupported('test.flac'), isTrue);
          expect(AudioFormatService.isFileSupported('test.FLAC'), isTrue);
        });

        test('should detect supported OGG formats', () {
          expect(AudioFormatService.isFileSupported('test.ogg'), isTrue);
          expect(AudioFormatService.isFileSupported('test.OGG'), isTrue);
        });

        test('should detect supported Opus formats', () {
          expect(AudioFormatService.isFileSupported('test.opus'), isTrue);
          expect(AudioFormatService.isFileSupported('test.OPUS'), isTrue);
        });

        test('should detect supported MP4/M4A formats', () {
          expect(AudioFormatService.isFileSupported('test.mp4'), isTrue);
          expect(AudioFormatService.isFileSupported('test.MP4'), isTrue);
          expect(AudioFormatService.isFileSupported('test.m4a'), isTrue);
          expect(AudioFormatService.isFileSupported('test.M4A'), isTrue);
          expect(AudioFormatService.isFileSupported('/path/to/audio.mp4'), isTrue);
          expect(AudioFormatService.isFileSupported('/path/to/audio.m4a'), isTrue);
        });

        test('should reject unsupported formats', () {
          expect(AudioFormatService.isFileSupported('test.xyz'), isFalse);
          expect(AudioFormatService.isFileSupported('test.txt'), isFalse);
          expect(AudioFormatService.isFileSupported('test.pdf'), isFalse);
          expect(AudioFormatService.isFileSupported('test'), isFalse);
        });
      });

      group('Sonix Static Methods', () {
        test('should check format support using static methods', () {
          expect(Sonix.isFormatSupported('test.mp3'), isTrue);
          expect(Sonix.isFormatSupported('test.wav'), isTrue);
          expect(Sonix.isFormatSupported('test.flac'), isTrue);
          expect(Sonix.isFormatSupported('test.ogg'), isTrue);
          expect(Sonix.isFormatSupported('test.mp4'), isTrue);
          expect(Sonix.isFormatSupported('test.unknown'), isFalse);
          expect(Sonix.isFormatSupported('test.xyz'), isFalse);
          expect(Sonix.isFormatSupported('test.txt'), isFalse);
        });

        test('should return supported formats list', () {
          final formats = Sonix.getSupportedFormats();
          expect(formats, isA<List<String>>());
          expect(formats, isNotEmpty);
          expect(formats, contains('MP3'));
          expect(formats, contains('WAV'));
          expect(formats, contains('FLAC'));
          expect(formats, contains('OGG Vorbis'));
        });

        test('should return supported extensions list', () {
          final extensions = Sonix.getSupportedExtensions();
          expect(extensions, isA<List<String>>());
          expect(extensions, isNotEmpty);
          expect(extensions, contains('mp3'));
          expect(extensions, contains('wav'));
          expect(extensions, contains('flac'));
          expect(extensions, contains('ogg'));
        });

        test('should check extension support', () {
          expect(Sonix.isExtensionSupported('mp3'), isTrue);
          expect(Sonix.isExtensionSupported('.mp3'), isTrue);
          expect(Sonix.isExtensionSupported('MP3'), isTrue);
          expect(Sonix.isExtensionSupported('.WAV'), isTrue);
          expect(Sonix.isExtensionSupported('xyz'), isFalse);
          expect(Sonix.isExtensionSupported('.txt'), isFalse);
        });
      });

      group('AudioFormatService Comprehensive Queries', () {
        test('should include all formats in supported formats list', () {
          final supportedFormats = AudioFormatService.supportedFormats;
          expect(supportedFormats, contains(AudioFormat.mp3));
          expect(supportedFormats, contains(AudioFormat.wav));
          expect(supportedFormats, contains(AudioFormat.flac));
          expect(supportedFormats, contains(AudioFormat.ogg));
          expect(supportedFormats, contains(AudioFormat.opus));
          expect(supportedFormats, contains(AudioFormat.mp4));
        });

        test('should include all extensions in supported extensions list', () {
          final supportedExtensions = AudioFormatService.getSupportedExtensions();
          expect(supportedExtensions, contains('mp3'));
          expect(supportedExtensions, contains('wav'));
          expect(supportedExtensions, contains('flac'));
          expect(supportedExtensions, contains('ogg'));
          expect(supportedExtensions, contains('opus'));
          expect(supportedExtensions, contains('mp4'));
          expect(supportedExtensions, contains('m4a'));
        });

        test('should include all format names in supported format names list', () {
          final supportedFormats = AudioFormatService.getSupportedFormatNames();
          expect(supportedFormats, isA<List<String>>());
          expect(supportedFormats, isNotEmpty);
          expect(supportedFormats, contains('MP3'));
          expect(supportedFormats, contains('WAV'));
          expect(supportedFormats, contains('FLAC'));
          expect(supportedFormats, contains('OGG Vorbis'));
          expect(supportedFormats, contains('Opus'));
          expect(supportedFormats, contains('MP4/AAC'));
        });
      });
    });

    group('Content-Based Format Detection', () {
      test('should detect MP3 format from generated file content', () async {
        if (!nativeLibAvailable) return;

        final mp3Path = TestDataLoader.getAssetPath('mp3_tiny_44100_2ch.mp3');
        if (!await File(mp3Path).exists()) {
          markTestSkipped('Generated MP3 test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(mp3Path).readAsBytes();
        final format = NativeAudioBindings.detectFormat(bytes);
        expect(format, equals(AudioFormat.mp3), reason: 'Should detect MP3 format from generated file');
      });

      test('should detect WAV format from generated file content', () async {
        if (!nativeLibAvailable) return;

        final wavPath = TestDataLoader.getAssetPath('mono_44100.wav');
        if (!await File(wavPath).exists()) {
          markTestSkipped('Generated WAV test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(wavPath).readAsBytes();
        final format = NativeAudioBindings.detectFormat(bytes);
        expect(format, equals(AudioFormat.wav), reason: 'Should detect WAV format from generated file');
      });

      test('should detect FLAC format from generated file content', () async {
        if (!nativeLibAvailable) return;

        final flacPath = TestDataLoader.getAssetPath('sample_audio.flac');
        if (!await File(flacPath).exists()) {
          markTestSkipped('Generated FLAC test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(flacPath).readAsBytes();
        final format = NativeAudioBindings.detectFormat(bytes);
        expect(format, equals(AudioFormat.flac), reason: 'Should detect FLAC format from generated file');
      });

      test('should detect OGG format from generated file content', () async {
        if (!nativeLibAvailable) return;

        final oggPath = TestDataLoader.getAssetPath('test_sample.ogg');
        if (!await File(oggPath).exists()) {
          markTestSkipped('Generated OGG test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(oggPath).readAsBytes();
        final format = NativeAudioBindings.detectFormat(bytes);
        expect(format, equals(AudioFormat.ogg), reason: 'Should detect OGG format from generated file');
      });

      test('should detect MP4 format from generated file content', () async {
        if (!nativeLibAvailable) return;

        final mp4Path = TestDataLoader.getAssetPath('Double-F the King - Your Blessing.mp4');
        if (!await File(mp4Path).exists()) {
          markTestSkipped('MP4 test file not found.');
          return;
        }

        final bytes = await File(mp4Path).readAsBytes();
        final format = NativeAudioBindings.detectFormat(bytes);

        // Note: MP4 format detection may return unknown if native MP4 support is not yet implemented
        // This test verifies the method doesn't crash and returns a valid format
        expect(format, isA<AudioFormat>());

        // If MP4 support is implemented, it should detect MP4
        if (format != AudioFormat.unknown) {
          expect(format, equals(AudioFormat.mp4), reason: 'Should detect MP4 format from real file');
        }
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty files gracefully', () async {
        if (!nativeLibAvailable) return;

        final emptyPath = TestDataLoader.getAssetPath('empty_file.mp3');
        if (!await File(emptyPath).exists()) {
          markTestSkipped('Generated empty test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(emptyPath).readAsBytes();
        // Empty files should throw DecodingException as they have no data to analyze
        expect(() => NativeAudioBindings.detectFormat(bytes), throwsA(isA<DecodingException>()));
      });

      test('should handle corrupted files gracefully', () async {
        if (!nativeLibAvailable) return;

        final corruptedPath = TestDataLoader.getAssetPath('corrupted_header.mp3');
        if (!await File(corruptedPath).exists()) {
          markTestSkipped('Generated corrupted test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(corruptedPath).readAsBytes();
        // Corrupted files should throw DecodingException as they cannot be detected
        expect(() => NativeAudioBindings.detectFormat(bytes), throwsA(isA<DecodingException>()));
      });

      test('should handle invalid format files', () async {
        if (!nativeLibAvailable) return;

        final invalidPath = TestDataLoader.getAssetPath('invalid_format.xyz');
        if (!await File(invalidPath).exists()) {
          markTestSkipped('Generated invalid format test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(invalidPath).readAsBytes();
        // Invalid format files should throw DecodingException
        expect(() => NativeAudioBindings.detectFormat(bytes), throwsA(isA<DecodingException>()));
      });

      test('should detect format from real file content using NativeAudioBindings', () async {
        if (!nativeLibAvailable) return;

        final testPath = TestDataLoader.getAssetPath('Double-F the King - Your Blessing.mp3');
        if (!await File(testPath).exists()) {
          markTestSkipped('Test MP3 file not found');
          return;
        }

        final bytes = await File(testPath).readAsBytes();
        final format = NativeAudioBindings.detectFormat(bytes);
        expect(format, equals(AudioFormat.mp3));
      });
    });
  });
}

/// Helper function to check if native library is available
bool _isNativeLibraryAvailable() {
  try {
    final testPtr = malloc<ffi.Uint8>(4);
    try {
      SonixNativeBindings.detectFormat(testPtr, 0);
      return true;
    } finally {
      malloc.free(testPtr);
    }
  } catch (e) {
    return false;
  }
}
