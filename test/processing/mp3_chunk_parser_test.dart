import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunk_boundary.dart';
import 'package:sonix/src/processing/mp3_chunk_parser.dart';

void main() {
  group('MP3ChunkParser', () {
    late MP3ChunkParser parser;

    setUp(() {
      parser = MP3ChunkParser();
    });

    group('parseChunkBoundaries', () {
      test('should detect valid MP3 sync words', () {
        // Create a chunk with a valid MP3 frame header
        // Use a realistic MP3 frame header: MPEG1 Layer III, 128kbps, 44.1kHz, stereo
        final data = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // Valid MP3 frame header (MPEG1 Layer III)
          0x00, 0x01, 0x02, 0x03, // Some audio data
          0xFF, 0xFB, 0x90, 0x00, // Another valid frame header
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, greaterThanOrEqualTo(1));
        expect(boundaries.first.type, equals(BoundaryType.frameStart));
        expect(boundaries.first.isSeekable, isTrue);
        expect(boundaries.first.position, equals(0));
      });

      test('should detect ID3v2 tags', () {
        final data = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x03, 0x00, // Version 2.3
          0x00, // Flags
          0x00, 0x00, 0x00, 0x00, // Size
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final id3Boundaries = boundaries.where((b) => b.type == BoundaryType.metadata).toList();
        expect(id3Boundaries.length, equals(1));
        expect(id3Boundaries.first.isSeekable, isFalse);
        expect(id3Boundaries.first.metadata?['type'], equals('ID3v2'));
      });

      test('should detect ID3v1 tags at end of chunk', () {
        final data = Uint8List(128);
        // Fill with zeros except for TAG signature at start
        data[0] = 0x54; // 'T'
        data[1] = 0x41; // 'A'
        data[2] = 0x47; // 'G'

        final chunk = FileChunk(data: data, startPosition: 1000, endPosition: 1000 + data.length, isLast: true);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final id3Boundaries = boundaries.where((b) => b.type == BoundaryType.metadata).toList();
        expect(id3Boundaries.length, equals(1));
        expect(id3Boundaries.first.metadata?['type'], equals('ID3v1'));
        expect(id3Boundaries.first.position, equals(1000)); // Start of chunk
      });

      test('should ignore invalid sync words', () {
        final data = Uint8List.fromList([
          0xFF, 0xDF, // Invalid sync word (not 0xFFE0 or higher)
          0xFF, 0x00, // Invalid sync word
          0xFE, 0xFF, // Invalid sync word
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        final frameBoundaries = boundaries.where((b) => b.type == BoundaryType.frameStart).toList();
        expect(frameBoundaries.length, equals(0));
      });
    });

    group('validateChunk', () {
      test('should validate chunk with MP3 frames', () {
        final data = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // Valid MP3 frame header
          0x00, 0x01, 0x02, 0x03, // Audio data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should warn about chunks without recognizable content', () {
        final data = Uint8List.fromList([
          0x00, 0x01, 0x02, 0x03, // Random data, no MP3 frames
          0x04, 0x05, 0x06, 0x07,
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue); // Still valid, just with warnings
        expect(result.warnings.length, greaterThan(0));
        expect(result.warnings.first, contains('no recognizable frame headers'));
      });

      test('should reject empty chunks', () {
        final chunk = FileChunk(data: Uint8List(0), startPosition: 0, endPosition: 0, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('cannot be empty')), isTrue);
      });
    });

    group('extractMetadata', () {
      test('should extract frame count and chunk information', () {
        final data = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // First MP3 frame
          0x00, 0x01, 0x02, 0x03,
          0xFF, 0xFB, 0x90, 0x00, // Second MP3 frame
          0x04, 0x05, 0x06, 0x07,
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final metadata = parser.extractMetadata(chunk);

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('MP3'));
        expect(metadata.data['frameCount'], greaterThanOrEqualTo(1));
        expect(metadata.data['chunkSize'], equals(data.length));
        expect(metadata.data['id3TagCount'], equals(0));
      });

      test('should count ID3 tags', () {
        final data = Uint8List.fromList([
          0x49, 0x44, 0x33, // ID3v2 tag
          0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0xFF, 0xFB, 0x90, 0x00, // MP3 frame
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final metadata = parser.extractMetadata(chunk);

        expect(metadata, isNotNull);
        expect(metadata!.data['id3TagCount'], equals(1));
      });
    });

    group('getRecommendedChunkSize', () {
      test('should return appropriate chunk sizes for different file sizes', () {
        // Small file
        expect(parser.getRecommendedChunkSize(1024 * 1024), equals(512 * 1024)); // 512KB

        // Medium file
        expect(parser.getRecommendedChunkSize(20 * 1024 * 1024), equals(2 * 1024 * 1024)); // 2MB

        // Large file
        expect(parser.getRecommendedChunkSize(100 * 1024 * 1024), equals(8 * 1024 * 1024)); // 8MB
      });
    });

    group('properties', () {
      test('should have correct format identifier', () {
        expect(parser.format, equals('MP3'));
      });

      test('should support efficient seeking', () {
        expect(parser.supportsEfficientSeeking, isTrue);
      });

      test('should have reasonable size limits', () {
        expect(parser.minimumChunkSize, equals(32 * 1024)); // 32KB
        expect(parser.maximumChunkSize, equals(20 * 1024 * 1024)); // 20MB
        expect(parser.minimumChunkSize, lessThan(parser.maximumChunkSize));
      });
    });

    group('MP3 frame header parsing', () {
      test('should parse frame header metadata', () {
        // Create a more complete MP3 frame header
        final data = Uint8List.fromList([
          0xFF, 0xFB, // Sync + MPEG1 Layer III
          0x90, // 128 kbps, 44.1 kHz
          0x00, // No padding, stereo
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, greaterThan(0));
        final frameHeader = boundaries.first;
        expect(frameHeader.metadata, isNotNull);
        expect(frameHeader.metadata!['mpegVersion'], isNotNull);
        expect(frameHeader.metadata!['layer'], isNotNull);
        expect(frameHeader.metadata!['channelMode'], isNotNull);
      });
    });
  });
}
