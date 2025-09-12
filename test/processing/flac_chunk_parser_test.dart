import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunk_boundary.dart';
import 'package:sonix/src/processing/flac_chunk_parser.dart';

void main() {
  group('FLACChunkParser', () {
    late FLACChunkParser parser;

    setUp(() {
      parser = FLACChunkParser();
    });

    group('parseChunkBoundaries', () {
      test('should detect FLAC stream marker', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" stream marker
          0x00, 0x00, 0x00, 0x22, // STREAMINFO block header
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final streamMarkers = boundaries.where((b) => b.type == BoundaryType.metadata).toList();
        expect(streamMarkers.length, equals(1));
        expect(streamMarkers.first.metadata?['type'], equals('FLAC_STREAM_MARKER'));
        expect(streamMarkers.first.isSeekable, isFalse);
      });

      test('should detect FLAC frame sync codes', () {
        // Create a valid FLAC frame header
        // Sync code 0x3FFE
        final data = Uint8List.fromList([
          0x3F, 0xFE, // Sync code (0x3FFE)
          0x69, 0x04, // Block size, sample rate, channels, sample size
          0x00, 0x01, 0x02, 0x03, // Frame data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final frameBoundaries = boundaries.where((b) => b.type == BoundaryType.frameStart).toList();
        expect(frameBoundaries.length, greaterThanOrEqualTo(1));
        expect(frameBoundaries.first.isSeekable, isTrue);
        expect(frameBoundaries.first.position, equals(0));
      });

      test('should detect metadata blocks', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" stream marker
          0x00, // STREAMINFO block (type 0, not last)
          0x00, 0x00, 0x22, // Block length (34 bytes)
          // ... STREAMINFO data would follow
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final blockBoundaries = boundaries.where((b) => b.type == BoundaryType.blockStart).toList();
        expect(blockBoundaries.length, equals(1));
        expect(blockBoundaries.first.metadata?['blockType'], equals('STREAMINFO'));
        expect(blockBoundaries.first.metadata?['isLastBlock'], isFalse);
        expect(blockBoundaries.first.metadata?['blockLength'], equals(34));
      });

      test('should detect SEEKTABLE blocks as seekable', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" stream marker first
          0x03, // SEEKTABLE block (type 3, not last)
          0x00, 0x00, 0x12, // Block length (18 bytes)
          // ... SEEKTABLE data would follow
        ]);

        final chunk = FileChunk(data: data, startPosition: 100, endPosition: 100 + data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final seekTableBoundaries = boundaries.where((b) => b.type == BoundaryType.blockStart && b.isSeekable).toList();
        expect(seekTableBoundaries.length, equals(1));
        expect(seekTableBoundaries.first.metadata?['blockType'], equals('SEEKTABLE'));
      });

      test('should detect last metadata block flag', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" stream marker first
          0x84, // VORBIS_COMMENT block (type 4, last block - 0x80 | 0x04)
          0x00, 0x00, 0x10, // Block length (16 bytes)
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final blockBoundaries = boundaries.where((b) => b.type == BoundaryType.blockStart).toList();
        expect(blockBoundaries.length, equals(1));
        expect(blockBoundaries.first.metadata?['blockType'], equals('VORBIS_COMMENT'));
        expect(blockBoundaries.first.metadata?['isLastBlock'], isTrue);
      });
    });

    group('validateChunk', () {
      test('should validate chunk with FLAC content', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" stream marker
          0x00, 0x00, 0x00, 0x22, // STREAMINFO block
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should warn about chunks without recognizable content', () {
        final data = Uint8List.fromList([
          0x10, 0x11, 0x12, 0x13, // Random data, no FLAC content
          0x14, 0x15, 0x16, 0x17, // Avoid values that could be mistaken for metadata blocks
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue); // Still valid, just with warnings
        expect(result.warnings.length, greaterThan(0));
        expect(result.warnings.first, contains('no recognizable frame headers'));
      });

      test('should warn about multiple stream markers', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // First "fLaC" stream marker
          0x00, 0x01, 0x02, 0x03,
          0x66, 0x4C, 0x61, 0x43, // Second "fLaC" stream marker
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.contains('Multiple FLAC stream markers')), isTrue);
      });

      test('should reject empty chunks', () {
        final chunk = FileChunk(data: Uint8List(0), startPosition: 0, endPosition: 0, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('cannot be empty')), isTrue);
      });
    });

    group('extractMetadata', () {
      test('should extract frame and block counts', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" stream marker
          0x00, 0x00, 0x00, 0x22, // STREAMINFO block
          0x03, 0x00, 0x00, 0x12, // SEEKTABLE block
          0x3F, 0xFE, 0x69, 0x04, // FLAC frame
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final metadata = parser.extractMetadata(chunk);

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('FLAC'));
        expect(metadata.data['hasStreamMarker'], isTrue);
        expect(metadata.data['metadataBlockCount'], equals(2));
        expect(metadata.data['seekTableBlocks'], equals(1));
        expect(metadata.data['frameCount'], greaterThanOrEqualTo(1));
        expect(metadata.data['chunkSize'], equals(data.length));
      });
    });

    group('getRecommendedChunkSize', () {
      test('should return appropriate chunk sizes for different file sizes', () {
        // Small file
        expect(parser.getRecommendedChunkSize(5 * 1024 * 1024), equals(1 * 1024 * 1024)); // 1MB

        // Medium file
        expect(parser.getRecommendedChunkSize(50 * 1024 * 1024), equals(4 * 1024 * 1024)); // 4MB

        // Large file
        expect(parser.getRecommendedChunkSize(200 * 1024 * 1024), equals(12 * 1024 * 1024)); // 12MB
      });
    });

    group('properties', () {
      test('should have correct format identifier', () {
        expect(parser.format, equals('FLAC'));
      });

      test('should support efficient seeking', () {
        expect(parser.supportsEfficientSeeking, isTrue);
      });

      test('should have reasonable size limits', () {
        expect(parser.minimumChunkSize, equals(64 * 1024)); // 64KB
        expect(parser.maximumChunkSize, equals(25 * 1024 * 1024)); // 25MB
        expect(parser.minimumChunkSize, lessThan(parser.maximumChunkSize));
      });
    });

    group('FLAC frame header parsing', () {
      test('should parse frame header metadata', () {
        // Create a valid FLAC frame header with specific values
        final data = Uint8List.fromList([
          0x3F, 0xFE, // Sync code (0x3FFE)
          0x69, // Fixed blocking, block size code 6, sample rate code 9
          0x04, // 1 channel (mono), 16-bit samples
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, greaterThan(0));
        final frameHeader = boundaries.first;
        expect(frameHeader.metadata, isNotNull);
        expect(frameHeader.metadata!['blockingStrategy'], equals('fixed'));
        expect(frameHeader.metadata!['channels'], equals(1));
        expect(frameHeader.metadata!['channelMode'], equals('independent'));
      });

      test('should handle different channel modes', () {
        // Test left-side stereo (channel assignment 8)
        final data = Uint8List.fromList([
          0x3F, 0xFE, // Sync code (0x3FFE)
          0x69, // Block size and sample rate
          0x84, // Channel assignment 8 (left-side), 16-bit
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        if (boundaries.isNotEmpty) {
          final frameHeader = boundaries.first;
          expect(frameHeader.metadata?['channels'], equals(2));
          expect(frameHeader.metadata?['channelMode'], equals('left_side'));
        }
      });
    });

    group('metadata block type names', () {
      test('should return correct block type names', () {
        final data = Uint8List.fromList([
          0x66, 0x4C, 0x61, 0x43, // "fLaC" stream marker
          0x00, 0x00, 0x00, 0x22, // STREAMINFO
          0x01, 0x00, 0x00, 0x10, // PADDING
          0x02, 0x00, 0x00, 0x08, // APPLICATION
          0x03, 0x00, 0x00, 0x12, // SEEKTABLE
          0x04, 0x00, 0x00, 0x20, // VORBIS_COMMENT
          0x05, 0x00, 0x00, 0x30, // CUESHEET
          0x06, 0x00, 0x00, 0x40, // PICTURE
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);
        final blockBoundaries = boundaries.where((b) => b.type == BoundaryType.blockStart).toList();

        expect(blockBoundaries.length, equals(7));
        expect(blockBoundaries[0].metadata?['blockType'], equals('STREAMINFO'));
        expect(blockBoundaries[1].metadata?['blockType'], equals('PADDING'));
        expect(blockBoundaries[2].metadata?['blockType'], equals('APPLICATION'));
        expect(blockBoundaries[3].metadata?['blockType'], equals('SEEKTABLE'));
        expect(blockBoundaries[4].metadata?['blockType'], equals('VORBIS_COMMENT'));
        expect(blockBoundaries[5].metadata?['blockType'], equals('CUESHEET'));
        expect(blockBoundaries[6].metadata?['blockType'], equals('PICTURE'));
      });
    });
  });
}
