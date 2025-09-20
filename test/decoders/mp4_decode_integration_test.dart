import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';

void main() {
  group('MP4 Decode Integration Tests', () {
    late MP4Decoder decoder;

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    test('should properly validate and handle MP4 files', () async {
      // Create a valid MP4 container structure
      final validMP4Data = Uint8List.fromList([
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

      final tempDir = Directory.systemTemp.createTempSync('mp4_integration_test_');
      final tempFile = File('${tempDir.path}/valid_mp4.mp4');
      await tempFile.writeAsBytes(validMP4Data);

      try {
        // Should pass container validation but fail at native decoding
        // since MP4 is not yet implemented in the native library
        await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<UnsupportedFormatException>()));
      } finally {
        try {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    });

    test('should reject invalid MP4 containers', () async {
      // Create an invalid MP4 container
      final invalidMP4Data = Uint8List.fromList([
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

      final tempDir = Directory.systemTemp.createTempSync('mp4_invalid_test_');
      final tempFile = File('${tempDir.path}/invalid_mp4.mp4');
      await tempFile.writeAsBytes(invalidMP4Data);

      try {
        // Should fail container validation
        await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<MP4ContainerException>()));
      } finally {
        try {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    });

    test('should handle empty files correctly', () async {
      final tempDir = Directory.systemTemp.createTempSync('mp4_empty_test_');
      final tempFile = File('${tempDir.path}/empty_mp4.mp4');
      await tempFile.writeAsBytes([]);

      try {
        await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
      } finally {
        try {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    });

    test('should handle non-existent files correctly', () async {
      await expectLater(() => decoder.decode('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
    });

    test('should maintain proper decoder state', () {
      // Verify initial state
      expect(decoder.isInitialized, isFalse);
      expect(decoder.currentPosition, equals(Duration.zero));
      expect(decoder.supportsEfficientSeeking, isTrue);

      // Verify format metadata
      final metadata = decoder.getFormatMetadata();
      expect(metadata['format'], equals('MP4/AAC'));
      expect(metadata['supportsSeekTable'], isTrue);
      expect(metadata['seekingAccuracy'], equals('high'));
    });
  });
}
