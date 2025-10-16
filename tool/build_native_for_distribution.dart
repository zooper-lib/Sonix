#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';

/// Build script for creating sonix_native binaries for package distribution
///
/// This script compiles the native sonix_native library for all supported platforms
/// and places them in the correct locations within the Flutter plugin structure
/// so they can be used during development and CI. Desktop relies on system FFmpeg.
///
/// ## What it does:
/// 1. Compiles sonix_native for each platform using CMake
/// 2. Places binaries in platform-specific directories:
///    - Linux: linux/libsonix_native.so
///    - macOS: macos/libsonix_native.dylib
///
/// ## Requirements:
/// - CMake 3.10+
/// - Platform-specific toolchains (MSVC, GCC, Clang, NDK)
/// - System FFmpeg installed (on macOS via Homebrew: brew install ffmpeg)
///
class NativeDistributionBuilder {
  // Distribution builds are supported for Linux and macOS only (system FFmpeg)
  final Map<String, String> platformOutputs = {'linux': 'linux/libsonix_native.so', 'macos': 'macos/libsonix_native.dylib'};

  /// Main entry point
  Future<void> run(List<String> arguments) async {
    try {
      final options = _parseArguments(arguments);

      if (options['help'] == true) {
        _printUsage();
        return;
      }

      if (options['clean'] == true) {
        await _cleanBuildArtifacts();
        return;
      }

      final platforms = options['platforms'] as List<String>? ?? ['current'];
      final skipValidation = options['skip-validation'] as bool? ?? false;

      print('Sonix Native Distribution Builder');
      print('=================================');
      print('');

      // Validate prerequisites
      if (!skipValidation) {
        print('Validating build environment...');
        final validationResult = await _validateBuildEnvironment();
        if (!validationResult) {
          print('❌ Build environment validation failed');
          exit(1);
        }
        print('✅ Build environment validated');
        print('');
      }

      // Build for specified platforms
      for (final platform in platforms) {
        if (platform == 'current') {
          await _buildForCurrentPlatform();
        } else if (platform == 'all') {
          await _buildForAllPlatforms();
        } else {
          await _buildForPlatform(platform);
        }
      }

      print('');
      print('🎉 Native library build completed successfully!');
      print('');
      print('Next steps:');
      print('1. Test the libraries with the example app');
      print('2. Run tests to ensure compatibility');
      print('3. The libraries are now ready for package distribution');
    } catch (e) {
      print('❌ Build failed: $e');
      exit(1);
    }
  }

  /// Validates the build environment
  Future<bool> _validateBuildEnvironment() async {
    // Check CMake
    final cmakeResult = await Process.run('cmake', ['--version']);
    if (cmakeResult.exitCode != 0) {
      print('❌ CMake not found. Please install CMake 3.10 or later.');
      return false;
    }

    // Check system FFmpeg for host platforms (macOS/Linux)
    if (Platform.isMacOS) {
      final brew = Process.runSync('brew', ['--prefix', 'ffmpeg']);
      if (brew.exitCode != 0 || (brew.stdout as String).toString().trim().isEmpty) {
        print('❌ System FFmpeg not found. Install via Homebrew: brew install ffmpeg');
        return false;
      }
    } else if (Platform.isLinux) {
      // Check for FFmpeg development libraries using pkg-config
      final pkgConfigResult = await Process.run('pkg-config', ['--exists', 'libavcodec', 'libavformat', 'libavutil', 'libswresample']);
      if (pkgConfigResult.exitCode != 0) {
        print('❌ System FFmpeg development libraries not found.');
        print('   Install via your package manager:');
        print('   - Ubuntu/Debian: sudo apt-get install libavcodec-dev libavformat-dev libavutil-dev libswresample-dev');
        print('   - Fedora/RHEL: sudo dnf install ffmpeg-devel');
        print('   - Arch: sudo pacman -S ffmpeg');
        return false;
      }
    }

    return true;
  }

