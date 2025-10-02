// ignore_for_file: avoid_print

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('Chunked Processing Performance Tests', () {
    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw StateError(
          'FFMPEG setup failed - chunked processing performance tests require FFMPEG DLLs. '
          'These tests measure chunked processing performance and '
          'cannot be skipped when FFMPEG is not available.',
        );
      }

      // Initialize native bindings for testing
      NativeAudioBindings.initialize();
    });

    test('should demonstrate chunked processing performance with large WAV file', () async {
      final wavFile = File('test/assets/Double-F the King - Your Blessing.wav');

      if (!await wavFile.exists()) {
        print('Large WAV test file not found, skipping performance test');
        return;
      }

      final stopwatch = Stopwatch();

      // Step 1: File loading performance (separate from format detection)
      stopwatch.start();
      final fileBytes = await wavFile.readAsBytes();
      final loadTime = stopwatch.elapsedMilliseconds;
      print('File loaded (${fileBytes.length} bytes) in ${loadTime}ms');

      // Add small delay to ensure file I/O is complete
      await Future.delayed(Duration(milliseconds: 10));

      final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
      final nativeData = dataPtr.asTypedList(fileBytes.length);
      nativeData.setAll(0, fileBytes);

      try {
        stopwatch.reset();
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
        final formatDetectionTime = stopwatch.elapsedMilliseconds;
        print('Format detection completed in ${formatDetectionTime}ms: format=$detectedFormat');

        expect(detectedFormat, equals(SONIX_FORMAT_WAV));

        // Step 2: Chunk size calculation performance
        stopwatch.reset();
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(detectedFormat, fileBytes.length);
        final chunkSizeTime = stopwatch.elapsedMilliseconds;
        print('Optimal chunk size calculated in ${chunkSizeTime}ms: $chunkSize bytes');

        // Step 3: Decoder initialization performance
        final filePathPtr = wavFile.path.toNativeUtf8();
        try {
          stopwatch.reset();
          final decoder = SonixNativeBindings.initChunkedDecoder(detectedFormat, filePathPtr.cast<ffi.Char>());
          final initTime = stopwatch.elapsedMilliseconds;
          print('Decoder initialization completed in ${initTime}ms');

          expect(decoder.address, isNot(equals(0)));

          // Step 4: Multiple chunk processing performance
          // Use smaller chunks like the working test (4KB instead of optimal size)
          final testChunkSize = 4096; // 4KB chunks like working test
          final numChunks = (fileBytes.length / testChunkSize).ceil();
          print('Processing file in $numChunks chunks of $testChunkSize bytes each (using 4KB test chunks)');

          var totalProcessingTime = 0;
          var totalAudioSamples = 0;
          var successfulChunks = 0;

          for (int i = 0; i < numChunks && i < 5; i++) {
            // Limit to first 5 chunks for performance test
            final chunkStart = i * testChunkSize;
            final chunkEnd = (chunkStart + testChunkSize < fileBytes.length) ? chunkStart + testChunkSize : fileBytes.length;
            final actualChunkSize = chunkEnd - chunkStart;

            ffi.Pointer<SonixFileChunk>? fileChunkPtr;
            ffi.Pointer<SonixChunkResult>? result;

            try {
              fileChunkPtr = malloc<SonixFileChunk>();
              final fileChunk = fileChunkPtr.ref;
              fileChunk.start_byte = chunkStart;
              fileChunk.end_byte = chunkEnd - 1;
              fileChunk.chunk_index = i;

              // Add small delay between chunks to avoid resource contention
              if (i > 0) {
                await Future.delayed(Duration(milliseconds: 5));
              }

              stopwatch.reset();
              result = SonixNativeBindings.processFileChunk(decoder, fileChunkPtr);
              final chunkProcessingTime = stopwatch.elapsedMilliseconds;
              totalProcessingTime += chunkProcessingTime;

              if (result.address != 0) {
                final resultData = result.ref;
                if (resultData.success == 1 && resultData.audio_data != ffi.nullptr) {
                  final audioData = resultData.audio_data.ref;
                  totalAudioSamples += audioData.sample_count;
                  successfulChunks++;

                  print('Chunk $i: $actualChunkSize bytes -> ${audioData.sample_count} samples in ${chunkProcessingTime}ms');
                } else {
                  print('Chunk $i: processing failed with success=${resultData.success}');
                  if (resultData.error_message != ffi.nullptr) {
                    try {
                      final errorMsg = resultData.error_message.cast<Utf8>().toDartString();
                      print('Error message: $errorMsg');
                    } catch (e) {
                      print('Error reading error message: $e');
                    }
                  }
                  // Continue processing other chunks - we'll fail later if ALL chunks fail
                }

                SonixNativeBindings.freeChunkResult(result);
                result = null; // Prevent double-free
              } else {
                print('Chunk $i: processing returned null result');
              }
            } catch (e, stackTrace) {
              print('Exception in chunk $i processing: $e');
              print('Stack trace: $stackTrace');
              // Continue with other chunks
            } finally {
              if (result != null && result.address != 0) {
                try {
                  SonixNativeBindings.freeChunkResult(result);
                } catch (e) {
                  print('Error freeing chunk result: $e');
                }
              }
              if (fileChunkPtr != null) {
                try {
                  malloc.free(fileChunkPtr);
                } catch (e) {
                  print('Error freeing file chunk pointer: $e');
                }
              }
            }
          }

          // Step 5: Seeking performance test
          final seekPositions = [0, 5000, 10000, 15000, 20000]; // milliseconds
          var totalSeekTime = 0;

          for (final position in seekPositions) {
            stopwatch.reset();
            final seekResult = SonixNativeBindings.seekToTime(decoder, position);
            final seekTime = stopwatch.elapsedMilliseconds;
            totalSeekTime += seekTime;

            print('Seek to ${position}ms: result=$seekResult in ${seekTime}ms');
          }

          // Performance summary
          print('\n=== PERFORMANCE SUMMARY ===');
          print('File size: ${fileBytes.length} bytes (${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
          print('Format detection: ${formatDetectionTime}ms');
          print('Chunk size calculation: ${chunkSizeTime}ms');
          print('Decoder initialization: ${initTime}ms');
          print('Chunks processed: $successfulChunks');
          print('Total audio samples decoded: $totalAudioSamples');
          print('Total chunk processing time: ${totalProcessingTime}ms');
          print('Average time per chunk: ${successfulChunks > 0 ? (totalProcessingTime / successfulChunks).toStringAsFixed(2) : 0}ms');
          print('Total seek operations: ${seekPositions.length}');
          print('Total seek time: ${totalSeekTime}ms');
          print('Average seek time: ${(totalSeekTime / seekPositions.length).toStringAsFixed(2)}ms');

          // Performance assertions (more tolerant for CI/load conditions)
          final expectedDetectionTime = (fileBytes.length / 1024 / 1024 * 50).toInt(); // ~50ms per MB (more tolerant)
          expect(
            formatDetectionTime,
            lessThan(expectedDetectionTime.clamp(200, 2000)),
            reason: 'Format detection took ${formatDetectionTime}ms, expected < ${expectedDetectionTime.clamp(200, 2000)}ms',
          );
          expect(chunkSizeTime, lessThan(50), reason: 'Chunk size calculation took ${chunkSizeTime}ms, expected < 50ms'); // More tolerant
          expect(initTime, lessThan(500), reason: 'Decoder init took ${initTime}ms, expected < 500ms'); // More tolerant for CI

          if (successfulChunks > 0) {
            final avgChunkTime = totalProcessingTime / successfulChunks;
            expect(avgChunkTime, lessThan(2000), reason: 'Average chunk processing took ${avgChunkTime.toStringAsFixed(2)}ms, expected < 2000ms');
          } else {
            fail(
              'No chunks processed successfully (all failed with success=0). '
              'Chunked processing must work for performance testing to be valid. '
              'This indicates a real issue that needs to be fixed, not ignored.',
            );
          }

          final avgSeekTime = totalSeekTime / seekPositions.length;
          expect(avgSeekTime, lessThan(200), reason: 'Average seek time was ${avgSeekTime.toStringAsFixed(2)}ms, expected < 200ms'); // More tolerant

          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should compare processing performance across formats', () async {
      final formatFiles = [
        {'path': 'test/assets/Double-F the King - Your Blessing.mp3', 'format': SONIX_FORMAT_MP3, 'name': 'MP3'},
        {'path': 'test/assets/Double-F the King - Your Blessing.wav', 'format': SONIX_FORMAT_WAV, 'name': 'WAV'},
        {'path': 'test/assets/Double-F the King - Your Blessing.flac', 'format': SONIX_FORMAT_FLAC, 'name': 'FLAC'},
      ];

      print('\n=== FORMAT PERFORMANCE COMPARISON ===');

      for (final formatFile in formatFiles) {
        final file = File(formatFile['path'] as String);
        final format = formatFile['format'] as int;
        final name = formatFile['name'] as String;

        if (!await file.exists()) {
          print('$name file not found, skipping');
          continue;
        }

        final stopwatch = Stopwatch()..start();
        final fileBytes = await file.readAsBytes();
        final loadTime = stopwatch.elapsedMilliseconds;

        final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
        final nativeData = dataPtr.asTypedList(fileBytes.length);
        nativeData.setAll(0, fileBytes);

        try {
          // Format detection timing
          stopwatch.reset();
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
          final detectionTime = stopwatch.elapsedMilliseconds;

          // Chunk size calculation timing
          stopwatch.reset();
          final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, fileBytes.length);
          final chunkSizeTime = stopwatch.elapsedMilliseconds;

          // Decoder initialization timing
          final filePathPtr = file.path.toNativeUtf8();
          try {
            stopwatch.reset();
            final decoder = SonixNativeBindings.initChunkedDecoder(format, filePathPtr.cast<ffi.Char>());
            final initTime = stopwatch.elapsedMilliseconds;

            print('$name (${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)}MB):');
            print('  Load: ${loadTime}ms, Detection: ${detectionTime}ms, ChunkSize: ${chunkSizeTime}ms, Init: ${initTime}ms');
            print('  Optimal chunk size: ${(chunkSize / 1024).toStringAsFixed(0)}KB');

            // Verify format detection
            expect(detectedFormat, equals(format));

            if (decoder.address != 0) {
              SonixNativeBindings.cleanupChunkedDecoder(decoder);
            }
          } finally {
            malloc.free(filePathPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      }
    });
  });
}
