import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('Chunked Processing Native Interface', () {
    test('should initialize chunked decoder', () {
      // Test with a non-existent file first to check error handling
      final filePathPtr = 'non_existent.mp3'.toNativeUtf8();

      try {
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, filePathPtr.cast<ffi.Char>());

        // Should return null for non-existent file
        expect(decoder.address, equals(0));
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should get optimal chunk size', () {
      // Test optimal chunk size calculation
      final chunkSize = SonixNativeBindings.getOptimalChunkSize(
        SONIX_FORMAT_MP3,
        10 * 1024 * 1024, // 10MB file
      );

      expect(chunkSize, greaterThan(0));
      expect(chunkSize, lessThanOrEqualTo(2 * 1024 * 1024)); // Should be reasonable
    });

    test('should handle different formats for chunk size', () {
      final mp3ChunkSize = SonixNativeBindings.getOptimalChunkSize(
        SONIX_FORMAT_MP3,
        100 * 1024 * 1024, // 100MB file
      );

      final wavChunkSize = SonixNativeBindings.getOptimalChunkSize(
        SONIX_FORMAT_WAV,
        100 * 1024 * 1024, // 100MB file
      );

      final flacChunkSize = SonixNativeBindings.getOptimalChunkSize(
        SONIX_FORMAT_FLAC,
        100 * 1024 * 1024, // 100MB file
      );

      expect(mp3ChunkSize, greaterThan(0));
      expect(wavChunkSize, greaterThan(0));
      expect(flacChunkSize, greaterThan(0));

      // FLAC should have larger chunks than WAV
      expect(flacChunkSize, greaterThanOrEqualTo(wavChunkSize));
    });

    test('should validate chunk size scaling with file size', () {
      // Small file
      final smallChunkSize = SonixNativeBindings.getOptimalChunkSize(
        SONIX_FORMAT_MP3,
        5 * 1024 * 1024, // 5MB file
      );

      // Large file
      final largeChunkSize = SonixNativeBindings.getOptimalChunkSize(
        SONIX_FORMAT_MP3,
        500 * 1024 * 1024, // 500MB file
      );

      // Large files should have larger or equal chunk sizes
      expect(largeChunkSize, greaterThanOrEqualTo(smallChunkSize));
    });

    test('should handle seeking operations', () {
      // Test seeking with invalid decoder (should return error)
      final result = SonixNativeBindings.seekToTime(
        ffi.Pointer<SonixChunkedDecoder>.fromAddress(0), // null pointer
        5000, // 5 seconds
      );

      // Should return error code for invalid decoder
      expect(result, equals(SONIX_ERROR_INVALID_DATA));
    });

    test('should handle cleanup of null decoder gracefully', () {
      // This should not crash
      SonixNativeBindings.cleanupChunkedDecoder(
        ffi.Pointer<SonixChunkedDecoder>.fromAddress(0), // null pointer
      );

      // Test passes if no exception is thrown
      expect(true, isTrue);
    });

    test('should handle chunk result cleanup', () {
      // This should not crash with null pointer
      SonixNativeBindings.freeChunkResult(
        ffi.Pointer<SonixChunkResult>.fromAddress(0), // null pointer
      );

      // Test passes if no exception is thrown
      expect(true, isTrue);
    });

    test('should handle format-specific chunk size recommendations', () {
      // Test that different formats return different optimal chunk sizes
      final formats = [SONIX_FORMAT_MP3, SONIX_FORMAT_FLAC, SONIX_FORMAT_WAV, SONIX_FORMAT_OGG];

      final fileSize = 100 * 1024 * 1024; // 100MB
      final chunkSizes = <int>[];

      for (final format in formats) {
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, fileSize);
        chunkSizes.add(chunkSize);
        expect(chunkSize, greaterThan(0));
      }

      // Verify that we get different recommendations for different formats
      // (at least some should be different)
      final uniqueSizes = chunkSizes.toSet();
      expect(uniqueSizes.length, greaterThan(1));
    });
  });
}

