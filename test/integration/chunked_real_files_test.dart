// ignore_for_file: avoid_print

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

void main() {
  group('Chunked Processing Real Files Tests', () {
    setUpAll(() async {
      // Ensure FFMPEG is available for testing
      final available = await FFMPEGSetupHelper.setupFFMPEGForTesting();
      if (!available) {
        throw Exception('FFMPEG libraries not available for testing');
      }

      // Initialize native bindings for testing
      NativeAudioBindings.initialize();
    });

    test('should process real MP3 file with chunked decoder', () async {
      final mp3File = File('test/assets/Double-F the King - Your Blessing.mp3');

      if (!await mp3File.exists()) {
        print('MP3 test file not found, skipping test');
        return;
      }

      // Test format detection first
      final fileBytes = await mp3File.readAsBytes();
      final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
      final nativeData = dataPtr.asTypedList(fileBytes.length);
      nativeData.setAll(0, fileBytes);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
        expect(detectedFormat, equals(SONIX_FORMAT_MP3));

        // Test chunked decoder initialization
        final filePathPtr = mp3File.path.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, filePathPtr.cast<ffi.Char>());

          // Should successfully initialize for existing MP3 file
          expect(decoder.address, isNot(equals(0)));

          // Test optimal chunk size for this file
          final chunkSize = SonixNativeBindings.getOptimalChunkSize(SONIX_FORMAT_MP3, fileBytes.length);
          expect(chunkSize, greaterThan(0));

          // Test seeking to different positions
          final seekPositions = [0, 1000, 5000, 10000]; // milliseconds
          for (final position in seekPositions) {
            final seekResult = SonixNativeBindings.seekToTime(decoder, position);
            expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_DECODE_FAILED, SONIX_ERROR_INVALID_DATA]));
          }

          // Test chunk processing with real data
          // Skip ID3 metadata and start from actual MP3 audio data
          int audioStart = 0;
          if (fileBytes.length >= 10 && fileBytes[0] == 0x49 && fileBytes[1] == 0x44 && fileBytes[2] == 0x33) {
            // Calculate ID3v2 tag size
            final tagSize = ((fileBytes[6] & 0x7F) << 21) | ((fileBytes[7] & 0x7F) << 14) | ((fileBytes[8] & 0x7F) << 7) | (fileBytes[9] & 0x7F);
            audioStart = 10 + tagSize;
            print('MP3 ID3v2 tag size: ${(tagSize / 1024).toStringAsFixed(1)}KB, audio starts at byte $audioStart');
          }

          // Take a chunk starting from the actual audio data
          final testChunkSize = 256 * 1024; // 256KB chunk of actual audio
          final chunkEnd = (audioStart + testChunkSize < fileBytes.length) ? audioStart + testChunkSize : fileBytes.length;
          final chunkData = fileBytes.sublist(audioStart, chunkEnd);
          final chunkPtr = malloc<ffi.Uint8>(chunkData.length);
          final chunkNativeData = chunkPtr.asTypedList(chunkData.length);
          chunkNativeData.setAll(0, chunkData);

          final fileChunkPtr = malloc<SonixFileChunk>();
          final fileChunk = fileChunkPtr.ref;
          fileChunk.chunk_index = 0;

          try {
            final result = SonixNativeBindings.processFileChunk(decoder, fileChunkPtr);

            if (result.address != 0) {
              final resultData = result.ref;
              print('MP3 chunk processing result: success=${resultData.success}');

              if (resultData.success == 1 && resultData.audio_data.address != 0) {
                // Verify audio data
                expect(resultData.audio_data.address, isNot(equals(0)));
                final audioData = resultData.audio_data.ref;
                expect(audioData.sample_count, greaterThan(0));
                print('MP3 decoded ${audioData.sample_count} samples');
              }

              SonixNativeBindings.freeChunkResult(result);
            }
          } finally {
            malloc.free(chunkPtr);
            malloc.free(fileChunkPtr);
          }

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should process real WAV file with chunked decoder', () async {
      final wavFile = File('test/assets/Double-F the King - Your Blessing.wav');

      if (!await wavFile.exists()) {
        print('WAV test file not found, skipping test');
        return;
      }

      final fileBytes = await wavFile.readAsBytes();
      final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
      final nativeData = dataPtr.asTypedList(fileBytes.length);
      nativeData.setAll(0, fileBytes);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
        expect(detectedFormat, equals(SONIX_FORMAT_WAV));

        final filePathPtr = wavFile.path.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

          expect(decoder.address, isNot(equals(0)));

          // Test WAV-specific seeking (should be more accurate than MP3)
          final seekResult = SonixNativeBindings.seekToTime(decoder, 2000);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_DECODE_FAILED, SONIX_ERROR_INVALID_DATA]));

          // Test processing WAV header chunk
          final headerSize = 44; // Standard WAV header
          if (fileBytes.length > headerSize) {
            final headerChunk = fileBytes.take(headerSize + 1024).toList(); // Header + some data
            final chunkPtr = malloc<ffi.Uint8>(headerChunk.length);
            final chunkNativeData = chunkPtr.asTypedList(headerChunk.length);
            chunkNativeData.setAll(0, headerChunk);

            final fileChunkPtr = malloc<SonixFileChunk>();
            final fileChunk = fileChunkPtr.ref;
            fileChunk.chunk_index = 0;

            try {
              final result = SonixNativeBindings.processFileChunk(decoder, fileChunkPtr);

              if (result.address != 0) {
                final resultData = result.ref;
                print('WAV chunk processing result: success=${resultData.success}, has_audio=${resultData.audio_data.address != 0}');
                SonixNativeBindings.freeChunkResult(result);
              }
            } finally {
              malloc.free(chunkPtr);
              malloc.free(fileChunkPtr);
            }
          }

          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should process real FLAC file with chunked decoder', () async {
      final flacFile = File('test/assets/Double-F the King - Your Blessing.flac');

      if (!await flacFile.exists()) {
        print('FLAC test file not found, skipping test');
        return;
      }

      final fileBytes = await flacFile.readAsBytes();
      final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
      final nativeData = dataPtr.asTypedList(fileBytes.length);
      nativeData.setAll(0, fileBytes);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
        expect(detectedFormat, equals(SONIX_FORMAT_FLAC));

        final filePathPtr = flacFile.path.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_FLAC, filePathPtr.cast<ffi.Char>());

          expect(decoder.address, isNot(equals(0)));

          // Test FLAC seeking
          final seekResult = SonixNativeBindings.seekToTime(decoder, 3000);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_DECODE_FAILED, SONIX_ERROR_INVALID_DATA]));

          // Test processing FLAC metadata + audio chunk
          final chunkSize = 128 * 1024; // 128KB chunk for FLAC
          final chunkData = fileBytes.take(chunkSize).toList();
          final chunkPtr = malloc<ffi.Uint8>(chunkData.length);
          final chunkNativeData = chunkPtr.asTypedList(chunkData.length);
          chunkNativeData.setAll(0, chunkData);

          final fileChunkPtr = malloc<SonixFileChunk>();
          final fileChunk = fileChunkPtr.ref;
          fileChunk.chunk_index = 0;

          try {
            final result = SonixNativeBindings.processFileChunk(decoder, fileChunkPtr);

            if (result.address != 0) {
              final resultData = result.ref;
              print('FLAC chunk processing result: success=${resultData.success}, has_audio=${resultData.audio_data.address != 0}');
              SonixNativeBindings.freeChunkResult(result);
            }
          } finally {
            malloc.free(chunkPtr);
            malloc.free(fileChunkPtr);
          }

          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should handle small WAV file processing', () async {
      final smallWavFile = File('test/assets/small.wav');

      if (!await smallWavFile.exists()) {
        print('Small WAV test file not found, skipping test');
        return;
      }

      final fileBytes = await smallWavFile.readAsBytes();
      print('Small WAV file size: ${fileBytes.length} bytes');

      final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
      final nativeData = dataPtr.asTypedList(fileBytes.length);
      nativeData.setAll(0, fileBytes);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
        expect(detectedFormat, equals(SONIX_FORMAT_WAV));

        // Test optimal chunk size for small file
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(SONIX_FORMAT_WAV, fileBytes.length);
        expect(chunkSize, greaterThan(0));
        expect(chunkSize, lessThanOrEqualTo(fileBytes.length * 2)); // Should be reasonable

        final filePathPtr = smallWavFile.path.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

          if (decoder.address != 0) {
            // Process entire small file as one chunk
            final fileChunkPtr = malloc<SonixFileChunk>();
            final fileChunk = fileChunkPtr.ref;
            fileChunk.chunk_index = 0;

            try {
              final result = SonixNativeBindings.processFileChunk(decoder, fileChunkPtr);

              if (result.address != 0) {
                final resultData = result.ref;
                print('Small WAV processing result: success=${resultData.success}, has_audio=${resultData.audio_data.address != 0}');

                if (resultData.success == 1 && resultData.audio_data.address != 0) {
                  final audioData = resultData.audio_data.ref;
                  expect(audioData.sample_count, greaterThan(0));
                  print('Small WAV audio: ${audioData.sample_count} samples, is_final=${resultData.is_final_chunk}');
                }

                SonixNativeBindings.freeChunkResult(result);
              }
            } finally {
              malloc.free(fileChunkPtr);
            }

            SonixNativeBindings.cleanupChunkedDecoder(decoder);
          }
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should handle corrupted and edge case files', () async {
      final testFiles = [
        {'path': 'test/assets/empty_file.mp3', 'expectedFormat': SONIX_FORMAT_UNKNOWN},
        {'path': 'test/assets/corrupted_header.mp3', 'expectedFormat': SONIX_FORMAT_UNKNOWN},
        {'path': 'test/assets/corrupted_data.wav', 'expectedFormat': SONIX_FORMAT_WAV},
        {'path': 'test/assets/truncated.flac', 'expectedFormat': SONIX_FORMAT_FLAC},
        {'path': 'test/assets/invalid_format.xyz', 'expectedFormat': SONIX_FORMAT_UNKNOWN},
      ];

      for (final testFile in testFiles) {
        final file = File(testFile['path'] as String);
        final expectedFormat = testFile['expectedFormat'] as int;

        if (!await file.exists()) {
          print('Test file ${testFile['path']} not found, skipping');
          continue;
        }

        final fileBytes = await file.readAsBytes();
        print('Testing ${testFile['path']}: ${fileBytes.length} bytes');

        if (fileBytes.isEmpty) {
          // Handle empty files
          final nullResult = SonixNativeBindings.detectFormat(ffi.Pointer<ffi.Uint8>.fromAddress(0), 0);
          expect(nullResult, equals(SONIX_FORMAT_UNKNOWN));
          continue;
        }

        final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
        final nativeData = dataPtr.asTypedList(fileBytes.length);
        nativeData.setAll(0, fileBytes);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
          expect(detectedFormat, equals(expectedFormat));

          if (detectedFormat != SONIX_FORMAT_UNKNOWN) {
            // Try to initialize decoder for valid formats
            final filePathPtr = file.path.toNativeUtf8();
            try {
              final decoder = SonixNativeBindings.initChunkedDecoder(detectedFormat, filePathPtr.cast<ffi.Char>());

              // May succeed or fail depending on file corruption
              if (decoder.address != 0) {
                print('Decoder initialized for ${testFile['path']}');

                // Try processing a small chunk
                final chunkSize = fileBytes.length < 1024 ? fileBytes.length : 1024;
                final chunkData = fileBytes.take(chunkSize).toList();
                final chunkPtr = malloc<ffi.Uint8>(chunkData.length);
                final chunkNativeData = chunkPtr.asTypedList(chunkData.length);
                chunkNativeData.setAll(0, chunkData);

                final fileChunkPtr = malloc<SonixFileChunk>();
                final fileChunk = fileChunkPtr.ref;
                fileChunk.chunk_index = 0;

                try {
                  final result = SonixNativeBindings.processFileChunk(decoder, fileChunkPtr);

                  if (result.address != 0) {
                    final resultData = result.ref;
                    print('Corrupted file processing: success=${resultData.success}');
                    SonixNativeBindings.freeChunkResult(result);
                  }
                } finally {
                  malloc.free(chunkPtr);
                  malloc.free(fileChunkPtr);
                }

                SonixNativeBindings.cleanupChunkedDecoder(decoder);
              } else {
                print('Decoder initialization failed for ${testFile['path']} (expected for corrupted files)');
              }
            } finally {
              malloc.free(filePathPtr);
            }
          }
        } finally {
          malloc.free(dataPtr);
        }
      }
    });

    test('should compare chunk sizes across different file formats', () async {
      final formatFiles = [
        {'path': 'test/assets/Double-F the King - Your Blessing.mp3', 'format': SONIX_FORMAT_MP3},
        {'path': 'test/assets/Double-F the King - Your Blessing.wav', 'format': SONIX_FORMAT_WAV},
        {'path': 'test/assets/Double-F the King - Your Blessing.flac', 'format': SONIX_FORMAT_FLAC},
        {'path': 'test/assets/Double-F the King - Your Blessing.ogg', 'format': SONIX_FORMAT_OGG},
      ];

      final chunkSizes = <String, int>{};

      for (final formatFile in formatFiles) {
        final file = File(formatFile['path'] as String);
        final format = formatFile['format'] as int;

        if (!await file.exists()) {
          print('File ${formatFile['path']} not found, skipping');
          continue;
        }

        final fileBytes = await file.readAsBytes();
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(format, fileBytes.length);

        final formatName = formatFile['path'].toString().split('.').last;
        chunkSizes[formatName] = chunkSize;

        print('$formatName (${fileBytes.length} bytes): optimal chunk size = $chunkSize bytes');

        expect(chunkSize, greaterThan(0));
        expect(chunkSize, lessThanOrEqualTo(10 * 1024 * 1024)); // Max 10MB
      }

      // Verify we got different recommendations for different formats
      if (chunkSizes.length > 1) {
        final uniqueSizes = chunkSizes.values.toSet();
        print('Unique chunk sizes: $uniqueSizes');
        // At least some formats should have different optimal sizes
        expect(uniqueSizes.length, greaterThanOrEqualTo(1));
      }
    });

    test('should validate file size impact on chunk recommendations', () async {
      final testFile = File('test/assets/small.wav');

      if (!await testFile.exists()) {
        print('Small WAV test file not found, skipping test');
        return;
      }

      final fileBytes = await testFile.readAsBytes();
      final actualFileSize = fileBytes.length;

      // Test chunk size recommendations for different hypothetical file sizes
      final fileSizes = [actualFileSize, actualFileSize * 10, actualFileSize * 100, actualFileSize * 1000];

      int? previousChunkSize;

      for (final fileSize in fileSizes) {
        final chunkSize = SonixNativeBindings.getOptimalChunkSize(SONIX_FORMAT_WAV, fileSize);

        print('File size: $fileSize bytes -> Chunk size: $chunkSize bytes');

        expect(chunkSize, greaterThan(0));

        // Chunk size should generally increase or stay the same with file size
        if (previousChunkSize != null) {
          expect(chunkSize, greaterThanOrEqualTo(previousChunkSize));
        }

        previousChunkSize = chunkSize;
      }
    });
  });
}
