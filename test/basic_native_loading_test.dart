import 'package:test/test.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Basic test to verify native library loading and function availability
void main() {
  group('Basic Native Library Loading Tests', () {
    late DynamicLibrary nativeLib;

    setUpAll(() {
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

    test('should have all required FFMPEG functions exported', () {
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

      print('✅ All required FFMPEG functions are exported correctly');
    });

    test('should get backend type without crashing', () {
      try {
        final getBackendType = nativeLib.lookupFunction<Int32 Function(), int Function()>('sonix_get_backend_type');
        final backendType = getBackendType();

        // Should return SONIX_BACKEND_FFMPEG (1)
        expect(backendType, equals(1));
        print('✅ Backend type function works: $backendType (FFMPEG)');
      } catch (e) {
        fail('Backend type function should not crash: $e');
      }
    });

    test('should get error message without crashing', () {
      try {
        final getErrorMessage = nativeLib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('sonix_get_error_message');
        final errorPtr = getErrorMessage();

        // Should return a valid pointer (even if empty string)
        expect(errorPtr, isNot(equals(nullptr)));

        final errorMessage = errorPtr.toDartString();
        print('✅ Error message function works: "$errorMessage"');
      } catch (e) {
        fail('Error message function should not crash: $e');
      }
    });

    test('should handle FFMPEG initialization safely', () {
      try {
        final initFFmpeg = nativeLib.lookupFunction<Int32 Function(), int Function()>('sonix_init_ffmpeg');
        final result = initFFmpeg();

        // Should return either success (0) or a specific error code
        expect(
          result,
          anyOf([
            equals(0), // SONIX_OK
            equals(-4), // SONIX_ERROR_FFMPEG_NOT_AVAILABLE
            equals(-5), // SONIX_ERROR_FFMPEG_INIT_FAILED
          ]),
        );

        if (result == 0) {
          print('✅ FFMPEG initialization succeeded');
        } else {
          print('✅ FFMPEG initialization failed gracefully with code: $result');
        }
      } catch (e) {
        fail('FFMPEG initialization should not crash: $e');
      }
    });

    test('should handle FFMPEG cleanup safely', () {
      try {
        final cleanupFFmpeg = nativeLib.lookupFunction<Void Function(), void Function()>('sonix_cleanup_ffmpeg');

        // Should not crash
        expect(() => cleanupFFmpeg(), returnsNormally);
        print('✅ FFMPEG cleanup completed without crashing');
      } catch (e) {
        fail('FFMPEG cleanup should not crash: $e');
      }
    });

    test('should verify memory management functions are available', () {
      // Test that memory management functions exist
      final memoryFunctions = ['sonix_free_audio_data', 'sonix_cleanup_chunked_decoder', 'sonix_free_chunk_result'];

      for (final functionName in memoryFunctions) {
        expect(() => nativeLib.lookup(functionName), returnsNormally, reason: 'Memory management function $functionName should be available');
      }

      print('✅ All memory management functions are available');
    });

    tearDownAll(() {
      // Final cleanup
      try {
        final cleanupFFmpeg = nativeLib.lookupFunction<Void Function(), void Function()>('sonix_cleanup_ffmpeg');
        cleanupFFmpeg();
        print('✅ Final cleanup completed');
      } catch (e) {
        print('Warning: Could not perform final cleanup: $e');
      }
    });
  });
}
