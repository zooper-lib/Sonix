import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('Chunked Processing Workflow Tests', () {
    test('should demonstrate complete chunked processing workflow', () {
      // This test demonstrates the complete workflow for chunked processing
      // even though we don't have real audio files to work with

      // Step 1: Format Detection
      final mp3Header = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
      final headerPtr = malloc<ffi.Uint8>(mp3Header.length);
      final headerData = headerPtr.asTypedList(mp3Header.length);
      headerData.setAll(0, mp3Header);

      try {
        final format = SonixNativeBindings.detectFormat(headerPtr, mp3Header.length);
        expect(format, equals(SONIX_FORMAT_MP3));

        // Step 2: Get optimal chunk size
        final fileSize = 50 * 1024 * 1024; // 50MB file
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, fileSize);
        expect(chunkSize, greaterThan(0));
        expect(chunkSize, lessThanOrEqualTo(10 * 1024 * 1024));

        // Step 3: Initialize decoder (will fail without real file, but demonstrates API)
        final filePathPtr = 'test.mp3'.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(format, filePathPtr.cast<ffi.Char>());

          // Should return null for non-existent file
          expect(decoder.address, equals(0));

          // Step 4: Demonstrate chunk processing structure
          final chunkPtr = malloc<SonixFileChunk>();
          final chunk = chunkPtr.ref;
          chunk.data = headerPtr;
          chunk.size = mp3Header.length;
          chunk.position = 0;
          chunk.is_last = 1;

          try {
            // This would process the chunk if decoder was valid
            final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);
            expect(result.address, equals(0)); // Null due to invalid decoder

            // Step 5: Demonstrate seeking (would work with valid decoder)
            final seekResult = SonixNativeBindings.seekToTime(decoder, 5000);
            expect(seekResult, equals(SONIX_ERROR_INVALID_DATA));

            // Step 6: Cleanup
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
            SonixNativeBindings.freeChunkResult(result);
          } finally {
            malloc.free(chunkPtr);
          }
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(headerPtr);
      }
    });

    test('should handle all supported formats in workflow', () {
      final formatTests = [
        {
          'format': SONIX_FORMAT_MP3,
          'signature': [0xFF, 0xFB, 0x90, 0x00],
          'extension': 'mp3',
        },
        {
          'format': SONIX_FORMAT_FLAC,
          'signature': [0x66, 0x4C, 0x61, 0x43],
          'extension': 'flac',
        },
        {
          'format': SONIX_FORMAT_WAV,
          'signature': [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45],
          'extension': 'wav',
        },
        {
          'format': SONIX_FORMAT_OGG,
          'signature': [0x4F, 0x67, 0x67, 0x53],
          'extension': 'ogg',
        },
      ];

      for (final test in formatTests) {
        final signature = test['signature'] as List<int>;
        final format = test['format'] as int;
        final extension = test['extension'] as String;

        // Test format detection
        final sigPtr = malloc<ffi.Uint8>(signature.length);
        final sigData = sigPtr.asTypedList(signature.length);
        sigData.setAll(0, signature);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(sigPtr, signature.length);
          expect(detectedFormat, equals(format));

          // Test chunk size calculation
          final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, 100 * 1024 * 1024);
          expect(chunkSize, greaterThan(0));

          // Test decoder initialization (will fail but should handle gracefully)
          final filePathPtr = 'test.$extension'.toNativeUtf8();
          try {
            final decoder = SonixNativeBindings.initChunkedDecoder(format, filePathPtr.cast<ffi.Char>());

            if (format == SONIX_FORMAT_OGG) {
              // OGG should fail due to symbol conflicts
              expect(decoder.address, equals(0));
            } else {
              // Other formats should return null for non-existent file
              expect(decoder.address, equals(0));
            }

            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          } finally {
            malloc.free(filePathPtr);
          }
        } finally {
          malloc.free(sigPtr);
        }
      }
    });

    test('should validate error handling throughout workflow', () {
      // Test error handling at each step of the workflow

      // 1. Invalid format detection
      final invalidData = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
      final dataPtr = malloc<ffi.Uint8>(invalidData.length);
      final nativeData = dataPtr.asTypedList(invalidData.length);
      nativeData.setAll(0, invalidData);

      try {
        final format = SonixNativeBindings.detectFormat(dataPtr, invalidData.length);
        expect(format, equals(SONIX_FORMAT_UNKNOWN));

        // 2. Invalid format for chunk size
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(999, 1024 * 1024);
        expect(chunkSize, greaterThan(0)); // Should return default size

        // 3. Invalid decoder initialization
        final filePathPtr = 'nonexistent.audio'.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(
            999, // Invalid format
            filePathPtr.cast<ffi.Char>(),
          );
          expect(decoder.address, equals(0));

          // 4. Operations on null decoder
          final seekResult = SonixNativeBindings.seekToTime(decoder, 1000);
          expect(seekResult, equals(SONIX_ERROR_INVALID_DATA));

          final chunkPtr = malloc<SonixFileChunk>();
          try {
            final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);
            expect(result.address, equals(0));

            // 5. Cleanup operations should be safe
            SonixNativeBindings.cleanupChunkedDecoder(decoder);
            SonixNativeBindings.freeChunkResult(result);
          } finally {
            malloc.free(chunkPtr);
          }
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should demonstrate memory management best practices', () {
      // This test demonstrates proper memory management patterns
      final allocations = <ffi.Pointer<ffi.NativeType>>[];

      try {
        // Allocate various structures
        final fileChunk = malloc<SonixFileChunk>();
        allocations.add(fileChunk);

        final audioChunk = malloc<SonixAudioChunk>();
        allocations.add(audioChunk);

        final chunkResult = malloc<SonixChunkResult>();
        allocations.add(chunkResult);

        final dataBuffer = malloc<ffi.Uint8>(1024);
        allocations.add(dataBuffer);

        // Use the structures
        final chunk = fileChunk.cast<SonixFileChunk>().ref;
        chunk.data = dataBuffer.cast<ffi.Uint8>();
        chunk.size = 1024;
        chunk.position = 0;
        chunk.is_last = 1;

        final audio = audioChunk.cast<SonixAudioChunk>().ref;
        audio.sample_count = 512;
        audio.start_sample = 0;
        audio.is_last = 0;

        final result = chunkResult.cast<SonixChunkResult>().ref;
        result.chunks = audioChunk.cast<SonixAudioChunk>();
        result.chunk_count = 1;
        result.error_code = SONIX_OK;

        // Verify values
        expect(chunk.size, equals(1024));
        expect(audio.sample_count, equals(512));
        expect(result.chunk_count, equals(1));
        expect(result.error_code, equals(SONIX_OK));
      } finally {
        // Clean up all allocations
        for (final allocation in allocations) {
          malloc.free(allocation);
        }
      }
    });
  });
}

