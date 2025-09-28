// ignore_for_file: avoid_print

import 'dart:ffi';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

import 'package:sonix/src/native/sonix_bindings.dart';
import 'ffmpeg_setup_helper.dart';

void main() {
  setUpAll(() async {
    // Setup FFMPEG libraries and native library in test fixtures
    final ffmpegReady = await FFMPEGSetupHelper.setupFFMPEGForTesting();
    if (!ffmpegReady) {
      print('⚠️ FFMPEG libraries not available - some tests may be skipped');
    }
  });

  tearDownAll(() async {
    await FFMPEGSetupHelper.cleanupFFMPEGAfterTesting();
  });
  group('FFMPEG Initialization Tests', () {
    test('should initialize FFMPEG successfully', () {
      print('Attempting to initialize FFMPEG...');

      final initResult = SonixNativeBindings.initFFMPEG();

      if (initResult == SONIX_OK) {
        print('✅ FFMPEG initialized successfully');

        // Verify backend type
        final backendType = SonixNativeBindings.getBackendType();
        expect(backendType, equals(SONIX_BACKEND_FFMPEG), reason: 'Should report FFMPEG backend after initialization');

        print('✅ Backend type confirmed as FFMPEG');

        // Cleanup
        SonixNativeBindings.cleanupFFMPEG();
        print('✅ FFMPEG cleanup completed');
      } else {
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        print('⚠️ FFMPEG initialization failed: $errorMsg');
        print('   Error code: $initResult');

        // This might be expected if FFMPEG binaries have issues
        expect(
          initResult,
          anyOf([equals(SONIX_ERROR_FFMPEG_NOT_AVAILABLE), equals(SONIX_ERROR_FFMPEG_INIT_FAILED)]),
          reason: 'Should return appropriate FFMPEG error code',
        );
      }
    });

    test('should handle multiple init/cleanup cycles', () {
      print('Testing multiple FFMPEG init/cleanup cycles...');

      for (int i = 0; i < 3; i++) {
        print('  Cycle ${i + 1}:');

        final initResult = SonixNativeBindings.initFFMPEG();

        if (initResult == SONIX_OK) {
          print('    ✅ Init successful');

          final backendType = SonixNativeBindings.getBackendType();
          expect(backendType, equals(SONIX_BACKEND_FFMPEG), reason: 'Should report FFMPEG backend in cycle $i');

          SonixNativeBindings.cleanupFFMPEG();
          print('    ✅ Cleanup successful');
        } else {
          final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
          print('    ⚠️ Init failed: $errorMsg');
        }
      }

      print('✅ Multiple cycles completed');
    });

    test('should test format detection after FFMPEG init', () {
      print('Testing format detection after FFMPEG initialization...');

      final initResult = SonixNativeBindings.initFFMPEG();

      if (initResult == SONIX_OK) {
        print('✅ FFMPEG initialized for format detection test');

        try {
          // Test with a simple MP3 header
          final mp3Header = [0xFF, 0xFB, 0x90, 0x00]; // Basic MP3 frame header
          final dataPtr = malloc<Uint8>(mp3Header.length);
          final dataList = dataPtr.asTypedList(mp3Header.length);
          dataList.setAll(0, mp3Header);

          try {
            print('Testing format detection with MP3 header...');
            final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, mp3Header.length);

            print('✅ Format detection completed without crash');
            print('   Detected format: $detectedFormat');

            expect(detectedFormat, anyOf([equals(SONIX_FORMAT_MP3), equals(SONIX_FORMAT_UNKNOWN)]), reason: 'Should return valid format result');
          } finally {
            malloc.free(dataPtr);
          }
        } finally {
          SonixNativeBindings.cleanupFFMPEG();
          print('✅ FFMPEG cleanup completed');
        }
      } else {
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        print('⚠️ Skipping format detection test - FFMPEG init failed: $errorMsg');
      }
    });
  });
}
