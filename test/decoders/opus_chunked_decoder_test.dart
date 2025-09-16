import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/decoders/opus_decoder.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

void main() {
  group('OpusDecoder Chunked Processing', () {
    late OpusDecoder decoder;

    setUp(() {
      decoder = OpusDecoder();
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
        expect(() => decoder.initializeChunkedDecoding('non_existent.opus'), throwsA(isA<FileAccessException>()));
      });

      test('should throw exception when disposed', () async {
        decoder.dispose();
        expect(() => decoder.initializeChunkedDecoding('test.opus'), throwsA(isA<StateError>()));
      });
    });

    group('Chunk Size Recommendations', () {
      test('should recommend appropriate chunk size for small files', () {
        final recommendation = decoder.getOptimalChunkSize(1024 * 1024); // 1MB

        expect(recommendation.recommendedSize, greaterThan(0));
        expect(recommendation.recommendedSize, lessThanOrEqualTo(1024 * 1024));
        expect(recommendation.minSize, greaterThan(0));
        expect(recommendation.maxSize, equals(1024 * 1024));
        expect(recommendation.reason, contains('Small Opus file'));
        expect(recommendation.metadata?['format'], equals('Opus'));
        expect(recommendation.metadata?['avgPageSize'], equals(4096));
        expect(recommendation.metadata?['implemented'], isFalse);
      });

      test('should recommend appropriate chunk size for medium files', () {
        final recommendation = decoder.getOptimalChunkSize(25 * 1024 * 1024); // 25MB

        expect(recommendation.recommendedSize, equals(8 * 1024 * 1024)); // 8MB
        expect(recommendation.minSize, equals(2 * 1024 * 1024)); // 2MB
        expect(recommendation.maxSize, equals(16 * 1024 * 1024)); // 16MB
        expect(recommendation.reason, contains('Medium Opus file'));
        expect(recommendation.metadata?['format'], equals('Opus'));
      });

      test('should recommend appropriate chunk size for large files', () {
        final recommendation = decoder.getOptimalChunkSize(100 * 1024 * 1024); // 100MB

        expect(recommendation.recommendedSize, equals(16 * 1024 * 1024)); // 16MB
        expect(recommendation.minSize, equals(8 * 1024 * 1024)); // 8MB
        expect(recommendation.maxSize, equals(32 * 1024 * 1024)); // 32MB
        expect(recommendation.reason, contains('Large Opus file'));
        expect(recommendation.metadata?['format'], equals('Opus'));
      });
    });

    group('Format Metadata', () {
      test('should return correct format metadata', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata['format'], equals('Opus'));
        expect(metadata['description'], equals('Opus audio codec in OGG container'));
        expect(metadata['fileExtensions'], equals(['opus']));
        expect(metadata['supportsChunkedDecoding'], isFalse); // Not implemented yet
        expect(metadata['supportsEfficientSeeking'], isFalse);
        expect(metadata['implementationStatus'], contains('libopus integration needed'));
        expect(metadata['isImplemented'], isFalse);
      });
    });

    group('Decoder State Management', () {
      test('should support efficient seeking check', () {
        expect(decoder.supportsEfficientSeeking, isFalse);
      });

      test('should handle cleanup properly', () async {
        await decoder.cleanupChunkedProcessing();
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should handle reset decoder state', () async {
        await decoder.resetDecoderState();
        expect(decoder.currentPosition, equals(Duration.zero));
      });
    });

    group('Duration Estimation', () {
      test('should return null for duration when not initialized', () async {
        final duration = await decoder.estimateDuration();
        expect(duration, isNull);
      });
    });

    group('Error Handling', () {
      test('should throw error for chunked processing (not implemented)', () async {
        // Since Opus is not fully implemented, it should throw errors
        expect(() => decoder.initializeChunkedDecoding('test/assets/test_sample.opus'), throwsA(isA<DecodingException>()));
      });

      test('should throw error for file chunk processing', () async {
        final chunk = FileChunk(startPosition: 0, endPosition: 4, data: Uint8List.fromList([1, 2, 3, 4]), isLast: true);

        expect(() => decoder.processFileChunk(chunk), throwsA(isA<StateError>()));
      });

      test('should throw error for seeking', () async {
        expect(() => decoder.seekToTime(Duration(seconds: 1)), throwsA(isA<StateError>()));
      });
    });

    group('Actual File Tests (if available)', () {
      test('should handle opus test file existence check', () {
        // This test checks if test files exist but doesn't fail if they don't
        const testFilePath = 'test/assets/test_sample.opus';
        // We don't actually test decoding since it's not implemented
        // Just verify the decoder throws appropriate errors
        expect(() => decoder.decode(testFilePath), throwsA(isA<DecodingException>()));
      });
    });
  });
}
