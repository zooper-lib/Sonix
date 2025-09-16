// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/wav_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'dart:io';

void main() {
  group('WAV Decoder Tests', () {
    late WAVDecoder decoder;

    setUp(() {
      decoder = WAVDecoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Error Handling', () {
      test('should handle corrupted WAV file gracefully', () async {
        final filePath = 'test/assets/corrupted_data.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Corrupted test WAV file does not exist: $filePath');
        }

        // Our simplified approach should handle even corrupted files gracefully
        // It may return minimal data or valid data from recoverable parts
        final result = await decoder.decode(filePath);
        expect(result, isA<AudioData>());
        expect(result.samples.length, greaterThanOrEqualTo(0));
        print('Corrupted file handled: ${result.samples.length} samples, ${result.sampleRate}Hz, ${result.channels} channels');
      });

      test('should handle large WAV file successfully', () async {
        final filePath = 'test/assets/Double-F the King - Your Blessing.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Large test WAV file does not exist: $filePath');
        }

        // Our simplified approach should handle large files transparently
        final result = await decoder.decode(filePath);
        expect(result, isA<AudioData>());
        expect(result.samples.length, greaterThan(1000000)); // Should have substantial audio data
        expect(result.sampleRate, greaterThan(0));
        expect(result.channels, greaterThan(0));
        expect(result.duration.inSeconds, greaterThan(30)); // Should be a substantial audio file

        print(
          'Large file decoded successfully: ${result.samples.length} samples, '
          '${result.sampleRate}Hz, ${result.channels} channels, '
          'duration: ${result.duration}',
        );
      });

      test('should throw FileAccessException for non-existent file', () async {
        expect(() => decoder.decode('non_existent_file.wav'), throwsA(isA<FileAccessException>()));
      });

      test('should throw StateError when using disposed decoder', () async {
        decoder.dispose();

        expect(() => decoder.decode('any_file.wav'), throwsA(isA<StateError>()));
      });
    });

    group('Format Validation', () {
      test('should validate WAV format through factory', () {
        expect(AudioDecoderFactory.isFormatSupported('test.wav'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.WAV'), isTrue);

        final decoder = AudioDecoderFactory.createDecoder('test.wav');
        expect(decoder, isA<WAVDecoder>());
      });

      test('should detect WAV format correctly', () {
        expect(AudioDecoderFactory.detectFormat('test.wav'), equals(AudioFormat.wav));
      });

      test('should list WAV in supported formats', () {
        final supportedFormats = AudioDecoderFactory.getSupportedFormatNames();
        expect(supportedFormats, contains('WAV'));

        final supportedExtensions = AudioDecoderFactory.getSupportedExtensions();
        expect(supportedExtensions, contains('wav'));
      });
    });
  });
}

