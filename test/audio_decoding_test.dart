import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'test_data_generator.dart';

void main() {
  group('Audio Decoding Tests', () {
    late Map<String, dynamic> referenceWaveforms;

    setUpAll(() async {
      // Generate test data if it doesn't exist
      if (!await TestDataLoader.assetExists('test_configurations.json')) {
        await TestDataGenerator.generateAllTestData();
      }

      referenceWaveforms = await TestDataLoader.loadReferenceWaveforms();
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

    group('WAV Decoding Accuracy', () {
      test('should decode mono WAV file correctly', () async {
        final filePath = TestDataLoader.getAssetPath('test_mono_44100.wav');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        final audioData = await decoder.decode(filePath);
        final reference = referenceWaveforms['test_mono_44100.wav'];

        expect(audioData.sampleRate, equals(reference['sample_rate']));
        expect(audioData.channels, equals(reference['channels']));
        expect(audioData.duration.inMilliseconds, closeTo(reference['duration_ms'], 50)); // 50ms tolerance
        expect(audioData.samples, isNotEmpty);

        // Verify sample values are within expected range
        expect(audioData.samples.every((s) => s >= -1.0 && s <= 1.0), isTrue);
      });

      test('should decode stereo WAV file correctly', () async {
        final filePath = TestDataLoader.getAssetPath('test_stereo_44100.wav');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        final audioData = await decoder.decode(filePath);
        final reference = referenceWaveforms['test_stereo_44100.wav'];

        expect(audioData.sampleRate, equals(reference['sample_rate']));
        expect(audioData.channels, equals(reference['channels']));
        expect(audioData.duration.inMilliseconds, closeTo(reference['duration_ms'], 50));

        // Stereo should have twice as many samples as mono for same duration
        final expectedSampleCount = reference['sample_rate'] * reference['channels'] * (reference['duration_ms'] / 1000);
        expect(audioData.samples.length, closeTo(expectedSampleCount, expectedSampleCount * 0.1));
      });

      test('should decode different sample rates correctly', () async {
        final filePath = TestDataLoader.getAssetPath('test_mono_48000.wav');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        final audioData = await decoder.decode(filePath);

        expect(audioData.sampleRate, equals(48000));
        expect(audioData.channels, equals(1));
        expect(audioData.samples, isNotEmpty);
      });
    }, skip: 'Native audio decoders not implemented yet');

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

    group('OGG Vorbis Decoding Accuracy', () {
      test('should decode OGG file correctly', () async {
        final filePath = TestDataLoader.getAssetPath('test_sample.ogg');
        if (!await TestDataLoader.assetExists('test_sample.ogg')) {
          return; // Skip if file doesn't exist
        }

        final decoder = AudioDecoderFactory.createDecoder(filePath);
        final audioData = await decoder.decode(filePath);

        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, greaterThan(0));
        expect(audioData.samples, isNotEmpty);
      });
    }, skip: 'Native audio decoders not implemented yet');

    group('Opus Decoding Accuracy', () {
      test('should decode Opus file correctly', () async {
        final filePath = TestDataLoader.getAssetPath('test_sample.opus');
        if (!await TestDataLoader.assetExists('test_sample.opus')) {
          return; // Skip if file doesn't exist
        }

        final decoder = AudioDecoderFactory.createDecoder(filePath);
        final audioData = await decoder.decode(filePath);

        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, greaterThan(0));
        expect(audioData.samples, isNotEmpty);
      });
    }, skip: 'Native audio decoders not implemented yet');

    group('Error Handling', () {
      test('should handle corrupted MP3 header', () async {
        final filePath = TestDataLoader.getAssetPath('corrupted_header.mp3');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        expect(() async => await decoder.decode(filePath), throwsA(isA<DecodingException>()));
      });

      test('should handle corrupted WAV data', () async {
        final filePath = TestDataLoader.getAssetPath('corrupted_data.wav');
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
    }, skip: 'Native audio decoders not implemented yet');

    group('Streaming Decoding', () {
      test('should decode WAV file in chunks', () async {
        final filePath = TestDataLoader.getAssetPath('test_mono_44100.wav');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        final chunks = <AudioChunk>[];
        await for (final chunk in decoder.decodeStream(filePath)) {
          chunks.add(chunk);
          expect(chunk.samples, isNotEmpty);
          expect(chunk.startSample, greaterThanOrEqualTo(0));
        }

        expect(chunks, isNotEmpty);
        expect(chunks.last.isLast, isTrue);

        // Verify total samples match non-streaming decode
        final totalStreamSamples = chunks.fold<int>(0, (sum, chunk) => sum + chunk.samples.length);
        final fullAudioData = await decoder.decode(filePath);
        expect(totalStreamSamples, equals(fullAudioData.samples.length));
      });

      test('should handle streaming errors gracefully', () async {
        final filePath = TestDataLoader.getAssetPath('corrupted_data.wav');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        expect(() async {
          await for (final _ in decoder.decodeStream(filePath)) {
            // Should throw before yielding any chunks
          }
        }, throwsA(isA<DecodingException>()));
      });
    }, skip: 'Native audio decoders not implemented yet');

    group('Memory Management', () {
      test('should properly dispose decoder resources', () async {
        final filePath = TestDataLoader.getAssetPath('test_mono_44100.wav');
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        final audioData = await decoder.decode(filePath);
        expect(audioData.samples, isNotEmpty);

        // Dispose should not throw
        expect(() => decoder.dispose(), returnsNormally);

        // Using decoder after disposal should throw
        expect(() async => await decoder.decode(filePath), throwsA(isA<Exception>()));
      });

      test('should handle multiple dispose calls', () {
        final decoder = AudioDecoderFactory.createDecoder('test.wav');

        expect(() => decoder.dispose(), returnsNormally);
        expect(() => decoder.dispose(), returnsNormally); // Should not throw
      });
    }, skip: 'Native audio decoders not implemented yet');

    group('Concurrent Decoding', () {
      test('should handle multiple simultaneous decoding operations', () async {
        final files = ['test_mono_44100.wav', 'test_stereo_44100.wav', 'test_mono_48000.wav'];

        final futures = files.map((filename) async {
          final filePath = TestDataLoader.getAssetPath(filename);
          final decoder = AudioDecoderFactory.createDecoder(filePath);
          return await decoder.decode(filePath);
        });

        final results = await Future.wait(futures);

        expect(results.length, equals(3));
        expect(results.every((data) => data.samples.isNotEmpty), isTrue);
      });
    }, skip: 'Native audio decoders not implemented yet');
  });
}
