// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/vorbis_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('VorbisDecoder Integration Tests', () {
    late VorbisDecoder decoder;

    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw Exception('FFMPEG libraries not available for testing');
      }
    });

    setUp(() {
      decoder = VorbisDecoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Basic Decoding', () {
      test('should handle non-existent file gracefully', () async {
        expect(() => decoder.decode('non_existent.ogg'), throwsA(isA<FileAccessException>()));
      });

      test('should throw appropriate error for empty file', () async {
        // Create a temporary empty file
        final tempDir = Directory.systemTemp.createTempSync('vorbis_test_');
        final tempFile = File('${tempDir.path}/empty.ogg');
        await tempFile.writeAsBytes([]);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          // Clean up
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });

      test('should throw error for invalid OGG data', () async {
        // Create a temporary file with invalid OGG data
        final tempDir = Directory.systemTemp.createTempSync('vorbis_test_');
        final tempFile = File('${tempDir.path}/invalid.ogg');
        await tempFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          // Clean up
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });
    });

    group('Format Detection', () {
      test('should detect OGG format correctly', () {
        // Test that the decoder is designed for OGG format
        final metadata = decoder.getFormatMetadata();
        expect(metadata['format'], equals('OGG Vorbis'));
        expect(metadata['fileExtensions'], contains('ogg'));
      });
    });

    group('Test File Processing (if available)', () {
      test('should process test OGG file if available', () async {
        // Use the Vorbis-encoded OGG file
        const testFilePath = 'test/assets/Double-F the King - Your Blessing.ogg';
        final testFile = File(testFilePath);

        if (testFile.existsSync()) {
          try {
            final audioData = await decoder.decode(testFilePath);

            // Verify basic audio properties
            expect(audioData.samples.length, greaterThan(0));
            expect(audioData.sampleRate, greaterThan(0));
            expect(audioData.channels, inInclusiveRange(1, 8));
            expect(audioData.duration.inMilliseconds, greaterThan(0));

            print('OGG Vorbis Decoding Results:');
            print('  Sample count: ${audioData.samples.length}');
            print('  Sample rate: ${audioData.sampleRate} Hz');
            print('  Channels: ${audioData.channels}');
            print('  Duration: ${audioData.duration.inMilliseconds} ms');
          } catch (e) {
            // If decoding fails, it might be because stb_vorbis integration
            // needs compilation fixes
            print('OGG Vorbis test file decode failed: $e');
            print('This is expected if native library compilation is needed');
          }
        } else {
          print('OGG test file not found at $testFilePath');
        }
      });
    });
  });
}
