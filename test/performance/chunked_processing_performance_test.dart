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
        throw Exception('FFMPEG libraries not available for testing');
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

      final stopwatch = Stopwatch()..start();

      // Step 1: Format detection performance
      final fileBytes = await wavFile.readAsBytes();
      final detectionTime = stopwatch.elapsedMilliseconds;
      print('File loaded (${fileBytes.length} bytes) in ${detectionTime}ms');

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
          final numChunks = (fileBytes.length / chunkSize).ceil();
          print('Processing file in $numChunks chunks of $chunkSize bytes each');

          var totalProcessingTime = 0;
          var totalAudioSamples = 0;
          var successfulChunks = 0;

          for (int i = 0; i < numChunks && i < 5; i++) {
            // Limit to first 5 chunks for performance test
            final chunkStart = i * chunkSize;
            final chunkEnd = (chunkStart + chunkSize < fileBytes.length) ? chunkStart + chunkSize : fileBytes.length;
            final actualChunkSize = chunkEnd - chunkStart;

            final chunkData = fileBytes.sublist(chunkStart, chunkEnd);
            final chunkPtr = malloc<ffi.Uint8>(chunkData.length);
            final chunkNativeData = chunkPtr.asTypedList(chunkData.length);
            chunkNativeData.setAll(0, chunkData);

            final fileChunkPtr = malloc<SonixFileChunk>();
            final fileChunk = fileChunkPtr.ref;
            fileChunk.data = chunkPtr;
            fileChunk.size = actualChunkSize;
            fileChunk.position = chunkStart;
            fileChunk.is_last = (i == numChunks - 1) ? 1 : 0;

            try {
              stopwatch.reset();
              final result = SonixNativeBindings.processFileChunk(decoder, fileChunkPtr);
              final chunkProcessingTime = stopwatch.elapsedMilliseconds;
              totalProcessingTime += chunkProcessingTime;

              if (result.address != 0) {
                final resultData = result.ref;
                if (resultData.error_code == SONIX_OK && resultData.chunk_count > 0) {
                  final audioChunk = (resultData.chunks + 0).ref;
                  totalAudioSamples += audioChunk.sample_count;
                  successfulChunks++;

                  print('Chunk $i: $actualChunkSize bytes -> ${audioChunk.sample_count} samples in ${chunkProcessingTime}ms');
                } else {
                  print('Chunk $i: processing failed with error_code=${resultData.error_code}');
                }

                SonixNativeBindings.freeChunkResult(result);
              } else {
                print('Chunk $i: processing returned null result');
              }
            } finally {
              malloc.free(chunkPtr);
              malloc.free(fileChunkPtr);
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

          // Performance assertions
          expect(formatDetectionTime, lessThan(100)); // Format detection should be fast
          expect(chunkSizeTime, lessThan(10)); // Chunk size calculation should be instant
          expect(initTime, lessThan(100)); // Decoder init should be fast
          if (successfulChunks > 0) {
            expect(totalProcessingTime / successfulChunks, lessThan(1000)); // Average chunk processing < 1s
          }
          expect(totalSeekTime / seekPositions.length, lessThan(100)); // Average seek < 100ms

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

