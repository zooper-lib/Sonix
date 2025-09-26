// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';

void main() {
  group('MP4 Comprehensive Tests', () {
    late MP4Decoder decoder;

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Real MP4 File Tests', () {
      test('should handle real MP4 file gracefully', () async {
        const testFile = 'test/assets/Double-F the King - Your Blessing.mp4';
        final file = File(testFile);

        if (!file.existsSync()) {
          fail('Test MP4 file not found: $testFile');
        }

        // Since native MP4 support isn't implemented yet, we expect UnsupportedFormatException
        // but the decoder should properly validate the container first
        await expectLater(() => decoder.decode(testFile), throwsA(isA<UnsupportedFormatException>()));

        // Verify the error message indicates MP4 is not yet implemented
        try {
          await decoder.decode(testFile);
          fail('Expected UnsupportedFormatException');
        } catch (e) {
          expect(e, isA<UnsupportedFormatException>());
          expect(e.toString().toLowerCase(), contains('not yet implemented'));
        }
      });

      test('should validate real MP4 file container structure', () async {
        const testFile = 'test/assets/Double-F the King - Your Blessing.mp4';
        final file = File(testFile);

        if (!file.existsSync()) {
          fail('Test MP4 file not found: $testFile');
        }

        // Read first few bytes to verify it's a valid MP4
        final bytes = await file.openRead(0, 12).expand((chunk) => chunk).toList();

        // Should have valid MP4 ftyp signature
        expect(bytes.length, greaterThanOrEqualTo(8));
        expect(bytes[4], equals(0x66)); // 'f'
        expect(bytes[5], equals(0x74)); // 't'
        expect(bytes[6], equals(0x79)); // 'y'
        expect(bytes[7], equals(0x70)); // 'p'

        // The decoder should pass container validation but fail at native decoding
        await expectLater(() => decoder.decode(testFile), throwsA(isA<UnsupportedFormatException>()));
      });

      test('should handle real MP4 file size and memory checks', () async {
        const testFile = 'test/assets/Double-F the King - Your Blessing.mp4';
        final file = File(testFile);

        if (!file.existsSync()) {
          fail('Test MP4 file not found: $testFile');
        }

        final fileSize = await file.length();
        print('MP4 file size: $fileSize bytes');

        // Test memory limit checking with real file
        final originalThreshold = NativeAudioBindings.memoryPressureThreshold;

        try {
          // Set threshold below file size to trigger memory exception
          NativeAudioBindings.setMemoryPressureThreshold(fileSize ~/ 2);

          await expectLater(() => decoder.decode(testFile), throwsA(isA<MemoryException>()));
        } finally {
          NativeAudioBindings.setMemoryPressureThreshold(originalThreshold);
        }
      });
    });

    group('Synthetic MP4 Container Tests', () {
      test('should validate proper MP4 ftyp box', () async {
        // Create synthetic MP4 with valid ftyp box
        final validMP4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // 'ftyp' box type
          0x69, 0x73, 0x6F, 0x6D, // Major brand 'isom'
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand 'isom'
          0x69, 0x73, 0x6F, 0x32, // Compatible brand 'iso2'
          0x61, 0x76, 0x63, 0x31, // Compatible brand 'avc1'
          0x6D, 0x70, 0x34, 0x31, // Compatible brand 'mp41'
          ...List.filled(64, 0x00), // Additional padding
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_test_');
        final tempFile = File('${tempDir.path}/valid_mp4.mp4');
        await tempFile.writeAsBytes(validMP4);

        try {
          // Should pass validation but fail at native decoding
          await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<UnsupportedFormatException>()));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should reject invalid MP4 ftyp box', () async {
        // Create synthetic file with invalid ftyp box
        final invalidMP4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x69, 0x6E, 0x76, 0x64, // 'invd' - invalid box type
          0x69, 0x73, 0x6F, 0x6D, // Data
          0x00, 0x00, 0x02, 0x00,
          0x69, 0x73, 0x6F, 0x6D,
          0x69, 0x73, 0x6F, 0x32,
          0x61, 0x76, 0x63, 0x31,
          0x6D, 0x70, 0x34, 0x31,
          ...List.filled(64, 0x00),
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_test_');
        final tempFile = File('${tempDir.path}/invalid_mp4.mp4');
        await tempFile.writeAsBytes(invalidMP4);

        try {
          await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<MP4ContainerException>()));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should reject files too small to be valid MP4', () async {
        final tooSmall = Uint8List.fromList([0x00, 0x00, 0x00]); // Only 3 bytes

        final tempDir = Directory.systemTemp.createTempSync('mp4_test_');
        final tempFile = File('${tempDir.path}/too_small.mp4');
        await tempFile.writeAsBytes(tooSmall);

        try {
          await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<MP4ContainerException>()));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should handle corrupted MP4 container', () async {
        // Create file with valid signature but corrupted structure
        final corruptedMP4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp' - valid signature
          0xFF, 0xFF, 0xFF, 0xFF, // Corrupted data
          0xFF, 0xFF, 0xFF, 0xFF,
          0xFF, 0xFF, 0xFF, 0xFF,
          0xFF, 0xFF, 0xFF, 0xFF,
          0xFF, 0xFF, 0xFF, 0xFF,
          0xFF, 0xFF, 0xFF, 0xFF,
          ...List.filled(64, 0xFF), // More corrupted data
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_test_');
        final tempFile = File('${tempDir.path}/corrupted_mp4.mp4');
        await tempFile.writeAsBytes(corruptedMP4);

        try {
          // Should pass basic validation but fail at native decoding
          await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<SonixException>()));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should handle different MP4 brand types', () async {
        // Create MP4 with different major brand
        final mp4DifferentBrand = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp'
          0x6D, 0x70, 0x34, 0x31, // Major brand 'mp41'
          0x00, 0x00, 0x00, 0x01, // Minor version
          0x6D, 0x70, 0x34, 0x31, // Compatible brands
          0x69, 0x73, 0x6F, 0x6D,
          0x61, 0x76, 0x63, 0x31,
          0x00, 0x00, 0x00, 0x00,
          ...List.filled(64, 0x00),
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_test_');
        final tempFile = File('${tempDir.path}/different_brand.mp4');
        await tempFile.writeAsBytes(mp4DifferentBrand);

        try {
          // Should still pass validation (different brands are valid)
          await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<UnsupportedFormatException>()));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('Error Handling Tests', () {
      test('should handle non-existent files', () async {
        await expectLater(() => decoder.decode('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
      });

      test('should handle empty files', () async {
        final tempDir = Directory.systemTemp.createTempSync('mp4_test_');
        final tempFile = File('${tempDir.path}/empty.mp4');
        await tempFile.writeAsBytes([]);

        try {
          await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('should handle memory pressure correctly', () async {
        final validMP4 = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp'
          0x69, 0x73, 0x6F, 0x6D, // 'isom'
          0x00, 0x00, 0x02, 0x00,
          0x69, 0x73, 0x6F, 0x6D,
          0x69, 0x73, 0x6F, 0x32,
          0x61, 0x76, 0x63, 0x31,
          0x6D, 0x70, 0x34, 0x31,
          ...List.filled(1024, 0x00), // Make it larger
        ]);

        final tempDir = Directory.systemTemp.createTempSync('mp4_test_');
        final tempFile = File('${tempDir.path}/memory_test.mp4');
        await tempFile.writeAsBytes(validMP4);

        try {
          // Set very low memory threshold
          final originalThreshold = NativeAudioBindings.memoryPressureThreshold;
          NativeAudioBindings.setMemoryPressureThreshold(100);

          try {
            await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<MemoryException>()));
          } finally {
            NativeAudioBindings.setMemoryPressureThreshold(originalThreshold);
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('Decoder State Management', () {
      test('should maintain proper state during operations', () {
        // Initial state
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));
        expect(decoder.supportsEfficientSeeking, isTrue);

        // Format metadata
        final metadata = decoder.getFormatMetadata();
        expect(metadata['format'], equals('MP4/AAC'));
        expect(metadata['supportsSeekTable'], isTrue);
        expect(metadata['seekingAccuracy'], equals('high'));
        expect(metadata['avgFrameSize'], equals(768));
      });

      test('should handle disposal correctly', () {
        decoder.dispose();
        expect(() => decoder.decode('test.mp4'), throwsStateError);
        expect(() => decoder.currentPosition, throwsStateError);
        expect(() => decoder.getFormatMetadata(), throwsStateError);
      });

      test('should maintain state after failed decode attempts', () async {
        // Try to decode a non-existent file
        try {
          await decoder.decode('non_existent.mp4');
        } catch (e) {
          // Expected to fail
        }

        // Decoder should still be usable
        expect(decoder.currentPosition, equals(Duration.zero));
        expect(decoder.isInitialized, isFalse);
        expect(() => decoder.getFormatMetadata(), returnsNormally);
      });
    });

    group('Integration with AudioDecoderFactory', () {
      test('should be created by factory for MP4 files', () {
        final decoder1 = AudioDecoderFactory.createDecoder('test.mp4');
        final decoder2 = AudioDecoderFactory.createDecoder('test.m4a');

        expect(decoder1, isA<MP4Decoder>());
        expect(decoder2, isA<MP4Decoder>());

        decoder1.dispose();
        decoder2.dispose();
      });

      test('should be detected by format detection', () {
        expect(AudioDecoderFactory.detectFormat('test.mp4'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.detectFormat('test.m4a'), equals(AudioFormat.mp4));
        expect(AudioDecoderFactory.isFormatSupported('test.mp4'), isTrue);
        expect(AudioDecoderFactory.isFormatSupported('test.m4a'), isTrue);
      });

      test('should be included in supported formats', () {
        final supportedFormats = AudioDecoderFactory.getSupportedFormats();
        final supportedExtensions = AudioDecoderFactory.getSupportedExtensions();
        final supportedNames = AudioDecoderFactory.getSupportedFormatNames();

        expect(supportedFormats, contains(AudioFormat.mp4));
        expect(supportedExtensions, contains('mp4'));
        expect(supportedExtensions, contains('m4a'));
        expect(supportedNames, contains('MP4/AAC'));
      });
    });
  });
}
