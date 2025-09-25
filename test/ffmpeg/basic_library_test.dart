/// Basic library loading test without FFMPEG initialization
///
/// Tests that the native library can be loaded and basic functions work
/// without initializing FFMPEG to isolate the issue.
library;

import 'dart:ffi';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('Basic Library Loading Tests', () {
    test('should load native library successfully', () {
      expect(() => SonixNativeBindings.lib, returnsNormally, reason: 'Should be able to load native library');

      final lib = SonixNativeBindings.lib;
      expect(lib, isNotNull, reason: 'Native library should be loaded');

      print('✅ Native library loaded successfully');
    });

    test('should have basic functions available', () {
      final lib = SonixNativeBindings.lib;

      // Test that basic functions exist
      expect(() => lib.lookup('sonix_get_backend_type'), returnsNormally, reason: 'Backend type function should be available');
      expect(() => lib.lookup('sonix_get_error_message'), returnsNormally, reason: 'Error message function should be available');

      print('✅ Basic functions are available');
    });

    test('should get backend type without FFMPEG init', () {
      // This should work without initializing FFMPEG
      final backendType = SonixNativeBindings.getBackendType();

      expect(backendType, anyOf([equals(SONIX_BACKEND_LEGACY), equals(SONIX_BACKEND_FFMPEG)]), reason: 'Should return valid backend type');

      print('✅ Backend type: ${backendType == SONIX_BACKEND_FFMPEG ? "FFMPEG" : "Legacy"}');
    });

    test('should handle error messages', () {
      // Get error message (should work even if no error)
      final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();

      // Error message should be a string (might be empty)
      expect(errorMsg, isA<String>(), reason: 'Should return string error message');

      print('✅ Error message function works: "${errorMsg}"');
    });

    test('should handle null data gracefully without FFMPEG', () {
      // Test format detection with null data (should not crash)
      final detectedFormat = SonixNativeBindings.detectFormat(nullptr, 0);

      expect(detectedFormat, equals(SONIX_FORMAT_UNKNOWN), reason: 'Null data should return unknown format');

      print('✅ Null data handled gracefully');
    });
  });
}
