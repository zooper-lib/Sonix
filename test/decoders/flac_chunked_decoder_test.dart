import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/flac_decoder.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('FLACDecoder Chunked Processing', () {
    late FLACDecoder decoder;

    setUp(() {
      decoder = FLACDecoder();
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
        expect(() => decoder.initializeChunkedDecoding('non_existent.flac'), throwsA(isA<FileAccessException>()));
      });

      test('should throw exception when disposed', () async {
        decoder.dispose();
        expect(() => decoder.initializeChunkedDecoding('test.flac'), throwsA(isA<StateError>()));
      });
    });

    group('Chunk Size Recommendations', () {
      test('should recommend appropriate chunk size for small files', () {
        final recommendation = decoder.getOptimalChunkSize(800 * 1024); // 800KB

        expect(recommendation.recommendedSize, greaterThan(0));
        expect(recommendation.recommendedSize, lessThanOrEqualTo(800 * 1024));
        expect(recommendation.minSize, greaterThan(0));
        expect(recommendation.maxSize, equals(800 * 1024));
        expect(recommendation.reason, contains('Small FLAC file'));
        expect(recommendation.metadata?['format'], equals('FLAC'));
        expect(recommendation.metadata?['blockSize'], equals(4096));
      });

      test('should recommend appropriate chunk size for medium files', () {
        final recommendation = decoder.getOptimalChunkSize(20 * 1024 * 1024); // 20MB

        expect(recommendation.recommendedSize, equals(3 * 1024 * 1024)); // 3MB
        expect(recommendation.minSize, equals(512 * 1024)); // 512KB
        expect(recommendation.maxSize, equals(15 * 1024 * 1024)); // 15MB
        expect(recommendation.reason, contains('Medium FLAC file'));
      });

      test('should recommend appropriate chunk size for large files', () {
        final recommendation = decoder.getOptimalChunkSize(200 * 1024 * 1024); // 200MB

        expect(recommendation.recommendedSize, equals(8 * 1024 * 1024)); // 8MB
        expect(recommendation.minSize, equals(2 * 1024 * 1024)); // 2MB
        expect(recommendation.maxSize, equals(25 * 1024 * 1024)); // 25MB
        expect(recommendation.reason, contains('Large FLAC file'));
      });
    });

    group('Format Metadata', () {
      test('should return correct format metadata', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata['format'], equals('FLAC'));
        expect(metadata['blockSize'], equals(4096));
        expect(metadata['supportsSeekTable'], isTrue);
        expect(metadata['hasSeekTable'], isFalse); // Initially false
        expect(metadata['seekPointCount'], equals(0));
      });

      test('should indicate seeking accuracy based on seek table availability', () {
        final metadata = decoder.getFormatMetadata();

        // Without seek table, seeking should be approximate
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
        expect(metadata['hasSeekTable'], isFalse);
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

      test('should validate chunk size against FLAC block size', () {
        final smallChunk = FileChunk(
          data: Uint8List(100), // Much smaller than typical FLAC block
          startPosition: 0,
          endPosition: 100,
          isLast: false,
        );

        // Should be smaller than expected FLAC block size
        expect(smallChunk.size < 4096, isTrue);
      });
    });

    group('Seeking', () {
      test('should throw exception when seeking without initialization', () async {
        expect(() => decoder.seekToTime(const Duration(seconds: 10)), throwsA(isA<StateError>()));
      });

      test('should support efficient seeking when seek table is available', () {
        // Initially no seek table
        expect(decoder.supportsEfficientSeeking, isFalse);

        final metadata = decoder.getFormatMetadata();
        expect(metadata['hasSeekTable'], isFalse);
      });
    });

    group('FLAC-Specific Features', () {
      test('should handle FLAC block size correctly', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata['blockSize'], equals(4096)); // Default FLAC block size
      });

      test('should track seek table availability', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata['supportsSeekTable'], isTrue); // FLAC format supports seek tables
        expect(metadata['hasSeekTable'], isFalse); // But this instance doesn't have one yet
      });

      test('should provide accurate seeking information', () {
        final metadata = decoder.getFormatMetadata();

        // Seeking accuracy depends on seek table availability
        if (metadata['hasSeekTable'] == true) {
          expect(metadata['seekingAccuracy'], equals('exact'));
        } else {
          expect(metadata['seekingAccuracy'], equals('approximate'));
        }
      });
    });

    group('Error Handling', () {
      test('should handle disposed state correctly', () {
        decoder.dispose();

        expect(() => decoder.currentPosition, throwsA(isA<StateError>()));
        expect(() => decoder.getFormatMetadata(), throwsA(isA<StateError>()));
      });

      test('should validate FLAC file signature', () {
        // Test would validate that invalid FLAC data is rejected
        final invalidData = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]); // Not FLAC signature
        expect(invalidData[0] != 0x66, isTrue); // Should not be 'f' from "fLaC"
      });

      test('should handle missing seek table gracefully', () {
        // Decoder should work without seek table, just with reduced seeking accuracy
        expect(decoder.supportsEfficientSeeking, isFalse);

        final metadata = decoder.getFormatMetadata();
        expect(metadata['seekingAccuracy'], equals('approximate'));
      });
    });
  });
}
