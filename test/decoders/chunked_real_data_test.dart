import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('Chunked Decoder Real Data Tests', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('sonix_real_test_');
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should handle minimal WAV file creation and processing', () async {
      // Create a minimal valid WAV file (44-byte header + 8 bytes of audio data)
      final wavFile = File('${tempDir.path}/test_minimal.wav');

      // WAV header for 16-bit stereo 44.1kHz, 4 samples (8 bytes of data)
      final wavHeader = ByteData(44);

      // RIFF header
      wavHeader.setUint8(0, 0x52); // 'R'
      wavHeader.setUint8(1, 0x49); // 'I'
      wavHeader.setUint8(2, 0x46); // 'F'
      wavHeader.setUint8(3, 0x46); // 'F'
      wavHeader.setUint32(4, 36, Endian.little); // File size - 8

      // WAVE format
      wavHeader.setUint8(8, 0x57); // 'W'
      wavHeader.setUint8(9, 0x41); // 'A'
      wavHeader.setUint8(10, 0x56); // 'V'
      wavHeader.setUint8(11, 0x45); // 'E'

      // fmt chunk
      wavHeader.setUint8(12, 0x66); // 'f'
      wavHeader.setUint8(13, 0x6D); // 'm'
      wavHeader.setUint8(14, 0x74); // 't'
      wavHeader.setUint8(15, 0x20); // ' '
      wavHeader.setUint32(16, 16, Endian.little); // fmt chunk size
      wavHeader.setUint16(20, 1, Endian.little); // PCM format
      wavHeader.setUint16(22, 2, Endian.little); // 2 channels
      wavHeader.setUint32(24, 44100, Endian.little); // Sample rate
      wavHeader.setUint32(28, 176400, Endian.little); // Byte rate
      wavHeader.setUint16(32, 4, Endian.little); // Block align
      wavHeader.setUint16(34, 16, Endian.little); // Bits per sample

      // data chunk
      wavHeader.setUint8(36, 0x64); // 'd'
      wavHeader.setUint8(37, 0x61); // 'a'
      wavHeader.setUint8(38, 0x74); // 't'
      wavHeader.setUint8(39, 0x61); // 'a'
      wavHeader.setUint32(40, 8, Endian.little); // Data size

      // Write header
      await wavFile.writeAsBytes(wavHeader.buffer.asUint8List());

      // Append 8 bytes of audio data (4 stereo samples)
      final audioData = ByteData(8);
      audioData.setInt16(0, 1000, Endian.little); // Left channel
      audioData.setInt16(2, -1000, Endian.little); // Right channel
      audioData.setInt16(4, 2000, Endian.little); // Left channel
      audioData.setInt16(6, -2000, Endian.little); // Right channel

      await wavFile.writeAsBytes(audioData.buffer.asUint8List(), mode: FileMode.append);

      // Test format detection
      final fileBytes = await wavFile.readAsBytes();
      final dataPtr = malloc<ffi.Uint8>(fileBytes.length);
      final nativeData = dataPtr.asTypedList(fileBytes.length);
      nativeData.setAll(0, fileBytes);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, fileBytes.length);
        expect(detectedFormat, equals(SONIX_FORMAT_WAV));

        // Test chunked decoder initialization
        final filePathPtr = wavFile.path.toNativeUtf8();
        try {
          final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_WAV, filePathPtr.cast<ffi.Char>());

          // Should successfully initialize for existing file
          expect(decoder.address, isNot(equals(0)));

          // Test chunk processing with the header chunk
          final chunkPtr = malloc<SonixFileChunk>();
          final chunk = chunkPtr.ref;
          chunk.data = dataPtr;
          chunk.size = fileBytes.length;
          chunk.position = 0;
          chunk.is_last = 1;

          try {
            final result = SonixNativeBindings.processFileChunk(decoder, chunkPtr);

            if (result.address != 0) {
              final resultData = result.ref;
              expect(resultData.error_code, equals(SONIX_OK));

              // Clean up result
              SonixNativeBindings.freeChunkResult(result);
            }
          } finally {
            malloc.free(chunkPtr);
          }

          // Test seeking
          final seekResult = SonixNativeBindings.seekToTime(decoder, 0);
          expect(seekResult, anyOf([SONIX_OK, SONIX_ERROR_INVALID_DATA]));

          // Cleanup decoder
          SonixNativeBindings.cleanupChunkedDecoder(decoder);
        } finally {
          malloc.free(filePathPtr);
        }
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should handle MP3 sync frame detection', () {
      // Create a buffer with MP3 sync pattern
      final mp3Data = Uint8List.fromList([
        0xFF, 0xFB, 0x90, 0x00, // MP3 sync frame header
        0x00, 0x00, 0x00, 0x00, // Padding
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]);

      final dataPtr = malloc<ffi.Uint8>(mp3Data.length);
      final nativeData = dataPtr.asTypedList(mp3Data.length);
      nativeData.setAll(0, mp3Data);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, mp3Data.length);
        expect(detectedFormat, equals(SONIX_FORMAT_MP3));
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should handle FLAC signature detection', () {
      // Create a buffer with FLAC signature
      final flacData = Uint8List.fromList([
        0x66, 0x4C, 0x61, 0x43, // 'fLaC' signature
        0x00, 0x00, 0x00, 0x22, // Metadata block header
        0x00, 0x00, 0x00, 0x00, // Padding
        0x00, 0x00, 0x00, 0x00,
      ]);

      final dataPtr = malloc<ffi.Uint8>(flacData.length);
      final nativeData = dataPtr.asTypedList(flacData.length);
      nativeData.setAll(0, flacData);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, flacData.length);
        expect(detectedFormat, equals(SONIX_FORMAT_FLAC));
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should handle OGG signature detection', () {
      // Create a buffer with OGG signature
      final oggData = Uint8List.fromList([
        0x4F, 0x67, 0x67, 0x53, // 'OggS' signature
        0x00, 0x02, 0x00, 0x00, // Page header
        0x00, 0x00, 0x00, 0x00, // Padding
        0x00, 0x00, 0x00, 0x00,
      ]);

      final dataPtr = malloc<ffi.Uint8>(oggData.length);
      final nativeData = dataPtr.asTypedList(oggData.length);
      nativeData.setAll(0, oggData);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, oggData.length);
        expect(detectedFormat, equals(SONIX_FORMAT_OGG));
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should handle unknown format detection', () {
      // Create a buffer with unknown signature
      final unknownData = Uint8List.fromList([
        0x12, 0x34, 0x56, 0x78, // Unknown signature
        0x9A, 0xBC, 0xDE, 0xF0,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]);

      final dataPtr = malloc<ffi.Uint8>(unknownData.length);
      final nativeData = dataPtr.asTypedList(unknownData.length);
      nativeData.setAll(0, unknownData);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, unknownData.length);
        expect(detectedFormat, equals(SONIX_FORMAT_UNKNOWN));
      } finally {
        malloc.free(dataPtr);
      }
    });

    test('should handle edge cases in format detection', () {
      // Test with very small buffer
      final smallData = Uint8List.fromList([0xFF, 0xFB]);
      final dataPtr = malloc<ffi.Uint8>(smallData.length);
      final nativeData = dataPtr.asTypedList(smallData.length);
      nativeData.setAll(0, smallData);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, smallData.length);
        // With only 2 bytes, detection might fail or succeed depending on implementation
        expect(detectedFormat, anyOf([SONIX_FORMAT_MP3, SONIX_FORMAT_UNKNOWN]));
      } finally {
        malloc.free(dataPtr);
      }

      // Test with null pointer
      final nullResult = SonixNativeBindings.detectFormat(ffi.Pointer<ffi.Uint8>.fromAddress(0), 0);
      expect(nullResult, equals(SONIX_FORMAT_UNKNOWN));

      // Test with empty buffer
      final emptyPtr = malloc<ffi.Uint8>(1); // Allocate at least 1 byte
      try {
        final emptyResult = SonixNativeBindings.detectFormat(emptyPtr, 0);
        expect(emptyResult, equals(SONIX_FORMAT_UNKNOWN));
      } finally {
        malloc.free(emptyPtr);
      }
    });

    test('should validate chunk size recommendations scale properly', () {
      final fileSizes = [
        1 * 1024 * 1024, // 1MB
        10 * 1024 * 1024, // 10MB
        100 * 1024 * 1024, // 100MB
        1000 * 1024 * 1024, // 1GB
      ];

      for (final format in [SONIX_FORMAT_MP3, SONIX_FORMAT_FLAC, SONIX_FORMAT_WAV]) {
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
      // Test decoder cleanup with null pointer (should be safe)
      SonixNativeBindings.cleanupChunkedDecoder(ffi.Pointer<SonixChunkedDecoder>.fromAddress(0));

      // Test multiple cleanup calls should be safe
      final nullDecoder = ffi.Pointer<SonixChunkedDecoder>.fromAddress(0);
      SonixNativeBindings.cleanupChunkedDecoder(nullDecoder);
      SonixNativeBindings.cleanupChunkedDecoder(nullDecoder);

      // Test passes if we get here without crashing
      expect(true, isTrue);
    });
  });
}
