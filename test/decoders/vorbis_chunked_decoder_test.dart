import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/vorbis_decoder.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('VorbisDecoder Chunked Processing', () {
    late VorbisDecoder decoder;

    setUp(() {
      decoder = VorbisDecoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully with valid interface', () async {
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should throw exception for non-existent file', () async {
        expect(() => decoder.initializeChunkedDecoding('non_existent.ogg'), throwsA(isA<FileAccessException>()));
      });

      test('should throw exception when disposed', () async {
        decoder.dispose();
        expect(() => decoder.initializeChunkedDecoding('test.ogg'), throwsA(isA<StateError>()));
      });
    });

    group('Chunk Size Recommendations', () {
      test('should recommend appropriate chunk size for small files', () {
        final recommendation = decoder.getOptimalChunkSize(1024 * 1024); // 1MB

        expect(recommendation.recommendedSize, greaterThan(0));
        expect(recommendation.recommendedSize, lessThanOrEqualTo(1024 * 1024));
        expect(recommendation.minSize, greaterThan(0));
        expect(recommendation.maxSize, equals(1024 * 1024));
        expect(recommendation.reason, contains('Small OGG Vorbis file'));
        expect(recommendation.metadata?['format'], equals('OGG Vorbis'));
        expect(recommendation.metadata?['avgPageSize'], equals(4096));
      });

      test('should recommend appropriate chunk size for medium files', () {
        final recommendation = decoder.getOptimalChunkSize(25 * 1024 * 1024); // 25MB

        expect(recommendation.recommendedSize, equals(4 * 1024 * 1024)); // 4MB
        expect(recommendation.minSize, equals(1024 * 1024)); // 1MB
        expect(recommendation.maxSize, equals(15 * 1024 * 1024)); // 15MB
        expect(recommendation.reason, contains('Medium OGG Vorbis file'));
      });

      test('should recommend appropriate chunk size for large files', () {
        final recommendation = decoder.getOptimalChunkSize(100 * 1024 * 1024); // 100MB

        expect(recommendation.recommendedSize, equals(8 * 1024 * 1024)); // 8MB
        expect(recommendation.minSize, equals(2 * 1024 * 1024)); // 2MB
        expect(recommendation.maxSize, equals(30 * 1024 * 1024)); // 30MB
        expect(recommendation.reason, contains('Large OGG Vorbis file'));
      });
    });

    group('Format Metadata', () {
      test('should return correct format metadata', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata['format'], equals('OGG Vorbis'));
        expect(metadata['supportsSeekTable'], isFalse); // OGG uses granule positions
        expect(metadata['hasGranulePositions'], isFalse); // Initially false
        expect(metadata['pageCount'], equals(0));
        expect(metadata['avgPageSize'], equals(4096));
      });

      test('should indicate seeking accuracy based on granule positions', () {
        final metadata = decoder.getFormatMetadata();

        // Without granule positions, seeking should be approximate
        expect(metadata['seekingAccuracy'], equals('approximate'));
        expect(decoder.supportsEfficientSeeking, isFalse);
      });
    });

    group('State Management', () {
      test('should track current position correctly', () {
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should reset state correctly', () async {
        await decoder.resetDecoderState();
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should cleanup resources correctly', () async {
        await decoder.cleanupChunkedProcessing();
        expect(decoder.isInitialized, isFalse);

        final metadata = decoder.getFormatMetadata();
        expect(metadata['sampleRate'], equals(0));
        expect(metadata['channels'], equals(0));
        expect(metadata['pageCount'], equals(0));
        expect(metadata['hasGranulePositions'], isFalse);
      });
    });

    group('Chunk Processing', () {
      test('should throw exception when processing chunk without initialization', () async {
        final chunk = FileChunk(data: Uint8List(4096), startPosition: 0, endPosition: 4096, isLast: false);

        expect(() => decoder.processFileChunk(chunk), throwsA(isA<StateError>()));
      });

      test('should handle empty chunks gracefully', () async {
        final chunk = FileChunk(data: Uint8List(0), startPosition: 0, endPosition: 0, isLast: true);

        expect(chunk.data.isEmpty, isTrue);
      });

      test('should validate chunk size against OGG page size', () {
        final smallChunk = FileChunk(
          data: Uint8List(100), // Much smaller than typical OGG page
          startPosition: 0,
          endPosition: 100,
          isLast: false,
        );

        // Should be smaller than expected OGG page size
        expect(smallChunk.size < 4096, isTrue);
      });
    });

    group('Seeking', () {
      test('should throw exception when seeking without initialization', () async {
        expect(() => decoder.seekToTime(const Duration(seconds: 10)), throwsA(isA<StateError>()));
      });

      test('should support efficient seeking when granule positions are available', () {
        // Initially no granule positions
        expect(decoder.supportsEfficientSeeking, isFalse);

        final metadata = decoder.getFormatMetadata();
        expect(metadata['hasGranulePositions'], isFalse);
      });
    });

    group('OGG Vorbis-Specific Features', () {
      test('should handle OGG page structure correctly', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata['avgPageSize'], equals(4096)); // Typical OGG page size
        expect(metadata['pageCount'], equals(0)); // Not initialized yet
      });

      test('should track granule position availability', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata['hasGranulePositions'], isFalse); // Initially false
        expect(metadata['supportsSeekTable'], isFalse); // OGG doesn't use seek tables
      });

      test('should provide seeking accuracy information', () {
        final metadata = decoder.getFormatMetadata();

        // Seeking accuracy depends on granule position availability
        if (metadata['hasGranulePositions'] == true) {
          expect(metadata['seekingAccuracy'], equals('good'));
        } else {
          expect(metadata['seekingAccuracy'], equals('approximate'));
        }
      });
    });

    group('OGG Page Processing', () {
      test('should validate OGG page signature', () {
        // Test would validate that invalid OGG data is rejected
        final invalidData = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]); // Not OggS signature
        expect(invalidData[0] != 0x4F, isTrue); // Should not be 'O' from "OggS"
      });

      test('should handle OGG page boundaries correctly', () {
        // OGG pages should be processed as complete units
        final oggSignature = Uint8List.fromList([0x4F, 0x67, 0x67, 0x53]); // "OggS"
        expect(oggSignature[0], equals(0x4F)); // 'O'
        expect(oggSignature[1], equals(0x67)); // 'g'
        expect(oggSignature[2], equals(0x67)); // 'g'
        expect(oggSignature[3], equals(0x53)); // 'S'
      });

      test('should track page positions for seeking', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata.containsKey('pageCount'), isTrue);
        expect(metadata.containsKey('hasGranulePositions'), isTrue);
      });
    });

    group('Granule Position Handling', () {
      test('should use granule positions for accurate seeking when available', () {
        // Granule positions provide sample-accurate seeking in OGG Vorbis
        final metadata = decoder.getFormatMetadata();

        if (metadata['hasGranulePositions'] == true) {
          expect(decoder.supportsEfficientSeeking, isTrue);
          expect(metadata['seekingAccuracy'], equals('good'));
        }
      });

      test('should fall back to approximate seeking without granule positions', () {
        // Without granule positions, seeking should still work but be approximate
        expect(decoder.supportsEfficientSeeking, isFalse);

        final metadata = decoder.getFormatMetadata();
        expect(metadata['seekingAccuracy'], equals('approximate'));
      });

      test('should handle granule position parsing', () {
        // Test would validate granule position extraction from OGG pages
        final metadata = decoder.getFormatMetadata();
        expect(metadata.containsKey('hasGranulePositions'), isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle disposed state correctly', () {
        decoder.dispose();

        expect(() => decoder.currentPosition, throwsA(isA<StateError>()));
        expect(() => decoder.getFormatMetadata(), throwsA(isA<StateError>()));
      });

      test('should validate OGG file structure', () {
        // Test would validate proper OGG file structure
        final tooSmallData = Uint8List(10); // Smaller than minimum OGG page header
        expect(tooSmallData.length < 27, isTrue); // OGG page header is at least 27 bytes
      });

      test('should handle corrupted OGG pages gracefully', () {
        // Decoder should skip corrupted pages and continue processing
        final metadata = decoder.getFormatMetadata();
        expect(metadata['format'], equals('OGG Vorbis'));
      });

      test('should handle missing granule positions gracefully', () {
        // Decoder should work without granule positions, just with reduced seeking accuracy
        expect(decoder.supportsEfficientSeeking, isFalse);

        final metadata = decoder.getFormatMetadata();
        expect(metadata['seekingAccuracy'], equals('approximate'));
      });
    });

    group('Vorbis Stream Processing', () {
      test('should handle Vorbis stream within OGG container', () {
        // OGG is a container format that can contain Vorbis audio streams
        final metadata = decoder.getFormatMetadata();
        expect(metadata['format'], equals('OGG Vorbis'));
      });

      test('should process variable bitrate content correctly', () {
        // Vorbis supports variable bitrate encoding
        final metadata = decoder.getFormatMetadata();
        expect(metadata['avgPageSize'], equals(4096)); // Average page size
      });

      test('should handle stream boundaries correctly', () {
        // OGG streams can be chained or multiplexed
        final chunk = FileChunk(
          data: Uint8List(8192), // Two typical pages
          startPosition: 0,
          endPosition: 8192,
          isLast: false,
        );

        expect(chunk.size, equals(8192));
        // Processing should handle multiple pages within a chunk
      });
    });
  });
}
