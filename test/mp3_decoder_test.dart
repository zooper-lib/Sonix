// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/mp3_decoder.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('MP3 Decoder Tests', () {
    late String testFilePath;

    setUpAll(() {
      // Initialize native bindings before running tests
      NativeAudioBindings.initialize();
      testFilePath = 'test/assets/Double-F the King - Your Blessing.mp3';
    });

    group('Format Detection', () {
      test('should detect MP3 format correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.mp3'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.MP3'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('AUDIO.Mp3'), isTrue);
      });

      test('should create MP3 decoder instance', () {
        final decoder = AudioDecoderFactory.createDecoder('test.mp3');
        expect(decoder, isA<MP3Decoder>());
      });

      test('should detect MP3 format from file content', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test MP3 file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final format = NativeAudioBindings.detectFormat(Uint8List.fromList(bytes));
        expect(format, equals(AudioFormat.mp3));
      });
    });

    group('MP3 File Decoding', () {
      test('should decode MP3 file successfully', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test MP3 file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3);

        // Verify basic audio properties
        expect(audioData.samples.length, greaterThan(0));
        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, inInclusiveRange(1, 2)); // Mono or stereo
        expect(audioData.duration.inMilliseconds, greaterThan(0));

        print('MP3 Decoding Results:');
        print('  File size: ${bytes.length} bytes');
        print('  Sample count: ${audioData.samples.length}');
        print('  Sample rate: ${audioData.sampleRate} Hz');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds} ms');
        print('  Duration: ${(audioData.duration.inMilliseconds / 1000).toStringAsFixed(2)} seconds');
      });

      test('should decode MP3 using decoder class', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test MP3 file not found: $testFilePath');
          return;
        }

        final decoder = MP3Decoder();
        final audioData = await decoder.decode(testFilePath);

        expect(audioData, isA<AudioData>());
        expect(audioData.samples.length, greaterThan(0));
        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, inInclusiveRange(1, 2));

        // Clean up
        decoder.dispose();
      });

      test('should handle MP3 file with expected audio characteristics', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test MP3 file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3);

        // Verify reasonable audio characteristics for a music file
        expect(audioData.sampleRate, anyOf(44100, 48000, 22050, 16000)); // Common sample rates
        expect(audioData.channels, anyOf(1, 2)); // Mono or stereo
        expect(audioData.duration.inSeconds, greaterThan(10)); // Should be a reasonable length song

        // Calculate expected sample count (allowing for small rounding differences)
        final expectedSamples = audioData.channels * (audioData.sampleRate * audioData.duration.inMilliseconds / 1000).round();
        expect(audioData.samples.length, closeTo(expectedSamples, 100)); // Allow small tolerance for rounding
      });
    });

    group('MP3 Error Handling', () {
      test('should handle corrupted MP3 header', () async {
        final corruptedFile = File('test/assets/corrupted_header.mp3');
        if (!corruptedFile.existsSync()) {
          markTestSkipped('Corrupted MP3 test file not found');
          return;
        }

        final bytes = await corruptedFile.readAsBytes();

        expect(() => NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3), throwsA(isA<DecodingException>()));
      });

      test('should handle empty MP3 file', () async {
        final emptyFile = File('test/assets/empty_file.mp3');
        if (!emptyFile.existsSync()) {
          markTestSkipped('Empty MP3 test file not found');
          return;
        }

        final bytes = await emptyFile.readAsBytes();

        expect(() => NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3), throwsA(isA<DecodingException>()));
      });

      test('should handle invalid MP3 data', () {
        final invalidData = Uint8List.fromList([0xFF, 0xFE, 0x01, 0x02]); // Not valid MP3

        expect(() => NativeAudioBindings.decodeAudio(invalidData, AudioFormat.mp3), throwsA(isA<DecodingException>()));
      });

      test('should handle null or empty data', () {
        final emptyData = Uint8List(0);

        expect(() => NativeAudioBindings.decodeAudio(emptyData, AudioFormat.mp3), throwsA(isA<DecodingException>()));
      });
    });

    group('MP3 Audio Quality Validation', () {
      test('should produce valid audio samples', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test MP3 file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3);

        // Check that samples are within valid range [-1.0, 1.0]
        for (int i = 0; i < audioData.samples.length && i < 1000; i++) {
          expect(audioData.samples[i], inInclusiveRange(-1.0, 1.0));
        }

        // Check that not all samples are zero (silence)
        final nonZeroSamples = audioData.samples.where((sample) => sample.abs() > 0.001).length;
        expect(nonZeroSamples, greaterThan(audioData.samples.length * 0.1)); // At least 10% non-silent
      });

      test('should decode consistently on multiple runs', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test MP3 file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();

        // Decode the same file multiple times
        final audioData1 = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3);
        final audioData2 = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3);

        // Results should be identical
        expect(audioData1.sampleRate, equals(audioData2.sampleRate));
        expect(audioData1.channels, equals(audioData2.channels));
        expect(audioData1.samples.length, equals(audioData2.samples.length));
        expect(audioData1.duration.inMilliseconds, equals(audioData2.duration.inMilliseconds));

        // Sample data should be identical (check first 100 samples)
        for (int i = 0; i < 100 && i < audioData1.samples.length; i++) {
          expect(audioData1.samples[i], closeTo(audioData2.samples[i], 0.0001));
        }
      });
    });

    group('MP3 Performance Tests', () {
      test('should decode MP3 file within reasonable time', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test MP3 file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final stopwatch = Stopwatch()..start();

        final audioData = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.mp3);

        stopwatch.stop();

        // Decoding should complete in reasonable time (less than 1 second for most files)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));

        print('MP3 decoding performance:');
        print('  File size: ${bytes.length} bytes');
        print('  Decode time: ${stopwatch.elapsedMilliseconds} ms');
        print('  Samples decoded: ${audioData.samples.length}');
        print('  Decode rate: ${(audioData.samples.length / stopwatch.elapsedMilliseconds * 1000).round()} samples/sec');
      });
    });
  });
}
