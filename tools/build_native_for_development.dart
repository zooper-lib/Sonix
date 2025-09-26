#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';

/// Quick development build script for Sonix native library
///
/// This script is for DEVELOPMENT ONLY - it builds the native library
/// for local testing and development in the native/build/ directory.
///
/// For package distribution builds, use:
/// dart run tools/build_native_for_distribution.dart
///
class NativeDevelopmentBuilder {
  /// Main entry point
  Future<void> run(List<String> arguments) async {
    try {
      final options = _parseArguments(arguments);

      if (options['help'] == true) {
        _printUsage();
        return;
      }

      if (options['clean'] == true) {
        await _cleanBuild();
        return;
      }

      await _buildForDevelopment(options);
    } catch (e) {
      print('❌ Build failed: $e');
      exit(1);
    }
  }

  /// Builds the native library for development
  Future<void> _buildForDevelopment(Map<String, dynamic> options) async {
    final verbose = options['verbose'] as bool? ?? false;
    final buildType = options['build-type'] as String? ?? 'Release';

    print('Sonix Native Development Builder');
    print('===============================');
    print('');
    print('📝 NOTE: This is a development build for local testing.');
    print('   For package distribution builds, use:');
    print('   dart run tools/build_native_for_distribution.dart');
    print('');

    // Detect platform
    final platform = _getCurrentPlatform();
    print('Platform: $platform');
    print('Build type: $buildType');
    print('');

    // Validate prerequisites
    print('Validating build environment...');
    final validationResult = await _validateBuildEnvironment();
    if (!validationResult) {
      print('❌ Build environment validation failed');
      exit(1);
    }
    print('✅ Build environment validated');
    print('');

    // Create build directory
    final buildDir = 'build/development';
    await _createBuildDirectory(buildDir);

    // Configure with CMake
    print('Configuring with CMake...');
    final configArgs = _getCMakeConfigArgs(platform, buildType);

    if (verbose) {
      print('CMake command: cmake ${configArgs.join(' ')}');
    }

    final configResult = await Process.run('cmake', configArgs);

    if (configResult.exitCode != 0) {
      print('❌ CMake configuration failed:');
      print(configResult.stderr);
      exit(1);
    }

    if (verbose) {
      print('CMake configuration output:');
      print(configResult.stdout);
    }

    print('✅ Configuration completed');
    print('');

    // Build
    print('Building native library...');
    final buildArgs = _getCMakeBuildArgs(platform, buildType);

    if (verbose) {
      print('Build command: cmake ${buildArgs.join(' ')}');
    }

    final buildResult = await Process.run('cmake', buildArgs);

    if (buildResult.exitCode != 0) {
      print('❌ Build failed:');
      print(buildResult.stderr);
      exit(1);
    }

    if (verbose) {
      print('Build output:');
      print(buildResult.stdout);
    }

    print('✅ Build completed successfully!');
    print('');

    // Show built files
    await _showBuiltFiles(buildDir, platform);

    print('');
    print('🎉 Development build completed!');
    print('');
    print('Next steps:');
    print('1. Test your changes with the example app');
    print('2. Run unit tests: flutter test');
    print('3. For distribution builds: dart run tools/build_native_for_distribution.dart');
  }

  /// Validates the build environment
  Future<bool> _validateBuildEnvironment() async {
    // Check CMake
    try {
      final cmakeResult = await Process.run('cmake', ['--version']);
      if (cmakeResult.exitCode != 0) {
        print('❌ CMake not found. Please install CMake 3.10 or later.');
        return false;
      }
    } catch (e) {
      print('❌ CMake not found. Please install CMake 3.10 or later.');
      return false;
    }

    // Check if we're in the right directory
    if (!await File('native/CMakeLists.txt').exists()) {
      print('❌ CMakeLists.txt not found in native/ directory.');
      print('   Make sure you\'re running this from the Sonix package root.');
      return false;
    }

    // Check FFMPEG binaries (optional for development)
    final platform = _getCurrentPlatform();
    final ffmpegDir = 'native/$platform';
    if (!await Directory(ffmpegDir).exists()) {
      print('⚠️  FFMPEG binaries not found in $ffmpegDir');
      print('   Run: dart run tools/download_ffmpeg_binaries.dart');
      print('   Continuing anyway (build may fail if FFMPEG is required)...');
    }

    return true;
  }

  /// Gets CMake configuration arguments for the platform
  List<String> _getCMakeConfigArgs(String platform, String buildType) {
    final args = ['-S', 'native', '-B', 'build/development', '-DCMAKE_BUILD_TYPE=$buildType'];

    // Add platform-specific configuration
    switch (platform) {
      case 'windows':
        args.addAll(['-G', 'Visual Studio 17 2022', '-A', 'x64']);
        break;
      case 'linux':
      case 'macos':
        // Use default generator (Make or Ninja)
        break;
    }

    // Add FFMPEG path if available
    final ffmpegDir = Directory('native/$platform');
    if (ffmpegDir.existsSync()) {
      args.add('-DFFMPEG_ROOT=native/$platform');
    }

    return args;
  }

