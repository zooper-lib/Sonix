import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunk_boundary.dart';
import 'package:sonix/src/processing/wav_chunk_parser.dart';

void main() {
  group('WAVChunkParser', () {
    late WAVChunkParser parser;

    setUp(() {
      parser = WAVChunkParser();
    });

    group('parseChunkBoundaries', () {
      test('should detect RIFF header with WAVE format', () {
        final data = Uint8List.fromList([
          // RIFF header
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x08, 0x00, 0x00, // File size (2084 bytes)
          0x57, 0x41, 0x56, 0x45, // "WAVE"
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final riffBoundaries = boundaries.where((b) => b.metadata?['type'] == 'RIFF_HEADER').toList();
        expect(riffBoundaries.length, equals(1));
        expect(riffBoundaries.first.metadata?['format'], equals('WAVE'));
        expect(riffBoundaries.first.metadata?['fileSize'], equals(2084));
        expect(riffBoundaries.first.isSeekable, isFalse);
      });

      test('should detect WAV chunk headers', () {
        final data = Uint8List.fromList([
          // Format chunk
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // Chunk size (16 bytes)
          // Data chunk
          0x64, 0x61, 0x74, 0x61, // "data"
          0x00, 0x08, 0x00, 0x00, // Chunk size (2048 bytes)
        ]);

        final chunk = FileChunk(data: data, startPosition: 100, endPosition: 100 + data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(2));

        // Check format chunk
        final formatChunk = boundaries.firstWhere((b) => b.metadata?['chunkId'] == 'fmt ');
        expect(formatChunk.metadata?['chunkSize'], equals(16));
        expect(formatChunk.isSeekable, isFalse);

        // Check data chunk
        final dataChunk = boundaries.firstWhere((b) => b.metadata?['chunkId'] == 'data');
        expect(dataChunk.metadata?['chunkSize'], equals(2048));
        expect(dataChunk.metadata?['isDataChunk'], isTrue);
        expect(dataChunk.isSeekable, isTrue);
      });

      test('should ignore invalid chunk IDs', () {
        final data = Uint8List.fromList([
          // Invalid chunk ID (contains non-printable character)
          0x00, 0x01, 0x02, 0x03, // Invalid ID
          0x10, 0x00, 0x00, 0x00, // Size
          // Valid chunk ID
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // Size
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        // Should only find the valid chunk
        expect(boundaries.length, equals(1));
        expect(boundaries.first.metadata?['chunkId'], equals('fmt '));
      });

      test('should handle chunk size validation', () {
        final data = Uint8List.fromList([
          // Chunk with invalid size (too large)
          0x74, 0x65, 0x73, 0x74, // "test"
          0xFF, 0xFF, 0xFF, 0x7F, // Invalid size (max int32)
          // Valid chunk
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // Valid size
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        // Should only find the valid chunk
        expect(boundaries.length, equals(1));
        expect(boundaries.first.metadata?['chunkId'], equals('fmt '));
      });
    });

    group('validateChunk', () {
      test('should validate chunk with WAV content', () {
        final data = Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x08, 0x00, 0x00, // File size
          0x57, 0x41, 0x56, 0x45, // "WAVE"
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // Chunk size
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should warn about chunks without recognizable content', () {
        final data = Uint8List.fromList([
          0x10, 0x11, 0x12, 0x13, // Random data, no WAV content
          0x14, 0x15, 0x16, 0x17,
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue); // Still valid, just with warnings
        expect(result.warnings.length, greaterThan(0));
        expect(result.warnings.first, contains('no recognizable RIFF chunks'));
      });

      test('should warn about multiple RIFF headers', () {
        final data = Uint8List.fromList([
          // First RIFF header
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x08, 0x00, 0x00, // File size
          0x57, 0x41, 0x56, 0x45, // "WAVE"
          // Second RIFF header
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x08, 0x00, 0x00, // File size
          0x57, 0x41, 0x56, 0x45, // "WAVE"
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.contains('Multiple RIFF headers')), isTrue);
      });

      test('should warn about data chunk without format chunk', () {
        final data = Uint8List.fromList([
          // Data chunk without format chunk
          0x64, 0x61, 0x74, 0x61, // "data"
          0x00, 0x08, 0x00, 0x00, // Chunk size
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.contains('Data chunk found without')), isTrue);
      });

      test('should reject empty chunks', () {
        final chunk = FileChunk(data: Uint8List(0), startPosition: 0, endPosition: 0, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('cannot be empty')), isTrue);
      });
    });

    group('extractMetadata', () {
      test('should extract chunk information and counts', () {
        final data = Uint8List.fromList([
          // RIFF header
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x08, 0x00, 0x00, // File size (2084)
          0x57, 0x41, 0x56, 0x45, // "WAVE"
          // Format chunk
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // Chunk size (16)
          // Data chunk
          0x64, 0x61, 0x74, 0x61, // "data"
          0x00, 0x08, 0x00, 0x00, // Chunk size (2048)
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final metadata = parser.extractMetadata(chunk);

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('WAV'));
        expect(metadata.data['hasRiffHeader'], isTrue);
        expect(metadata.data['fileSize'], equals(2084));
        expect(metadata.data['chunkCount'], equals(3)); // RIFF header, fmt and data chunks
        expect(metadata.data['formatChunks'], equals(1));
        expect(metadata.data['dataChunks'], equals(1));
        expect(metadata.data['totalDataSize'], equals(2048));
        expect(metadata.data['chunkSize'], equals(data.length));

        // Check chunks array
        final chunks = metadata.data['chunks'] as List;
        expect(chunks.length, equals(3));
        expect(chunks[0]['id'], equals('unknown')); // RIFF header
        expect(chunks[1]['id'], equals('fmt '));
        expect(chunks[2]['id'], equals('data'));
      });
    });

    group('getRecommendedChunkSize', () {
      test('should return appropriate chunk sizes for different file sizes', () {
        // Small file
        expect(parser.getRecommendedChunkSize(5 * 1024 * 1024), equals(2 * 1024 * 1024)); // 2MB

        // Medium file
        expect(parser.getRecommendedChunkSize(50 * 1024 * 1024), equals(8 * 1024 * 1024)); // 8MB

        // Large file
        expect(parser.getRecommendedChunkSize(200 * 1024 * 1024), equals(16 * 1024 * 1024)); // 16MB
      });
    });

    group('properties', () {
      test('should have correct format identifier', () {
        expect(parser.format, equals('WAV'));
      });

      test('should support efficient seeking', () {
        expect(parser.supportsEfficientSeeking, isTrue);
      });

      test('should have reasonable size limits', () {
        expect(parser.minimumChunkSize, equals(128 * 1024)); // 128KB
        expect(parser.maximumChunkSize, equals(50 * 1024 * 1024)); // 50MB
        expect(parser.minimumChunkSize, lessThan(parser.maximumChunkSize));
      });
    });

    group('sample position calculations', () {
      test('should calculate sample positions correctly', () {
        // 16-bit stereo (2 bytes per sample, 2 channels = 4 bytes per frame)
        expect(parser.calculateSamplePosition(1000, 2, 2), equals(250));
        expect(parser.calculateSamplePosition(0, 2, 2), equals(0));

        // 24-bit mono (3 bytes per sample, 1 channel = 3 bytes per frame)
        expect(parser.calculateSamplePosition(300, 3, 1), equals(100));
      });

      test('should calculate byte positions correctly', () {
        // 16-bit stereo
        expect(parser.calculateBytePosition(250, 2, 2), equals(1000));
        expect(parser.calculateBytePosition(0, 2, 2), equals(0));

        // 24-bit mono
        expect(parser.calculateBytePosition(100, 3, 1), equals(300));
      });

      test('should align positions to sample boundaries', () {
        // 16-bit stereo (4 bytes per frame)
        expect(parser.alignToSampleBoundary(1000, 2, 2), equals(1000)); // Already aligned
        expect(parser.alignToSampleBoundary(1001, 2, 2), equals(1000)); // Round down
        expect(parser.alignToSampleBoundary(1003, 2, 2), equals(1000)); // Round down
        expect(parser.alignToSampleBoundary(1004, 2, 2), equals(1004)); // Next boundary

        // 24-bit mono (3 bytes per frame)
        expect(parser.alignToSampleBoundary(300, 3, 1), equals(300)); // Already aligned
        expect(parser.alignToSampleBoundary(301, 3, 1), equals(300)); // Round down
        expect(parser.alignToSampleBoundary(302, 3, 1), equals(300)); // Round down
        expect(parser.alignToSampleBoundary(303, 3, 1), equals(303)); // Next boundary
      });
    });

    group('little-endian reading', () {
      test('should read little-endian 32-bit integers correctly', () {
        final data = Uint8List.fromList([
          0x00, 0x01, 0x02, 0x03, // Should read as 0x03020100
          0xFF, 0xFE, 0xFD, 0xFC, // Should read as 0xFCFDFEFF
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        // Test the private method through chunk parsing
        final testData = Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x00, 0x01, 0x02, 0x03, // Size: 0x03020100 = 50462976
          0x57, 0x41, 0x56, 0x45, // "WAVE"
        ]);

        final testChunk = FileChunk(data: testData, startPosition: 0, endPosition: testData.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(testChunk);
        final riffBoundary = boundaries.firstWhere((b) => b.metadata?['type'] == 'RIFF_HEADER');

        expect(riffBoundary.metadata?['fileSize'], equals(0x03020100));
      });
    });

    group('chunk ID validation', () {
      test('should accept valid chunk IDs', () {
        final validIds = ['fmt ', 'data', 'LIST', 'INFO', 'JUNK', 'bext'];

        for (final id in validIds) {
          final data = Uint8List.fromList([
            ...id.codeUnits,
            0x10, 0x00, 0x00, 0x00, // Size
          ]);

          final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

          final boundaries = parser.parseChunkBoundaries(chunk);
          expect(boundaries.length, equals(1), reason: 'Failed for chunk ID: $id');
          expect(boundaries.first.metadata?['chunkId'], equals(id));
        }
      });

      test('should reject invalid chunk IDs', () {
        final invalidData = [
          [0x00, 0x01, 0x02, 0x03], // Non-printable characters
          [0x1F, 0x20, 0x21, 0x22], // Contains control character
          [0x7F, 0x80, 0x81, 0x82], // Contains extended ASCII
        ];

        for (final idBytes in invalidData) {
          final data = Uint8List.fromList([
            ...idBytes,
            0x10, 0x00, 0x00, 0x00, // Size
          ]);

          final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

          final boundaries = parser.parseChunkBoundaries(chunk);
          expect(boundaries.length, equals(0), reason: 'Should reject invalid chunk ID: ${idBytes.map((b) => '0x${b.toRadixString(16)}').join(' ')}');
        }
      });
    });
  });
}
