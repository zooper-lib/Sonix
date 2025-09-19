import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/decoders/mp4_decoder.dart';
import '../../lib/src/decoders/audio_decoder.dart';
import '../../lib/src/decoders/chunked_audio_decoder.dart';
import '../../lib/src/exceptions/sonix_exceptions.dart';
import '../../lib/src/exceptions/mp4_exceptions.dart';
import '../../lib/src/models/file_chunk.dart';
import '../../lib/src/models/chunked_processing_models.dart';

void main() {
  group('MP4Decoder', () {
    late MP4Decoder decoder;

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Basic Instantiation and Disposal', () {
      test('should create MP4Decoder instance', () {
        expect(decoder, isA<MP4Decoder>());
        expect(decoder, isA<ChunkedAudioDecoder>());
        expect(decoder, isA<AudioDecoder>());
      });

      test('should not be initialized initially', () {
        expect(decoder.isInitialized, isFalse);
      });

      test('should have zero current position initially', () {
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should support efficient seeking', () {
        expect(decoder.supportsEfficientSeeking, isTrue);
      });

      test('should dispose without error', () {
        expect(() => decoder.dispose(), returnsNormally);
      });

      test('should throw StateError when accessing disposed decoder', () {
        decoder.dispose();
        expect(() => decoder.currentPosition, throwsStateError);
        expect(() => decoder.getFormatMetadata(), throwsStateError);
      });

      test('should throw StateError on multiple operations after disposal', () {
        decoder.dispose();

        expect(() => decoder.decode('test.mp4'), throwsStateError);
        expect(() => decoder.initializeChunkedDecoding('test.mp4'), throwsStateError);
        expect(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
        expect(() => decoder.resetDecoderState(), throwsStateError);
      });
    });

    group('State Management', () {
      test('should track disposed state correctly', () {
        expect(decoder.isInitialized, isFalse);
        decoder.dispose();

        // Should throw StateError for any operation after disposal
        expect(() => decoder.currentPosition, throwsStateError);
      });

      test('should handle multiple dispose calls gracefully', () {
        decoder.dispose();
        expect(() => decoder.dispose(), returnsNormally);
      });

      test('should maintain consistent state before initialization', () {
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));
        expect(decoder.supportsEfficientSeeking, isTrue);
      });
    });

    group('Format Metadata', () {
      test('should return correct format metadata before initialization', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata['format'], equals('MP4/AAC'));
        expect(metadata['sampleRate'], equals(0));
        expect(metadata['channels'], equals(0));
        expect(metadata['supportsSeekTable'], isTrue);
        expect(metadata['seekingAccuracy'], equals('high'));
        expect(metadata['avgFrameSize'], equals(768));
      });

      test('should include container info in metadata when available', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata.containsKey('containerInfo'), isTrue);
      });
    });

    group('Chunk Size Recommendations', () {
      test('should return appropriate chunk size for small files', () {
        const fileSize = 1024 * 1024; // 1MB
        final recommendation = decoder.getOptimalChunkSize(fileSize);

        expect(recommendation.recommendedSize, greaterThanOrEqualTo(8192));
        expect(recommendation.recommendedSize, lessThanOrEqualTo(512 * 1024));
        expect(recommendation.minSize, equals(8192));
        expect(recommendation.maxSize, equals(fileSize));
        expect(recommendation.reason, contains('Small MP4 file'));
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
        expect(recommendation.metadata?['avgFrameSize'], equals(768));
      });

      test('should return appropriate chunk size for medium files', () {
        const fileSize = 50 * 1024 * 1024; // 50MB
        final recommendation = decoder.getOptimalChunkSize(fileSize);

        expect(recommendation.recommendedSize, equals(4 * 1024 * 1024));
        expect(recommendation.minSize, equals(512 * 1024));
        expect(recommendation.maxSize, equals(20 * 1024 * 1024));
        expect(recommendation.reason, contains('Medium MP4 file'));
      });

      test('should return appropriate chunk size for large files', () {
        const fileSize = 200 * 1024 * 1024; // 200MB
        final recommendation = decoder.getOptimalChunkSize(fileSize);

        expect(recommendation.recommendedSize, equals(8 * 1024 * 1024));
        expect(recommendation.minSize, equals(2 * 1024 * 1024));
        expect(recommendation.maxSize, equals(50 * 1024 * 1024));
        expect(recommendation.reason, contains('Large MP4 file'));
      });

      test('should handle edge case file sizes', () {
        // Very small file
        final smallRecommendation = decoder.getOptimalChunkSize(1024);
        expect(smallRecommendation.recommendedSize, greaterThanOrEqualTo(8192));

        // Exactly at boundary
        final boundaryRecommendation = decoder.getOptimalChunkSize(2 * 1024 * 1024);
        expect(boundaryRecommendation.recommendedSize, isPositive);
      });
    });

    group('Error Handling', () {
      test('should throw FileAccessException for non-existent file in decode', () async {
        expect(() => decoder.decode('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
      });

      test('should throw FileAccessException for non-existent file in chunked init', () async {
        expect(() => decoder.initializeChunkedDecoding('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
      });

      test('should throw StateError when processing chunks without initialization', () async {
        final chunk = FileChunk(data: Uint8List.fromList([1, 2, 3, 4]), startPosition: 0, endPosition: 4, isLast: false);

        expect(() => decoder.processFileChunk(chunk), throwsStateError);
      });

      test('should throw StateError when seeking without initialization', () async {
        expect(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
      });

      test('should handle empty file gracefully in decode', () async {
        // Create a temporary empty file
        final tempFile = File('test_empty.mp4');
        await tempFile.writeAsBytes([]);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should handle empty file gracefully in chunked initialization', () async {
        // Create a temporary empty file
        final tempFile = File('test_empty_chunked.mp4');
        await tempFile.writeAsBytes([]);

        try {
          expect(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });
    });

    group('Duration Estimation', () {
      test('should return null for duration estimation when not initialized', () async {
        final duration = await decoder.estimateDuration();
        expect(duration, isNull);
      });

      test('should handle duration estimation errors gracefully', () async {
        expect(() => decoder.estimateDuration(), returnsNormally);
      });
    });

    group('Decoder State Reset', () {
      test('should reset decoder state successfully', () async {
        await decoder.resetDecoderState();
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should handle state reset when disposed', () {
        decoder.dispose();
        expect(() => decoder.resetDecoderState(), throwsStateError);
      });
    });

    group('Cleanup Operations', () {
      test('should cleanup chunked processing successfully', () async {
        await decoder.cleanupChunkedProcessing();
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));
      });

      test('should handle cleanup when not initialized', () async {
        expect(() => decoder.cleanupChunkedProcessing(), returnsNormally);
      });

      test('should reset all state during cleanup', () async {
        // Set some state first (this would normally happen during initialization)
        await decoder.cleanupChunkedProcessing();

        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));

        final metadata = decoder.getFormatMetadata();
        expect(metadata['sampleRate'], equals(0));
        expect(metadata['channels'], equals(0));
        expect(metadata['duration'], isNull);
        expect(metadata['bitrate'], equals(0));
      });
    });

    group('Interface Compliance', () {
      test('should implement AudioDecoder interface', () {
        expect(decoder, isA<AudioDecoder>());

        // Verify required methods exist
        expect(decoder.decode, isA<Function>());
        expect(decoder.dispose, isA<Function>());
      });

      test('should implement ChunkedAudioDecoder interface', () {
        expect(decoder, isA<ChunkedAudioDecoder>());

        // Verify required methods exist
        expect(decoder.initializeChunkedDecoding, isA<Function>());
        expect(decoder.processFileChunk, isA<Function>());
        expect(decoder.seekToTime, isA<Function>());
        expect(decoder.getOptimalChunkSize, isA<Function>());
        expect(decoder.resetDecoderState, isA<Function>());
        expect(decoder.cleanupChunkedProcessing, isA<Function>());
        expect(decoder.estimateDuration, isA<Function>());
        expect(decoder.getFormatMetadata, isA<Function>());
      });

      test('should have correct property getters', () {
        expect(decoder.supportsEfficientSeeking, isA<bool>());
        expect(decoder.currentPosition, isA<Duration>());
        expect(decoder.isInitialized, isA<bool>());
      });
    });

    group('MP4-Specific Behavior', () {
      test('should indicate support for efficient seeking', () {
        expect(decoder.supportsEfficientSeeking, isTrue);
      });

      test('should use MP4-specific constants in chunk recommendations', () {
        final recommendation = decoder.getOptimalChunkSize(10 * 1024 * 1024);
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
        expect(recommendation.metadata?['avgFrameSize'], equals(768));
      });

      test('should include MP4-specific metadata fields', () {
        final metadata = decoder.getFormatMetadata();
        expect(metadata['format'], equals('MP4/AAC'));
        expect(metadata['avgFrameSize'], equals(768));
        expect(metadata['seekingAccuracy'], equals('high'));
        expect(metadata['supportsSeekTable'], isTrue);
      });
    });
  });
}