  /// Gets CMake build arguments for the platform
  List<String> _getCMakeBuildArgs(String platform, String buildType) {
    final args = ['--build', 'build/development'];

    // Add platform-specific build options
    switch (platform) {
      case 'windows':
        args.addAll(['--config', buildType]);
        break;
      case 'linux':
      case 'macos':
        // Parallel build
        final cores = _getProcessorCount();
        args.addAll(['--parallel', cores.toString()]);
        break;
    }

    return args;
  }

  /// Gets the number of processor cores for parallel builds
  int _getProcessorCount() {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final result = Process.runSync('nproc', []);
        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim()) ?? 4;
        }
      }
      if (Platform.isMacOS) {
        final result = Process.runSync('sysctl', ['-n', 'hw.ncpu']);
        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim()) ?? 4;
        }
      }
    } catch (e) {
      // Fallback to 4 cores
    }
    return 4;
  }

  /// Shows the built files
  Future<void> _showBuiltFiles(String buildDir, String platform) async {
    print('Built files:');

    final extensions = _getLibraryExtensions(platform);
    bool foundFiles = false;

    for (final ext in extensions) {
      final files = await _findFilesWithExtension(buildDir, ext);
      for (final file in files) {
        final stat = await file.stat();
        final size = _formatFileSize(stat.size);
        print('  ✅ ${file.path} ($size)');
        foundFiles = true;
      }
    }

    if (!foundFiles) {
      print('  ⚠️  No library files found. Build may have failed.');
    }

    print('');
    print('Build directory: ${Directory(buildDir).absolute.path}');
  }

  /// Gets library file extensions for the platform
  List<String> _getLibraryExtensions(String platform) {
    switch (platform) {
      case 'windows':
        return ['.dll', '.lib'];
      case 'linux':
        return ['.so', '.a'];
      case 'macos':
        return ['.dylib', '.a'];
      default:
        return ['.so', '.dylib', '.dll', '.a', '.lib'];
    }
  }

  /// Finds files with specific extension in directory
  Future<List<File>> _findFilesWithExtension(String dirPath, String extension) async {
    final files = <File>[];
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      return files;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith(extension)) {
        files.add(entity);
      }
    }

    return files;
  }

  /// Formats file size in human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Creates build directory
  Future<void> _createBuildDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      // Don't delete existing build directory for incremental builds
      print('Using existing build directory: $path');
    } else {
      await dir.create(recursive: true);
      print('Created build directory: $path');
    }
  }

  /// Cleans the build directory
  Future<void> _cleanBuild() async {
    print('Cleaning development build...');

    final buildDir = Directory('build/development');
    if (await buildDir.exists()) {
      await buildDir.delete(recursive: true);
      print('✅ Removed: ${buildDir.path}');
    } else {
      print('Build directory does not exist: ${buildDir.path}');
    }

    print('✅ Clean completed');
  }

  /// Gets the current platform
  String _getCurrentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Parses command line arguments
  Map<String, dynamic> _parseArguments(List<String> arguments) {
    final options = <String, dynamic>{};

    for (int i = 0; i < arguments.length; i++) {
      final arg = arguments[i];

      switch (arg) {
        case '--help':
        case '-h':
          options['help'] = true;
          break;
        case '--verbose':
        case '-v':
          options['verbose'] = true;
          break;
        case '--clean':
        case '-c':
          options['clean'] = true;
          break;
        case '--build-type':
        case '-t':
          if (i + 1 < arguments.length) {
            options['build-type'] = arguments[++i];
          }
          break;
        default:
          if (arg.startsWith('-')) {
            throw ArgumentError('Unknown option: $arg');
          }
      }
    }

    return options;
  }

  /// Prints usage information
  void _printUsage() {
    print('''
Sonix Native Development Builder
===============================

Quick development build script for the Sonix native library.
Builds to native/build/ directory for local testing and development.

Usage:
  dart run tools/build_native_for_development.dart [options]

Options:
  -h, --help              Show this help message
  -v, --verbose           Show detailed build output
  -c, --clean             Clean build directory and exit
  -t, --build-type <type> Build type (Debug, Release, RelWithDebInfo)
                         Default: Release

Examples:
  # Quick development build
  dart run tools/build_native_for_development.dart

  # Debug build with verbose output
  dart run tools/build_native_for_development.dart --build-type Debug --verbose

  # Clean build directory
  dart run tools/build_native_for_development.dart --clean

Build Output:
  - Windows: build/development/Release/sonix_native.dll
  - Linux: build/development/libsonix_native.so
  - macOS: build/development/libsonix_native.dylib

Note: This is for development only. For package distribution builds, use:
  dart run tools/build_native_for_distribution.dart

Prerequisites:
  1. CMake 3.10 or later installed
  2. Platform-specific toolchain (MSVC, GCC, Clang)
  3. FFMPEG binaries (optional): dart run tools/download_ffmpeg_binaries.dart
''');
  }
}

/// Main entry point
Future<void> main(List<String> arguments) async {
  final builder = NativeDevelopmentBuilder();
  await builder.run(arguments);
}
