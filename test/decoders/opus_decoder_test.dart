// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/opus_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('OpusDecoder Integration Tests', () {
    late OpusDecoder decoder;
    final testFilePath = 'test/assets/Double-F the King - Your Blessing.opus';

    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw StateError(
          'FFMPEG setup failed - Opus decoder tests require FFMPEG DLLs. '
          'These tests validate Opus decoding functionality and '
          'cannot be skipped when FFMPEG is not available.',
        );
      }
    });

    setUp(() {
      decoder = OpusDecoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Basic Decoding', () {
      test('should handle non-existent file gracefully', () async {
        expect(() => decoder.decode('non_existent.opus'), throwsA(isA<FileAccessException>()));
      });

      test('should throw appropriate error for empty file', () async {
        // Create a temporary empty file
        final tempDir = await Directory.systemTemp.createTemp('opus_test_');
        final tempFile = File('${tempDir.path}/empty.opus');
        await tempFile.writeAsBytes([]);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          // Clean up with async deletion to avoid file locks
          try {
            if (await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          } catch (e) {
            print('Cleanup warning (non-critical): $e');
          }
        }
      });

      test('should throw error for invalid Opus data', () async {
        // Create a temporary file with invalid Opus data
        final tempDir = await Directory.systemTemp.createTemp('opus_test_');
        final tempFile = File('${tempDir.path}/invalid.opus');
        await tempFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          // Clean up with async deletion to avoid file locks
          try {
            if (await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          } catch (e) {
            print('Cleanup warning (non-critical): $e');
          }
        }
      });
    });

    group('Test File Processing (if available)', () {
      test('should process test Opus file if available', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          fail('Test file not found: $testFilePath - ensure test assets are properly set up');
        }

        final audioData = await decoder.decode(testFilePath);

        expect(audioData.samples.length, greaterThan(0));
        expect(audioData.sampleRate, greaterThan(0));
        expect(audioData.channels, anyOf(1, 2)); // Mono or stereo
        expect(audioData.duration.inSeconds, greaterThan(10)); // Should be a reasonable length

        print('Opus Decoding Results:');
        print('  Sample count: ${audioData.samples.length}');
        print('  Sample rate: ${audioData.sampleRate} Hz');
        print('  Channels: ${audioData.channels}');
        print('  Duration: ${audioData.duration.inSeconds} seconds');
      });

      test('should handle Opus file with expected audio characteristics', () async {
        final testFile = File(testFilePath);
        if (!testFile.existsSync()) {
          fail('Test file not found: $testFilePath - ensure test assets are properly set up');
        }

        final bytes = await testFile.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(Uint8List.fromList(bytes), AudioFormat.opus);

        // Verify reasonable audio characteristics for a music file
        expect(audioData.sampleRate, anyOf(44100, 48000, 22050, 16000)); // Common sample rates
        expect(audioData.channels, anyOf(1, 2)); // Mono or stereo
        expect(audioData.duration.inSeconds, greaterThan(10)); // Should be a reasonable length song

        // Calculate expected sample count (allowing for small rounding differences)
        final expectedSamples = audioData.channels * (audioData.sampleRate * audioData.duration.inMilliseconds / 1000).round();
        expect(audioData.samples.length, closeTo(expectedSamples, 100)); // Allow small tolerance for rounding

        // Verify Opus compression efficiency
        final compressionRatio = audioData.samples.length / bytes.length;
        expect(compressionRatio, greaterThan(5), reason: 'Opus should have high compression ratio');

        print('Opus compression ratio: ${compressionRatio.toStringAsFixed(2)} samples/byte');
      });
    });

    group('Opus Error Handling', () {
      test('should handle invalid native Opus data gracefully', () async {
        final invalidData = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
        expect(() => NativeAudioBindings.decodeAudio(invalidData, AudioFormat.opus), throwsA(isA<DecodingException>()));
      });

      test('should handle empty native Opus data gracefully', () async {
        final emptyData = Uint8List(0);
        expect(() => NativeAudioBindings.decodeAudio(emptyData, AudioFormat.opus), throwsA(isA<Exception>()));
      });
    });
  });
}
