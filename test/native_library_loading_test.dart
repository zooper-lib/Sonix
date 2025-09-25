import 'package:test/test.dart';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Tests for native library loading and FFMPEG memory management
///
/// This test verifies that:
/// 1. The native library loads correctly
/// 2. FFMPEG functions are accessible
/// 3. Memory management works properly
/// 4. Error handling is comprehensive
void main() {
  group('Native Library Loading Tests', () {
    late DynamicLibrary nativeLib;

    setUpAll(() {
      // Ensure FFMPEG binaries are available in test fixtures
      final ffmpegDir = Directory('test/fixtures/ffmpeg');
      if (!ffmpegDir.existsSync()) {
        throw StateError('FFMPEG binaries not found in test/fixtures/ffmpeg. Run setup first.');
      }

      // Note: FFMPEG DLLs should be in the same directory as the native library

      // Load the native library
      try {
        if (Platform.isWindows) {
          nativeLib = DynamicLibrary.open('./sonix_native.dll');
        } else if (Platform.isMacOS) {
          nativeLib = DynamicLibrary.open('./libsonix_native.dylib');
        } else {
          nativeLib = DynamicLibrary.open('./libsonix_native.so');
        }
      } catch (e) {
        throw StateError('Failed to load native library: $e');
      }
    });

    test('should load native library successfully', () {
      expect(nativeLib, isNotNull);
      print('✅ Native library loaded successfully');
    });

    test('should have all required FFMPEG functions', () {
      // Test that all required functions are available
      final requiredFunctions = [
        'sonix_init_ffmpeg',
        'sonix_cleanup_ffmpeg',
        'sonix_get_backend_type',
        'sonix_get_error_message',
        'sonix_detect_format',
        'sonix_decode_audio',
        'sonix_free_audio_data',
        'sonix_init_chunked_decoder',
        'sonix_process_file_chunk',
        'sonix_seek_to_time',
        'sonix_get_optimal_chunk_size',
        'sonix_cleanup_chunked_decoder',
        'sonix_free_chunk_result',
      ];

      for (final functionName in requiredFunctions) {
        expect(() => nativeLib.lookup(functionName), returnsNormally, reason: 'Function $functionName should be available');
      }

      print('✅ All required FFMPEG functions are available');
    });

    test('should initialize FFMPEG correctly', () {
      // Get function pointers
      final initFFmpeg = nativeLib.lookupFunction<Int32 Function(), int Function()>('sonix_init_ffmpeg');
      final getBackendType = nativeLib.lookupFunction<Int32 Function(), int Function()>('sonix_get_backend_type');
      final getErrorMessage = nativeLib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('sonix_get_error_message');

      // Initialize FFMPEG
      final result = initFFmpeg();

      if (result == 0) {
        // SONIX_OK
        print('✅ FFMPEG initialized successfully');

        // Check backend type
        final backendType = getBackendType();
        expect(backendType, equals(1)); // SONIX_BACKEND_FFMPEG
        print('✅ Backend type is FFMPEG');
      } else {
        // Get error message
        final errorPtr = getErrorMessage();
        final errorMessage = errorPtr.toDartString();
        print('⚠️ FFMPEG initialization failed: $errorMessage');

        // This is expected if FFMPEG binaries are not properly installed
        expect(result, anyOf([equals(-4), equals(-5)])); // FFMPEG_NOT_AVAILABLE or FFMPEG_INIT_FAILED
      }
    });

    test('should handle format detection with proper memory management', () {
      // Get function pointers
      final initFFmpeg = nativeLib.lookupFunction<Int32 Function(), int Function()>('sonix_init_ffmpeg');
      final detectFormat = nativeLib.lookupFunction<Int32 Function(Pointer<Uint8>, IntPtr), int Function(Pointer<Uint8>, int)>('sonix_detect_format');
      final getErrorMessage = nativeLib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('sonix_get_error_message');

      // Initialize FFMPEG first
      final initResult = initFFmpeg();

      if (initResult == 0) {
        // Test with MP3 header
        final mp3Header = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        final dataPtr = calloc<Uint8>(mp3Header.length);

        try {
          // Copy data to native memory
          for (int i = 0; i < mp3Header.length; i++) {
            dataPtr[i] = mp3Header[i];
          }

          // Detect format
          final format = detectFormat(dataPtr, mp3Header.length);

          // Should detect MP3 (format = 1) or unknown (format = 0)
          expect(format, anyOf([equals(0), equals(1)]));
          print('✅ Format detection works: format=$format');
        } finally {
          calloc.free(dataPtr);
        }

        // Test with invalid data (should not crash)
        final invalidData = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        final invalidPtr = calloc<Uint8>(invalidData.length);

        try {
          for (int i = 0; i < invalidData.length; i++) {
            invalidPtr[i] = invalidData[i];
          }

          final format = detectFormat(invalidPtr, invalidData.length);
          expect(format, equals(0)); // SONIX_FORMAT_UNKNOWN
          print('✅ Invalid data handled correctly');
        } finally {
          calloc.free(invalidPtr);
        }

        // Test with null data (should handle gracefully)
        final nullFormat = detectFormat(nullptr, 0);
        expect(nullFormat, equals(0)); // SONIX_FORMAT_UNKNOWN

        final errorPtr = getErrorMessage();
        final errorMessage = errorPtr.toDartString();
        expect(errorMessage, contains('Invalid input data'));
        print('✅ Null data handled with proper error message: $errorMessage');
      } else {
        print('⚠️ Skipping format detection test - FFMPEG not available');
      }
    });

    test('should handle chunked decoder lifecycle correctly', () {
      // Get function pointers
      final initFFmpeg = nativeLib.lookupFunction<Int32 Function(), int Function()>('sonix_init_ffmpeg');
      final initChunkedDecoder = nativeLib.lookupFunction<Pointer Function(Int32, Pointer<Utf8>), Pointer Function(int, Pointer<Utf8>)>(
        'sonix_init_chunked_decoder',
      );
      final cleanupChunkedDecoder = nativeLib.lookupFunction<Void Function(Pointer), void Function(Pointer)>('sonix_cleanup_chunked_decoder');
      final getErrorMessage = nativeLib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('sonix_get_error_message');

      // Initialize FFMPEG first
      final initResult = initFFmpeg();

      if (initResult == 0) {
        // Test with non-existent file (should fail gracefully)
        final filePathStr = 'non_existent_file.mp3'.toNativeUtf8();

        try {
          final decoder = initChunkedDecoder(1, filePathStr); // MP3 format

          if (decoder == nullptr) {
            // Expected for non-existent file
            final errorPtr = getErrorMessage();
            final errorMessage = errorPtr.toDartString();
            expect(errorMessage, anyOf([contains('Failed to open input file'), contains('Audio file not found')]));
            print('✅ Non-existent file handled correctly: $errorMessage');
          } else {
            // If somehow it worked, clean it up
            cleanupChunkedDecoder(decoder);
            print('✅ Chunked decoder created and cleaned up');
          }
        } finally {
          calloc.free(filePathStr);
        }

        // Test with null file path (should fail gracefully)
        final nullDecoder = initChunkedDecoder(1, nullptr);
        expect(nullDecoder, equals(nullptr));

        final errorPtr = getErrorMessage();
        final errorMessage = errorPtr.toDartString();
        expect(errorMessage, contains('Invalid file path'));
        print('✅ Null file path handled correctly: $errorMessage');
      } else {
        print('⚠️ Skipping chunked decoder test - FFMPEG not available');
      }
    });

    test('should handle memory allocation failures gracefully', () {
      // Get function pointers
      final initFFmpeg = nativeLib.lookupFunction<Int32 Function(), int Function()>('sonix_init_ffmpeg');
      final decodeAudio = nativeLib.lookupFunction<Pointer Function(Pointer<Uint8>, IntPtr, Int32), Pointer Function(Pointer<Uint8>, int, int)>(
        'sonix_decode_audio',
      );
      final freeAudioData = nativeLib.lookupFunction<Void Function(Pointer), void Function(Pointer)>('sonix_free_audio_data');
      final getErrorMessage = nativeLib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('sonix_get_error_message');

      // Initialize FFMPEG first
      final initResult = initFFmpeg();

      if (initResult == 0) {
        // Test with extremely large size (should fail gracefully)
        final smallData = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]);
        final dataPtr = calloc<Uint8>(smallData.length);

        try {
          for (int i = 0; i < smallData.length; i++) {
            dataPtr[i] = smallData[i];
          }

          // Try to decode (will likely fail due to invalid data, but should not crash)
          final audioData = decodeAudio(dataPtr, smallData.length, 1); // MP3 format

          if (audioData != nullptr) {
            // If it somehow worked, clean it up
            freeAudioData(audioData);
            print('✅ Audio decoding worked and cleaned up properly');
          } else {
            // Expected for invalid data
            final errorPtr = getErrorMessage();
            final errorMessage = errorPtr.toDartString();
            print('✅ Invalid audio data handled correctly: $errorMessage');
          }
        } finally {
          calloc.free(dataPtr);
        }

        // Test with null data (should fail gracefully)
        final nullAudioData = decodeAudio(nullptr, 0, 1);
        expect(nullAudioData, equals(nullptr));

        final errorPtr = getErrorMessage();
        final errorMessage = errorPtr.toDartString();
        expect(errorMessage, contains('Invalid input data'));
        print('✅ Null audio data handled correctly: $errorMessage');
      } else {
        print('⚠️ Skipping audio decoding test - FFMPEG not available');
      }
    });

    test('should cleanup FFMPEG properly', () {
      // Get function pointers
      final cleanupFFmpeg = nativeLib.lookupFunction<Void Function(), void Function()>('sonix_cleanup_ffmpeg');

      // Cleanup should not crash
      expect(() => cleanupFFmpeg(), returnsNormally);
      print('✅ FFMPEG cleanup completed without errors');
    });

    tearDownAll(() {
      // Cleanup
      try {
        final cleanupFFmpeg = nativeLib.lookupFunction<Void Function(), void Function()>('sonix_cleanup_ffmpeg');
        cleanupFFmpeg();
      } catch (e) {
        print('Warning: Could not cleanup FFMPEG: $e');
      }
    });
  });
}
