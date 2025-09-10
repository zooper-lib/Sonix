import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/decoders/flac_decoder.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('FLAC Decoder Tests', () {
    late String testFilePath;

    setUpAll(() {
      // Initialize native bindings before running tests
      NativeAudioBindings.initialize();
      testFilePath = 'test/assets/Double-F the King - Your Blessing.flac';
    });

    group('Format Detection', () {
      test('should detect FLAC format correctly', () {
        expect(AudioDecoderFactory.isFormatSupported('test.flac'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.FLAC'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('AUDIO.Flac'), isTrue);
      });

      test('should create FLAC decoder instance', () {
        final decoder = AudioDecoderFactory.createDecoder('test.flac');
        expect(decoder, isA<FLACDecoder>());
      });

      test('should detect FLAC format from file content', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final format = NativeAudioBindings.detectFormat(Uint8List.fromList(bytes));
        expect(format, equals(AudioFormat.flac));
      });

      test('should verify FLAC signature in file', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        
        // FLAC files should start with "fLaC" signature (0x66 0x4C 0x61 0x43)
        expect(bytes.length, greaterThan(4));
        expect(bytes[0], equals(0x66)); // 'f'
        expect(bytes[1], equals(0x4C)); // 'L'
        expect(bytes[2], equals(0x61)); // 'a'
        expect(bytes[3], equals(0x43)); // 'C'
        
        print('FLAC signature verified: ${bytes.take(4).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      });
    });

    group('FLAC File Decoding', () {
      test('should decode FLAC file successfully', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(
          Uint8List.fromList(bytes),
          AudioFormat.flac,
        );

        // Verify basic audio properties
        expect(audioData.samples.length, greaterThan(0));
        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, inInclusiveRange(1, 2)); // Mono or stereo
        expect(audioData.duration.inMilliseconds, greaterThan(0));

        print('FLAC Decoding Results:');
        print('  File size: ${bytes.length} bytes');
        print('  Sample count: ${audioData.samples.length}');
        print('  Sample rate: ${audioData.sampleRate} Hz');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inMilliseconds} ms');
        print('  Duration: ${(audioData.duration.inMilliseconds / 1000).toStringAsFixed(2)} seconds');
      });

      test('should decode FLAC using decoder class', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final decoder = FLACDecoder();
        final audioData = await decoder.decode(testFilePath);

        expect(audioData, isA<AudioData>());
        expect(audioData.samples.length, greaterThan(0));
        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, inInclusiveRange(1, 2));
        
        // Clean up
        decoder.dispose();
      });

      test('should handle FLAC file with expected audio characteristics', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(
          Uint8List.fromList(bytes),
          AudioFormat.flac,
        );

        // Verify reasonable audio characteristics for a music file
        expect(audioData.sampleRate, anyOf(44100, 48000, 96000, 192000, 22050, 16000)); // Common sample rates
        expect(audioData.channels, anyOf(1, 2)); // Mono or stereo
        expect(audioData.duration.inSeconds, greaterThan(10)); // Should be a reasonable length song
        
        // Calculate expected sample count (allowing for small rounding differences)
        final expectedSamples = audioData.channels * (audioData.sampleRate * audioData.duration.inMilliseconds / 1000).round();
        expect(audioData.samples.length, closeTo(expectedSamples, 100)); // Allow small tolerance for rounding
      });
    });

    group('FLAC vs MP3 Comparison', () {
      test('should decode FLAC and MP3 versions with similar characteristics', () async {
        final flacFile = File(testFilePath);
        final mp3File = File('test/assets/Double-F the King - Your Blessing.mp3');
        
        if (!flacFile.existsSync() || !mp3File.existsSync()) {
          markTestSkipped('Test files not found for comparison');
          return;
        }

        // Decode both files
        final flacBytes = await flacFile.readAsBytes();
        final mp3Bytes = await mp3File.readAsBytes();
        
        final flacData = NativeAudioBindings.decodeAudio(Uint8List.fromList(flacBytes), AudioFormat.flac);
        final mp3Data = NativeAudioBindings.decodeAudio(Uint8List.fromList(mp3Bytes), AudioFormat.mp3);

        // Should have similar characteristics (same source material)
        // Note: Sample rates might differ between formats due to different encoding settings
        expect(flacData.sampleRate, anyOf(44100, 48000, 96000)); // Common sample rates
        expect(mp3Data.sampleRate, anyOf(44100, 48000)); // MP3 common sample rates
        expect(flacData.channels, equals(mp3Data.channels)); // Should be same channels
        
        // Duration should be very close (within 1 second)
        final durationDiff = (flacData.duration.inMilliseconds - mp3Data.duration.inMilliseconds).abs();
        expect(durationDiff, lessThan(1000));

        print('FLAC vs MP3 Comparison:');
        print('  FLAC file size: ${flacBytes.length} bytes');
        print('  MP3 file size: ${mp3Bytes.length} bytes');
        print('  FLAC samples: ${flacData.samples.length}');
        print('  MP3 samples: ${mp3Data.samples.length}');
        print('  FLAC duration: ${flacData.duration.inMilliseconds} ms');
        print('  MP3 duration: ${mp3Data.duration.inMilliseconds} ms');
        print('  Compression ratio: ${(flacBytes.length / mp3Bytes.length).toStringAsFixed(2)}x');
      });
    });

    group('FLAC Error Handling', () {
      test('should handle truncated FLAC file', () async {
        final truncatedFile = File('test/assets/truncated.flac');
        if (!truncatedFile.existsSync()) {
          markTestSkipped('Truncated FLAC test file not found');
          return;
        }

        final bytes = await truncatedFile.readAsBytes();
        
        expect(
          () => NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.flac),
          throwsA(isA<DecodingException>()),
        );
      });

      test('should handle invalid FLAC signature', () {
        final invalidData = Uint8List.fromList([0x66, 0x4C, 0x61, 0x00]); // Invalid last byte
        
        expect(
          () => NativeAudioBindings.decodeAudio(invalidData, AudioFormat.flac),
          throwsA(isA<DecodingException>()),
        );
      });

      test('should handle null or empty data', () {
        final emptyData = Uint8List(0);
        
        expect(
          () => NativeAudioBindings.decodeAudio(emptyData, AudioFormat.flac),
          throwsA(isA<DecodingException>()),
        );
      });

      test('should handle corrupted FLAC metadata', () {
        // Create data with valid signature but corrupted metadata
        final corruptedData = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // Valid FLAC signature
          0xFF, 0xFF, 0xFF, 0xFF, // Corrupted metadata block
          0x00, 0x00, 0x00, 0x00,
        ]);
        
        expect(
          () => NativeAudioBindings.decodeAudio(corruptedData, AudioFormat.flac),
          throwsA(isA<DecodingException>()),
        );
      });
    });

    group('FLAC Audio Quality Validation', () {
      test('should produce valid audio samples', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(
          Uint8List.fromList(bytes),
          AudioFormat.flac,
        );

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
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        
        // Decode the same file multiple times
        final audioData1 = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.flac);
        final audioData2 = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.flac);

        // Results should be identical (FLAC is lossless)
        expect(audioData1.sampleRate, equals(audioData2.sampleRate));
        expect(audioData1.channels, equals(audioData2.channels));
        expect(audioData1.samples.length, equals(audioData2.samples.length));
        expect(audioData1.duration.inMilliseconds, equals(audioData2.duration.inMilliseconds));

        // Sample data should be identical for lossless format
        for (int i = 0; i < 100 && i < audioData1.samples.length; i++) {
          expect(audioData1.samples[i], equals(audioData2.samples[i]));
        }
      });

      test('should demonstrate lossless quality vs MP3', () async {
        final flacFile = File(testFilePath);
        final mp3File = File('test/assets/Double-F the King - Your Blessing.mp3');
        
        if (!flacFile.existsSync() || !mp3File.existsSync()) {
          markTestSkipped('Test files not found for quality comparison');
          return;
        }

        final flacBytes = await flacFile.readAsBytes();
        final mp3Bytes = await mp3File.readAsBytes();
        
        final flacData = NativeAudioBindings.decodeAudio(Uint8List.fromList(flacBytes), AudioFormat.flac);
        final mp3Data = NativeAudioBindings.decodeAudio(Uint8List.fromList(mp3Bytes), AudioFormat.mp3);

        // FLAC should typically have higher bit depth precision
        // This is demonstrated by file size difference
        expect(flacBytes.length, greaterThan(mp3Bytes.length));
        
        print('Quality Comparison:');
        print('  FLAC file: ${flacBytes.length} bytes (lossless)');
        print('  MP3 file: ${mp3Bytes.length} bytes (lossy)');
        print('  Size ratio: ${(flacBytes.length / mp3Bytes.length).toStringAsFixed(2)}x larger');
        print('  FLAC samples: ${flacData.samples.length}');
        print('  MP3 samples: ${mp3Data.samples.length}');
      });
    });

    group('FLAC Performance Tests', () {
      test('should decode FLAC file within reasonable time', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          markTestSkipped('Test FLAC file not found: $testFilePath');
          return;
        }

        final bytes = await testFile.readAsBytes();
        final stopwatch = Stopwatch()..start();
        
        final audioData = NativeAudioBindings.decodeAudio(
          Uint8List.fromList(bytes),
          AudioFormat.flac,
        );
        
        stopwatch.stop();
        
        // FLAC decoding should complete in reasonable time (may be slower than MP3 due to lossless)
        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // Allow more time for lossless decoding
        
        print('FLAC decoding performance:');
        print('  File size: ${bytes.length} bytes');
        print('  Decode time: ${stopwatch.elapsedMilliseconds} ms');
        print('  Samples decoded: ${audioData.samples.length}');
        print('  Decode rate: ${(audioData.samples.length / stopwatch.elapsedMilliseconds * 1000).round()} samples/sec');
      });

      test('should compare FLAC vs MP3 decoding performance', () async {
        final flacFile = File(testFilePath);
        final mp3File = File('test/assets/Double-F the King - Your Blessing.mp3');
        
        if (!flacFile.existsSync() || !mp3File.existsSync()) {
          markTestSkipped('Test files not found for performance comparison');
          return;
        }

        final flacBytes = await flacFile.readAsBytes();
        final mp3Bytes = await mp3File.readAsBytes();

        // Time FLAC decoding
        final flacStopwatch = Stopwatch()..start();
        final flacData = NativeAudioBindings.decodeAudio(Uint8List.fromList(flacBytes), AudioFormat.flac);
        flacStopwatch.stop();

        // Time MP3 decoding
        final mp3Stopwatch = Stopwatch()..start();
        final mp3Data = NativeAudioBindings.decodeAudio(Uint8List.fromList(mp3Bytes), AudioFormat.mp3);
        mp3Stopwatch.stop();

        print('Performance Comparison:');
        print('  FLAC decode time: ${flacStopwatch.elapsedMilliseconds} ms');
        print('  MP3 decode time: ${mp3Stopwatch.elapsedMilliseconds} ms');
        print('  FLAC samples/sec: ${(flacData.samples.length / flacStopwatch.elapsedMilliseconds * 1000).round()}');
        print('  MP3 samples/sec: ${(mp3Data.samples.length / mp3Stopwatch.elapsedMilliseconds * 1000).round()}');
        
        // Both should complete within reasonable time
        expect(flacStopwatch.elapsedMilliseconds, lessThan(2000));
        expect(mp3Stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}
