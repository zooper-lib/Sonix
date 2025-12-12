import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('Audio Decoding Tests', () {
    // Format detection tests moved to test/core/format_detection_test.dart

    group('Decoder Creation', () {
      test('should create appropriate decoder for each format', () {
        // Use memorySafe: false to get the raw decoder types
        final mp3Decoder = AudioDecoderFactory.createDecoder('test.mp3', memorySafe: false);
        expect(mp3Decoder.runtimeType.toString(), contains('MP3'));

        final wavDecoder = AudioDecoderFactory.createDecoder('test.wav', memorySafe: false);
        expect(wavDecoder.runtimeType.toString(), contains('WAV'));

        final flacDecoder = AudioDecoderFactory.createDecoder('test.flac', memorySafe: false);
        expect(flacDecoder.runtimeType.toString(), contains('FLAC'));

        final oggDecoder = AudioDecoderFactory.createDecoder('test.ogg', memorySafe: false);
        expect(oggDecoder.runtimeType.toString(), contains('Vorbis'));

        final opusDecoder = AudioDecoderFactory.createDecoder('test.opus', memorySafe: false);
        expect(opusDecoder.runtimeType.toString(), contains('Opus'));

        final mp4Decoder = AudioDecoderFactory.createDecoder('test.mp4', memorySafe: false);
        expect(mp4Decoder.runtimeType.toString(), contains('MP4'));

        final m4aDecoder = AudioDecoderFactory.createDecoder('test.m4a', memorySafe: false);
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
        expect(extensions, contains('opus'));
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
        expect(formats, contains(AudioFormat.opus));
        expect(formats, contains(AudioFormat.mp4));
        expect(formats.length, equals(6));
      });

      test('should return human-readable format names', () {
        final formatNames = AudioDecoderFactory.getSupportedFormatNames();
        expect(formatNames, contains('MP3'));
        expect(formatNames, contains('WAV'));
        expect(formatNames, contains('FLAC'));
        expect(formatNames, contains('OGG Vorbis'));
        expect(formatNames, contains('Opus'));
        expect(formatNames, contains('MP4/AAC'));
        expect(formatNames.length, equals(6));
      });
    });

    group('AudioFormat Extension Methods', () {
      test('should provide correct extensions for each format', () {
        expect(AudioFormat.mp3.extensions, equals(['mp3']));
        expect(AudioFormat.wav.extensions, equals(['wav']));
        expect(AudioFormat.flac.extensions, equals(['flac']));
        expect(AudioFormat.ogg.extensions, equals(['ogg']));
        expect(AudioFormat.opus.extensions, equals(['opus']));
        expect(AudioFormat.mp4.extensions, equals(['mp4', 'm4a']));
        expect(AudioFormat.unknown.extensions, isEmpty);
      });

      test('should provide correct format names', () {
        expect(AudioFormat.mp3.name, equals('MP3'));
        expect(AudioFormat.wav.name, equals('WAV'));
        expect(AudioFormat.flac.name, equals('FLAC'));
        expect(AudioFormat.ogg.name, equals('OGG Vorbis'));
        expect(AudioFormat.opus.name, equals('Opus'));
        expect(AudioFormat.mp4.name, equals('MP4/AAC'));
        expect(AudioFormat.unknown.name, equals('Unknown'));
      });
      test('should indicate chunked processing support', () {
        expect(AudioFormat.mp3.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.wav.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.flac.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.ogg.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.opus.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.mp4.supportsChunkedProcessing, isTrue);
        expect(AudioFormat.unknown.supportsChunkedProcessing, isFalse);
      });

      test('should provide compression ratios', () {
        expect(AudioFormat.mp3.typicalCompressionRatio, equals(10.0));
        expect(AudioFormat.ogg.typicalCompressionRatio, equals(8.0));
        expect(AudioFormat.opus.typicalCompressionRatio, equals(12.0));
        expect(AudioFormat.mp4.typicalCompressionRatio, equals(10.0));
        expect(AudioFormat.flac.typicalCompressionRatio, equals(2.0));
        expect(AudioFormat.wav.typicalCompressionRatio, equals(1.0));
        expect(AudioFormat.unknown.typicalCompressionRatio, equals(10.0));
      });
    });
  });
}
