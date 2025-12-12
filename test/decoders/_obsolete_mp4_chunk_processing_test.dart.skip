import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/models/file_chunk.dart';

void main() {
  group('MP4Decoder Enhanced Chunk Processing', () {
    late MP4Decoder decoder;

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Chunk Processing Interface', () {
      test('should throw StateError when processing chunks without initialization', () async {
        final chunk = _createTestFileChunk(_createAACFrameData(), 0, false);

        await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
      });

      test('should handle empty chunk data without initialization', () async {
        final emptyChunk = _createTestFileChunk([], 0, true);

        await expectLater(() => decoder.processFileChunk(emptyChunk), throwsStateError);
      });

      test('should handle various chunk sizes without initialization', () async {
        final chunkSizes = [1024, 4096, 16384, 65536]; // 1KB to 64KB

        for (final chunkSize in chunkSizes) {
          final chunk = _createTestFileChunk(List.filled(chunkSize, 0), 0, true);

          await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
        }
      });

      test('should handle last chunk flag correctly without initialization', () async {
        final lastChunk = _createTestFileChunk(List.filled(1024, 0xFF), 0, true);

        await expectLater(() => decoder.processFileChunk(lastChunk), throwsStateError);
      });

      test('should handle corrupted chunk data without initialization', () async {
        final corruptedChunk = _createTestFileChunk([0xFF, 0xFF, 0xFF, 0xFF], 0, true);

        await expectLater(() => decoder.processFileChunk(corruptedChunk), throwsStateError);
      });
    });

    group('Chunk Size Recommendations', () {
      test('should recommend appropriate chunk size for small MP4 files', () {
        final recommendation = decoder.getOptimalChunkSize(1 * 1024 * 1024); // 1MB

        expect(recommendation.recommendedSize, greaterThan(8192));
        expect(recommendation.recommendedSize, lessThanOrEqualTo(512 * 1024));
        expect(recommendation.minSize, equals(8192));
        expect(recommendation.maxSize, equals(1 * 1024 * 1024));
        expect(recommendation.reason, contains('Small MP4 file'));
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
        expect(recommendation.metadata?['avgFrameSize'], equals(768));
      });

      test('should recommend appropriate chunk size for medium MP4 files', () {
        final recommendation = decoder.getOptimalChunkSize(50 * 1024 * 1024); // 50MB

        expect(recommendation.recommendedSize, equals(4 * 1024 * 1024)); // 4MB
        expect(recommendation.minSize, equals(512 * 1024)); // 512KB
        expect(recommendation.maxSize, equals(20 * 1024 * 1024)); // 20MB
        expect(recommendation.reason, contains('Medium MP4 file'));
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
      });

      test('should recommend appropriate chunk size for large MP4 files', () {
        final recommendation = decoder.getOptimalChunkSize(200 * 1024 * 1024); // 200MB

        expect(recommendation.recommendedSize, equals(8 * 1024 * 1024)); // 8MB
        expect(recommendation.minSize, equals(2 * 1024 * 1024)); // 2MB
        expect(recommendation.maxSize, equals(50 * 1024 * 1024)); // 50MB
        expect(recommendation.reason, contains('Large MP4 file'));
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
      });
    });

    group('Format Metadata', () {
      test('should return correct format metadata for MP4', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata['format'], equals('MP4/AAC'));
        expect(metadata['supportsSeekTable'], isTrue);
        expect(metadata['seekingAccuracy'], equals('high'));
        expect(metadata['avgFrameSize'], equals(768));
      });
    });

    group('State Management', () {
      test('should track current position correctly', () {
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should support efficient seeking', () {
        expect(decoder.supportsEfficientSeeking, isTrue);
      });

      test('should reset state correctly', () async {
        await decoder.resetDecoderState();
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should cleanup resources correctly', () async {
        await decoder.cleanupChunkedProcessing();
        expect(decoder.isInitialized, isFalse);
      });

      test('should maintain initialization state', () {
        expect(decoder.isInitialized, isFalse);
      });
    });

    group('Error Handling', () {
      test('should throw StateError for operations requiring initialization', () async {
        // Test that all chunk processing operations require initialization
        final chunk = _createTestFileChunk([1, 2, 3, 4], 0, false);

        await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
        await expectLater(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
      });

      test('should handle disposed state correctly', () {
        decoder.dispose();

        expect(() => decoder.currentPosition, throwsStateError);
        expect(() => decoder.getFormatMetadata(), throwsStateError);
        expect(() => decoder.processFileChunk(_createTestFileChunk([1, 2, 3], 0, false)), throwsStateError);
      });
    });

    group('Buffer Management Logic', () {
      test('should have appropriate decode threshold for MP4/AAC', () {
        // Test that the decoder has reasonable constants for AAC processing
        // This tests the internal constants indirectly through chunk size recommendations
        final smallFileRec = decoder.getOptimalChunkSize(100 * 1024); // 100KB
        final largeFileRec = decoder.getOptimalChunkSize(100 * 1024 * 1024); // 100MB

        // AAC frames are larger than MP3, so recommendations should reflect this
        expect(smallFileRec.metadata?['avgFrameSize'], equals(768));
        expect(largeFileRec.metadata?['avgFrameSize'], equals(768));
      });
    });
  });
}

/// Create a test FileChunk with the given data
FileChunk _createTestFileChunk(List<int> data, int startPosition, bool isLast) {
  return FileChunk(data: Uint8List.fromList(data), startPosition: startPosition, endPosition: startPosition + data.length, isLast: isLast);
}

/// Create synthetic AAC frame data for testing
List<int> _createAACFrameData({bool partial = false, bool completion = false}) {
  if (partial) {
    // Return partial AAC frame (first half)
    return List.filled(384, 0xAA); // Half of typical 768-byte frame
  } else if (completion) {
    // Return completion of AAC frame (second half)
    return List.filled(384, 0xBB); // Second half of frame
  } else {
    // Return complete AAC frame
    return List.filled(768, 0xCC); // Typical AAC frame size
  }
}
