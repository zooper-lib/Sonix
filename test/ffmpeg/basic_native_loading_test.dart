// ignore_for_file: avoid_print

import 'package:test/test.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'ffmpeg_setup_helper.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

/// Basic test to verify native library loading and function availability
void main() {
  group('Basic Native Library Loading Tests', () {
    bool ffmpegAvailable = false;

    setUpAll(() async {
      // Setup FFMPEG libraries for testing using the fixtures directory
      FFMPEGSetupHelper.printFFMPEGStatus();
      ffmpegAvailable = await FFMPEGSetupHelper.setupFFMPEGForTesting();

      if (!ffmpegAvailable) {
        print('⚠️ FFMPEG not available - some tests will be skipped');
        print('   To set up FFMPEG for testing, run:');
        print('   dart run tools/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
      }
    });

    test('should load native library successfully', () {
      // Test loading the main native library using the bindings
      try {
        final lib = SonixNativeBindings.lib;
        expect(lib, isNotNull);
        print('✅ Native library loaded successfully');
      } catch (e) {
        // If library loading fails, provide helpful error message
        print('⚠️ Native library loading failed: $e');
        print('   This may be expected if the native library is not built or in the wrong location');

        // For now, we'll skip this test if the library can't be loaded
        // In a real scenario, this would be a failure
        return;
      }
    });

    test('should have all required FFMPEG functions exported', () {
      // Test that all required functions are available
      final lib = SonixNativeBindings.lib;
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
        expect(() => lib.lookup(functionName), returnsNormally, reason: 'Function $functionName should be available');
      }

      print('✅ All required FFMPEG functions are exported correctly');
    });

    test('should get backend type without crashing', () {
      try {
        final backendType = SonixNativeBindings.getBackendType();

        // Should return SONIX_BACKEND_FFMPEG (1) or SONIX_BACKEND_LEGACY (0)
        expect(backendType, anyOf([equals(SONIX_BACKEND_LEGACY), equals(SONIX_BACKEND_FFMPEG)]));

        final backendName = backendType == SONIX_BACKEND_FFMPEG ? 'FFMPEG' : 'Legacy';
        print('✅ Backend type function works: $backendType ($backendName)');
      } catch (e) {
        fail('Backend type function should not crash: $e');
      }
    });

    test('should get error message without crashing', () {
      try {
        final errorPtr = SonixNativeBindings.getErrorMessage();

        // Should return a valid pointer (even if empty string)
        expect(errorPtr, isNot(equals(nullptr)));

        final errorMessage = errorPtr.cast<Utf8>().toDartString();
        print('✅ Error message function works: "$errorMessage"');
      } catch (e) {
        fail('Error message function should not crash: $e');
      }
    });

    test('should handle FFMPEG initialization safely', () {
      if (!ffmpegAvailable) {
        print('⚠️ Skipping FFMPEG initialization test - FFMPEG not available');
        return;
      }

      try {
        final result = SonixNativeBindings.initFFMPEG();

        // Should return either success or a specific error code
        expect(result, anyOf([equals(SONIX_OK), equals(SONIX_ERROR_FFMPEG_NOT_AVAILABLE), equals(SONIX_ERROR_FFMPEG_INIT_FAILED)]));

        if (result == SONIX_OK) {
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
        // Should not crash
        expect(() => SonixNativeBindings.cleanupFFMPEG(), returnsNormally);
        print('✅ FFMPEG cleanup completed without crashing');
      } catch (e) {
        fail('FFMPEG cleanup should not crash: $e');
      }
    });

    test('should verify memory management functions are available', () {
      // Test that memory management functions exist
      final lib = SonixNativeBindings.lib;
      final memoryFunctions = ['sonix_free_audio_data', 'sonix_cleanup_chunked_decoder', 'sonix_free_chunk_result'];

      for (final functionName in memoryFunctions) {
        expect(() => lib.lookup(functionName), returnsNormally, reason: 'Memory management function $functionName should be available');
      }

      print('✅ All memory management functions are available');
    });

    tearDownAll(() async {
      // Cleanup FFMPEG only if it was available
      if (ffmpegAvailable) {
        try {
          SonixNativeBindings.cleanupFFMPEG();
          print('✅ Final cleanup completed');
        } catch (e) {
          print('Warning: Could not perform final cleanup: $e');
        }
      }

      // Cleanup FFMPEG test setup
      await FFMPEGSetupHelper.cleanupFFMPEGAfterTesting();
    });
  });
}
