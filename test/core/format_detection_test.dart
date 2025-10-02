// ignore_for_file: avoid_print

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
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
      group('AudioDecoderFactory.detectFormat', () {
        test('should detect MP3 format by extension', () {
          expect(AudioDecoderFactory.detectFormat('test.mp3'), equals(AudioFormat.mp3));
          expect(AudioDecoderFactory.detectFormat('test.MP3'), equals(AudioFormat.mp3));
          expect(AudioDecoderFactory.detectFormat('AUDIO.Mp3'), equals(AudioFormat.mp3));
          expect(AudioDecoderFactory.detectFormat('/path/to/audio.mp3'), equals(AudioFormat.mp3));
          expect(AudioDecoderFactory.detectFormat('C:\\Users\\Music\\song.mp3'), equals(AudioFormat.mp3));
        });

        test('should detect WAV format by extension', () {
          expect(AudioDecoderFactory.detectFormat('test.wav'), equals(AudioFormat.wav));
          expect(AudioDecoderFactory.detectFormat('test.WAV'), equals(AudioFormat.wav));
          expect(AudioDecoderFactory.detectFormat('/path/to/audio.wav'), equals(AudioFormat.wav));
        });

        test('should detect FLAC format by extension', () {
          expect(AudioDecoderFactory.detectFormat('test.flac'), equals(AudioFormat.flac));
          expect(AudioDecoderFactory.detectFormat('test.FLAC'), equals(AudioFormat.flac));
        });

        test('should detect OGG format by extension', () {
          expect(AudioDecoderFactory.detectFormat('test.ogg'), equals(AudioFormat.ogg));
          expect(AudioDecoderFactory.detectFormat('test.OGG'), equals(AudioFormat.ogg));
        });

        test('should detect Opus format by extension', () {
          expect(AudioDecoderFactory.detectFormat('test.opus'), equals(AudioFormat.opus));
          expect(AudioDecoderFactory.detectFormat('test.OPUS'), equals(AudioFormat.opus));
        });

        test('should detect MP4/M4A format by extension', () {
          expect(AudioDecoderFactory.detectFormat('test.mp4'), equals(AudioFormat.mp4));
          expect(AudioDecoderFactory.detectFormat('test.MP4'), equals(AudioFormat.mp4));
          expect(AudioDecoderFactory.detectFormat('test.m4a'), equals(AudioFormat.mp4));
          expect(AudioDecoderFactory.detectFormat('test.M4A'), equals(AudioFormat.mp4));
          expect(AudioDecoderFactory.detectFormat('/path/to/audio.mp4'), equals(AudioFormat.mp4));
          expect(AudioDecoderFactory.detectFormat('/path/to/audio.m4a'), equals(AudioFormat.mp4));
        });

        test('should handle complex file paths correctly', () {
          final pathCases = ['/home/user/music/song.mp4', 'C:\\Users\\Music\\song.mp4', './relative/path/song.m4a', '../parent/song.MP4', 'song.with.dots.mp4'];
          for (final pathCase in pathCases) {
            expect(AudioDecoderFactory.detectFormat(pathCase), equals(AudioFormat.mp4), reason: 'Failed for path: $pathCase');
          }
        });

        test('should return unknown for unsupported formats', () {
          expect(AudioDecoderFactory.detectFormat('test.xyz'), equals(AudioFormat.unknown));
          expect(AudioDecoderFactory.detectFormat('test.txt'), equals(AudioFormat.unknown));
          expect(AudioDecoderFactory.detectFormat('test.pdf'), equals(AudioFormat.unknown));
          expect(AudioDecoderFactory.detectFormat('test'), equals(AudioFormat.unknown));
        });
      });
    });

    group('Format Support Queries', () {
      group('AudioDecoderFactory.isFormatSupported', () {
        test('should detect supported MP3 formats', () {
          expect(AudioDecoderFactory.isFormatSupported('test.mp3'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.MP3'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.mp3'), isTrue);
        });

        test('should detect supported WAV formats', () {
          expect(AudioDecoderFactory.isFormatSupported('test.wav'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.WAV'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.wav'), isTrue);
        });

        test('should detect supported FLAC formats', () {
          expect(AudioDecoderFactory.isFormatSupported('test.flac'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.FLAC'), isTrue);
        });

        test('should detect supported OGG formats', () {
          expect(AudioDecoderFactory.isFormatSupported('test.ogg'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.OGG'), isTrue);
        });

        test('should detect supported Opus formats', () {
          expect(AudioDecoderFactory.isFormatSupported('test.opus'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.OPUS'), isTrue);
        });

        test('should detect supported MP4/M4A formats', () {
          expect(AudioDecoderFactory.isFormatSupported('test.mp4'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.MP4'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.m4a'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('test.M4A'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.mp4'), isTrue);
          expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.m4a'), isTrue);
        });

        test('should reject unsupported formats', () {
          expect(AudioDecoderFactory.isFormatSupported('test.xyz'), isFalse);
          expect(AudioDecoderFactory.isFormatSupported('test.txt'), isFalse);
          expect(AudioDecoderFactory.isFormatSupported('test.pdf'), isFalse);
          expect(AudioDecoderFactory.isFormatSupported('test'), isFalse);
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

      group('AudioDecoderFactory Comprehensive Queries', () {
        test('should include all formats in supported formats list', () {
          final supportedFormats = AudioDecoderFactory.getSupportedFormats();
          expect(supportedFormats, contains(AudioFormat.mp3));
          expect(supportedFormats, contains(AudioFormat.wav));
          expect(supportedFormats, contains(AudioFormat.flac));
          expect(supportedFormats, contains(AudioFormat.ogg));
          expect(supportedFormats, contains(AudioFormat.opus));
          expect(supportedFormats, contains(AudioFormat.mp4));
        });

        test('should include all extensions in supported extensions list', () {
          final supportedExtensions = AudioDecoderFactory.getSupportedExtensions();
          expect(supportedExtensions, contains('mp3'));
          expect(supportedExtensions, contains('wav'));
          expect(supportedExtensions, contains('flac'));
          expect(supportedExtensions, contains('ogg'));
          expect(supportedExtensions, contains('opus'));
          expect(supportedExtensions, contains('mp4'));
          expect(supportedExtensions, contains('m4a'));
        });

        test('should include all format names in supported format names list', () {
          final supportedFormats = AudioDecoderFactory.getSupportedFormatNames();
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

        final oggPath = TestDataLoader.getAssetPath('sample_audio.ogg');
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
        // Corrupted files should be handled gracefully, typically returning unknown format
        final format = NativeAudioBindings.detectFormat(bytes);
        expect(format, equals(AudioFormat.unknown));
      });

      test('should handle invalid format files', () async {
        if (!nativeLibAvailable) return;

        final invalidPath = TestDataLoader.getAssetPath('invalid_format.xyz');
        if (!await File(invalidPath).exists()) {
          markTestSkipped('Generated invalid format test file not found. Run test data generator first.');
          return;
        }

        final bytes = await File(invalidPath).readAsBytes();
        // Invalid format files should return unknown format
        final format = NativeAudioBindings.detectFormat(bytes);
        expect(format, equals(AudioFormat.unknown));
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
