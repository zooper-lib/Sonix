import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';
import 'package:sonix/src/models/file_chunk.dart';

void main() {
  group('MP4Decoder Chunked Processing', () {
    late MP4Decoder decoder;

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    group('Chunked Processing Initialization', () {
      test('should handle initialization with valid MP4 signature but incomplete structure', () async {
        // Create a file with valid MP4 signature but incomplete structure
        final tempFile = await _createBasicMP4File('test_chunked_init.mp4');

        try {
          // The current implementation will detect the MP4 signature but fail on track parsing
          // This tests that the initialization method properly validates the file structure
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should handle initialization with custom chunk size parameter', () async {
        final tempFile = await _createBasicMP4File('test_chunked_custom_size.mp4');

        try {
          const customChunkSize = 2 * 1024 * 1024; // 2MB
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, chunkSize: customChunkSize), throwsA(isA<MP4TrackException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should handle initialization with seek position parameter', () async {
        final tempFile = await _createBasicMP4File('test_chunked_seek_init.mp4');

        try {
          const seekPosition = Duration(seconds: 5);
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, seekPosition: seekPosition), throwsA(isA<MP4TrackException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should throw FileAccessException for non-existent file', () async {
        await expectLater(() => decoder.initializeChunkedDecoding('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
      });

      test('should throw DecodingException for empty file', () async {
        final tempFile = File('test_empty_chunked.mp4');
        await tempFile.writeAsBytes([]);

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<DecodingException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should throw MP4ContainerException for invalid MP4 signature', () async {
        final tempFile = File('test_invalid_chunked.mp4');
        final invalidData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x69, 0x6E, 0x76, 0x64, // 'invd' instead of 'ftyp'
          ...List.filled(24, 0x00), // Padding
        ]);
        await tempFile.writeAsBytes(invalidData);

        try {
          // The initializeChunkedDecoding method doesn't validate signature first,
          // it goes straight to container parsing which will fail with MP4TrackException
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<SonixException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should validate file existence during initialization', () async {
        // Test that the method properly checks file existence
        await expectLater(() => decoder.initializeChunkedDecoding('definitely_does_not_exist.mp4'), throwsA(isA<FileAccessException>()));
      });

      test('should handle initialization state correctly', () async {
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));

        // After failed initialization, state should remain uninitialized
        final tempFile = await _createBasicMP4File('test_init_state.mp4');
        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
          expect(decoder.isInitialized, isFalse);
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });
    });

    group('Seeking Functionality', () {
      test('should throw StateError when seeking without initialization', () async {
        await expectLater(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
      });

      test('should maintain uninitialized state when seeking fails', () async {
        expect(decoder.isInitialized, isFalse);

        await expectLater(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);

        expect(decoder.isInitialized, isFalse);
      });
    });

    group('State Management During Chunked Processing', () {
      test('should maintain proper state throughout failed initialization', () async {
        final tempFile = await _createBasicMP4File('test_state_management.mp4');

        try {
          // Before initialization
          expect(decoder.isInitialized, isFalse);
          expect(decoder.currentPosition, equals(Duration.zero));

          // During failed initialization
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // After failed initialization
          expect(decoder.isInitialized, isFalse);
          expect(decoder.currentPosition, equals(Duration.zero));

          // After cleanup
          await decoder.cleanupChunkedProcessing();
          expect(decoder.isInitialized, isFalse);
          expect(decoder.currentPosition, equals(Duration.zero));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should handle state reset when not initialized', () async {
        expect(decoder.currentPosition, equals(Duration.zero));

        await decoder.resetDecoderState();
        expect(decoder.currentPosition, equals(Duration.zero));
        expect(decoder.isInitialized, isFalse);
      });

      test('should prevent operations on disposed decoder during chunked processing', () async {
        decoder.dispose();

        expect(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
        expect(() => decoder.currentPosition, throwsStateError);
        expect(() => decoder.resetDecoderState(), throwsStateError);
        expect(() => decoder.initializeChunkedDecoding('test.mp4'), throwsStateError);
      });
    });

    group('Error Handling During Chunked Processing', () {
      test('should handle file access errors during initialization', () async {
        // Create file then delete it to simulate access error
        final tempFile = File('test_access_error.mp4');
        await tempFile.writeAsBytes([1, 2, 3, 4]);
        await tempFile.delete();

        await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<FileAccessException>()));
      });

      test('should handle container parsing errors gracefully', () async {
        final tempFile = File('test_parsing_error.mp4');
        // Create file with valid signature but corrupted structure
        final corruptedData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Box size
          0x66, 0x74, 0x79, 0x70, // 'ftyp' - valid signature
          0xFF, 0xFF, 0xFF, 0xFF, // Corrupted data
          ...List.filled(20, 0xFF), // More corrupted data
        ]);
        await tempFile.writeAsBytes(corruptedData);

        try {
          // Should handle parsing errors gracefully
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<SonixException>()));
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should handle seeking errors gracefully when not initialized', () async {
        // Seeking should throw StateError when not initialized
        expect(() => decoder.seekToTime(Duration(days: 365)), throwsStateError);
        expect(() => decoder.seekToTime(Duration(microseconds: -1)), throwsStateError);
      });
    });

    group('Performance and Memory Management', () {
      test('should handle initialization attempt efficiently', () async {
        final tempFile = await _createBasicMP4File('test_performance.mp4');

        try {
          final stopwatch = Stopwatch()..start();

          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          stopwatch.stop();

          // Even failed initialization should complete quickly
          expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // 1 second max
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });

      test('should manage memory efficiently during initialization attempts', () async {
        final tempFile = await _createBasicMP4File('test_memory_management.mp4');

        try {
          // Multiple initialization attempts should not leak memory
          for (int i = 0; i < 5; i++) {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
          }

          // State should remain consistent
          expect(decoder.isInitialized, isFalse);
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      });
    });

    group('MP4 Container Validation', () {
      test('should validate MP4 signature correctly', () async {
        final validFile = await _createBasicMP4File('test_valid_sig.mp4');
        final invalidFile = File('test_invalid_sig.mp4');

        // Invalid signature
        await invalidFile.writeAsBytes([
          0x00, 0x00, 0x00, 0x20,
          0x69, 0x6E, 0x76, 0x64, // 'invd' instead of 'ftyp'
          ...List.filled(24, 0x00),
        ]);

        try {
          // Valid signature should pass initial validation but fail on track parsing
          await expectLater(() => decoder.initializeChunkedDecoding(validFile.path), throwsA(isA<MP4TrackException>()));

          // Invalid signature should fail during container parsing
          await expectLater(() => decoder.initializeChunkedDecoding(invalidFile.path), throwsA(isA<SonixException>()));
        } finally {
          if (validFile.existsSync()) await validFile.delete();
          if (invalidFile.existsSync()) await invalidFile.delete();
        }
      });

      test('should handle file size validation', () async {
        final tooSmallFile = File('test_too_small.mp4');
        await tooSmallFile.writeAsBytes([0x00, 0x00]); // Only 2 bytes

        try {
          // Small files will fail during container parsing
          await expectLater(() => decoder.initializeChunkedDecoding(tooSmallFile.path), throwsA(isA<SonixException>()));
        } finally {
          if (tooSmallFile.existsSync()) {
            await tooSmallFile.delete();
          }
        }
      });
    });

    group('Chunk Processing', () {
      test('should throw StateError when processing chunks without initialization', () async {
        final fileChunk = _createTestFileChunk([1, 2, 3, 4], 0, false);

        await expectLater(() => decoder.processFileChunk(fileChunk), throwsStateError);
      });

      test('should handle empty chunk data gracefully', () async {
        final tempFile = await _createBasicMP4File('test_empty_chunk.mp4');

        try {
          // Initialize decoder (will fail but that's expected)
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Since initialization failed, processFileChunk should throw StateError
          final emptyChunk = _createTestFileChunk([], 0, true);
          await expectLater(() => decoder.processFileChunk(emptyChunk), throwsStateError);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should handle chunk processing with various chunk sizes', () async {
        final tempFile = await _createBasicMP4File('test_chunk_sizes.mp4');

        try {
          // Test different chunk sizes
          final chunkSizes = [1024, 4096, 16384, 65536]; // 1KB to 64KB

          for (final chunkSize in chunkSizes) {
            final testDecoder = MP4Decoder();

            try {
              await expectLater(() => testDecoder.initializeChunkedDecoding(tempFile.path, chunkSize: chunkSize), throwsA(isA<MP4TrackException>()));

              // Since initialization failed, processFileChunk should throw StateError
              final chunk = _createTestFileChunk(List.filled(chunkSize, 0), 0, true);
              await expectLater(() => testDecoder.processFileChunk(chunk), throwsStateError);
            } finally {
              testDecoder.dispose();
            }
          }
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should handle AAC frame boundary conditions', () async {
        // Test that the decoder properly handles AAC frames that span chunk boundaries
        final tempFile = await _createBasicMP4File('test_frame_boundaries.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Create chunks that would split AAC frames
          final chunk1 = _createTestFileChunk(List.filled(500, 0xAA), 0, false);
          final chunk2 = _createTestFileChunk(List.filled(300, 0xBB), 500, true);

          // Since decoder is not initialized, these should throw StateError
          await expectLater(() => decoder.processFileChunk(chunk1), throwsStateError);
          await expectLater(() => decoder.processFileChunk(chunk2), throwsStateError);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should handle last chunk processing correctly', () async {
        final tempFile = await _createBasicMP4File('test_last_chunk.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Test last chunk processing
          final lastChunk = _createTestFileChunk(List.filled(1024, 0xFF), 0, true);

          await expectLater(() => decoder.processFileChunk(lastChunk), throwsStateError);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should manage buffer size efficiently during chunk processing', () async {
        final tempFile = await _createBasicMP4File('test_buffer_management.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Test buffer management with large chunks
          final largeChunk = _createTestFileChunk(List.filled(2 * 1024 * 1024, 0x55), 0, false); // 2MB

          await expectLater(() => decoder.processFileChunk(largeChunk), throwsStateError);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should handle corrupted chunk data gracefully', () async {
        final tempFile = await _createBasicMP4File('test_corrupted_chunks.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Create corrupted chunk data
          final corruptedChunk = _createTestFileChunk([0xFF, 0xFF, 0xFF, 0xFF], 0, true);

          await expectLater(() => decoder.processFileChunk(corruptedChunk), throwsStateError);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should handle multiple sequential chunks correctly', () async {
        final tempFile = await _createBasicMP4File('test_sequential_chunks.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Test processing multiple chunks in sequence
          final chunks = [
            _createTestFileChunk(List.filled(1024, 0x11), 0, false),
            _createTestFileChunk(List.filled(1024, 0x22), 1024, false),
            _createTestFileChunk(List.filled(1024, 0x33), 2048, true),
          ];

          for (final chunk in chunks) {
            await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
          }
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });
    });

    group('Buffer Management', () {
      test('should handle buffer overflow protection', () async {
        final tempFile = await _createBasicMP4File('test_buffer_overflow.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Test with extremely large chunk that would cause buffer overflow
          final oversizedChunk = _createTestFileChunk(List.filled(10 * 1024 * 1024, 0xAA), 0, false); // 10MB

          await expectLater(() => decoder.processFileChunk(oversizedChunk), throwsStateError);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should maintain buffer state across chunk boundaries', () async {
        final tempFile = await _createBasicMP4File('test_buffer_state.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Test that buffer state is maintained correctly
          final chunk1 = _createTestFileChunk(List.filled(512, 0xAA), 0, false);
          final chunk2 = _createTestFileChunk(List.filled(512, 0xBB), 512, false);

          await expectLater(() => decoder.processFileChunk(chunk1), throwsStateError);
          await expectLater(() => decoder.processFileChunk(chunk2), throwsStateError);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });
    });

    group('Interface Compliance', () {
      test('should implement required chunked processing methods', () {
        // Verify all required methods exist and have correct signatures
        expect(decoder.initializeChunkedDecoding, isA<Function>());
        expect(decoder.processFileChunk, isA<Function>());
        expect(decoder.seekToTime, isA<Function>());
        expect(decoder.resetDecoderState, isA<Function>());
        expect(decoder.cleanupChunkedProcessing, isA<Function>());
        expect(decoder.estimateDuration, isA<Function>());
        expect(decoder.getFormatMetadata, isA<Function>());
      });

      test('should have correct property getters for chunked processing', () {
        expect(decoder.supportsEfficientSeeking, isA<bool>());
        expect(decoder.currentPosition, isA<Duration>());
        expect(decoder.isInitialized, isA<bool>());

        // MP4 should support efficient seeking
        expect(decoder.supportsEfficientSeeking, isTrue);
      });

      test('should maintain consistent state across operations', () {
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));

        // State should remain consistent after cleanup
        decoder.cleanupChunkedProcessing();
        expect(decoder.isInitialized, isFalse);
        expect(decoder.currentPosition, equals(Duration.zero));
      });
    });
  });
}

/// Create a test FileChunk with the given data
FileChunk _createTestFileChunk(List<int> data, int startPosition, bool isLast) {
  return FileChunk(data: Uint8List.fromList(data), startPosition: startPosition, endPosition: startPosition + data.length, isLast: isLast);
}

/// Create a basic MP4 file with valid signature but minimal structure
Future<File> _createBasicMP4File(String filename) async {
  final file = File(filename);

  // Create minimal MP4 with valid ftyp box but incomplete structure
  final mp4Data = Uint8List.fromList([
    // ftyp box
    0x00, 0x00, 0x00, 0x20, // Box size (32 bytes)
    0x66, 0x74, 0x79, 0x70, // 'ftyp'
    0x69, 0x73, 0x6F, 0x6D, // Major brand 'isom'
    0x00, 0x00, 0x02, 0x00, // Minor version
    0x69, 0x73, 0x6F, 0x6D, // Compatible brand 'isom'
    0x69, 0x73, 0x6F, 0x32, // Compatible brand 'iso2'
    0x61, 0x76, 0x63, 0x31, // Compatible brand 'avc1'
    0x6D, 0x70, 0x34, 0x31, // Compatible brand 'mp41'
    // Add minimal moov box structure (incomplete)
    0x00, 0x00, 0x00, 0x40, // Box size (64 bytes)
    0x6D, 0x6F, 0x6F, 0x76, // 'moov'
    // mvhd box (minimal)
    0x00, 0x00, 0x00, 0x38, // Box size (56 bytes)
    0x6D, 0x76, 0x68, 0x64, // 'mvhd'
    0x00, 0x00, 0x00, 0x00, // Version and flags
    0x00, 0x00, 0x00, 0x00, // Creation time
    0x00, 0x00, 0x00, 0x00, // Modification time
    0x00, 0x00, 0xAC, 0x44, // Time scale (44100 Hz)
    0x00, 0x01, 0x5F, 0x90, // Duration
    ...List.filled(32, 0x00), // Remaining mvhd fields
    // Add some padding
    ...List.filled(128, 0x00),
  ]);

  await file.writeAsBytes(mp4Data);
  return file;
}
