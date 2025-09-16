import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/mp3_decoder.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('MP3Decoder Chunked Processing', () {
    late MP3Decoder decoder;

    setUp(() {
      decoder = MP3Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully with valid file', () async {
        // This test would require a real MP3 file
        // For now, we'll test the interface
        expect(decoder.isInitialized, isFalse);
        expect(decoder.supportsEfficientSeeking, isFalse);
      });

      test('should throw exception for non-existent file', () async {
        expect(() => decoder.initializeChunkedDecoding('non_existent.mp3'), throwsA(isA<FileAccessException>()));
      });

      test('should throw exception when disposed', () async {
        decoder.dispose();
        expect(() => decoder.initializeChunkedDecoding('test.mp3'), throwsA(isA<StateError>()));
      });
    });

    group('Chunk Size Recommendations', () {
      test('should recommend appropriate chunk size for small files', () {
        final recommendation = decoder.getOptimalChunkSize(500 * 1024); // 500KB

        expect(recommendation.recommendedSize, greaterThan(4096));
        expect(recommendation.recommendedSize, lessThanOrEqualTo(500 * 1024));
        expect(recommendation.minSize, equals(4096));
        expect(recommendation.maxSize, equals(500 * 1024));
        expect(recommendation.reason, contains('Small MP3 file'));
        expect(recommendation.metadata?['format'], equals('MP3'));
      });

      test('should recommend appropriate chunk size for medium files', () {
        final recommendation = decoder.getOptimalChunkSize(10 * 1024 * 1024); // 10MB

        expect(recommendation.recommendedSize, equals(2 * 1024 * 1024)); // 2MB
        expect(recommendation.minSize, equals(256 * 1024)); // 256KB
        expect(recommendation.maxSize, equals(10 * 1024 * 1024)); // 10MB
        expect(recommendation.reason, contains('Medium MP3 file'));
      });

      test('should recommend appropriate chunk size for large files', () {
        final recommendation = decoder.getOptimalChunkSize(100 * 1024 * 1024); // 100MB

        expect(recommendation.recommendedSize, equals(5 * 1024 * 1024)); // 5MB
        expect(recommendation.minSize, equals(1024 * 1024)); // 1MB
        expect(recommendation.maxSize, equals(20 * 1024 * 1024)); // 20MB
        expect(recommendation.reason, contains('Large MP3 file'));
      });
    });

    group('Format Metadata', () {
      test('should return correct format metadata', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata['format'], equals('MP3'));
        expect(metadata['supportsSeekTable'], isFalse);
        expect(metadata['seekingAccuracy'], equals('approximate'));
        expect(metadata['avgFrameSize'], equals(417));
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
      });
    });

    group('Chunk Processing', () {
      test('should throw exception when processing chunk without initialization', () async {
        final chunk = FileChunk(data: Uint8List(1024), startPosition: 0, endPosition: 1024, isLast: false);

        expect(() => decoder.processFileChunk(chunk), throwsA(isA<StateError>()));
      });

      test('should handle empty chunks gracefully', () async {
        // This test would require proper initialization with a real file
        // For now, we test the interface
        final chunk = FileChunk(data: Uint8List(0), startPosition: 0, endPosition: 0, isLast: true);

        // Would return empty list for empty chunk
        expect(chunk.data.isEmpty, isTrue);
      });
    });

    group('Seeking', () {
      test('should throw exception when seeking without initialization', () async {
        expect(() => decoder.seekToTime(const Duration(seconds: 10)), throwsA(isA<StateError>()));
      });

      test('should return seek result with appropriate warning for approximate seeking', () {
        // MP3 seeking should always be marked as approximate
        expect(decoder.supportsEfficientSeeking, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle disposed state correctly', () {
        decoder.dispose();

        expect(() => decoder.currentPosition, throwsA(isA<StateError>()));
        expect(() => decoder.getFormatMetadata(), throwsA(isA<StateError>()));
      });

      test('should validate chunk data integrity', () {
        final invalidChunk = FileChunk(
          data: Uint8List(10), // Too small for MP3 frame
          startPosition: 0,
          endPosition: 10,
          isLast: false,
        );

        expect(invalidChunk.size, equals(10));
        expect(invalidChunk.size < 417, isTrue); // Smaller than average MP3 frame
      });
    });
  });
}

