/// FFMPEG memory management and error handling tests
///
/// Tests proper FFMPEG context cleanup, resource management, and error handling
/// with real FFMPEG contexts and large audio files.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

import '../test_helpers/test_data_loader.dart';
import 'audio_test_data_manager.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('FFMPEG Memory Management Tests', () {
    setUpAll(() async {
      // Print test file status
      await AudioTestDataManager.printTestFileStatus();

      // Initialize FFMPEG
      final initResult = SonixNativeBindings.initFFMPEG();
      if (initResult != 0) {
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        throw StateError('Failed to initialize FFMPEG: $errorMsg');
      }
    });

    tearDownAll(() {
      // Cleanup FFMPEG
      SonixNativeBindings.cleanupFFMPEG();
    });

    group('FFMPEG Context Cleanup Tests', () {
      test('should properly cleanup FFMPEG contexts after decoding', () async {
        const testKey = 'wav_small';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping FFMPEG context cleanup test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          // Perform multiple decode operations to test context cleanup
          for (int i = 0; i < 10; i++) {
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, expected['format'] as int);

            expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode audio in iteration $i');

            if (audioDataPtr != nullptr) {
              final audioData = audioDataPtr.ref;
              expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples in iteration $i');

              // Cleanup immediately
              SonixNativeBindings.freeAudioData(audioDataPtr);
            }
          }

          print('Multiple FFMPEG context cleanup cycles completed successfully');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle FFMPEG initialization and cleanup cycles', () {
        // Test multiple init/cleanup cycles
        for (int i = 0; i < 5; i++) {
          // Cleanup current instance
          SonixNativeBindings.cleanupFFMPEG();

          // Re-initialize
          final initResult = SonixNativeBindings.initFFMPEG();
          expect(initResult, equals(0), reason: 'Should successfully re-initialize FFMPEG in cycle $i');

          // Verify backend type
          final backendType = SonixNativeBindings.getBackendType();
          expect(backendType, equals(SONIX_BACKEND_FFMPEG), reason: 'Should report FFMPEG backend after re-initialization');
        }

        print('Multiple FFMPEG init/cleanup cycles completed successfully');
      });
    });

    group('Chunked Processing Memory Management', () {
      test('should properly cleanup chunked decoder resources', () async {
        final largeFiles = AudioTestDataManager.getLargeTestFiles();

        if (largeFiles.isEmpty) {
          print('Skipping chunked decoder cleanup test - no large files available');
          return;
        }

        final testKey = largeFiles.first;
        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping chunked decoder cleanup test - large file not found');
          return;
        }

        final filePath = AudioTestDataManager.getFilePath(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        // Initialize chunked decoder
        final filePathPtr = filePath.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(expected['format'] as int, filePathPtr.cast<Char>());

          expect(decoder, isNot(equals(nullptr)), reason: 'Should successfully initialize chunked decoder');

          if (decoder != nullptr) {
            // Process a few chunks
            for (int i = 0; i < 3; i++) {
              final chunkPtr = malloc<SonixFileChunk>();
              chunkPtr.ref.data = nullptr;
              chunkPtr.ref.size = 4096;
              chunkPtr.ref.position = i * 4096;
              chunkPtr.ref.is_last = (i == 2) ? 1 : 0;

              try {
                final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

                if (result != nullptr) {
                  final chunkResult = result.ref;

                  if (chunkResult.error_code == SONIX_OK && chunkResult.chunks != nullptr) {
                    print('Processed chunk $i: ${chunkResult.chunk_count} audio chunks');
                  }

                  // Cleanup chunk result
                  SonixNativeBindings.freeChunkResult(result);
                }
              } finally {
                malloc.free(chunkPtr);
              }
            }

            // Cleanup decoder
            SonixNativeBindings.cleanupChunkedDecoder(decoder);

            print('Chunked decoder cleanup completed successfully');
          }
        } finally {
          malloc.free(filePathPtr);
        }
      });

      test('should handle multiple chunked decoders simultaneously', () async {
        final largeFiles = AudioTestDataManager.getLargeTestFiles();

        if (largeFiles.isEmpty) {
          print('Skipping multiple chunked decoders test - no large files available');
          return;
        }

        final testKey = largeFiles.first;
        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping multiple chunked decoders test - large file not found');
          return;
        }

        final filePath = AudioTestDataManager.getFilePath(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);
        final filePathPtr = filePath.toNativeUtf8();

        try {
          final decoders = <Pointer<SonixChunkedDecoder>>[];

          // Create multiple decoders
          for (int i = 0; i < 3; i++) {
            final decoder = SonixNativeBindings.initChunkedDecoder(expected['format'] as int, filePathPtr.cast<Char>());

            expect(decoder, isNot(equals(nullptr)), reason: 'Should successfully initialize chunked decoder $i');

            if (decoder != nullptr) {
              decoders.add(decoder);
            }
          }

          print('Created ${decoders.length} simultaneous chunked decoders');

          // Process chunks with each decoder
          for (int decoderIndex = 0; decoderIndex < decoders.length; decoderIndex++) {
            final decoder = decoders[decoderIndex];

            final chunkPtr = malloc<SonixFileChunk>();
            chunkPtr.ref.data = nullptr;
            chunkPtr.ref.size = 4096;
            chunkPtr.ref.position = 0;
            chunkPtr.ref.is_last = 1;

            try {
              final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

              if (result != nullptr) {
                final chunkResult = result.ref;

                if (chunkResult.error_code == SONIX_OK && chunkResult.chunks != nullptr) {
                  print('Decoder $decoderIndex processed chunk: ${chunkResult.chunk_count} audio chunks');
                }

                SonixNativeBindings.freeChunkResult(result);
              }
            } finally {
              malloc.free(chunkPtr);
            }
          }

          // Cleanup all decoders
          for (final decoder in decoders) {
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          }

          print('Multiple chunked decoders cleanup completed successfully');
        } finally {
          malloc.free(filePathPtr);
        }
      });

      test('should handle chunked processing with large files', () async {
        final largeFiles = AudioTestDataManager.getLargeTestFiles();

        if (largeFiles.isEmpty) {
          print('Skipping large file chunked processing test - no large files available');
          return;
        }

        final testKey = largeFiles.first;
        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping large file chunked processing test - large file not found');
          return;
        }

        final filePath = AudioTestDataManager.getFilePath(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);
        final fileSize = await AudioTestDataManager.getFileSize(testKey);

        print('Testing chunked processing with large file: $filePath (${fileSize} bytes)');

        final filePathPtr = filePath.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(expected['format'] as int, filePathPtr.cast<Char>());

          expect(decoder, isNot(equals(nullptr)), reason: 'Should successfully initialize chunked decoder for large file');

          if (decoder != nullptr) {
            var totalChunks = 0;
            var chunksProcessed = 0;
            const maxChunks = 10; // Limit chunks to avoid long test times

            // Process chunks until we reach max or end of file
            for (int i = 0; i < maxChunks; i++) {
              final chunkSize = 8192; // 8KB chunks
              final chunkPtr = malloc<SonixFileChunk>();
              chunkPtr.ref.data = nullptr;
              chunkPtr.ref.size = chunkSize;
              chunkPtr.ref.position = i * chunkSize;
              chunkPtr.ref.is_last = (i == maxChunks - 1) ? 1 : 0;

              try {
                final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

                if (result != nullptr) {
                  final chunkResult = result.ref;

                  if (chunkResult.error_code == SONIX_OK && chunkResult.chunks != nullptr) {
                    totalChunks += chunkResult.chunk_count;
                    chunksProcessed++;

                    if (i % 5 == 0) {
                      // Print every 5th chunk
                      print('Chunk $i: ${chunkResult.chunk_count} audio chunks');
                    }
                  }

                  SonixNativeBindings.freeChunkResult(result);
                } else {
                  // No more chunks available
                  break;
                }
              } finally {
                malloc.free(chunkPtr);
              }
            }

            print('Large file chunked processing completed: $chunksProcessed file chunks, $totalChunks audio chunks');

            expect(chunksProcessed, greaterThan(0), reason: 'Should process at least one chunk');

            // Cleanup decoder
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          }
        } finally {
          malloc.free(filePathPtr);
        }
      });
    });

    group('Error Handling Tests', () {
      test('should handle invalid/corrupted audio files gracefully', () async {
        final corruptedFiles = AudioTestDataManager.getCorruptedTestFiles();

        for (final testKey in corruptedFiles) {
          if (!await AudioTestDataManager.testFileExists(testKey)) {
            print('Skipping corrupted file test for $testKey - file not found');
            continue;
          }

          print('Testing error handling with corrupted file: $testKey');

          final corruptedData = await AudioTestDataManager.loadTestFile(testKey);

          final dataPtr = malloc<Uint8>(corruptedData.length);
          final dataList = dataPtr.asTypedList(corruptedData.length);
          dataList.setAll(0, corruptedData);

          try {
            // Try to decode corrupted data
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, corruptedData.length, SONIX_FORMAT_WAV);

            if (audioDataPtr == nullptr) {
              // Expected behavior - should fail gracefully
              final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
              expect(errorMsg, isNotEmpty, reason: 'Should set error message for corrupted file $testKey');
              print('  Error (expected): $errorMsg');
            } else {
              // Unexpected success - cleanup and note
              SonixNativeBindings.freeAudioData(audioDataPtr);
              print('  Unexpectedly succeeded in decoding corrupted file $testKey');
            }
          } finally {
            malloc.free(dataPtr);
          }
        }
      });

      test('should handle chunked processing errors gracefully', () async {
        final corruptedFiles = AudioTestDataManager.getCorruptedTestFiles();

        for (final testKey in corruptedFiles) {
          if (!await AudioTestDataManager.testFileExists(testKey)) {
            continue;
          }

          print('Testing chunked processing error handling with: $testKey');

          final filePath = AudioTestDataManager.getFilePath(testKey);
          final filePathPtr = filePath.toNativeUtf8();

          try {
            // Try to initialize chunked decoder with corrupted file
            final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<Char>());

            if (decoder == nullptr) {
              // Expected behavior - should fail gracefully
              final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
              expect(errorMsg, isNotEmpty, reason: 'Should set error message for corrupted file $testKey');
              print('  Chunked decoder init error (expected): $errorMsg');
            } else {
              // If decoder was created, try to process a chunk
              final chunkPtr = malloc<SonixFileChunk>();
              chunkPtr.ref.data = nullptr;
              chunkPtr.ref.size = 4096;
              chunkPtr.ref.position = 0;
              chunkPtr.ref.is_last = 1;

              try {
                final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

                if (result != nullptr) {
                  final chunkResult = result.ref;

                  if (chunkResult.error_code != SONIX_OK) {
                    // Expected failure
                    if (chunkResult.error_message != nullptr) {
                      final errorMsg = chunkResult.error_message.cast<Utf8>().toDartString();
                      print('  Chunk processing error (expected): $errorMsg');
                    }
                  } else {
                    print('  Unexpectedly succeeded in processing corrupted file chunk');
                  }

                  SonixNativeBindings.freeChunkResult(result);
                }
              } finally {
                malloc.free(chunkPtr);
              }

              // Cleanup decoder
              SonixNativeBindings.cleanupChunkedDecoder(decoder);
            }
          } finally {
            malloc.free(filePathPtr);
          }
        }
      });

      test('should handle file not found errors', () {
        const nonExistentFile = '/path/to/nonexistent/file.wav';
        final filePathPtr = nonExistentFile.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<Char>());

          expect(decoder, equals(nullptr), reason: 'Should return null for non-existent file');

          final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
          expect(errorMsg, isNotEmpty, reason: 'Should set error message for non-existent file');

          print('File not found error: $errorMsg');
        } finally {
          malloc.free(filePathPtr);
        }
      });

      test('should handle seek errors gracefully', () async {
        const testKey = 'wav_small';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping seek error test - file not found');
          return;
        }

        final filePath = AudioTestDataManager.getFilePath(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);
        final filePathPtr = filePath.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(expected['format'] as int, filePathPtr.cast<Char>());

          if (decoder != nullptr) {
            // Try to seek to an invalid position (way beyond file end)
            final seekResult = SonixNativeBindings.seekToTime(decoder, 999999999); // 999999 seconds

            expect(seekResult, isNot(equals(SONIX_OK)), reason: 'Should return error code for invalid seek position');

            final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
            if (errorMsg.isNotEmpty) {
              print('Seek error (expected): $errorMsg');
            }

            // Cleanup decoder
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          }
        } finally {
          malloc.free(filePathPtr);
        }
      });

      test('should handle null pointer parameters gracefully', () {
        // Test null decoder parameter
        final chunkPtr = malloc<SonixFileChunk>();
        chunkPtr.ref.data = nullptr;
        chunkPtr.ref.size = 4096;
        chunkPtr.ref.position = 0;
        chunkPtr.ref.is_last = 1;

        try {
          final result = SonixNativeBindings.processFileChunk(nullptr, chunkPtr);

          expect(result, equals(nullptr), reason: 'Should return null for null decoder');

          final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
          expect(errorMsg, isNotEmpty, reason: 'Should set error message for null decoder');

          print('Null decoder error: $errorMsg');
        } finally {
          malloc.free(chunkPtr);
        }

        // Test null chunk parameter
        const testKey = 'wav_small';
        if (AudioTestDataManager.testFiles.containsKey(testKey)) {
          final filePath = AudioTestDataManager.getFilePath(testKey);
          final filePathPtr = filePath.toNativeUtf8();

          try {
            final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<Char>());

            if (decoder != nullptr) {
              final result = SonixNativeBindings.processFileChunk(decoder, nullptr);

              expect(result, equals(nullptr), reason: 'Should return null for null chunk');

              final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
              expect(errorMsg, isNotEmpty, reason: 'Should set error message for null chunk');

              print('Null chunk error: $errorMsg');

              SonixNativeBindings.cleanupChunkedDecoder(decoder);
            }
          } finally {
            malloc.free(filePathPtr);
          }
        }
      });
    });

    group('Resource Stress Tests', () {
      test('should handle rapid allocation and deallocation', () async {
        const testKey = 'wav_small';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping stress test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          final stopwatch = Stopwatch()..start();

          // Rapid allocation/deallocation cycles
          for (int i = 0; i < 50; i++) {
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, expected['format'] as int);

            if (audioDataPtr != nullptr) {
              // Immediately free without using the data
              SonixNativeBindings.freeAudioData(audioDataPtr);
            }

            if (i % 10 == 0) {
              print('Completed $i rapid allocation/deallocation cycles');
            }
          }

          stopwatch.stop();
          print('Rapid allocation/deallocation stress test completed in ${stopwatch.elapsedMilliseconds}ms');
        } finally {
          malloc.free(dataPtr);
        }
      });
    });
  });
}
