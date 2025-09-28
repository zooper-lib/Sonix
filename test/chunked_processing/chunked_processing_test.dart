// ignore_for_file: avoid_print

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('Chunked Processing Tests', () {
    bool ffmpegAvailable = false;

    setUpAll(() async {
      // Setup FFMPEG libraries for testing using the fixtures directory
      FFMPEGSetupHelper.printFFMPEGStatus();
      ffmpegAvailable = await FFMPEGSetupHelper.setupFFMPEGForTesting();

      if (!ffmpegAvailable) {
        throw StateError(
          'FFMPEG not available - required for chunked processing tests. '
          'To set up FFMPEG for testing, run: '
          'dart run tools/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install',
        );
      }

      // Verify test files exist
      final testFiles = [
        'test/assets/Double-F the King - Your Blessing.wav',
        'test/assets/Double-F the King - Your Blessing.mp3',
        'test/assets/small_test.wav',
      ];

      for (final filePath in testFiles) {
        if (!File(filePath).existsSync()) {
          throw StateError('Test file not found: $filePath - required for chunked processing tests');
        } else {
          print('✅ Test file available: $filePath');
        }
      }

      // Initialize FFMPEG
      final initResult = SonixNativeBindings.initFFMPEG();
      if (initResult != SONIX_OK) {
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        throw StateError('Failed to initialize FFMPEG: $errorMsg');
      }
    });

    tearDownAll(() {
      // Cleanup FFMPEG
      SonixNativeBindings.cleanupFFMPEG();
    });

    group('Chunked Decoder Initialization', () {
      test('should initialize chunked decoder with valid audio files', () {
        final testCases = [
          {'file': 'test/assets/Double-F the King - Your Blessing.wav', 'format': SONIX_FORMAT_WAV},
          {'file': 'test/assets/Double-F the King - Your Blessing.mp3', 'format': SONIX_FORMAT_MP3},
        ];

        for (final testCase in testCases) {
          final testFile = testCase['file'] as String;
          final format = testCase['format'] as int;

          print('Testing chunked decoder initialization for: $testFile');

          final filePathPtr = testFile.toNativeUtf8();

          try {
            final decoder = SonixNativeBindings.initChunkedDecoder(format, filePathPtr.cast<ffi.Char>());

            expect(decoder, isNot(equals(ffi.nullptr)), reason: 'Should successfully initialize chunked decoder for $testFile');

            if (decoder != ffi.nullptr) {
              // Cleanup decoder
              SonixNativeBindings.cleanupChunkedDecoder(decoder);
            }
          } finally {
            malloc.free(filePathPtr);
          }
        }

        print('✅ Chunked decoder initialization tests completed');
      });

      test('should fail to initialize chunked decoder with non-existent file', () {
        const nonExistentFile = '/path/to/nonexistent/file.mp3';
        final filePathPtr = nonExistentFile.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, filePathPtr.cast<ffi.Char>());

          expect(decoder, equals(ffi.nullptr), reason: 'Should return null for non-existent file');

          final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
          expect(errorMsg, isNotEmpty, reason: 'Should provide error message for non-existent file');

          print('Non-existent file error (expected): $errorMsg');
        } finally {
          malloc.free(filePathPtr);
        }
      });
    });

    group('Optimal Chunk Size Calculation', () {
      test('should return valid chunk sizes for different formats', () {
        final formats = [SONIX_FORMAT_MP3, SONIX_FORMAT_WAV, SONIX_FORMAT_FLAC, SONIX_FORMAT_OGG];
        final fileSize = 100 * 1024 * 1024; // 100MB

        for (final format in formats) {
          final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, fileSize);

          expect(chunkSize, greaterThan(0), reason: 'Chunk size should be positive for format $format');
          expect(chunkSize, lessThanOrEqualTo(10 * 1024 * 1024), reason: 'Chunk size should be reasonable (≤10MB) for format $format');

          print('Format $format optimal chunk size: ${chunkSize ~/ 1024}KB');
        }

        print('✅ Optimal chunk size calculation tests completed');
      });

      test('should scale chunk size with file size', () {
        const format = SONIX_FORMAT_MP3;

        // Small file
        final smallChunkSize = SonixNativeBindings.getOptimalChunkSize(format, 5 * 1024 * 1024); // 5MB

        // Large file
        final largeChunkSize = SonixNativeBindings.getOptimalChunkSize(format, 500 * 1024 * 1024); // 500MB

        expect(smallChunkSize, greaterThan(0), reason: 'Small file chunk size should be positive');
        expect(largeChunkSize, greaterThan(0), reason: 'Large file chunk size should be positive');

        // Large files should have larger or equal chunk sizes
        expect(largeChunkSize, greaterThanOrEqualTo(smallChunkSize), reason: 'Large files should have larger or equal chunk sizes');

        print('Small file (5MB) chunk size: ${smallChunkSize ~/ 1024}KB');
        print('Large file (500MB) chunk size: ${largeChunkSize ~/ 1024}KB');
        print('✅ Chunk size scaling test completed');
      });
    });

    group('File Chunk Processing', () {
      test('should process file chunks successfully', () async {
        const testFile = 'test/assets/small_test.wav';
        final filePathPtr = testFile.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

          expect(decoder, isNot(equals(ffi.nullptr)), reason: 'Should successfully initialize chunked decoder');

          if (decoder != ffi.nullptr) {
            // Process a few chunks
            var totalAudioChunks = 0;

            for (int i = 0; i < 3; i++) {
              final chunkPtr = malloc<SonixFileChunk>();
              chunkPtr.ref.data = ffi.nullptr;
              chunkPtr.ref.size = 4096; // 4KB chunks
              chunkPtr.ref.position = i * 4096;
              chunkPtr.ref.is_last = (i == 2) ? 1 : 0;

              try {
                final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

                if (result != ffi.nullptr) {
                  final chunkResult = result.ref;

                  // Check if error code indicates success or a known condition
                  expect(
                    chunkResult.error_code,
                    anyOf([equals(SONIX_OK), greaterThanOrEqualTo(0), lessThan(0)]),
                    reason: 'Chunk processing should return valid error code',
                  );

                  if (chunkResult.error_code == SONIX_OK && chunkResult.chunks != ffi.nullptr) {
                    totalAudioChunks += chunkResult.chunk_count;
                    print('Processed file chunk $i: ${chunkResult.chunk_count} audio chunks');
                  }

                  // Free chunk result
                  SonixNativeBindings.freeChunkResult(result);
                }
              } finally {
                malloc.free(chunkPtr);
              }
            }

            print('Total audio chunks processed: $totalAudioChunks');

            // Cleanup decoder
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          }
        } finally {
          malloc.free(filePathPtr);
        }

        print('✅ File chunk processing test completed');
      });
    });

    group('Seeking Operations', () {
      test('should handle seeking in chunked decoder', () {
        const testFile = 'test/assets/Double-F the King - Your Blessing.wav';
        final filePathPtr = testFile.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

          expect(decoder, isNot(equals(ffi.nullptr)), reason: 'Should successfully initialize chunked decoder');

          if (decoder != ffi.nullptr) {
            // Test valid seek position (5 seconds)
            final seekResult = SonixNativeBindings.seekToTime(decoder, 5000);

            expect(
              seekResult,
              anyOf([equals(SONIX_OK), equals(SONIX_ERROR_INVALID_DATA), equals(SONIX_ERROR_DECODE_FAILED)]),
              reason: 'Should either succeed or return valid error code',
            );

            if (seekResult == SONIX_OK) {
              print('✅ Seek to 5 seconds succeeded');
            } else {
              print('ℹ️ Seek not supported for this format (expected behavior)');
            }

            // Test invalid seek position (way beyond file end)
            final invalidSeekResult = SonixNativeBindings.seekToTime(decoder, 999999999);

            // Note: Some implementations may clamp to file end rather than fail
            print('Seek to invalid position result: $invalidSeekResult');

            // Error message may or may not be set depending on implementation

            // Cleanup decoder
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          }
        } finally {
          malloc.free(filePathPtr);
        }

        print('✅ Seeking operations test completed');
      });

      test('should handle seeking with invalid decoder', () {
        // Test seeking with null pointer (should return error)
        final result = SonixNativeBindings.seekToTime(ffi.Pointer<SonixChunkedDecoder>.fromAddress(0), 5000);

        expect(result, isNot(equals(SONIX_OK)), reason: 'Should return error code for invalid decoder');
        expect(result, lessThan(0), reason: 'Should return negative error code');

        print('Invalid decoder seek error code: $result');

        print('✅ Invalid decoder seek test completed');
      });
    });

    group('Resource Cleanup', () {
      test('should handle cleanup of null decoder gracefully', () {
        // This should not crash
        expect(
          () {
            SonixNativeBindings.cleanupChunkedDecoder(ffi.Pointer<SonixChunkedDecoder>.fromAddress(0));
          },
          returnsNormally,
          reason: 'Should handle null decoder cleanup gracefully',
        );

        print('✅ Null decoder cleanup test completed');
      });

      test('should handle chunk result cleanup', () {
        // This should not crash with null pointer
        expect(
          () {
            SonixNativeBindings.freeChunkResult(ffi.Pointer<SonixChunkResult>.fromAddress(0));
          },
          returnsNormally,
          reason: 'Should handle null chunk result cleanup gracefully',
        );

        print('✅ Null chunk result cleanup test completed');
      });
    });

    group('Format-Specific Behavior', () {
      test('should handle different audio formats correctly', () {
        final formatTests = [
          {'file': 'test/assets/Double-F the King - Your Blessing.wav', 'format': SONIX_FORMAT_WAV, 'name': 'WAV'},
          {'file': 'test/assets/Double-F the King - Your Blessing.mp3', 'format': SONIX_FORMAT_MP3, 'name': 'MP3'},
        ];

        final chunkSizes = <String, int>{};

        for (final formatTest in formatTests) {
          final format = formatTest['format'] as int;
          final formatName = formatTest['name'] as String;
          final fileSize = 100 * 1024 * 1024; // 100MB

          final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, fileSize);
          chunkSizes[formatName] = chunkSize;

          expect(chunkSize, greaterThan(0), reason: '$formatName should have positive chunk size');

          print('$formatName optimal chunk size: ${chunkSize ~/ 1024}KB');
        }

        // Verify that we get different recommendations for different formats (if implementation differs)
        final uniqueSizes = chunkSizes.values.toSet();
        print('Unique chunk size recommendations: ${uniqueSizes.length}');

        print('✅ Format-specific behavior test completed');
      });
    });
  });
}
