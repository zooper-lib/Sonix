// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/ffmpeg_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/models/audio_data.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('WAV Decoding Tests', () {
    late FFmpegDecoder decoder;

    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw Exception('FFMPEG libraries not available for testing');
      }
    });

    setUp(() {
      decoder = FFmpegDecoder(AudioFormat.wav);
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Basic Decoding', () {
      test('should have correct format hint', () {
        expect(decoder.format, equals(AudioFormat.wav));
      });

      test('should decode small WAV file', () async {
        final filePath = 'test/assets/small.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();
        final result = decoder.decode(bytes);

        expect(result, isA<AudioData>());
        expect(result.samples.length, greaterThan(0));
        expect(result.sampleRate, greaterThan(0));
        expect(result.channels, greaterThan(0));

        print(
          'Small WAV decoded: ${result.samples.length} samples, '
          '${result.sampleRate}Hz, ${result.channels} channels',
        );
      });

      test('should decode stereo 44100Hz WAV', () async {
        final filePath = 'test/assets/test_stereo_44100.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();
        final result = decoder.decode(bytes);

        expect(result, isA<AudioData>());
        expect(result.sampleRate, equals(44100));
        expect(result.channels, equals(2));
        expect(result.samples.length, greaterThan(0));

        print(
          'Stereo WAV decoded: ${result.samples.length} samples, '
          '${result.duration}',
        );
      });

      test('should decode mono 44100Hz WAV', () async {
        final filePath = 'test/assets/test_mono_44100.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();
        final result = decoder.decode(bytes);

        expect(result, isA<AudioData>());
        expect(result.sampleRate, equals(44100));
        expect(result.channels, equals(1));
        expect(result.samples.length, greaterThan(0));

        print(
          'Mono WAV decoded: ${result.samples.length} samples, '
          '${result.duration}',
        );
      });

      test('should decode mono 48000Hz WAV', () async {
        final filePath = 'test/assets/test_mono_48000.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();
        final result = decoder.decode(bytes);

        expect(result, isA<AudioData>());
        expect(result.sampleRate, equals(48000));
        expect(result.channels, equals(1));
        expect(result.samples.length, greaterThan(0));

        print(
          'Mono 48kHz WAV decoded: ${result.samples.length} samples, '
          '${result.duration}',
        );
      });
    });

    group('Error Handling', () {
      test('should throw DecodingException for invalid data', () {
        final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);

        expect(() => decoder.decode(invalidBytes), throwsA(isA<DecodingException>()));
      });

      test('should throw DecodingException for empty data', () {
        final emptyBytes = Uint8List(0);

        expect(() => decoder.decode(emptyBytes), throwsA(isA<DecodingException>()));
      });

      test('should handle corrupted WAV data gracefully', () async {
        final filePath = 'test/assets/corrupted_data.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Corrupted test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();

        // Should either decode successfully or throw DecodingException
        // (depends on how recoverable the corruption is)
        try {
          final result = decoder.decode(bytes);
          expect(result, isA<AudioData>());
          print('Corrupted file handled: ${result.samples.length} samples');
        } catch (e) {
          expect(e, isA<DecodingException>());
          print('Corrupted file properly rejected: $e');
        }
      });
    });

    group('Large Files', () {
      test('should decode large WAV file', () async {
        final filePath = 'test/assets/Double-F the King - Your Blessing.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Large test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();
        final result = decoder.decode(bytes);

        expect(result, isA<AudioData>());
        expect(result.samples.length, greaterThan(1000000));
        expect(result.sampleRate, greaterThan(0));
        expect(result.channels, greaterThan(0));
        expect(result.duration.inSeconds, greaterThan(30));

        print(
          'Large WAV decoded: ${result.samples.length} samples, '
          '${result.sampleRate}Hz, ${result.channels} channels, '
          'duration: ${result.duration}',
        );
      });
    });

    group('Sample Validation', () {
      test('should produce valid sample values', () async {
        final filePath = 'test/assets/small.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();
        final result = decoder.decode(bytes);

        // Check that all samples are in valid range [-1.0, 1.0]
        for (final sample in result.samples) {
          expect(sample, greaterThanOrEqualTo(-1.0));
          expect(sample, lessThanOrEqualTo(1.0));
        }
      });

      test('should decode consistently', () async {
        final filePath = 'test/assets/test_short.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();

        // Decode the same data twice
        final result1 = decoder.decode(bytes);
        final result2 = decoder.decode(bytes);

        // Results should be identical
        expect(result1.sampleRate, equals(result2.sampleRate));
        expect(result1.channels, equals(result2.channels));
        expect(result1.samples.length, equals(result2.samples.length));

        // Check first few samples are identical
        final samplesToCheck = result1.samples.length < 100 ? result1.samples.length : 100;
        for (var i = 0; i < samplesToCheck; i++) {
          expect(result1.samples[i], equals(result2.samples[i]));
        }
      });
    });

    group('Dispose', () {
      test('should dispose without error', () {
        decoder.dispose();
        // Should not throw
      });

      test('should allow multiple dispose calls', () {
        decoder.dispose();
        decoder.dispose(); // Should not throw
      });

      test('should still work after dispose (stateless)', () async {
        final filePath = 'test/assets/small.wav';
        final file = File(filePath);

        if (!file.existsSync()) {
          fail('Test WAV file does not exist: $filePath');
        }

        final bytes = await file.readAsBytes();

        // Dispose doesn't affect functionality since decoder is stateless
        decoder.dispose();

        final result = decoder.decode(bytes);
        expect(result, isA<AudioData>());
      });
    });
  });
}
