import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import '../../tools/test_data_generator.dart';

void main() {
  group('Audio Decoding Tests', () {
    setUpAll(() async {
      // Generate essential test data if it doesn't exist (faster)
      if (!await TestDataLoader.assetExists('test_configurations.json')) {
        await TestDataGenerator.generateEssentialTestData();
      }
    });

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

      test('should detect Opus format correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.opus'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.OPUS'), isTrue);
      });

      test('should reject unsupported formats', () {
        expect(AudioDecoderFactory.isFormatSupported('test.xyz'), isFalse);
        expect(AudioDecoderFactory.isFormatSupported('test.txt'), isFalse);
        expect(AudioDecoderFactory.isFormatSupported('test.pdf'), isFalse);
        expect(AudioDecoderFactory.isFormatSupported('test'), isFalse);
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

        final opusDecoder = AudioDecoderFactory.createDecoder('test.opus');
        expect(opusDecoder.runtimeType.toString(), contains('Opus'));
      });

      test('should throw UnsupportedFormatException for unsupported formats', () {
        expect(() => AudioDecoderFactory.createDecoder('test.xyz'), throwsA(isA<UnsupportedFormatException>()));
        expect(() => AudioDecoderFactory.createDecoder('test.txt'), throwsA(isA<UnsupportedFormatException>()));
      });
    });

    group('MP3 Decoding Accuracy', () {
      test('should decode short MP3 file', () async {
        final filePath = TestDataLoader.getAssetPath('test_short.mp3');
        if (!await TestDataLoader.assetExists('test_short.mp3')) {
          return; // Skip if file doesn't exist
        }

        final decoder = AudioDecoderFactory.createDecoder(filePath);
        final audioData = await decoder.decode(filePath);

        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, greaterThan(0));
        expect(audioData.samples, isNotEmpty);
        expect(audioData.duration.inMilliseconds, greaterThan(0));
      });

      test('should decode medium MP3 file', () async {
        final filePath = TestDataLoader.getAssetPath('test_medium.mp3');
        if (!await TestDataLoader.assetExists('test_medium.mp3')) {
          return; // Skip if file doesn't exist
        }

        final decoder = AudioDecoderFactory.createDecoder(filePath);
        final audioData = await decoder.decode(filePath);

        expect(audioData.duration.inSeconds, greaterThan(5));
        expect(audioData.samples.length, greaterThan(44100 * 5)); // At least 5 seconds
      });
    }, skip: 'Native audio decoders not implemented yet');

    group('FLAC Decoding Accuracy', () {
      test('should decode FLAC file correctly', () async {
        final filePath = TestDataLoader.getAssetPath('test_sample.flac');
        if (!await TestDataLoader.assetExists('test_sample.flac')) {
          return; // Skip if file doesn't exist
        }

        final decoder = AudioDecoderFactory.createDecoder(filePath);
        final audioData = await decoder.decode(filePath);

        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, greaterThan(0));
        expect(audioData.samples, isNotEmpty);

        // FLAC should provide lossless quality
        expect(audioData.samples.every((s) => s >= -1.0 && s <= 1.0), isTrue);
      });
    }, skip: 'Native audio decoders not implemented yet');

    group('Error Handling', () {
      test('should handle corrupted MP3 header', () async {
        final filePath = TestDataLoader.getAssetPath('corrupted_header.mp3');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        expect(() async => await decoder.decode(filePath), throwsA(isA<DecodingException>()));
      });

      test('should handle truncated FLAC file', () async {
        final filePath = TestDataLoader.getAssetPath('truncated.flac');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        expect(() async => await decoder.decode(filePath), throwsA(isA<DecodingException>()));
      });

      test('should handle empty file', () async {
        final filePath = TestDataLoader.getAssetPath('empty_file.mp3');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        expect(() async => await decoder.decode(filePath), throwsA(isA<DecodingException>()));
      });

      test('should handle non-existent file', () async {
        final filePath = TestDataLoader.getAssetPath('non_existent.mp3');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        expect(() async => await decoder.decode(filePath), throwsA(isA<FileAccessException>()));
      });
    });
  });
}

