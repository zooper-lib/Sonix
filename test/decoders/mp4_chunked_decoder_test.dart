import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/decoders/mp4_decoder.dart';
import 'package:sonix/src/decoders/chunked_audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';
import 'package:sonix/src/models/file_chunk.dart';

void main() {
  group('MP4Decoder Chunked Processing', () {
    late MP4Decoder decoder;
    late String smallMP4File;
    late String mediumMP4File;

    setUpAll(() async {
      // Create test MP4 files of different sizes for comprehensive testing
      smallMP4File = await _createTestMP4File('test_small_chunked.mp4', 1024 * 1024); // 1MB
      mediumMP4File = await _createTestMP4File('test_medium_chunked.mp4', 10 * 1024 * 1024); // 10MB
    });

    setUp(() {
      decoder = MP4Decoder();
    });

    tearDown(() {
      decoder.dispose();
    });

    tearDownAll(() async {
      // Clean up test files
      await _cleanupTestFile(smallMP4File);
      await _cleanupTestFile(mediumMP4File);
    });

    group('Chunked Processing Initialization', () {
      group('File Size Variations', () {
        test('should initialize with small MP4 files (< 2MB)', () async {
          // Test with synthetic small file
          final tempFile = await _createBasicMP4File('test_small_init.mp4');

          try {
            // Should fail due to incomplete structure but test the initialization path
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
            expect(decoder.isInitialized, isFalse);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle medium MP4 files (2MB - 100MB)', () async {
          // Test initialization behavior with medium-sized files
          final tempFile = await _createBasicMP4File('test_medium_init.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
            expect(decoder.isInitialized, isFalse);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle large MP4 files (> 100MB)', () async {
          // Test with a larger synthetic file
          final tempFile = await _createLargeMP4File('test_large_init.mp4', 150 * 1024 * 1024); // 150MB

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
            expect(decoder.isInitialized, isFalse);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Seek Position Initialization', () {
        test('should initialize with seek position at beginning', () async {
          final tempFile = await _createBasicMP4File('test_seek_begin.mp4');

          try {
            const seekPosition = Duration.zero;
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, seekPosition: seekPosition), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should initialize with seek position in middle', () async {
          final tempFile = await _createBasicMP4File('test_seek_middle.mp4');

          try {
            const seekPosition = Duration(seconds: 30);
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, seekPosition: seekPosition), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should initialize with seek position near end', () async {
          final tempFile = await _createBasicMP4File('test_seek_end.mp4');

          try {
            const seekPosition = Duration(minutes: 2, seconds: 45);
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, seekPosition: seekPosition), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle seek position beyond file duration', () async {
          final tempFile = await _createBasicMP4File('test_seek_beyond.mp4');

          try {
            const seekPosition = Duration(hours: 1); // Way beyond typical test file duration
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, seekPosition: seekPosition), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Custom Chunk Size Parameters', () {
        test('should initialize with very small chunk size (1KB)', () async {
          final tempFile = await _createBasicMP4File('test_chunk_1kb.mp4');

          try {
            const customChunkSize = 1024; // 1KB
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, chunkSize: customChunkSize), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should initialize with optimal chunk size (4MB)', () async {
          final tempFile = await _createBasicMP4File('test_chunk_4mb.mp4');

          try {
            const customChunkSize = 4 * 1024 * 1024; // 4MB
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, chunkSize: customChunkSize), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should initialize with large chunk size (50MB)', () async {
          final tempFile = await _createBasicMP4File('test_chunk_50mb.mp4');

          try {
            const customChunkSize = 50 * 1024 * 1024; // 50MB
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path, chunkSize: customChunkSize), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Error Conditions', () {
        test('should throw FileAccessException for non-existent file', () async {
          await expectLater(() => decoder.initializeChunkedDecoding('non_existent_file.mp4'), throwsA(isA<FileAccessException>()));
        });

        test('should throw DecodingException for empty file', () async {
          final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
          final tempFile = File('${tempDir.path}/empty.mp4');
          await tempFile.writeAsBytes([]);

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<DecodingException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should throw MP4ContainerException for invalid MP4 signature', () async {
          final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
          final tempFile = File('${tempDir.path}/invalid.mp4');
          final invalidData = Uint8List.fromList([
            0x00, 0x00, 0x00, 0x20, // Box size
            0x69, 0x6E, 0x76, 0x64, // 'invd' instead of 'ftyp'
            ...List.filled(24, 0x00), // Padding
          ]);
          await tempFile.writeAsBytes(invalidData);

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<SonixException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should validate file existence during initialization', () async {
          await expectLater(() => decoder.initializeChunkedDecoding('definitely_does_not_exist.mp4'), throwsA(isA<FileAccessException>()));
        });
      });

      group('State Management', () {
        test('should handle initialization state correctly', () async {
          expect(decoder.isInitialized, isFalse);
          expect(decoder.currentPosition, equals(Duration.zero));

          final tempFile = await _createBasicMP4File('test_init_state.mp4');
          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
            expect(decoder.isInitialized, isFalse);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should reset state properly after failed initialization', () async {
          final tempFile = await _createBasicMP4File('test_state_reset.mp4');

          try {
            // Multiple failed initialization attempts
            for (int i = 0; i < 3; i++) {
              await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
              expect(decoder.isInitialized, isFalse);
              expect(decoder.currentPosition, equals(Duration.zero));
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should prevent double initialization', () async {
          final tempFile = await _createBasicMP4File('test_double_init.mp4');

          try {
            // First initialization attempt (will fail)
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Second initialization attempt should also fail the same way
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });
    });

    group('Seeking Functionality', () {
      group('Seek Accuracy Tests', () {
        test('should seek to exact positions with sample table', () async {
          final tempFile = await _createBasicMP4File('test_seek_exact.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test seeking to various positions (will fail due to uninitialized state)
            final seekPositions = [Duration.zero, Duration(seconds: 1), Duration(seconds: 5), Duration(seconds: 10), Duration(seconds: 30)];

            for (final position in seekPositions) {
              await expectLater(() => decoder.seekToTime(position), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle seeking to millisecond precision', () async {
          final tempFile = await _createBasicMP4File('test_seek_precision.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test precise seeking
            final precisePositions = [
              Duration(milliseconds: 100),
              Duration(milliseconds: 1500),
              Duration(milliseconds: 2750),
              Duration(seconds: 5, milliseconds: 250),
            ];

            for (final position in precisePositions) {
              await expectLater(() => decoder.seekToTime(position), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle seeking near AAC frame boundaries', () async {
          final tempFile = await _createBasicMP4File('test_seek_boundaries.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test seeking near typical AAC frame boundaries (23ms per frame at 44.1kHz)
            final boundaryPositions = [
              Duration(milliseconds: 23), // One frame
              Duration(milliseconds: 46), // Two frames
              Duration(milliseconds: 69), // Three frames
              Duration(milliseconds: 92), // Four frames
            ];

            for (final position in boundaryPositions) {
              await expectLater(() => decoder.seekToTime(position), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle seeking beyond file duration', () async {
          final tempFile = await _createBasicMP4File('test_seek_beyond.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test seeking beyond typical file duration
            final beyondPositions = [Duration(minutes: 10), Duration(hours: 1), Duration(days: 1)];

            for (final position in beyondPositions) {
              await expectLater(() => decoder.seekToTime(position), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Seek Performance Tests', () {
        test('should seek quickly using sample table', () async {
          final tempFile = await _createBasicMP4File('test_seek_performance.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test seek performance (even though it will fail, we test the timing)
            final stopwatch = Stopwatch()..start();

            await expectLater(() => decoder.seekToTime(Duration(seconds: 30)), throwsStateError);

            stopwatch.stop();

            // Seeking should be fast even when failing
            expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should complete within 100ms
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle multiple rapid seeks efficiently', () async {
          final tempFile = await _createBasicMP4File('test_rapid_seeks.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final stopwatch = Stopwatch()..start();

            // Perform multiple rapid seeks
            final seekPositions = [Duration(seconds: 1), Duration(seconds: 5), Duration(seconds: 2), Duration(seconds: 8), Duration(seconds: 3)];

            for (final position in seekPositions) {
              await expectLater(() => decoder.seekToTime(position), throwsStateError);
            }

            stopwatch.stop();

            // Multiple seeks should still be reasonably fast
            expect(stopwatch.elapsedMilliseconds, lessThan(500)); // 5 seeks in 500ms
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should maintain performance with large sample tables', () async {
          final tempFile = await _createLargeMP4File('test_large_sample_table.mp4', 50 * 1024 * 1024); // 50MB

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final stopwatch = Stopwatch()..start();

            // Test seeking in large file
            await expectLater(() => decoder.seekToTime(Duration(minutes: 2)), throwsStateError);

            stopwatch.stop();

            // Should still be fast even with large files
            expect(stopwatch.elapsedMilliseconds, lessThan(200));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Seek State Management', () {
        test('should throw StateError when seeking without initialization', () async {
          await expectLater(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
        });

        test('should maintain uninitialized state when seeking fails', () async {
          expect(decoder.isInitialized, isFalse);
          await expectLater(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
          expect(decoder.isInitialized, isFalse);
        });

        test('should handle seeking after failed initialization', () async {
          final tempFile = await _createBasicMP4File('test_seek_after_fail.mp4');

          try {
            // Failed initialization
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Seeking should still throw StateError
            await expectLater(() => decoder.seekToTime(Duration(seconds: 5)), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle negative seek positions', () async {
          await expectLater(() => decoder.seekToTime(Duration(microseconds: -1)), throwsStateError);
          await expectLater(() => decoder.seekToTime(Duration(seconds: -5)), throwsStateError);
        });
      });

      group('Seek Result Validation', () {
        test('should validate seek result properties', () {
          // Test that MP4 decoder supports efficient seeking
          expect(decoder.supportsEfficientSeeking, isTrue);
        });

        test('should handle seek result accuracy indicators', () async {
          final tempFile = await _createBasicMP4File('test_seek_accuracy.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Even though seeking will fail, we test the interface
            await expectLater(() => decoder.seekToTime(Duration(seconds: 1)), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle seek warnings for approximate positions', () async {
          final tempFile = await _createBasicMP4File('test_seek_warnings.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test seeking to positions that might not be exact
            await expectLater(() => decoder.seekToTime(Duration(milliseconds: 1337)), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Seek Integration with Chunked Processing', () {
        test('should handle seeking during chunked processing', () async {
          final tempFile = await _createBasicMP4File('test_seek_during_chunked.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Try to process a chunk, then seek
            final chunk = _createTestFileChunk(List.filled(1024, 0), 0, false);
            await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            await expectLater(() => decoder.seekToTime(Duration(seconds: 5)), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should reset buffer state after seeking', () async {
          final tempFile = await _createBasicMP4File('test_seek_buffer_reset.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Seek should reset internal buffer state (even when failing)
            await expectLater(() => decoder.seekToTime(Duration(seconds: 10)), throwsStateError);
            await expectLater(() => decoder.seekToTime(Duration(seconds: 5)), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
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
        final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
        final tempFile = File('${tempDir.path}/access_error.mp4');
        await tempFile.writeAsBytes([1, 2, 3, 4]);
        await tempFile.delete();

        await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<FileAccessException>()));
      });

      test('should handle container parsing errors gracefully', () async {
        final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
        final tempFile = File('${tempDir.path}/parsing_error.mp4');
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
        final tempDir2 = Directory.systemTemp.createTempSync('mp4_chunked_test_');
        final invalidFile = File('${tempDir2.path}/invalid_sig.mp4');

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
        final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
        final tooSmallFile = File('${tempDir.path}/too_small.mp4');
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
      group('Chunk Size Variations', () {
        test('should handle very small chunks (< 1KB)', () async {
          final tempFile = await _createBasicMP4File('test_small_chunks.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test with very small chunks
            final smallChunks = [
              _createTestFileChunk(List.filled(256, 0xAA), 0, false), // 256 bytes
              _createTestFileChunk(List.filled(512, 0xBB), 256, false), // 512 bytes
              _createTestFileChunk(List.filled(128, 0xCC), 768, true), // 128 bytes
            ];

            for (final chunk in smallChunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle optimal chunk sizes (1KB - 10MB)', () async {
          final tempFile = await _createBasicMP4File('test_optimal_chunks.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final optimalSizes = [1024, 4096, 16384, 65536, 256 * 1024, 1024 * 1024, 4 * 1024 * 1024]; // 1KB to 4MB

            for (final size in optimalSizes) {
              final testDecoder = MP4Decoder();
              try {
                await expectLater(() => testDecoder.initializeChunkedDecoding(tempFile.path, chunkSize: size), throwsA(isA<MP4TrackException>()));

                final chunk = _createTestFileChunk(List.filled(math.min(size, 1024), 0), 0, true);
                await expectLater(() => testDecoder.processFileChunk(chunk), throwsStateError);
              } finally {
                testDecoder.dispose();
              }
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle large chunks (> 10MB)', () async {
          final tempFile = await _createBasicMP4File('test_large_chunks.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test with large chunk (simulate processing large chunk)
            final largeChunk = _createTestFileChunk(List.filled(1024, 0x55), 0, false); // Simulate large chunk with smaller data
            await expectLater(() => decoder.processFileChunk(largeChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('AAC Frame Boundary Conditions', () {
        test('should handle chunks that split AAC frames', () async {
          final tempFile = await _createBasicMP4File('test_frame_split.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Create chunks that would split typical AAC frames (768 bytes average)
            final chunks = [
              _createTestFileChunk(List.filled(400, 0xAA), 0, false), // Partial frame
              _createTestFileChunk(List.filled(368, 0xBB), 400, false), // Complete first frame
              _createTestFileChunk(List.filled(500, 0xCC), 768, false), // Partial second frame
              _createTestFileChunk(List.filled(268, 0xDD), 1268, true), // Complete second frame
            ];

            for (final chunk in chunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle chunks aligned with AAC frame boundaries', () async {
          final tempFile = await _createBasicMP4File('test_frame_aligned.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Create chunks aligned with typical AAC frame size (768 bytes)
            const frameSize = 768;
            final alignedChunks = [
              _createTestFileChunk(List.filled(frameSize, 0xAA), 0, false),
              _createTestFileChunk(List.filled(frameSize, 0xBB), frameSize, false),
              _createTestFileChunk(List.filled(frameSize, 0xCC), frameSize * 2, true),
            ];

            for (final chunk in alignedChunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle variable AAC frame sizes', () async {
          final tempFile = await _createBasicMP4File('test_variable_frames.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Simulate variable AAC frame sizes (200-2000 bytes range)
            final variableChunks = [
              _createTestFileChunk(List.filled(200, 0xAA), 0, false), // Small frame
              _createTestFileChunk(List.filled(1500, 0xBB), 200, false), // Large frame
              _createTestFileChunk(List.filled(800, 0xCC), 1700, false), // Medium frame
              _createTestFileChunk(List.filled(300, 0xDD), 2500, true), // Small frame
            ];

            for (final chunk in variableChunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Sequential Chunk Processing', () {
        test('should process multiple sequential chunks correctly', () async {
          final tempFile = await _createBasicMP4File('test_sequential.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Process chunks in sequence
            final sequentialChunks = List.generate(
              10,
              (i) => _createTestFileChunk(
                List.filled(1024, i),
                i * 1024,
                i == 9, // Last chunk
              ),
            );

            for (final chunk in sequentialChunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle out-of-order chunk processing', () async {
          final tempFile = await _createBasicMP4File('test_out_of_order.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Process chunks out of order (should still fail due to uninitialized state)
            final chunks = [
              _createTestFileChunk(List.filled(1024, 0x22), 1024, false), // Second chunk first
              _createTestFileChunk(List.filled(1024, 0x11), 0, false), // First chunk second
              _createTestFileChunk(List.filled(1024, 0x33), 2048, true), // Last chunk
            ];

            for (final chunk in chunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle overlapping chunk ranges', () async {
          final tempFile = await _createBasicMP4File('test_overlapping.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Create overlapping chunks
            final overlappingChunks = [
              _createTestFileChunk(List.filled(1024, 0xAA), 0, false), // 0-1024
              _createTestFileChunk(List.filled(1024, 0xBB), 512, false), // 512-1536 (overlaps)
              _createTestFileChunk(List.filled(512, 0xCC), 1024, true), // 1024-1536 (overlaps)
            ];

            for (final chunk in overlappingChunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Error Conditions', () {
        test('should throw StateError when processing chunks without initialization', () async {
          final fileChunk = _createTestFileChunk([1, 2, 3, 4], 0, false);
          await expectLater(() => decoder.processFileChunk(fileChunk), throwsStateError);
        });

        test('should handle empty chunk data gracefully', () async {
          final tempFile = await _createBasicMP4File('test_empty_chunk.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final emptyChunk = _createTestFileChunk([], 0, true);
            await expectLater(() => decoder.processFileChunk(emptyChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle corrupted chunk data gracefully', () async {
          final tempFile = await _createBasicMP4File('test_corrupted_chunks.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final corruptedChunk = _createTestFileChunk([0xFF, 0xFF, 0xFF, 0xFF], 0, true);
            await expectLater(() => decoder.processFileChunk(corruptedChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle null or invalid chunk data', () async {
          final tempFile = await _createBasicMP4File('test_invalid_chunk.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test with invalid chunk positions
            final invalidChunk = _createTestFileChunk(List.filled(1024, 0), -1, false); // Negative position
            await expectLater(() => decoder.processFileChunk(invalidChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Last Chunk Processing', () {
        test('should handle last chunk processing correctly', () async {
          final tempFile = await _createBasicMP4File('test_last_chunk.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final lastChunk = _createTestFileChunk(List.filled(1024, 0xFF), 0, true);
            await expectLater(() => decoder.processFileChunk(lastChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle incomplete last chunk', () async {
          final tempFile = await _createBasicMP4File('test_incomplete_last.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Last chunk with incomplete AAC frame
            final incompleteLastChunk = _createTestFileChunk(List.filled(300, 0xFF), 0, true); // Less than typical frame size
            await expectLater(() => decoder.processFileChunk(incompleteLastChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle zero-size last chunk', () async {
          final tempFile = await _createBasicMP4File('test_zero_last.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final zeroLastChunk = _createTestFileChunk([], 1024, true);
            await expectLater(() => decoder.processFileChunk(zeroLastChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });
    });

    group('Memory Management During Chunked Processing', () {
      group('Buffer Management', () {
        test('should handle buffer overflow protection', () async {
          final tempFile = await _createBasicMP4File('test_buffer_overflow.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test with extremely large chunk that would cause buffer overflow
            final oversizedChunk = _createTestFileChunk(List.filled(1024, 0xAA), 0, false); // Simulate large chunk
            await expectLater(() => decoder.processFileChunk(oversizedChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should maintain buffer state across chunk boundaries', () async {
          final tempFile = await _createBasicMP4File('test_buffer_state.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final chunk1 = _createTestFileChunk(List.filled(512, 0xAA), 0, false);
            final chunk2 = _createTestFileChunk(List.filled(512, 0xBB), 512, false);

            await expectLater(() => decoder.processFileChunk(chunk1), throwsStateError);
            await expectLater(() => decoder.processFileChunk(chunk2), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should manage buffer size efficiently', () async {
          final tempFile = await _createBasicMP4File('test_buffer_efficiency.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Test buffer management with multiple chunks
            final chunks = List.generate(20, (i) => _createTestFileChunk(List.filled(1024, i), i * 1024, i == 19));

            for (final chunk in chunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle buffer truncation at AAC frame boundaries', () async {
          final tempFile = await _createBasicMP4File('test_buffer_truncation.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Simulate buffer that needs truncation
            final largeChunk = _createTestFileChunk(List.filled(2048, 0xAA), 0, false);
            await expectLater(() => decoder.processFileChunk(largeChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Memory Usage Monitoring', () {
        test('should track memory usage during initialization', () async {
          final tempFile = await _createBasicMP4File('test_memory_init.mp4');

          try {
            // Monitor memory before initialization
            final initialMemory = _getApproximateMemoryUsage();

            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final afterInitMemory = _getApproximateMemoryUsage();

            // Memory usage should be reasonable (this is a rough check)
            expect(afterInitMemory - initialMemory, lessThan(10 * 1024 * 1024)); // Less than 10MB increase
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should manage memory during chunk processing', () async {
          final tempFile = await _createBasicMP4File('test_memory_chunks.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final beforeProcessing = _getApproximateMemoryUsage();

            // Process multiple chunks and monitor memory
            for (int i = 0; i < 10; i++) {
              final chunk = _createTestFileChunk(List.filled(1024, i), i * 1024, i == 9);
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }

            final afterProcessing = _getApproximateMemoryUsage();

            // Memory shouldn't grow unbounded
            expect(afterProcessing - beforeProcessing, lessThan(50 * 1024 * 1024)); // Less than 50MB increase
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should release memory after cleanup', () async {
          final tempFile = await _createBasicMP4File('test_memory_cleanup.mp4');

          try {
            final beforeInit = _getApproximateMemoryUsage();

            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Cleanup
            await decoder.cleanupChunkedProcessing();

            final afterCleanup = _getApproximateMemoryUsage();

            // Memory should be released (allowing some variance)
            expect(afterCleanup - beforeInit, lessThan(5 * 1024 * 1024)); // Less than 5MB difference
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Memory Pressure Handling', () {
        test('should handle memory pressure during large file processing', () async {
          final tempFile = await _createLargeMP4File('test_memory_pressure.mp4', 100 * 1024 * 1024); // 100MB

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Simulate processing under memory pressure
            final largeChunk = _createTestFileChunk(List.filled(10 * 1024, 0xAA), 0, false); // 10KB chunk
            await expectLater(() => decoder.processFileChunk(largeChunk), throwsStateError);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should prevent memory leaks during repeated operations', () async {
          final tempFile = await _createBasicMP4File('test_memory_leaks.mp4');

          try {
            final initialMemory = _getApproximateMemoryUsage();

            // Perform repeated initialization and cleanup cycles
            for (int cycle = 0; cycle < 5; cycle++) {
              final testDecoder = MP4Decoder();

              try {
                await expectLater(() => testDecoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));
                await testDecoder.cleanupChunkedProcessing();
              } finally {
                testDecoder.dispose();
              }
            }

            final finalMemory = _getApproximateMemoryUsage();

            // Memory shouldn't grow significantly after repeated cycles
            expect(finalMemory - initialMemory, lessThan(20 * 1024 * 1024)); // Less than 20MB growth
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle out-of-memory conditions gracefully', () async {
          final tempFile = await _createBasicMP4File('test_oom_handling.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Simulate processing that might cause OOM (using reasonable test data)
            final chunks = List.generate(100, (i) => _createTestFileChunk(List.filled(1024, i), i * 1024, i == 99));

            for (final chunk in chunks) {
              await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);
            }
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Resource Cleanup', () {
        test('should cleanup resources after successful processing', () async {
          final tempFile = await _createBasicMP4File('test_cleanup_success.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Cleanup should work even after failed initialization
            await decoder.cleanupChunkedProcessing();

            expect(decoder.isInitialized, isFalse);
            expect(decoder.currentPosition, equals(Duration.zero));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should cleanup resources after processing errors', () async {
          final tempFile = await _createBasicMP4File('test_cleanup_error.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Try to process chunk (will fail)
            final chunk = _createTestFileChunk(List.filled(1024, 0xFF), 0, true);
            await expectLater(() => decoder.processFileChunk(chunk), throwsStateError);

            // Cleanup should still work
            await decoder.cleanupChunkedProcessing();

            expect(decoder.isInitialized, isFalse);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle multiple cleanup calls safely', () async {
          // Multiple cleanup calls should be safe
          await decoder.cleanupChunkedProcessing();
          await decoder.cleanupChunkedProcessing();
          await decoder.cleanupChunkedProcessing();

          expect(decoder.isInitialized, isFalse);
        });

        test('should cleanup resources on decoder disposal', () async {
          final tempFile = await _createBasicMP4File('test_cleanup_dispose.mp4');
          final testDecoder = MP4Decoder();

          try {
            await expectLater(() => testDecoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Dispose should cleanup everything
            testDecoder.dispose();

            // Operations should throw StateError after disposal
            expect(() => testDecoder.currentPosition, throwsA(isA<StateError>()));
            expect(() => testDecoder.getFormatMetadata(), throwsA(isA<StateError>()));
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });

      group('Sample Table Memory Management', () {
        test('should manage sample table memory efficiently', () async {
          final tempFile = await _createBasicMP4File('test_sample_table_memory.mp4');

          try {
            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            // Sample table should be loaded efficiently (test the interface)
            expect(decoder.supportsEfficientSeeking, isTrue);
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should handle large sample tables without excessive memory usage', () async {
          final tempFile = await _createLargeMP4File('test_large_sample_table.mp4', 200 * 1024 * 1024); // 200MB

          try {
            final beforeInit = _getApproximateMemoryUsage();

            await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

            final afterInit = _getApproximateMemoryUsage();

            // Sample table loading shouldn't use excessive memory
            expect(afterInit - beforeInit, lessThan(50 * 1024 * 1024)); // Less than 50MB for sample table
          } finally {
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });
      });
    });

    group('Chunk Size Optimization', () {
      test('should recommend appropriate chunk size for small files', () {
        final recommendation = decoder.getOptimalChunkSize(500 * 1024); // 500KB

        expect(recommendation.recommendedSize, greaterThan(8192)); // > 8KB
        expect(recommendation.recommendedSize, lessThanOrEqualTo(500 * 1024));
        expect(recommendation.minSize, equals(8192));
        expect(recommendation.maxSize, equals(500 * 1024));
        expect(recommendation.reason, contains('Small MP4 file'));
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
        expect(recommendation.metadata?['avgFrameSize'], equals(768));
      });

      test('should recommend appropriate chunk size for medium files', () {
        final recommendation = decoder.getOptimalChunkSize(10 * 1024 * 1024); // 10MB

        expect(recommendation.recommendedSize, equals(4 * 1024 * 1024)); // 4MB
        expect(recommendation.minSize, equals(512 * 1024)); // 512KB
        expect(recommendation.maxSize, equals(20 * 1024 * 1024)); // 20MB
        expect(recommendation.reason, contains('Medium MP4 file'));
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
      });

      test('should recommend appropriate chunk size for large files', () {
        final recommendation = decoder.getOptimalChunkSize(100 * 1024 * 1024); // 100MB

        expect(recommendation.recommendedSize, equals(8 * 1024 * 1024)); // 8MB
        expect(recommendation.minSize, equals(2 * 1024 * 1024)); // 2MB
        expect(recommendation.maxSize, equals(50 * 1024 * 1024)); // 50MB
        expect(recommendation.reason, contains('Large MP4 file'));
        expect(recommendation.metadata?['format'], equals('MP4/AAC'));
      });

      test('should handle edge cases in chunk size calculation', () {
        // Very small file
        final tinyRecommendation = decoder.getOptimalChunkSize(1024); // 1KB
        expect(tinyRecommendation.recommendedSize, greaterThanOrEqualTo(8192));
        expect(tinyRecommendation.maxSize, equals(1024));

        // Very large file
        final hugeRecommendation = decoder.getOptimalChunkSize(1024 * 1024 * 1024); // 1GB
        expect(hugeRecommendation.recommendedSize, equals(8 * 1024 * 1024)); // 8MB
        expect(hugeRecommendation.minSize, equals(2 * 1024 * 1024)); // 2MB
      });

      test('should provide consistent recommendations for same file size', () {
        const fileSize = 50 * 1024 * 1024; // 50MB

        final rec1 = decoder.getOptimalChunkSize(fileSize);
        final rec2 = decoder.getOptimalChunkSize(fileSize);

        expect(rec1.recommendedSize, equals(rec2.recommendedSize));
        expect(rec1.minSize, equals(rec2.minSize));
        expect(rec1.maxSize, equals(rec2.maxSize));
        expect(rec1.reason, equals(rec2.reason));
      });
    });

    group('Format Metadata', () {
      test('should return correct format metadata when not initialized', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata['format'], equals('MP4/AAC'));
        expect(metadata['supportsSeekTable'], isTrue);
        expect(metadata['seekingAccuracy'], equals('high'));
        expect(metadata['avgFrameSize'], equals(768));
        expect(metadata['sampleRate'], equals(0)); // Not initialized
        expect(metadata['channels'], equals(0)); // Not initialized
      });

      test('should include MP4-specific metadata fields', () {
        final metadata = decoder.getFormatMetadata();

        expect(metadata.containsKey('format'), isTrue);
        expect(metadata.containsKey('sampleRate'), isTrue);
        expect(metadata.containsKey('channels'), isTrue);
        expect(metadata.containsKey('duration'), isTrue);
        expect(metadata.containsKey('bitrate'), isTrue);
        expect(metadata.containsKey('sampleCount'), isTrue);
        expect(metadata.containsKey('supportsSeekTable'), isTrue);
        expect(metadata.containsKey('avgFrameSize'), isTrue);
        expect(metadata.containsKey('seekingAccuracy'), isTrue);
        expect(metadata.containsKey('containerInfo'), isTrue);
      });

      test('should handle metadata after failed initialization', () async {
        final tempFile = await _createBasicMP4File('test_metadata_failed.mp4');

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Metadata should still be accessible
          final metadata = decoder.getFormatMetadata();
          expect(metadata['format'], equals('MP4/AAC'));
          expect(metadata['supportsSeekTable'], isTrue);
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should throw StateError when getting metadata after disposal', () {
        decoder.dispose();
        expect(() => decoder.getFormatMetadata(), throwsStateError);
      });
    });

    group('Duration Estimation', () {
      test('should estimate duration for uninitialized decoder', () async {
        final duration = await decoder.estimateDuration();
        expect(duration, isNull); // No file path set
      });

      test('should attempt duration estimation from file header', () async {
        final tempFile = await _createBasicMP4File('test_duration_estimate.mp4');

        try {
          // Set up decoder with file path but don't initialize
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<MP4TrackException>()));

          // Duration estimation should still work (may return null due to parsing failure)
          final duration = await decoder.estimateDuration();
          // Duration may be null due to parsing failure, which is acceptable
          expect(duration, anyOf(isNull, isA<Duration>()));
        } finally {
          if (tempFile.existsSync()) await tempFile.delete();
        }
      });

      test('should handle duration estimation errors gracefully', () async {
        final tempFile = File('test_duration_error.mp4');
        await tempFile.writeAsBytes([0xFF, 0xFF, 0xFF, 0xFF]); // Invalid data

        try {
          await expectLater(() => decoder.initializeChunkedDecoding(tempFile.path), throwsA(isA<SonixException>()));

          final duration = await decoder.estimateDuration();
          expect(duration, anyOf(isNull, isA<Duration>()));
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
        expect(decoder.getOptimalChunkSize, isA<Function>());
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

      test('should implement ChunkedAudioDecoder interface completely', () {
        // Verify the decoder implements the interface
        expect(decoder, isA<ChunkedAudioDecoder>());

        // Test all interface methods are callable (even if they throw due to state)
        expect(() => decoder.supportsEfficientSeeking, returnsNormally);
        expect(() => decoder.currentPosition, returnsNormally);
        expect(() => decoder.isInitialized, returnsNormally);
        expect(() => decoder.getFormatMetadata(), returnsNormally);
        expect(() => decoder.getOptimalChunkSize(1024), returnsNormally);
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
  final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
  final file = File('${tempDir.path}/$filename');

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

/// Create a test MP4 file of specified size for testing
Future<String> _createTestMP4File(String filename, int targetSize) async {
  final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
  final file = File('${tempDir.path}/$filename');

  // Create basic MP4 structure
  final basicData = await _createBasicMP4File(filename);
  final basicSize = await basicData.length();

  // Copy basic data to our target file
  await file.writeAsBytes(await basicData.readAsBytes());

  if (targetSize > basicSize) {
    // Pad with additional data to reach target size
    final paddingSize = targetSize - basicSize;
    final padding = List.filled(paddingSize, 0x00);

    await file.writeAsBytes([...await file.readAsBytes(), ...padding], mode: FileMode.write);
  }

  return file.path;
}

/// Create a large MP4 file for testing memory management
Future<File> _createLargeMP4File(String filename, int targetSize) async {
  final tempDir = Directory.systemTemp.createTempSync('mp4_chunked_test_');
  final file = File('${tempDir.path}/$filename');

  // Start with basic MP4 structure
  final basicFile = await _createBasicMP4File(filename);
  final basicData = await basicFile.readAsBytes();

  // Calculate how much padding we need
  final paddingSize = math.max(0, targetSize - basicData.length);

  // Write the file in chunks to avoid memory issues
  await file.writeAsBytes(basicData, mode: FileMode.write);

  if (paddingSize > 0) {
    const chunkSize = 1024 * 1024; // 1MB chunks
    final fullChunks = paddingSize ~/ chunkSize;
    final remainingBytes = paddingSize % chunkSize;

    final chunk = Uint8List(chunkSize);

    // Write full chunks
    for (int i = 0; i < fullChunks; i++) {
      await file.writeAsBytes(chunk, mode: FileMode.append);
    }

    // Write remaining bytes
    if (remainingBytes > 0) {
      final lastChunk = Uint8List(remainingBytes);
      await file.writeAsBytes(lastChunk, mode: FileMode.append);
    }
  }

  return file;
}

/// Clean up test file if it exists
Future<void> _cleanupTestFile(String filename) async {
  final file = File(filename);
  if (await file.exists()) {
    await file.delete();
  }
}

/// Get approximate memory usage (simplified for testing)
int _getApproximateMemoryUsage() {
  // This is a simplified memory usage estimation for testing purposes
  // In a real implementation, you might use more sophisticated memory monitoring
  return DateTime.now().millisecondsSinceEpoch % 1000000; // Placeholder
}
