// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ffi';

class FFMPEGSetupHelper {
  static bool _setupComplete = false;
  static String? _fixturesPath;

  /// List of FFMPEG libraries required for each platform
  static const Map<String, List<String>> ffmpegLibraries = {
    'windows': ['avcodec-62.dll', 'avdevice-62.dll', 'avfilter-11.dll', 'avformat-62.dll', 'avutil-60.dll', 'swresample-6.dll', 'swscale-9.dll'],
    'macos': ['libavcodec.dylib', 'libavformat.dylib', 'libavutil.dylib', 'libswresample.dylib'],
    'linux': ['libavcodec.so', 'libavformat.so', 'libavutil.so', 'libswresample.so'],
  };

  /// Get the current platform key
  static String get currentPlatform {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Get the list of required libraries for the current platform
  static List<String> get requiredLibraries {
    return ffmpegLibraries[currentPlatform] ?? [];
  }

  /// Setup FFMPEG libraries for testing
  ///
  /// This verifies FFMPEG libraries are available in test/fixtures/ffmpeg
  /// and sets up the environment for loading them directly from there.
  static Future<bool> setupFFMPEGForTesting() async {
    if (_setupComplete) return true;

    final fixturesDir = Directory('test/fixtures/ffmpeg');
    if (!fixturesDir.existsSync()) {
      print('⚠️ FFMPEG fixtures directory not found: ${fixturesDir.path}');
      print('   FFMPEG tests will be skipped.');
      print('   To set up FFMPEG for testing, run:');
      print('   dart run tools/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
      return false;
    }

    _fixturesPath = fixturesDir.absolute.path;

    // Verify all required libraries are present
    bool allAvailable = true;
    final availableFiles = <String>[];
    final missingFiles = <String>[];

    for (final libraryName in requiredLibraries) {
      final libraryFile = File('${fixturesDir.path}/$libraryName');
      if (libraryFile.existsSync()) {
        availableFiles.add(libraryName);
      } else {
        missingFiles.add(libraryName);
        allAvailable = false;
      }
    }

    if (allAvailable) {
      print('✅ FFMPEG libraries available for testing: ${availableFiles.join(', ')}');

      // Set up environment for loading libraries from fixtures directory
      await _setupLibraryPath();
    } else {
      print('⚠️ Missing FFMPEG libraries: ${missingFiles.join(', ')}');
      print('   Available: ${availableFiles.join(', ')}');
      print('   To download missing libraries, run:');
      print('   dart run tools/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
    }

    _setupComplete = true;
    return allAvailable;
  }

  /// Setup library path environment for loading FFMPEG from fixtures
  static Future<void> _setupLibraryPath() async {
    if (_fixturesPath == null) return;

    if (Platform.isWindows) {
      // On Windows, we need to preload FFMPEG DLLs from the fixtures directory
      // This ensures they are available when the main native library tries to use them
      await _preloadFFMPEGLibraries();
      print('ℹ️ FFMPEG DLLs preloaded from: $_fixturesPath');
    } else if (Platform.isMacOS) {
      // On macOS, preload dylibs from fixtures directory
      await _preloadFFMPEGLibraries();
      print('ℹ️ FFMPEG dylibs preloaded from: $_fixturesPath');
    } else if (Platform.isLinux) {
      // On Linux, preload shared objects from fixtures directory
      await _preloadFFMPEGLibraries();
      print('ℹ️ FFMPEG shared objects preloaded from: $_fixturesPath');
    }
  }

  /// Preload FFMPEG libraries from fixtures directory
  static Future<void> _preloadFFMPEGLibraries() async {
    if (_fixturesPath == null) return;

    final loadedLibraries = <String>[];
    final failedLibraries = <String>[];

    // Load libraries in dependency order (most basic first)
    final orderedLibraries = _getLibrariesInDependencyOrder();

    for (final libraryName in orderedLibraries) {
      final libraryPath = '$_fixturesPath/$libraryName';
      final libraryFile = File(libraryPath);

      if (libraryFile.existsSync()) {
        try {
          // Preload the library to make it available for the main native library
          DynamicLibrary.open(libraryPath);
          loadedLibraries.add(libraryName);
        } catch (e) {
          failedLibraries.add('$libraryName: $e');
        }
      }
    }

    if (loadedLibraries.isNotEmpty) {
      print('✅ Preloaded FFMPEG libraries: ${loadedLibraries.join(', ')}');
    }

    if (failedLibraries.isNotEmpty) {
      print('⚠️ Failed to preload some libraries: ${failedLibraries.join(', ')}');
    }
  }

  /// Get libraries in dependency order (dependencies first)
  static List<String> _getLibrariesInDependencyOrder() {
    if (Platform.isWindows) {
      return [
        'avutil-60.dll', // Base utility library (no dependencies)
        'swresample-6.dll', // Depends on avutil
        'avcodec-62.dll', // Depends on avutil, swresample
        'avformat-62.dll', // Depends on avutil, avcodec
        'avfilter-11.dll', // Depends on avutil, avcodec, avformat, swresample
        'avdevice-62.dll', // Depends on avutil, avcodec, avformat
        'swscale-9.dll', // Depends on avutil
      ];
    } else if (Platform.isMacOS) {
      return ['libavutil.dylib', 'libswresample.dylib', 'libavcodec.dylib', 'libavformat.dylib'];
    } else if (Platform.isLinux) {
      return ['libavutil.so', 'libswresample.so', 'libavcodec.so', 'libavformat.so'];
    }
    return [];
  }

  /// Get the full path to a specific FFMPEG library in fixtures
  static String? getLibraryPath(String libraryName) {
    if (_fixturesPath == null) return null;

    final libraryFile = File('$_fixturesPath/$libraryName');
    return libraryFile.existsSync() ? libraryFile.absolute.path : null;
  }

  /// Check if FFMPEG libraries are available for testing
  static bool areFFMPEGLibrariesAvailable() {
    final fixturesDir = Directory('test/fixtures/ffmpeg');
    if (!fixturesDir.existsSync()) return false;

    for (final libraryName in requiredLibraries) {
      final file = File('${fixturesDir.path}/$libraryName');
      if (!file.existsSync()) return false;
    }

    return true;
  }

  /// Print FFMPEG availability status
  static void printFFMPEGStatus() {
    print('=== FFMPEG Test Setup Status ===');
    print('Platform: ${Platform.operatingSystem}');

    final available = areFFMPEGLibrariesAvailable();
    print('FFMPEG libraries available: ${available ? "✅ Yes" : "❌ No"}');

    if (!available) {
      print('');
      print('To set up FFMPEG for testing:');
      print('1. Run: dart run tools/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
      print('2. Or manually place the following libraries in test/fixtures/ffmpeg/:');
      for (final library in requiredLibraries) {
        print('   - $library');
      }
      print('3. Run tests again');
    }

    print('================================');
  }
}
