import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('Audio Decoding Tests', () {
    group('Format Detection', () {
      test('should detect MP3 format correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.mp3'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.MP3'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.mp3'), isTrue);
      });

      test('should detect WAV format correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.wav'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.WAV'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('/path/to/audio.wav'), isTrue);
      });

      test('should detect FLAC format correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.flac'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.FLAC'), isTrue);
      });

      test('should detect OGG format correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.ogg'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.OGG'), isTrue);
      });

      test('should detect MP4 format correctly', () {
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

    group('Format Detection by Content', () {
      test('should detect MP4 format by extension', () {
        // Test MP4 format detection by extension
        expect(AudioDecoderFactory.detectFormat('test.mp4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('test.m4a'), equals(AudioFormat.mp4));
      });

      test('should include MP4 in supported formats list', () {
        final supportedFormats = AudioDecoderFactory.getSupportedFormatNames();
        expect(supportedFormats, contains('MP4/AAC'));

        final supportedExtensions = AudioDecoderFactory.getSupportedExtensions();
        expect(supportedExtensions, contains('mp4'));
        expect(supportedExtensions, contains('m4a'));
      });

      test('should list MP4 format correctly', () {
        final supportedFormats = AudioDecoderFactory.getSupportedFormats();
        expect(supportedFormats, contains(AudioFormat.mp4));
      });

      test('should detect MP4 format with case variations', () {
        final testCases = ['test.mp4', 'test.MP4', 'test.Mp4', 'test.mP4'];
        for (final testCase in testCases) {
          expect(AudioDecoderFactory.detectFormat(testCase), equals(AudioFormat.mp4), reason: 'Failed for case: $testCase');
        }
      });

      test('should detect M4A format with case variations', () {
        final testCases = ['test.m4a', 'test.M4A', 'test.M4a', 'test.m4A'];
        for (final testCase in testCases) {
          expect(AudioDecoderFactory.detectFormat(testCase), equals(AudioFormat.mp4), reason: 'Failed for case: $testCase');
        }
      });

      test('should detect MP4 format with full paths', () {
        final pathCases = ['/home/user/music/song.mp4', 'C:\\Users\\Music\\song.mp4', './relative/path/song.m4a', '../parent/song.MP4', 'song.with.dots.mp4'];
        for (final pathCase in pathCases) {
          expect(AudioDecoderFactory.detectFormat(pathCase), equals(AudioFormat.mp4), reason: 'Failed for path: $pathCase');
        }
      });

      test('should detect other formats by extension', () {
        expect(AudioDecoderFactory.detectFormat('test.mp3'), equals(AudioFormat.mp3));
        expect(AudioDecoderFactory.detectFormat('test.wav'), equals(AudioFormat.wav));
        expect(AudioDecoderFactory.detectFormat('test.flac'), equals(AudioFormat.flac));
        expect(AudioDecoderFactory.detectFormat('test.ogg'), equals(AudioFormat.ogg));
      });

      test('should return unknown for unsupported formats', () {
        expect(AudioDecoderFactory.detectFormat('test.xyz'), equals(AudioFormat.unknown));
        expect(AudioDecoderFactory.detectFormat('test.txt'), equals(AudioFormat.unknown));
        expect(AudioDecoderFactory.detectFormat('test'), equals(AudioFormat.unknown));
      });
    });

    group('Decoder Creation', () {
      test('should create appropriate decoder for each format', () {
        final mp3Decoder = AudioDecoderFactory.createDecoder('test.mp3');
        expect(mp3Decoder.runtimeType.toString(), contains('MP3'));

        final wavDecoder = AudioDecoderFactory.createDecoder('test.wav');
        expect(wavDecoder.runtimeType.toString(), contains('WAV'));

        final flacDecoder = AudioDecoderFactory.createDecoder('test.flac');
        expect(flacDecoder.runtimeType.toString(), contains('FLAC'));

        final oggDecoder = AudioDecoderFactory.createDecoder('test.ogg');
        expect(oggDecoder.runtimeType.toString(), contains('Vorbis'));

        final mp4Decoder = AudioDecoderFactory.createDecoder('test.mp4');
        expect(mp4Decoder.runtimeType.toString(), contains('MP4'));

        final m4aDecoder = AudioDecoderFactory.createDecoder('test.m4a');
        expect(m4aDecoder.runtimeType.toString(), contains('MP4'));
      });

      test('should throw UnsupportedFormatException for unsupported formats', () {
        expect(() => AudioDecoderFactory.createDecoder('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
        expect(() => AudioDecoderFactory.createDecoder('test.txt'), throwsA(isA<UnsupportedFormatException>()));
      });

      test('should dispose decoders properly', () {
        final decoder = AudioDecoderFactory.createDecoder('test.mp3');
        expect(() => decoder.dispose(), returnsNormally);
      });
    });

    group('Supported Formats API', () {
      test('should return all supported extensions', () {
        final extensions = AudioDecoderFactory.getSupportedExtensions();
        expect(extensions, contains('mp3'));
        expect(extensions, contains('wav'));
        expect(extensions, contains('flac'));
        expect(extensions, contains('ogg'));
        expect(extensions, contains('mp4'));
        expect(extensions, contains('m4a'));
        expect(extensions.length, greaterThanOrEqualTo(6));
      });

      test('should return all supported formats', () {
        final formats = AudioDecoderFactory.getSupportedFormats();
        expect(formats, contains(AudioFormat.mp3));
        expect(formats, contains(AudioFormat.wav));
        expect(formats, contains(AudioFormat.flac));
        expect(formats, contains(AudioFormat.ogg));
        expect(formats, contains(AudioFormat.mp4));
        expect(formats.length, equals(5));
      });

      test('should return human-readable format names', () {
        final formatNames = AudioDecoderFactory.getSupportedFormatNames();
        expect(formatNames, contains('MP3'));
        expect(formatNames, contains('WAV'));
        expect(formatNames, contains('FLAC'));
        expect(formatNames, contains('OGG Vorbis'));
        expect(formatNames, contains('MP4/AAC'));
        expect(formatNames.length, equals(5));
      });
    });

    group('AudioFormat Extension Methods', () {
      test('should provide correct extensions for each format', () {
        expect(AudioFormat.mp3.extensions, equals(['mp3']));
        expect(AudioFormat.wav.extensions, equals(['wav']));
        expect(AudioFormat.flac.extensions, equals(['flac']));
        expect(AudioFormat.ogg.extensions, equals(['ogg']));
        expect(AudioFormat.mp4.extensions, equals(['mp4', 'm4a']));
        expect(AudioFormat.unknown.extensions, isEmpty);
      });

      test('should provide correct format names', () {
        expect(AudioFormat.mp3.name, equals('MP3'));
        expect(AudioFormat.wav.name, equals('WAV'));
        expect(AudioFormat.flac.name, equals('FLAC'));
        expect(AudioFormat.ogg.name, equals('OGG Vorbis'));
        expect(AudioFormat.mp4.name, equals('MP4/AAC'));
        expect(AudioFormat.unknown.name, equals('Unknown'));
      });
      test('should indicate chunked processing support', () {
        expect(AudioFormat.mp3.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.wav.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.flac.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.ogg.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.mp4.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.unknown.supportsChunkedProcessing, isFalse);
      });

      test('should provide compression ratios', () {
        expect(AudioFormat.mp3.typicalCompressionRatio, equals(10.0));
        expect(AudioFormat.ogg.typicalCompressionRatio, equals(8.0));
        expect(AudioFormat.mp4.typicalCompressionRatio, equals(10.0));
        expect(AudioFormat.flac.typicalCompressionRatio, equals(2.0));
        expect(AudioFormat.wav.typicalCompressionRatio, equals(1.0));
        expect(AudioFormat.unknown.typicalCompressionRatio, equals(10.0));
      });
    });
  });
}
