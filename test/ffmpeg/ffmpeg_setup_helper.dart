// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ffi';

class FFMPEGSetupHelper {
  static bool _setupComplete = false;
  static String? _fixturesPath;

  /// List of FFMPEG libraries for each platform
  /// Core libraries are required, optional libraries are nice-to-have
  static const Map<String, List<String>> coreLibraries = {
    'windows': ['avutil-60.dll', 'avcodec-62.dll', 'avformat-62.dll', 'swresample-6.dll'],
    'macos': ['libavutil.dylib', 'libavcodec.dylib', 'libavformat.dylib', 'libswresample.dylib'],
    'linux': ['libavutil.so', 'libavcodec.so', 'libavformat.so', 'libswresample.so'],
  };

  static const Map<String, List<String>> optionalLibraries = {
    'windows': ['avdevice-62.dll', 'avfilter-11.dll', 'swscale-9.dll'],
    'macos': [],
    'linux': [],
  };

  /// Get the current platform key
  static String get currentPlatform {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Get the list of core libraries for the current platform
  static List<String> get requiredLibraries {
    return coreLibraries[currentPlatform] ?? [];
  }

  /// Get the list of all libraries (core + optional) for the current platform
  static List<String> get allLibraries {
    final core = coreLibraries[currentPlatform] ?? [];
    final optional = optionalLibraries[currentPlatform] ?? [];
    return [...core, ...optional];
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
      print('   dart run tool/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
      return false;
    }

    _fixturesPath = fixturesDir.absolute.path;

    // Check core libraries (required)
    bool coreAvailable = true;
    final availableCoreFiles = <String>[];
    final missingCoreFiles = <String>[];

    for (final libraryName in requiredLibraries) {
      final libraryFile = File('${fixturesDir.path}/$libraryName');
      if (libraryFile.existsSync()) {
        availableCoreFiles.add(libraryName);
      } else {
        missingCoreFiles.add(libraryName);
        coreAvailable = false;
      }
    }

    // Check optional libraries (nice-to-have)
    final availableOptionalFiles = <String>[];
    final missingOptionalFiles = <String>[];

    for (final libraryName in optionalLibraries[currentPlatform] ?? []) {
      final libraryFile = File('${fixturesDir.path}/$libraryName');
      if (libraryFile.existsSync()) {
        availableOptionalFiles.add(libraryName);
      } else {
        missingOptionalFiles.add(libraryName);
      }
    }

    if (coreAvailable) {
      print('✅ Core FFMPEG libraries available: ${availableCoreFiles.join(', ')}');
      if (availableOptionalFiles.isNotEmpty) {
        print('✅ Optional FFMPEG libraries available: ${availableOptionalFiles.join(', ')}');
      }
      if (missingOptionalFiles.isNotEmpty) {
        print('ℹ️ Optional FFMPEG libraries missing: ${missingOptionalFiles.join(', ')} (not required)');
      }

      // Set up environment for loading libraries from fixtures directory
      await _setupLibraryPath();
    } else {
      print('⚠️ Missing core FFMPEG libraries: ${missingCoreFiles.join(', ')}');
      if (availableCoreFiles.isNotEmpty) {
        print('   Available core: ${availableCoreFiles.join(', ')}');
      }
      print('   To download missing libraries, run:');
      print('   dart run tool/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
    }

    _setupComplete = true;
    return coreAvailable;
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
    // Get all available libraries in dependency order
    final allAvailable = <String>[];

    if (Platform.isWindows) {
      final orderedLibs = [
        'avutil-60.dll', // Base utility library (no dependencies)
        'swresample-6.dll', // Depends on avutil
        'avcodec-62.dll', // Depends on avutil, swresample
        'avformat-62.dll', // Depends on avutil, avcodec
        'swscale-9.dll', // Depends on avutil (optional)
        'avfilter-11.dll', // Depends on avutil, avcodec, avformat, swresample (optional)
        'avdevice-62.dll', // Depends on avutil, avcodec, avformat (optional)
      ];

      // Only include libraries that actually exist
      for (final lib in orderedLibs) {
        if (_fixturesPath != null) {
          final file = File('$_fixturesPath/$lib');
          if (file.existsSync()) {
            allAvailable.add(lib);
          }
        }
      }
    } else if (Platform.isMacOS) {
      final orderedLibs = ['libavutil.dylib', 'libswresample.dylib', 'libavcodec.dylib', 'libavformat.dylib'];

      for (final lib in orderedLibs) {
        if (_fixturesPath != null) {
          final file = File('$_fixturesPath/$lib');
          if (file.existsSync()) {
            allAvailable.add(lib);
          }
        }
      }
    } else if (Platform.isLinux) {
      final orderedLibs = ['libavutil.so', 'libswresample.so', 'libavcodec.so', 'libavformat.so'];

      for (final lib in orderedLibs) {
        if (_fixturesPath != null) {
          final file = File('$_fixturesPath/$lib');
          if (file.existsSync()) {
            allAvailable.add(lib);
          }
        }
      }
    }

    return allAvailable;
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

    // Check that all core libraries are available
    for (final libraryName in requiredLibraries) {
      final file = File('${fixturesDir.path}/$libraryName');
      if (!file.existsSync()) return false;
    }

    return true;
  }

  /// Cleanup after testing
  static Future<void> cleanupFFMPEGAfterTesting() async {
    // No files to clean up since we don't copy to root anymore
    print('ℹ️ FFMPEG test cleanup complete');
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
      print('1. Run: dart run tool/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
      print('2. Or manually place the following libraries in test/fixtures/ffmpeg/:');
      for (final library in requiredLibraries) {
        print('   - $library');
      }
      print('3. Run tests again');
    }

    print('================================');
  }
}
