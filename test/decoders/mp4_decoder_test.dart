import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/decoders/chunked_audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';

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

    group('MP4 Container Validation', () {
      test('should throw MP4ContainerException for invalid MP4 signature', () async {
        // Create a file with invalid MP4 signature
        final tempFile = File('test_invalid_signature.mp4');
        final invalidData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x69, 0x6E, 0x76, 0x64, // 'invd' instead of 'ftyp'
          0x69, 0x73, 0x6F, 0x6D, // 'isom'
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand
          0x69, 0x73, 0x6F, 0x32, // Compatible brand
          0x61, 0x76, 0x63, 0x31, // Compatible brand
          0x6D, 0x70, 0x34, 0x31, // Compatible brand
        ]);
        await tempFile.writeAsBytes(invalidData);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<MP4ContainerException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should throw MP4ContainerException for file too small', () async {
        // Create a file that's too small to be valid MP4
        final tempFile = File('test_too_small.mp4');
        final tooSmallData = Uint8List.fromList([0x00, 0x00, 0x00, 0x20]); // Only 4 bytes
        await tempFile.writeAsBytes(tooSmallData);

        try {
          expect(() => decoder.decode(tempFile.path), throwsA(isA<MP4ContainerException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should handle valid MP4 signature but unsupported format gracefully', () async {
        // Create a file with valid MP4 signature but minimal content
        final tempFile = File('test_valid_signature.mp4');
        final validSignatureData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
          0x66, 0x74, 0x79, 0x70, // 'ftyp' - valid MP4 signature
          0x69, 0x73, 0x6F, 0x6D, // 'isom' major brand
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand
          0x69, 0x73, 0x6F, 0x32, // Compatible brand
          0x61, 0x76, 0x63, 0x31, // Compatible brand
          0x6D, 0x70, 0x34, 0x31, // Compatible brand
          // Add some padding to make it larger than minimum size
          ...List.filled(32, 0x00),
        ]);
        await tempFile.writeAsBytes(validSignatureData);

        try {
          // Should pass container validation but fail at native decoding
          expect(() => decoder.decode(tempFile.path), throwsA(isA<SonixException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });
    });

    group('MP4-Specific Error Handling', () {
      test('should handle native library MP4 not implemented error', () async {
        // Create a valid MP4 container structure
        final tempFile = File('test_mp4_not_implemented.mp4');
        final validMP4Data = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp'
          0x69, 0x73, 0x6F, 0x6D, // 'isom'
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand
          0x69, 0x73, 0x6F, 0x32, // Compatible brand
          0x61, 0x76, 0x63, 0x31, // Compatible brand
          0x6D, 0x70, 0x34, 0x31, // Compatible brand
          ...List.filled(64, 0x00), // Padding
        ]);
        await tempFile.writeAsBytes(validMP4Data);

        try {
          // Should throw UnsupportedFormatException when native library doesn't support MP4
          expect(() => decoder.decode(tempFile.path), throwsA(isA<UnsupportedFormatException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should handle memory limit exceeded for large files', () async {
        // This test simulates a large file by mocking the memory limit check
        // In a real scenario, we'd need a very large MP4 file
        final tempFile = File('test_memory_limit.mp4');
        final validMP4Data = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp'
          0x69, 0x73, 0x6F, 0x6D, // 'isom'
          0x00, 0x00, 0x02, 0x00, // Minor version
          0x69, 0x73, 0x6F, 0x6D, // Compatible brand
          0x69, 0x73, 0x6F, 0x32, // Compatible brand
          0x61, 0x76, 0x63, 0x31, // Compatible brand
          0x6D, 0x70, 0x34, 0x31, // Compatible brand
          ...List.filled(64, 0x00), // Padding
        ]);
        await tempFile.writeAsBytes(validMP4Data);

        try {
          // Temporarily set a very low memory threshold to trigger the error
          final originalThreshold = NativeAudioBindings.memoryPressureThreshold;
          NativeAudioBindings.setMemoryPressureThreshold(32); // Very small threshold

          try {
            await expectLater(() => decoder.decode(tempFile.path), throwsA(isA<MemoryException>()));
          } finally {
            // Restore original threshold
            NativeAudioBindings.setMemoryPressureThreshold(originalThreshold);
          }
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
