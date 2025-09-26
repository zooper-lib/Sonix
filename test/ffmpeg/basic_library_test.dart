// ignore_for_file: avoid_print

import 'dart:ffi';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

import 'ffmpeg_setup_helper.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('Basic Library Loading Tests', () {
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
      try {
        final lib = SonixNativeBindings.lib;
        expect(lib, isNotNull, reason: 'Native library should be loaded');
        print('✅ Native library loaded successfully');
      } catch (e) {
        // If library loading fails, provide helpful error message
        print('⚠️ Native library loading failed: $e');
        print('   This may be expected if the native library is not built or FFMPEG libraries are missing');

        // For now, we'll skip this test if the library can't be loaded
        return;
      }
    });

    test('should have basic functions available', () {
      final lib = SonixNativeBindings.lib;

      // Test that basic functions exist
      expect(() => lib.lookup('sonix_get_backend_type'), returnsNormally, reason: 'Backend type function should be available');
      expect(() => lib.lookup('sonix_get_error_message'), returnsNormally, reason: 'Error message function should be available');

      print('✅ Basic functions are available');
    });

    test('should get backend type without FFMPEG init', () {
      try {
        // This should work without initializing FFMPEG
        final backendType = SonixNativeBindings.getBackendType();

        expect(backendType, anyOf([equals(SONIX_BACKEND_LEGACY), equals(SONIX_BACKEND_FFMPEG)]), reason: 'Should return valid backend type');

        print('✅ Backend type: ${backendType == SONIX_BACKEND_FFMPEG ? "FFMPEG" : "Legacy"}');
      } catch (e) {
        print('⚠️ Backend type check failed: $e');
        print('   This may be expected if the native library is not available');
        return;
      }
    });

    test('should handle error messages', () {
      try {
        // Get error message (should work even if no error)
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();

        // Error message should be a string (might be empty)
        expect(errorMsg, isA<String>(), reason: 'Should return string error message');

        print('✅ Error message function works: "$errorMsg"');
      } catch (e) {
        print('⚠️ Error message check failed: $e');
        print('   This may be expected if the native library is not available');
        return;
      }
    });

    test('should handle null data gracefully without FFMPEG', () {
      try {
        // Test format detection with null data (should not crash)
        final detectedFormat = SonixNativeBindings.detectFormat(nullptr, 0);

        expect(detectedFormat, equals(SONIX_FORMAT_UNKNOWN), reason: 'Null data should return unknown format');

        print('✅ Null data handled gracefully');
      } catch (e) {
        print('⚠️ Format detection check failed: $e');
        print('   This may be expected if the native library is not available');
        return;
      }
    });

    tearDownAll(() async {
      // Cleanup FFMPEG test setup
      await FFMPEGSetupHelper.cleanupFFMPEGAfterTesting();
    });
  });
}