  /// Builds for the current platform only
  Future<void> _buildForCurrentPlatform() async {
    final currentPlatform = _getCurrentPlatform();
    print('Building for current platform: $currentPlatform');
    await _buildForPlatform(currentPlatform);
  }

  /// Builds for all supported platforms
  Future<void> _buildForAllPlatforms() async {
    print('Building for all platforms...');

    for (final platform in platformOutputs.keys) {
      try {
        await _buildForPlatform(platform);
      } catch (e) {
        print('⚠️  Failed to build for $platform: $e');
        print('   Continuing with other platforms...');
      }
    }
  }

  /// Builds for a specific platform
  Future<void> _buildForPlatform(String platform) async {
    print('');
    print('Building for $platform...');
    print('-' * 30);

    switch (platform) {
      case 'linux':
        await _buildLinux();
        break;
      case 'macos':
        await _buildMacOS();
        break;
      default:
        throw ArgumentError('Unsupported platform: $platform');
    }

    print('✅ $platform build completed');
  }

  /// Builds Linux shared library
  Future<void> _buildLinux() async {
    final tempBuildDir = 'build/sonix/linux';
    await _createBuildDirectory(tempBuildDir);

    // Configure with CMake using system FFmpeg on Linux
    final configResult = await Process.run('cmake', ['-S', 'native', '-B', tempBuildDir, '-DCMAKE_BUILD_TYPE=Release', '-DSONIX_USE_SYSTEM_FFMPEG=ON']);

    if (configResult.exitCode != 0) {
      throw Exception('CMake configuration failed: ${configResult.stderr}');
    }

    // Build
    final buildResult = await Process.run('cmake', ['--build', tempBuildDir, '--config', 'Release']);

    if (buildResult.exitCode != 0) {
      throw Exception('Build failed: ${buildResult.stderr}');
    }

    // Copy from build directory to plugin directory
    final sourceFile = File('$tempBuildDir/libsonix_native.so');
    final targetFile = File('linux/libsonix_native.so');

    if (await sourceFile.exists()) {
      await sourceFile.copy(targetFile.path);
      print('✅ Built and copied: ${targetFile.path}');
    } else {
      throw Exception('Built library not found: ${sourceFile.path}');
    }

    // Build directory preserved for incremental builds
  }

  /// Builds macOS dynamic library
  Future<void> _buildMacOS() async {
    final tempBuildDir = 'build/sonix/macos';
    await _createBuildDirectory(tempBuildDir);

    // Decide architectures to build based on available FFmpeg dylibs
    // Prefer system FFmpeg; architecture choice can simply follow host arch
    // If you need universal binaries, you can extend this later by probing Homebrew Cellar.
    final hostArch = _detectHostMacArch();
    final cmakeArchArg = hostArch;

    // Configure with CMake
    final configResult = await Process.run('cmake', [
      '-S',
      'native',
      '-B',
      tempBuildDir,
      '-DCMAKE_BUILD_TYPE=Release',
      '-DSONIX_USE_SYSTEM_FFMPEG=ON',
      '-DCMAKE_OSX_ARCHITECTURES=$cmakeArchArg',
    ]);

    if (configResult.exitCode != 0) {
      throw Exception('CMake configuration failed: ${configResult.stderr}');
    }

    // Build
    final buildResult = await Process.run('cmake', ['--build', tempBuildDir, '--config', 'Release']);

    if (buildResult.exitCode != 0) {
      throw Exception('Build failed: ${buildResult.stderr}');
    }

    // Copy from build directory to plugin directory
    final sourceFile = File('$tempBuildDir/libsonix_native.dylib');
    final targetFile = File('macos/libsonix_native.dylib');

    if (await sourceFile.exists()) {
      await sourceFile.copy(targetFile.path);
      print('✅ Built and copied: ${targetFile.path}');
    } else {
      throw Exception('Built library not found: ${sourceFile.path}');
    }

    // Build directory preserved for incremental builds
  }

