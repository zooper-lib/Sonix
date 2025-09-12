import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunk_boundary.dart';
import 'package:sonix/src/processing/ogg_chunk_parser.dart';

void main() {
  group('OGGChunkParser', () {
    late OGGChunkParser parser;

    setUp(() {
      parser = OGGChunkParser();
    });

    group('parseChunkBoundaries', () {
      test('should detect OGG page headers', () {
        final data = Uint8List.fromList([
          // OGG page header
          0x4F, 0x67, 0x67, 0x53, // "OggS" sync pattern
          0x00, // Version
          0x02, // Header type (first page)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position
          0x01, 0x02, 0x03, 0x04, // Stream serial
          0x00, 0x00, 0x00, 0x00, // Page sequence
          0x12, 0x34, 0x56, 0x78, // CRC checksum
          0x01, // Segment count
          0x1E, // Segment size (30 bytes)
          // Page data (30 bytes)
          ...List.filled(30, 0x00),
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(1));
        final pageHeader = boundaries.first;
        expect(pageHeader.type, equals(BoundaryType.pageStart));
        expect(pageHeader.isSeekable, isTrue);
        expect(pageHeader.metadata?['version'], equals(0));
        expect(pageHeader.metadata?['isFirstPage'], isTrue);
        expect(pageHeader.metadata?['streamSerial'], equals(0x04030201));
        expect(pageHeader.metadata?['segmentCount'], equals(1));
      });

      test('should detect multiple OGG pages', () {
        final data = Uint8List.fromList([
          // First OGG page
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version, header type
          ...List.filled(20, 0x00), // Granule, serial, sequence, CRC
          0x01, 0x10, // 1 segment of 16 bytes
          ...List.filled(16, 0x00), // Page data
          // Second OGG page
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x00, // Version, header type
          ...List.filled(20, 0x00), // Granule, serial, sequence, CRC
          0x01, 0x20, // 1 segment of 32 bytes
          ...List.filled(32, 0x00), // Page data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(2));
        expect(boundaries[0].type, equals(BoundaryType.pageStart));
        expect(boundaries[1].type, equals(BoundaryType.pageStart));
      });

      test('should ignore invalid OGG sync patterns', () {
        final data = Uint8List.fromList([
          // Invalid sync pattern
          0x4F, 0x67, 0x67, 0x54, // "OggT" (invalid)
          0x00, 0x02,
          ...List.filled(20, 0x00),
          0x01, 0x10,
          ...List.filled(16, 0x00),

          // Valid sync pattern
          0x4F, 0x67, 0x67, 0x53, // "OggS" (valid)
          0x00, 0x00,
          ...List.filled(20, 0x00),
          0x01, 0x10,
          ...List.filled(16, 0x00),
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        // Should only find the valid page
        expect(boundaries.length, equals(1));
      });

      test('should handle incomplete page headers', () {
        final data = Uint8List.fromList([
          // Incomplete OGG page header (only 20 bytes instead of 27+)
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          ...List.filled(14, 0x00), // Incomplete header
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        // Should not find any valid pages
        expect(boundaries.length, equals(0));
      });
    });

    group('validateChunk', () {
      test('should validate chunk with OGG content', () {
        final data = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02,
          ...List.filled(20, 0x00),
          0x01, 0x10,
          ...List.filled(16, 0x00),
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should warn about chunks without recognizable content', () {
        final data = Uint8List.fromList([
          0x10, 0x11, 0x12, 0x13, // Random data, no OGG content
          0x14, 0x15, 0x16, 0x17,
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue); // Still valid, just with warnings
        expect(result.warnings.length, greaterThan(0));
        expect(result.warnings.first, contains('no recognizable page headers'));
      });

      test('should warn about non-continuous sequence numbers', () {
        final data = Uint8List.fromList([
          // First page (sequence 0)
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x00, // Version, header type
          ...List.filled(8, 0x00), // Granule position
          0x01, 0x02, 0x03, 0x04, // Stream serial
          0x00, 0x00, 0x00, 0x00, // Sequence 0
          ...List.filled(4, 0x00), // CRC
          0x01, 0x10, // Segments
          ...List.filled(16, 0x00), // Data
          // Second page (sequence 2, skipping 1)
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x00, // Version, header type
          ...List.filled(8, 0x00), // Granule position
          0x01, 0x02, 0x03, 0x04, // Same stream serial
          0x02, 0x00, 0x00, 0x00, // Sequence 2 (should be 1)
          ...List.filled(4, 0x00), // CRC
          0x01, 0x10, // Segments
          ...List.filled(16, 0x00), // Data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isTrue);
        expect(result.warnings.any((w) => w.contains('sequence numbers are not continuous')), isTrue);
      });

      test('should reject empty chunks', () {
        final chunk = FileChunk(data: Uint8List(0), startPosition: 0, endPosition: 0, isLast: false);

        final result = parser.validateChunk(chunk);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('cannot be empty')), isTrue);
      });
    });

    group('extractMetadata', () {
      test('should extract page and stream information', () {
        final data = Uint8List.fromList([
          // First page (stream 1)
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version, header type (first page)
          0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position (4096)
          0x01, 0x00, 0x00, 0x00, // Stream serial 1
          0x00, 0x00, 0x00, 0x00, // Sequence 0
          ...List.filled(4, 0x00), // CRC
          0x01, 0x10, // Segments
          ...List.filled(16, 0x00), // Data
          // Second page (stream 2)
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x06, // Version, header type (first + last page)
          0x00, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Granule position (8192)
          0x02, 0x00, 0x00, 0x00, // Stream serial 2
          0x00, 0x00, 0x00, 0x00, // Sequence 0
          ...List.filled(4, 0x00), // CRC
          0x01, 0x10, // Segments
          ...List.filled(16, 0x00), // Data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final metadata = parser.extractMetadata(chunk);

        expect(metadata, isNotNull);
        expect(metadata!.format, equals('OGG'));
        expect(metadata.data['pageCount'], equals(2));
        expect(metadata.data['streamCount'], equals(2));
        expect(metadata.data['streamSerials'], containsAll([1, 2]));
        expect(metadata.data['hasFirstPage'], isTrue);
        expect(metadata.data['hasLastPage'], isTrue);
        expect(metadata.data['totalGranulePosition'], equals(4096 + 8192));
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
        expect(parser.getRecommendedChunkSize(200 * 1024 * 1024), equals(10 * 1024 * 1024)); // 10MB
      });
    });

    group('properties', () {
      test('should have correct format identifier', () {
        expect(parser.format, equals('OGG'));
      });

      test('should support efficient seeking', () {
        expect(parser.supportsEfficientSeeking, isTrue);
      });

      test('should have reasonable size limits', () {
        expect(parser.minimumChunkSize, equals(64 * 1024)); // 64KB
        expect(parser.maximumChunkSize, equals(30 * 1024 * 1024)); // 30MB
        expect(parser.minimumChunkSize, lessThan(parser.maximumChunkSize));
      });
    });

    group('codec identification', () {
      test('should identify Vorbis codec', () {
        final data = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version, header type (first page)
          ...List.filled(20, 0x00), // Granule, serial, sequence, CRC
          0x01, 0x1E, // 1 segment of 30 bytes
          // Vorbis identification header
          0x01, // Packet type
          0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // "vorbis"
          ...List.filled(23, 0x00), // Rest of data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(1));
        expect(boundaries.first.metadata?['codecType'], equals('vorbis'));
      });

      test('should identify Opus codec', () {
        final data = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version, header type (first page)
          ...List.filled(20, 0x00), // Granule, serial, sequence, CRC
          0x01, 0x13, // 1 segment of 19 bytes
          // Opus identification header
          0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
          ...List.filled(11, 0x00), // Rest of data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(1));
        expect(boundaries.first.metadata?['codecType'], equals('opus'));
      });

      test('should identify FLAC codec', () {
        final data = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version, header type (first page)
          ...List.filled(20, 0x00), // Granule, serial, sequence, CRC
          0x01, 0x10, // 1 segment of 16 bytes
          // FLAC in OGG header
          0x7F, // Packet type for FLAC
          0x46, 0x4C, 0x41, 0x43, // "FLAC"
          ...List.filled(11, 0x00), // Rest of data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(1));
        expect(boundaries.first.metadata?['codecType'], equals('flac'));
      });
    });

    group('granule position calculations', () {
      test('should calculate granule positions correctly', () {
        const sampleRate = 44100;

        // 1 second
        expect(parser.calculateGranulePosition(const Duration(seconds: 1), sampleRate), equals(44100));

        // 0.5 seconds
        expect(parser.calculateGranulePosition(const Duration(milliseconds: 500), sampleRate), equals(22050));

        // 0 seconds
        expect(parser.calculateGranulePosition(Duration.zero, sampleRate), equals(0));
      });

      test('should calculate time positions correctly', () {
        const sampleRate = 44100;

        // 44100 samples = 1 second
        expect(parser.calculateTimePosition(44100, sampleRate), equals(const Duration(seconds: 1)));

        // 22050 samples = 0.5 seconds
        expect(parser.calculateTimePosition(22050, sampleRate), equals(const Duration(milliseconds: 500)));

        // 0 samples = 0 seconds
        expect(parser.calculateTimePosition(0, sampleRate), equals(Duration.zero));
      });

      test('should handle invalid sample rates', () {
        // Zero sample rate
        expect(parser.calculateTimePosition(44100, 0), equals(Duration.zero));

        // Negative sample rate
        expect(parser.calculateTimePosition(44100, -1), equals(Duration.zero));
      });
    });

    group('little-endian reading', () {
      test('should read little-endian 32-bit integers correctly', () {
        final data = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version, header type
          ...List.filled(8, 0x00), // Granule position
          0x78, 0x56, 0x34, 0x12, // Stream serial (little-endian 0x12345678)
          0x21, 0x43, 0x65, 0x87, // Sequence (little-endian 0x87654321)
          ...List.filled(4, 0x00), // CRC
          0x01, 0x10, // Segments
          ...List.filled(16, 0x00), // Data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(1));
        expect(boundaries.first.metadata?['streamSerial'], equals(0x12345678));
        expect(boundaries.first.metadata?['sequenceNumber'], equals(0x87654321));
      });

      test('should read little-endian 64-bit integers correctly', () {
        final data = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x02, // Version, header type
          // Granule position (little-endian 0x0123456789ABCDEF)
          0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01,
          ...List.filled(12, 0x00), // Serial, sequence, CRC
          0x01, 0x10, // Segments
          ...List.filled(16, 0x00), // Data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(1));
        expect(boundaries.first.metadata?['granulePosition'], equals(0x0123456789ABCDEF));
      });
    });

    group('header type flags', () {
      test('should parse header type flags correctly', () {
        final data = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS"
          0x00, 0x07, // Version, header type (continuation + first + last = 0x01 | 0x02 | 0x04)
          ...List.filled(20, 0x00), // Rest of header
          0x01, 0x10, // Segments
          ...List.filled(16, 0x00), // Data
        ]);

        final chunk = FileChunk(data: data, startPosition: 0, endPosition: data.length, isLast: false);

        final boundaries = parser.parseChunkBoundaries(chunk);

        expect(boundaries.length, equals(1));
        final metadata = boundaries.first.metadata!;
        expect(metadata['isContinuation'], isTrue);
        expect(metadata['isFirstPage'], isTrue);
        expect(metadata['isLastPage'], isTrue);
        expect(metadata['headerType'], equals(0x07));
      });
    });
  });
}
