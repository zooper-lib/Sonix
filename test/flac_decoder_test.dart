// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/flac_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('FLAC Decoder Tests', () {
    late String testFlacFile;

    setUpAll(() {
      testFlacFile = 'test/assets/test_sample.flac';
    });

    test('should create FLAC decoder from factory', () {
      final decoder = AudioDecoderFactory.createDecoder(testFlacFile);
      expect(decoder, isA<FLACDecoder>());
    });

    test('should detect FLAC format', () {
      final format = AudioDecoderFactory.detectFormat(testFlacFile);
      expect(format, equals(AudioFormat.flac));
    });

    test('should decode FLAC file successfully', () async {
      final file = File(testFlacFile);
      if (!file.existsSync()) {
        markTestSkipped('Test FLAC file not found: $testFlacFile');
        return;
      }

      final decoder = FLACDecoder();
      try {
        final audioData = await decoder.decode(testFlacFile);

        expect(audioData.samples, isNotEmpty);
        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, greaterThan(0));
        expect(audioData.duration.inMilliseconds, greaterThan(0));

        print('FLAC decoded successfully:');
        print('  Sample count: ${audioData.samples.length}');
        print('  Sample rate: ${audioData.sampleRate} Hz');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds} ms');
      } finally {
        decoder.dispose();
      }
    });

    test('should stream FLAC file successfully', () async {
      final file = File(testFlacFile);
      if (!file.existsSync()) {
        markTestSkipped('Test FLAC file not found: $testFlacFile');
        return;
      }

      final decoder = FLACDecoder();
      try {
        int chunkCount = 0;
        int totalSamples = 0;

        await for (final chunk in decoder.decodeStream(testFlacFile)) {
          chunkCount++;
          totalSamples += chunk.samples.length;
          expect(chunk.samples, isNotEmpty);

          if (chunk.isLast) break;
        }

        expect(chunkCount, greaterThan(0));
        expect(totalSamples, greaterThan(0));

        print('FLAC streaming successful:');
        print('  Chunks received: $chunkCount');
        print('  Total samples: $totalSamples');
      } finally {
        decoder.dispose();
      }
    });

    test('should throw exception for non-existent file', () async {
      final decoder = FLACDecoder();
      try {
        expect(() => decoder.decode('non_existent_file.flac'), throwsA(isA<FileAccessException>()));
      } finally {
        decoder.dispose();
      }
    });

    test('should throw exception when disposed', () async {
      final decoder = FLACDecoder();
      decoder.dispose();

      expect(() => decoder.decode(testFlacFile), throwsA(isA<StateError>()));
    });
  });
}
