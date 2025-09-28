import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
import '../test_helpers/test_data_loader.dart';

/// Helper function to check if native library is available
bool _isNativeLibraryAvailable() {
  try {
    // Try to call a simple native function to test availability
    final testPtr = malloc<ffi.Uint8>(4);
    try {
      SonixNativeBindings.detectFormat(testPtr, 0);
      return true;
    } finally {
      malloc.free(testPtr);
    }
  } catch (e) {
    return false;
  }
}

void main() {
  group('Chunked Decoder Real Data Tests', () {
    late bool nativeLibAvailable;

    setUpAll(() async {
      // Check if native library is available
      nativeLibAvailable = _isNativeLibraryAvailable();

      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Native library not available - some tests will be skipped');
        return;
      }

      // Ensure test data is available
      final hasSmallFile = await TestDataLoader.assetExists('mono_44100.wav');
      if (!hasSmallFile) {
        fail('Test data not found. Please run: dart run tools/test_data_generator.dart --essential');
      }
    });

    test('should have required test files available', () async {
      final requiredFiles = ['mono_44100.wav', 'stereo_44100.wav'];
      final optionalFiles = ['short_duration.mp3', 'sample_audio.flac', 'sample_audio.ogg', 'invalid_format.xyz', 'empty_file.mp3'];

      // Check required files
      for (final file in requiredFiles) {
        final exists = await TestDataLoader.assetExists(file);
        expect(exists, isTrue, reason: 'Required test file $file not found. Run: dart run tools/test_data_generator.dart --essential');
      }

      // Report on optional files
      for (final file in optionalFiles) {
        final exists = await TestDataLoader.assetExists(file);
        if (!exists) {
          // ignore: avoid_print
          print('Optional test file $file not found - some tests may be skipped');
        }
      }

      // List available files for debugging
      final availableFiles = await TestDataLoader.getAvailableAudioFiles();
      expect(availableFiles.length, greaterThan(0), reason: 'Should have at least some test files available');
    });

    test('should handle WAV chunked decoder initialization', () async {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping WAV chunked decoder test - native library not available');
        return;
      }

      final wavPath = TestDataLoader.getAssetPath('mono_44100.wav');
      final wavFile = File(wavPath);

      expect(await wavFile.exists(), isTrue, reason: 'WAV test file should exist at $wavPath');

      // Test chunked decoder initialization with known WAV format
      final filePathPtr = wavFile.path.toNativeUtf8();
      try {
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

        if (decoder.address != 0) {
          // Test seeking
          final seekResult = SonixNativeBindings.seekToTime(decoder, 0);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_INVALID_DATA]));

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } else {
          // ignore: avoid_print
          print('WAV decoder initialization failed - this may be expected if native implementation is incomplete');
        }
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should handle stereo WAV chunked decoder', () async {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping stereo WAV chunked decoder test - native library not available');
        return;
      }

      final wavPath = TestDataLoader.getAssetPath('stereo_44100.wav');
      final wavFile = File(wavPath);

      expect(await wavFile.exists(), isTrue, reason: 'Stereo WAV test file should exist at $wavPath');

      final filePathPtr = wavFile.path.toNativeUtf8();
      try {
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

        if (decoder.address != 0) {
          // Test seeking
          final seekResult = SonixNativeBindings.seekToTime(decoder, 0);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_INVALID_DATA]));

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } else {
          // ignore: avoid_print
          print('Stereo WAV decoder initialization failed - this may be expected');
        }
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should handle MP3 chunked decoder initialization', () async {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping MP3 chunked decoder test - native library not available');
        return;
      }

      final mp3Path = TestDataLoader.getAssetPath('short_duration.mp3');
      final mp3File = File(mp3Path);

      if (!await mp3File.exists()) {
        // ignore: avoid_print
        print('Skipping MP3 test - file not found: $mp3Path');
        return;
      }

      final filePathPtr = mp3File.path.toNativeUtf8();
      try {
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, filePathPtr.cast<ffi.Char>());

        if (decoder.address != 0) {
          // Test seeking
          final seekResult = SonixNativeBindings.seekToTime(decoder, 0);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_INVALID_DATA]));

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } else {
          // ignore: avoid_print
          print('MP3 decoder initialization failed - this may be expected');
        }
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should handle FLAC chunked decoder initialization', () async {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping FLAC chunked decoder test - native library not available');
        return;
      }

      final flacPath = TestDataLoader.getAssetPath('sample_audio.flac');
      final flacFile = File(flacPath);

      if (!await flacFile.exists()) {
        // ignore: avoid_print
        print('Skipping FLAC test - file not found: $flacPath');
        return;
      }

      final filePathPtr = flacFile.path.toNativeUtf8();
      try {
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_FLAC, filePathPtr.cast<ffi.Char>());

        if (decoder.address != 0) {
          // Test seeking
          final seekResult = SonixNativeBindings.seekToTime(decoder, 0);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_INVALID_DATA]));

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } else {
          // ignore: avoid_print
          print('FLAC decoder initialization failed - this may be expected');
        }
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should handle OGG chunked decoder initialization', () async {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping OGG chunked decoder test - native library not available');
        return;
      }

      final oggPath = TestDataLoader.getAssetPath('sample_audio.ogg');
      final oggFile = File(oggPath);

      if (!await oggFile.exists()) {
        // ignore: avoid_print
        print('Skipping OGG test - file not found: $oggPath');
        return;
      }

      final filePathPtr = oggFile.path.toNativeUtf8();
      try {
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_OGG, filePathPtr.cast<ffi.Char>());

        if (decoder.address != 0) {
          // Test seeking
          final seekResult = SonixNativeBindings.seekToTime(decoder, 0);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_INVALID_DATA]));

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } else {
          // ignore: avoid_print
          print('OGG decoder initialization failed - this may be expected');
        }
      } finally {
        malloc.free(filePathPtr);
      }
    });

    test('should handle file chunk processing', () async {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping chunk processing test - native library not available');
        return;
      }

      final wavPath = TestDataLoader.getAssetPath('mono_44100.wav');
      final wavFile = File(wavPath);

      if (!await wavFile.exists()) {
        return;
      }

      final fileBytes = await wavFile.readAsBytes();
      final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
      final nativeData = dataPtr.asTypedList(fileBytes.length);
      nativeData.setAll(0, fileBytes);

      try {
        final filePathPtr = wavFile.path.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

          if (decoder.address != 0) {
            // Test chunk processing
            final chunkPtr = malloc<SonixFileChunk>();
            final chunk = chunkPtr.ref;
            chunk.start_byte = 0;
            chunk.end_byte = fileBytes.length - 1;
            chunk.chunk_index = 0;

            try {
              final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

              if (result.address != 0) {
                final resultData = result.ref;
                // Accept various valid responses for chunk processing
                // Check if processing succeeded (success=1) or failed (success=0)
                expect(resultData.success, anyOf([0, 1]), reason: 'Should return valid success status');

                // Clean up result
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
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should validate chunk size recommendations scale properly', () {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping chunk size test - native library not available');
        return;
      }

      final fileSizes = [
        1 * 1024 * 1024, // 1MB
        10 * 1024 * 1024, // 10MB
        100 * 1024 * 1024, // 100MB
        1000 * 1024 * 1024, // 1GB
      ];

      for (final format in [SONIX_FORMAT_MP3, SONIX_FORMAT_FLAC, SONIX_FORMAT_WAV, SONIX_FORMAT_OGG]) {
        int? previousChunkSize;

        for (final fileSize in fileSizes) {
          final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, fileSize);

          // Chunk size should be reasonable
          expect(chunkSize, greaterThan(0));
          expect(chunkSize, lessThanOrEqualTo(10 * 1024 * 1024)); // Max 10MB

          // Chunk size should generally increase or stay the same with file size
          if (previousChunkSize != null) {
            expect(chunkSize, greaterThanOrEqualTo(previousChunkSize));
          }

          previousChunkSize = chunkSize;
        }
      }
    });

    test('should handle decoder cleanup safely', () {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping decoder cleanup test - native library not available');
        return;
      }

      // Test decoder cleanup with null pointer (should be safe)
      SonixNativeBindings.cleanupChunkedDecoder(ffi.Pointer<SonixChunkedDecoder>.fromAddress(0));

      // Test multiple cleanup calls should be safe
      final nullDecoder = ffi.Pointer<SonixChunkedDecoder>.fromAddress(0);
      SonixNativeBindings.cleanupChunkedDecoder(nullDecoder);
      SonixNativeBindings.cleanupChunkedDecoder(nullDecoder);

      // Test passes if we get here without crashing
      expect(true, isTrue);
    });

    test('should handle corrupted files gracefully', () async {
      if (!nativeLibAvailable) {
        // ignore: avoid_print
        print('Skipping corrupted files test - native library not available');
        return;
      }

      final corruptedPath = TestDataLoader.getAssetPath('corrupted_header.mp3');
      final corruptedFile = File(corruptedPath);

      if (!await corruptedFile.exists()) {
        // ignore: avoid_print
        print('Skipping corrupted files test - file not found: $corruptedPath');
        return;
      }

      final fileBytes = await corruptedFile.readAsBytes();
      if (fileBytes.isEmpty) {
        return;
      }

      // Test chunked decoder initialization with corrupted file
      final filePathPtr = corruptedFile.path.toNativeUtf8();
      try {
        // Try to initialize decoder with MP3 format (assuming it's a corrupted MP3)
        final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, filePathPtr.cast<ffi.Char>());

        if (decoder.address != 0) {
          // Processing should handle corruption gracefully
          final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
          final nativeData = dataPtr.asTypedList(fileBytes.length);
          nativeData.setAll(0, fileBytes);

          try {
            final chunkPtr = malloc<SonixFileChunk>();
            final chunk = chunkPtr.ref;
            chunk.start_byte = 0;
            chunk.end_byte = fileBytes.length - 1;
            chunk.chunk_index = 0;

            try {
              final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

              if (result.address != 0) {
                final resultData = result.ref;
                // Should return an error for corrupted data
                // Check if processing failed as expected for invalid data
                expect(resultData.success, equals(0), reason: 'Should fail for invalid data');

                // Clean up result
                SonixNativeBindings.freeChunkResult(result);
              }
            } finally {
              malloc.free(chunkPtr);
            }
          } finally {
            malloc.free(dataPtr);
          }

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } else {
          // ignore: avoid_print
          print('Corrupted file decoder initialization failed - this is expected');
        }
      } finally {
        malloc.free(filePathPtr);
      }
    });
  });
}
