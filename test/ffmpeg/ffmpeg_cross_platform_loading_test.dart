// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffi/ffi.dart';

import 'ffmpeg_setup_helper.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

/// Cross-platform FFMPEG binary loading tests
///
/// Tests FFMPEG binary loading on Windows (DLL), macOS (dylib), and Linux (so)
/// and verifies platform-specific binary path resolution.

void main() {
  group('Cross-Platform FFMPEG Binary Loading Tests', () {
    bool ffmpegAvailable = false;

    setUpAll(() async {
      // Setup FFMPEG libraries for testing using the fixtures directory
      FFMPEGSetupHelper.printFFMPEGStatus();
      ffmpegAvailable = await FFMPEGSetupHelper.setupFFMPEGForTesting();

      if (!ffmpegAvailable) {
        print('⚠️ FFMPEG not available - some tests will be skipped');
        print('   To set up FFMPEG for testing, run:');
        print('   dart run tool/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
      }
    });

    group('Platform Detection', () {
      test('should correctly identify current platform', () {
        print('Current platform: ${Platform.operatingSystem}');
        print('Platform version: ${Platform.operatingSystemVersion}');
        print('Is Windows: ${Platform.isWindows}');
        print('Is macOS: ${Platform.isMacOS}');
        print('Is Linux: ${Platform.isLinux}');
        print('Is Android: ${Platform.isAndroid}');
        print('Is iOS: ${Platform.isIOS}');

        // Verify platform detection is working
        final platformCount = [Platform.isWindows, Platform.isMacOS, Platform.isLinux, Platform.isAndroid, Platform.isIOS].where((p) => p).length;

        expect(platformCount, equals(1), reason: 'Exactly one platform should be detected as true');
      });
    });

    group('Native Library Loading', () {
      test('should load native library for current platform', () {
        // This test verifies that the native library can be loaded
        // The SonixNativeBindings.lib getter should handle platform-specific loading

        expect(() => SonixNativeBindings.lib, returnsNormally, reason: 'Should be able to load native library without throwing');

        final lib = SonixNativeBindings.lib;
        expect(lib, isNotNull, reason: 'Native library should be loaded successfully');

        print('✅ Native library loaded successfully for ${Platform.operatingSystem}');
      });

      test('should have all required FFMPEG functions available', () {
        final lib = SonixNativeBindings.lib;

        // List of required FFMPEG functions that should be available
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
          expect(() => lib.lookup(functionName), returnsNormally, reason: 'Function $functionName should be available in native library');
        }

        print('✅ All ${requiredFunctions.length} required FFMPEG functions are available');
      });
    });

    group('Windows-Specific Tests', () {
      test('should handle Windows DLL loading', () {
        if (!Platform.isWindows) {
          print('Skipping Windows DLL test - not running on Windows');
          return;
        }

        // On Windows, verify that the DLL and its dependencies can be loaded
        final expectedFiles = ['sonix_native.dll', 'avformat-62.dll', 'avcodec-62.dll', 'avutil-60.dll', 'swresample-6.dll'];

        // Check in test fixtures directory (where DLLs are actually located)
        final currentDir = Directory.current.path;
        final testFixturesDir = '$currentDir\\test\\fixtures\\ffmpeg';
        final windowsDir = '$currentDir\\windows';

        print('Checking for Windows FFMPEG DLL files:');
        print('  Test fixtures dir: $testFixturesDir');
        print('  Windows build dir: $windowsDir');

        bool mainDllFound = false;

        for (final fileName in expectedFiles) {
          // Check in test fixtures directory (preferred for tests)
          final testFile = File('$testFixturesDir\\$fileName');
          final windowsFile = File('$windowsDir\\$fileName');

          final testExists = testFile.existsSync();
          final windowsExists = windowsFile.existsSync();
          final exists = testExists || windowsExists;

          print('  $fileName: ${exists ? "✅ Found" : "❌ Missing"} ${testExists ? "(test)" : ""} ${windowsExists ? "(windows)" : ""}');

          if (fileName == 'sonix_native.dll') {
            mainDllFound = exists;
          }
        }

        expect(mainDllFound, isTrue, reason: 'Main native DLL sonix_native.dll should exist in either test fixtures or windows directory');

        // Test that we can actually load the library
        expect(() => SonixNativeBindings.lib, returnsNormally, reason: 'Should be able to load Windows DLL');

        final lib = SonixNativeBindings.lib;
        expect(lib, isNotNull, reason: 'Windows DLL should be loaded successfully');

        print('✅ Windows DLL loading test completed');
      });

      test('should handle Windows path resolution', () {
        if (!Platform.isWindows) {
          print('Skipping Windows path test - not running on Windows');
          return;
        }

        // Test various Windows path scenarios
        final currentDir = Directory.current.path;
        final executablePath = Platform.resolvedExecutable;
        final executableDir = Directory(executablePath).parent.path;

        print('Windows path information:');
        print('  Current directory: $currentDir');
        print('  Executable path: $executablePath');
        print('  Executable directory: $executableDir');

        // Check if DLL exists in current directory
        final dllInCurrentDir = File('$currentDir\\sonix_native.dll');
        print('  DLL in current dir: ${dllInCurrentDir.existsSync()}');

        // Check if DLL exists in executable directory
        final dllInExecDir = File('$executableDir\\sonix_native.dll');
        print('  DLL in exec dir: ${dllInExecDir.existsSync()}');

        // Check actual DLL locations (where they really are)
        final dllInTestFixtures = File('$currentDir\\test\\fixtures\\ffmpeg\\sonix_native.dll');
        print('  DLL in test fixtures: ${dllInTestFixtures.existsSync()}');

        final dllInWindows = File('$currentDir\\windows\\sonix_native.dll');
        print('  DLL in windows dir: ${dllInWindows.existsSync()}');

        // At least one of the actual build locations should have the DLL
        expect(dllInTestFixtures.existsSync() || dllInWindows.existsSync(), isTrue, reason: 'DLL should be found in test fixtures or windows build directory');

        print('✅ Windows path resolution test completed');
      });
    });

    group('macOS-Specific Tests', () {
      test('should handle macOS dylib loading', () {
        if (!Platform.isMacOS) {
          print('Skipping macOS dylib test - not running on macOS');
          return;
        }

        // On macOS, verify that the dylib can be loaded
        final expectedFiles = ['libsonix_native.dylib'];

        print('Checking for macOS FFMPEG dylib files:');
        for (final fileName in expectedFiles) {
          final file = File(fileName);
          final exists = file.existsSync();
          print('  $fileName: ${exists ? "✅ Found" : "❌ Missing"}');

          expect(exists, isTrue, reason: 'Native dylib $fileName should exist');
        }

        // Test that we can actually load the library
        expect(() => SonixNativeBindings.lib, returnsNormally, reason: 'Should be able to load macOS dylib');

        print('✅ macOS dylib loading test completed');
      });

      test('should handle macOS framework paths', () {
        if (!Platform.isMacOS) {
          print('Skipping macOS framework test - not running on macOS');
          return;
        }

        // Test macOS-specific path scenarios
        final currentDir = Directory.current.path;

        print('macOS path information:');
        print('  Current directory: $currentDir');

        // Check if dylib exists in current directory
        final dylibInCurrentDir = File('$currentDir/libsonix_native.dylib');
        print('  Dylib in current dir: ${dylibInCurrentDir.existsSync()}');

        expect(dylibInCurrentDir.existsSync(), isTrue, reason: 'Dylib should be found in current directory');

        print('✅ macOS framework path test completed');
      });
    });

    group('Linux-Specific Tests', () {
      test('should handle Linux shared object loading', () {
        if (!Platform.isLinux) {
          print('Skipping Linux SO test - not running on Linux');
          return;
        }

        // On Linux, verify that the shared object can be loaded
        final expectedFiles = ['libsonix_native.so'];

        print('Checking for Linux FFMPEG SO files:');
        for (final fileName in expectedFiles) {
          final file = File(fileName);
          final exists = file.existsSync();
          print('  $fileName: ${exists ? "✅ Found" : "❌ Missing"}');

          expect(exists, isTrue, reason: 'Native shared object $fileName should exist');
        }

        // Test that we can actually load the library
        expect(() => SonixNativeBindings.lib, returnsNormally, reason: 'Should be able to load Linux shared object');

        print('✅ Linux SO loading test completed');
      });

      test('should handle Linux library paths', () {
        if (!Platform.isLinux) {
          print('Skipping Linux path test - not running on Linux');
          return;
        }

        // Test Linux-specific path scenarios
        final currentDir = Directory.current.path;

        print('Linux path information:');
        print('  Current directory: $currentDir');

        // Check if SO exists in current directory
        final soInCurrentDir = File('$currentDir/libsonix_native.so');
        print('  SO in current dir: ${soInCurrentDir.existsSync()}');

        expect(soInCurrentDir.existsSync(), isTrue, reason: 'Shared object should be found in current directory');

        print('✅ Linux library path test completed');
      });
    });

    group('FFMPEG Binary Dependencies', () {
      test('should verify FFMPEG libraries are accessible', () async {
        // Initialize FFMPEG to test if libraries are properly linked
        final initResult = SonixNativeBindings.initFFMPEG();

        if (initResult == SONIX_OK) {
          print('✅ FFMPEG libraries initialized successfully');

          // Verify backend type
          final backendType = SonixNativeBindings.getBackendType();
          expect(backendType, equals(SONIX_BACKEND_FFMPEG), reason: 'Should report FFMPEG backend when initialized successfully');

          print('✅ FFMPEG backend is active');

          // Test basic FFMPEG functionality
          await _testBasicFFMPEGFunctionality();

          // Cleanup
          SonixNativeBindings.cleanupFFMPEG();
          print('✅ FFMPEG cleanup completed');
        } else {
          final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
          print('⚠️ FFMPEG initialization failed: $errorMsg');

          // This is expected if FFMPEG binaries are not properly installed
          expect(
            initResult,
            anyOf([equals(SONIX_ERROR_FFMPEG_NOT_AVAILABLE), equals(SONIX_ERROR_FFMPEG_INIT_FAILED)]),
            reason: 'Should return appropriate FFMPEG error code',
          );

          print('ℹ️ FFMPEG not available - this is expected if binaries are not installed');
        }
      });

      test('should handle missing FFMPEG dependencies gracefully', () {
        // Test behavior when FFMPEG dependencies might be missing

        // Try to initialize FFMPEG multiple times to test robustness
        for (int i = 0; i < 3; i++) {
          final initResult = SonixNativeBindings.initFFMPEG();

          if (initResult != SONIX_OK) {
            final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
            expect(errorMsg, isNotEmpty, reason: 'Should provide error message when FFMPEG init fails');
            print('FFMPEG init attempt ${i + 1} failed (expected): $errorMsg');
          } else {
            print('FFMPEG init attempt ${i + 1} succeeded');
            SonixNativeBindings.cleanupFFMPEG();
          }
        }

        print('✅ FFMPEG dependency handling test completed');
      });
    });

    group('Cross-Platform Compatibility', () {
      test('should work consistently across platforms', () {
        // Test library loading
        expect(() => SonixNativeBindings.lib, returnsNormally, reason: 'Library loading should work on all platforms');

        final lib = SonixNativeBindings.lib;
        expect(lib, isNotNull, reason: 'Library should be loaded successfully');

        // Test function availability
        expect(() => lib.lookup('sonix_get_backend_type'), returnsNormally, reason: 'Basic functions should be available on all platforms');

        // Test backend type query
        final backendType = SonixNativeBindings.getBackendType();
        expect(backendType, anyOf([equals(SONIX_BACKEND_LEGACY), equals(SONIX_BACKEND_FFMPEG)]), reason: 'Should return valid backend type on all platforms');

        print('✅ Cross-platform compatibility verified');
        print('   Platform: ${Platform.operatingSystem}');
        print('   Backend: ${backendType == SONIX_BACKEND_FFMPEG ? "FFMPEG" : "Legacy"}');
      });

      test('should handle platform-specific error messages', () {
        // Test that error messages are appropriate for the platform

        // Try to decode null data to trigger an error
        final audioDataPtr = SonixNativeBindings.decodeAudio(nullptr, 0, SONIX_FORMAT_MP3);
        expect(audioDataPtr, equals(nullptr), reason: 'Should return null for invalid input');

        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        expect(errorMsg, isNotEmpty, reason: 'Should provide error message');
        expect(errorMsg, isNot(contains('�')), reason: 'Error message should not contain invalid characters');

        print('✅ Platform-specific error handling verified');
        print('   Error message: $errorMsg');
      });
    });
  });
}

