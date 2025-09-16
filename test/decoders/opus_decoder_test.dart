// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/opus_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('OpusDecoder Integration Tests', () {
    late OpusDecoder decoder;

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
        final tempFile = File('temp_empty.opus');
        await tempFile.writeAsBytes([]);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          // Clean up
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        }
      });

      test('should throw error for invalid Opus data', () async {
        // Create a temporary file with invalid Opus data
        final tempFile = File('temp_invalid.opus');
        await tempFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          // Clean up
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        }
      });
    });

    group('Format Detection', () {
      test('should detect Opus format correctly', () {
        // Test that the decoder is designed for Opus format
        final metadata = decoder.getFormatMetadata();
        expect(metadata['format'], equals('Opus'));
        expect(metadata['fileExtensions'], contains('opus'));
        expect(metadata['isImplemented'], isFalse); // Not fully implemented yet
      });
    });

    group('Test File Processing (if available)', () {
      test('should handle test Opus file appropriately', () async {
        const testFilePath = 'test/assets/test_sample.opus';
        final testFile = File(testFilePath);

        if (testFile.existsSync()) {
          // Since Opus is not fully implemented, it should throw an error
          expect(() => decoder.decode(testFilePath), throwsA(isA<DecodingException>()));

          print('Opus test file found at $testFilePath');
          print('Opus decoding correctly throws error (not implemented yet)');
        } else {
          print('Opus test file not found at $testFilePath');
        }
      });

      test('should handle larger Opus test file appropriately', () async {
        const testFilePath = 'test/assets/Double-F the King - Your Blessing.opus';
        final testFile = File(testFilePath);

        if (testFile.existsSync()) {
          // Since Opus is not fully implemented, it should throw an error
          expect(() => decoder.decode(testFilePath), throwsA(isA<DecodingException>()));

          print('Larger Opus test file found at $testFilePath');
          print('Opus decoding correctly throws error (not implemented yet)');
        } else {
          print('Larger Opus test file not found at $testFilePath');
        }
      });
    });

    group('Implementation Status', () {
      test('should clearly indicate not implemented status', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata['implementationStatus'], contains('libopus integration needed'));
        expect(metadata['supportsChunkedDecoding'], isFalse);
        expect(metadata['supportsEfficientSeeking'], isFalse);
      });
    });
  });
}
