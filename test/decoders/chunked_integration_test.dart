import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('Chunked Decoder Integration Tests', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('sonix_test_');
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should initialize and cleanup MP3 decoder properly', () {
      // Create a temporary MP3 file path
      final mp3File = File('${tempDir.path}/test.mp3');
      final filePathPtr = mp3File.path.toNativeUtf8();

      try {
        // Initialize decoder (will fail for non-existent file, but should handle gracefully)
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, filePathPtr.cast<ffi.Char>());

        // Should return null for non-existent file
        expect(decoder.address, equals(0));

        // Cleanup should handle null pointer gracefully
        SonixNativeBindings.cleanupChunkedDecoder(decoder);
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should handle different format initializations', () {
      final formats = [SONIX_FORMAT_MP3, SONIX_FORMAT_FLAC, SONIX_FORMAT_WAV];

      for (final format in formats) {
        final testFile = File('${tempDir.path}/test_$format.audio');
        final filePathPtr = testFile.path.toNativeUtf8();

        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(format, filePathPtr.cast<ffi.Char>());

          // Should return null for non-existent files
          expect(decoder.address, equals(0));

          // Cleanup
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } finally {
          malloc.free(filePathPtr);
        }
      }
    });

    test('should reject invalid format initialization', () {
      final testFile = File('${tempDir.path}/test.audio');
      final filePathPtr = testFile.path.toNativeUtf8();

      try {
        // Try with invalid format
        final decoder = SonixNativeBindings.initChunkedDecoder(
          999, // Invalid format
          filePathPtr.cast<ffi.Char>(),
        );

        // Should return null for invalid format
        expect(decoder.address, equals(0));
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should handle OGG format limitation gracefully', () {
      final testFile = File('${tempDir.path}/test.ogg');
      final filePathPtr = testFile.path.toNativeUtf8();

      try {
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_OGG, filePathPtr.cast<ffi.Char>());

        // Should return null due to symbol conflict limitation
        expect(decoder.address, equals(0));
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should create and process file chunks with proper memory management', () {
      // Create a mock file chunk
      final chunkData = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]); // MP3 sync header
      final chunkPtr = malloc<ffi.Uint8>(chunkData.length);
      final chunkNativeData = chunkPtr.asTypedList(chunkData.length);
      chunkNativeData.setAll(0, chunkData);

      final fileChunkPtr = malloc<SonixFileChunk>();
      final fileChunk = fileChunkPtr.ref;
      fileChunk.data = chunkPtr;
      fileChunk.size = chunkData.length;
      fileChunk.position = 0;
      fileChunk.is_last = 1;

      try {
        // Test with null decoder (should handle gracefully)
        final result = SonixNativeBindings.processFileChunk(ffi.Pointer<SonixChunkedDecoder>.fromAddress(0), fileChunkPtr);

        // Should return null for invalid decoder
        expect(result.address, equals(0));
      } finally {
        malloc.free(chunkPtr);
        malloc.free(fileChunkPtr);
      }
    });

    test('should validate chunk size recommendations are reasonable', () {
      final testCases = [
        {'format': SONIX_FORMAT_MP3, 'fileSize': 1024 * 1024, 'expectedMin': 64 * 1024},
        {'format': SONIX_FORMAT_FLAC, 'fileSize': 10 * 1024 * 1024, 'expectedMin': 256 * 1024},
        {'format': SONIX_FORMAT_WAV, 'fileSize': 5 * 1024 * 1024, 'expectedMin': 32 * 1024},
        {'format': SONIX_FORMAT_OGG, 'fileSize': 8 * 1024 * 1024, 'expectedMin': 64 * 1024},
      ];

      for (final testCase in testCases) {
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(testCase['format'] as int, testCase['fileSize'] as int);

        expect(chunkSize, greaterThanOrEqualTo(testCase['expectedMin'] as int));
        expect(chunkSize, lessThanOrEqualTo(10 * 1024 * 1024)); // Max 10MB
      }
    });

    test('should handle seeking with invalid decoder gracefully', () {
      final result = SonixNativeBindings.seekToTime(
        ffi.Pointer<SonixChunkedDecoder>.fromAddress(0),
        5000, // 5 seconds
      );

      expect(result, equals(SONIX_ERROR_INVALID_DATA));
    });

    test('should handle chunk result cleanup with null pointer', () {
      // This should not crash
      SonixNativeBindings.freeChunkResult(ffi.Pointer<SonixChunkResult>.fromAddress(0));

      // Test passes if no exception is thrown
      expect(true, isTrue);
    });

    test('should validate file chunk structure creation', () {
      final chunkPtr = malloc<SonixFileChunk>();

      try {
        final chunk = chunkPtr.ref;

        // Test setting values
        chunk.position = 1024;
        chunk.size = 4096;
        chunk.is_last = 1;

        // Verify values
        expect(chunk.position, equals(1024));
        expect(chunk.size, equals(4096));
        expect(chunk.is_last, equals(1));
      } finally {
        malloc.free(chunkPtr);
      }
    });

    test('should validate audio chunk structure creation', () {
      final chunkPtr = malloc<SonixAudioChunk>();

      try {
        final chunk = chunkPtr.ref;

        // Test setting values
        chunk.sample_count = 2048;
        chunk.start_sample = 0;
        chunk.is_last = 0;

        // Verify values
        expect(chunk.sample_count, equals(2048));
        expect(chunk.start_sample, equals(0));
        expect(chunk.is_last, equals(0));
      } finally {
        malloc.free(chunkPtr);
      }
    });

    test('should validate chunk result structure creation', () {
      final resultPtr = malloc<SonixChunkResult>();

      try {
        final result = resultPtr.ref;

        // Test setting values
        result.chunk_count = 5;
        result.error_code = SONIX_OK;

        // Verify values
        expect(result.chunk_count, equals(5));
        expect(result.error_code, equals(SONIX_OK));
      } finally {
        malloc.free(resultPtr);
      }
    });

    test('should handle memory allocation patterns correctly', () {
      // Test multiple allocations and deallocations
      final pointers = <ffi.Pointer<ffi.Uint8>>[];

      try {
        // Allocate multiple chunks
        for (int i = 0; i < 10; i++) {
          final ptr = malloc<ffi.Uint8>(1024);
          pointers.add(ptr);

          // Write some data
          final data = ptr.asTypedList(1024);
          data.fillRange(0, 1024, i);
        }

        // Verify data integrity
        for (int i = 0; i < pointers.length; i++) {
          final data = pointers[i].asTypedList(1024);
          expect(data[0], equals(i));
          expect(data[1023], equals(i));
        }
      } finally {
        // Clean up all allocations
        for (final ptr in pointers) {
          malloc.free(ptr);
        }
      }
    });
  });
}