  /// Detect host macOS CPU architecture (arm64 or x86_64)
  String _detectHostMacArch() {
    try {
      final res = Process.runSync('uname', ['-m']);
      if (res.exitCode == 0) {
        final m = (res.stdout as String).trim().toLowerCase();
        if (m.contains('arm64') || m.contains('aarch64')) return 'arm64';
        if (m.contains('x86_64') || m.contains('amd64')) return 'x86_64';
      }
    } catch (_) {}
    // Fallback: infer from Dart version string
    final v = Platform.version.toLowerCase();
    if (v.contains('arm64') || v.contains('aarch64')) return 'arm64';
    return 'x86_64';
  }

  /// Creates build directory
  Future<void> _createBuildDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('Created build directory: $path');
    } else {
      print('Using existing build directory: $path');
    }
  }

  /// Cleans build artifacts
  Future<void> _cleanBuildArtifacts() async {
    print('Cleaning build artifacts...');

    // Clean build directories (these are gitignored anyway)
    final buildDirsToClean = ['build/sonix/linux', 'build/sonix/macos'];

    // Clean built binaries from plugin directories
    final filesToClean = [...platformOutputs.values];

    for (final dir in buildDirsToClean) {
      final directory = Directory(dir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        print('Removed build directory: $dir');
      }
    }

    for (final file in filesToClean) {
      final fileObj = File(file);
      if (await fileObj.exists()) {
        await fileObj.delete();
        print('Removed binary: $file');
      }
    }

    print('✅ Cleanup completed');
  }

  /// Gets the current platform
  String _getCurrentPlatform() {
    // Only linux/macos are supported here
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Parses command line arguments
  Map<String, dynamic> _parseArguments(List<String> arguments) {
    final options = <String, dynamic>{'platforms': <String>[]};

    for (int i = 0; i < arguments.length; i++) {
      final arg = arguments[i];

      switch (arg) {
        case '--help':
        case '-h':
          options['help'] = true;
          break;
        case '--platforms':
        case '-p':
          if (i + 1 < arguments.length) {
            final platforms = arguments[++i].split(',');
            options['platforms'] = platforms;
          }
          break;
        case '--clean':
        case '-c':
          options['clean'] = true;
          break;
        case '--skip-validation':
          options['skip-validation'] = true;
          break;
        default:
          if (arg.startsWith('-')) {
            throw ArgumentError('Unknown option: $arg');
          }
      }
    }

    if ((options['platforms'] as List).isEmpty) {
      options['platforms'] = ['current'];
    }

    return options;
  }

  /// Prints usage information
  void _printUsage() {
    print('''
Sonix Native Distribution Builder
=================================

Builds sonix_native libraries for package distribution across all platforms.

Usage:
  dart run tool/build_native_for_distribution.dart [options]

Options:
  -h, --help                    Show this help message
  -p, --platforms <list>        Comma-separated list of platforms to build
                               Options: current, all, linux, macos
  -c, --clean                   Clean build artifacts and exit
      --skip-validation         Skip build environment validation

Examples:
  # Build for current platform only
  dart run tool/build_native_for_distribution.dart

  # Build for all platforms
  dart run tool/build_native_for_distribution.dart --platforms all

  # Build for specific platforms
  dart run tool/build_native_for_distribution.dart --platforms linux,macos

  # Clean build artifacts
  dart run tool/build_native_for_distribution.dart --clean

Prerequisites:
  1. CMake 3.10 or later installed
  2. Platform-specific toolchains (Clang, GCC)
  3. System FFmpeg installed (on macOS via Homebrew: brew install ffmpeg)

Output Locations:
  - Linux: linux/libsonix_native.so
  - macOS: macos/libsonix_native.dylib
  

Note: This tool prepares native libraries for package distribution.
The libraries will be automatically bundled when users install the Sonix package.
''');
  }
}

/// Main entry point
Future<void> main(List<String> arguments) async {
  final builder = NativeDistributionBuilder();
  await builder.run(arguments);
}
