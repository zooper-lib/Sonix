import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/audio_format_service.dart';

void main() {
  group('AudioFormatService', () {
    group('supportedFormats', () {
      test('should contain all expected formats', () {
        expect(AudioFormatService.supportedFormats, contains(AudioFormat.mp3));
        expect(AudioFormatService.supportedFormats, contains(AudioFormat.wav));
        expect(AudioFormatService.supportedFormats, contains(AudioFormat.flac));
        expect(AudioFormatService.supportedFormats, contains(AudioFormat.ogg));
        expect(AudioFormatService.supportedFormats, contains(AudioFormat.opus));
        expect(AudioFormatService.supportedFormats, contains(AudioFormat.mp4));
      });

      test('should not contain unknown format', () {
        expect(AudioFormatService.supportedFormats, isNot(contains(AudioFormat.unknown)));
      });

      test('should have exactly 6 supported formats', () {
        expect(AudioFormatService.supportedFormats.length, equals(6));
      });
    });

    group('detectFromFilePath', () {
      test('should detect MP3 format', () {
        expect(AudioFormatService.detectFromFilePath('audio.mp3'), equals(AudioFormat.mp3));
        expect(AudioFormatService.detectFromFilePath('path/to/audio.MP3'), equals(AudioFormat.mp3));
        expect(AudioFormatService.detectFromFilePath('/absolute/path/song.Mp3'), equals(AudioFormat.mp3));
      });

      test('should detect WAV format including wave extension', () {
        expect(AudioFormatService.detectFromFilePath('audio.wav'), equals(AudioFormat.wav));
        expect(AudioFormatService.detectFromFilePath('audio.wave'), equals(AudioFormat.wav));
        expect(AudioFormatService.detectFromFilePath('audio.WAV'), equals(AudioFormat.wav));
        expect(AudioFormatService.detectFromFilePath('audio.WAVE'), equals(AudioFormat.wav));
      });

      test('should detect FLAC format', () {
        expect(AudioFormatService.detectFromFilePath('audio.flac'), equals(AudioFormat.flac));
        expect(AudioFormatService.detectFromFilePath('audio.FLAC'), equals(AudioFormat.flac));
      });

      test('should detect OGG format', () {
        expect(AudioFormatService.detectFromFilePath('audio.ogg'), equals(AudioFormat.ogg));
        expect(AudioFormatService.detectFromFilePath('audio.OGG'), equals(AudioFormat.ogg));
      });

      test('should detect Opus format', () {
        expect(AudioFormatService.detectFromFilePath('audio.opus'), equals(AudioFormat.opus));
        expect(AudioFormatService.detectFromFilePath('audio.OPUS'), equals(AudioFormat.opus));
      });

      test('should detect MP4/AAC format including all extensions', () {
        expect(AudioFormatService.detectFromFilePath('audio.mp4'), equals(AudioFormat.mp4));
        expect(AudioFormatService.detectFromFilePath('audio.m4a'), equals(AudioFormat.mp4));
        expect(AudioFormatService.detectFromFilePath('audio.aac'), equals(AudioFormat.mp4));
        expect(AudioFormatService.detectFromFilePath('audio.MP4'), equals(AudioFormat.mp4));
        expect(AudioFormatService.detectFromFilePath('audio.M4A'), equals(AudioFormat.mp4));
        expect(AudioFormatService.detectFromFilePath('audio.AAC'), equals(AudioFormat.mp4));
      });

      test('should return unknown for unsupported extensions', () {
        expect(AudioFormatService.detectFromFilePath('audio.xyz'), equals(AudioFormat.unknown));
        expect(AudioFormatService.detectFromFilePath('audio.txt'), equals(AudioFormat.unknown));
        expect(AudioFormatService.detectFromFilePath('audio.pdf'), equals(AudioFormat.unknown));
      });

      test('should return unknown for empty path', () {
        expect(AudioFormatService.detectFromFilePath(''), equals(AudioFormat.unknown));
      });

      test('should return unknown for path without extension', () {
        expect(AudioFormatService.detectFromFilePath('filename'), equals(AudioFormat.unknown));
        expect(AudioFormatService.detectFromFilePath('/path/to/filename'), equals(AudioFormat.unknown));
      });

      test('should handle files with multiple dots in name', () {
        expect(AudioFormatService.detectFromFilePath('my.audio.file.mp3'), equals(AudioFormat.mp3));
        expect(AudioFormatService.detectFromFilePath('version.1.0.wav'), equals(AudioFormat.wav));
        expect(AudioFormatService.detectFromFilePath('song.final.mix.flac'), equals(AudioFormat.flac));
      });

      test('should handle paths with dots in directory names', () {
        expect(AudioFormatService.detectFromFilePath('/path.with.dots/audio.mp3'), equals(AudioFormat.mp3));
        expect(AudioFormatService.detectFromFilePath('folder.name/subfolder.v2/song.wav'), equals(AudioFormat.wav));
      });
    });

    group('isFileSupported', () {
      test('should return true for supported formats', () {
        expect(AudioFormatService.isFileSupported('audio.mp3'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.wav'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.wave'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.flac'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.ogg'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.opus'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.mp4'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.m4a'), isTrue);
        expect(AudioFormatService.isFileSupported('audio.aac'), isTrue);
      });

      test('should return false for unsupported formats', () {
        expect(AudioFormatService.isFileSupported('audio.xyz'), isFalse);
        expect(AudioFormatService.isFileSupported('audio.txt'), isFalse);
        expect(AudioFormatService.isFileSupported(''), isFalse);
        expect(AudioFormatService.isFileSupported('filename'), isFalse);
      });
    });

    group('isFormatSupported', () {
      test('should return true for all known formats', () {
        expect(AudioFormatService.isFormatSupported(AudioFormat.mp3), isTrue);
        expect(AudioFormatService.isFormatSupported(AudioFormat.wav), isTrue);
        expect(AudioFormatService.isFormatSupported(AudioFormat.flac), isTrue);
        expect(AudioFormatService.isFormatSupported(AudioFormat.ogg), isTrue);
        expect(AudioFormatService.isFormatSupported(AudioFormat.opus), isTrue);
        expect(AudioFormatService.isFormatSupported(AudioFormat.mp4), isTrue);
      });

      test('should return false for unknown format', () {
        expect(AudioFormatService.isFormatSupported(AudioFormat.unknown), isFalse);
      });
    });

    group('getSupportedExtensions', () {
      test('should return all extensions from AudioFormat enum', () {
        final extensions = AudioFormatService.getSupportedExtensions();

        // MP3
        expect(extensions, contains('mp3'));
        // WAV
        expect(extensions, contains('wav'));
        expect(extensions, contains('wave'));
        // FLAC
        expect(extensions, contains('flac'));
        // OGG
        expect(extensions, contains('ogg'));
        // Opus
        expect(extensions, contains('opus'));
        // MP4/AAC
        expect(extensions, contains('mp4'));
        expect(extensions, contains('m4a'));
        expect(extensions, contains('aac'));
      });

      test('should have correct total count of extensions', () {
        final extensions = AudioFormatService.getSupportedExtensions();
        // mp3(1) + wav(2) + flac(1) + ogg(1) + opus(1) + mp4(3) = 9
        expect(extensions.length, equals(9));
      });

      test('should derive from AudioFormat.extensions', () {
        // Verify that getSupportedExtensions matches the enum definitions
        final extensions = AudioFormatService.getSupportedExtensions();
        for (final format in AudioFormatService.supportedFormats) {
          for (final ext in format.extensions) {
            expect(extensions, contains(ext), reason: 'Missing extension $ext for format $format');
          }
        }
      });
    });

    group('getSupportedFormatNames', () {
      test('should return all format names from AudioFormat enum', () {
        final names = AudioFormatService.getSupportedFormatNames();

        expect(names, contains('MP3'));
        expect(names, contains('WAV'));
        expect(names, contains('FLAC'));
        expect(names, contains('OGG Vorbis'));
        expect(names, contains('Opus'));
        expect(names, contains('MP4/AAC'));
      });

      test('should have correct count matching supportedFormats', () {
        final names = AudioFormatService.getSupportedFormatNames();
        expect(names.length, equals(AudioFormatService.supportedFormats.length));
      });

      test('should derive from AudioFormat.name', () {
        final names = AudioFormatService.getSupportedFormatNames();
        for (final format in AudioFormatService.supportedFormats) {
          expect(names, contains(format.name), reason: 'Missing name ${format.name} for format $format');
        }
      });
    });

    group('getFormatForExtension', () {
      test('should return correct format for each extension', () {
        expect(AudioFormatService.getFormatForExtension('mp3'), equals(AudioFormat.mp3));
        expect(AudioFormatService.getFormatForExtension('wav'), equals(AudioFormat.wav));
        expect(AudioFormatService.getFormatForExtension('wave'), equals(AudioFormat.wav));
        expect(AudioFormatService.getFormatForExtension('flac'), equals(AudioFormat.flac));
        expect(AudioFormatService.getFormatForExtension('ogg'), equals(AudioFormat.ogg));
        expect(AudioFormatService.getFormatForExtension('opus'), equals(AudioFormat.opus));
        expect(AudioFormatService.getFormatForExtension('mp4'), equals(AudioFormat.mp4));
        expect(AudioFormatService.getFormatForExtension('m4a'), equals(AudioFormat.mp4));
        expect(AudioFormatService.getFormatForExtension('aac'), equals(AudioFormat.mp4));
      });

      test('should be case-insensitive', () {
        expect(AudioFormatService.getFormatForExtension('MP3'), equals(AudioFormat.mp3));
        expect(AudioFormatService.getFormatForExtension('WAV'), equals(AudioFormat.wav));
        expect(AudioFormatService.getFormatForExtension('FLAC'), equals(AudioFormat.flac));
        expect(AudioFormatService.getFormatForExtension('Mp3'), equals(AudioFormat.mp3));
      });

      test('should return unknown for unsupported extensions', () {
        expect(AudioFormatService.getFormatForExtension('xyz'), equals(AudioFormat.unknown));
        expect(AudioFormatService.getFormatForExtension('txt'), equals(AudioFormat.unknown));
        expect(AudioFormatService.getFormatForExtension(''), equals(AudioFormat.unknown));
      });
    });

    group('Single Source of Truth Verification', () {
      test('getSupportedExtensions should match all format extensions combined', () {
        final serviceExtensions = AudioFormatService.getSupportedExtensions();
        final enumExtensions = <String>[];

        for (final format in AudioFormatService.supportedFormats) {
          enumExtensions.addAll(format.extensions);
        }

        expect(serviceExtensions.toSet(), equals(enumExtensions.toSet()));
      });

      test('getSupportedFormatNames should match all format names', () {
        final serviceNames = AudioFormatService.getSupportedFormatNames();
        final enumNames = AudioFormatService.supportedFormats.map((f) => f.name).toList();

        expect(serviceNames, equals(enumNames));
      });

      test('all extensions in getSupportedExtensions should be detectable', () {
        final extensions = AudioFormatService.getSupportedExtensions();

        for (final ext in extensions) {
          final format = AudioFormatService.getFormatForExtension(ext);
          expect(format, isNot(equals(AudioFormat.unknown)), reason: 'Extension $ext should be detectable');
        }
      });
    });
  });
}