/// Test basic FFMPEG functionality to verify libraries are working
Future<void> _testBasicFFMPEGFunctionality() async {
  print('Testing basic FFMPEG functionality...');

  // Test format detection with a simple MP3 header
  final mp3Header = [0xFF, 0xFB, 0x90, 0x00]; // Basic MP3 frame header
  final dataPtr = malloc<Uint8>(mp3Header.length);
  final dataList = dataPtr.asTypedList(mp3Header.length);
  dataList.setAll(0, mp3Header);

  try {
    final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, mp3Header.length);

    // Should either detect MP3 or return unknown (both are acceptable for this simple test)
    expect(detectedFormat, anyOf([equals(SONIX_FORMAT_MP3), equals(SONIX_FORMAT_UNKNOWN)]), reason: 'Format detection should return valid result');

    print('  Format detection test: ${detectedFormat == SONIX_FORMAT_MP3 ? "MP3 detected" : "Unknown format (acceptable)"}');
  } finally {
    malloc.free(dataPtr);
  }

  // Test chunked decoder initialization with non-existent file (should fail gracefully)
  final nonExistentFile = '/tmp/nonexistent_test_file.mp3'.toNativeUtf8();

  try {
    final decoder = SonixNativeBindings.initChunkedDecoder(SONIX_FORMAT_MP3, nonExistentFile.cast<Char>());

    if (decoder == nullptr) {
      final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
      expect(errorMsg, isNotEmpty, reason: 'Should provide error message for non-existent file');
      print('  Chunked decoder test: Failed gracefully (expected)');
    } else {
      // Unexpected success, but clean up
      SonixNativeBindings.cleanupChunkedDecoder(decoder);
      print('  Chunked decoder test: Unexpectedly succeeded');
    }
  } finally {
    malloc.free(nonExistentFile);
  }

  print('✅ Basic FFMPEG functionality test completed');
}
