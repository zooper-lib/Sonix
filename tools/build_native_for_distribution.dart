#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';

/// Build script for creating sonix_native binaries for package distribution
///
/// This script compiles the native sonix_native library for all supported platforms
/// and places them in the correct locations within the Flutter plugin structure
/// so they can be bundled with the published package.
///
/// ## What it does:
/// 1. Compiles sonix_native for each platform using CMake
/// 2. Places binaries in platform-specific directories:
///    - Windows: windows/sonix_native.dll
///    - Linux: linux/libsonix_native.so
///    - macOS: macos/libsonix_native.dylib
///    - iOS: ios/libsonix_native.a (static library)
///    - Android: android/src/main/jniLibs/{arch}/libsonix_native.so
///
/// ## Requirements:
/// - CMake 3.10+
/// - Platform-specific toolchains (MSVC, GCC, Clang, NDK)
/// - FFMPEG binaries installed (run download_ffmpeg_binaries.dart first)
///
class NativeDistributionBuilder {
  final Map<String, String> platformOutputs = {
    'windows': 'windows/sonix_native.dll',
    'linux': 'linux/libsonix_native.so',
    'macos': 'macos/libsonix_native.dylib',
    'ios': 'ios/libsonix_native.a',
  };

  final List<String> androidArchs = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

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

    // Check FFMPEG binaries
    final ffmpegDirs = ['build/ffmpeg/windows', 'build/ffmpeg/linux', 'build/ffmpeg/macos'];
    bool ffmpegFound = false;

    for (final dir in ffmpegDirs) {
      if (await Directory(dir).exists()) {
        final files = await Directory(dir).list().toList();
        if (files.isNotEmpty) {
          ffmpegFound = true;
          break;
        }
      }
    }

    if (!ffmpegFound) {
      print('❌ FFMPEG binaries not found. Run: dart run tools/download_ffmpeg_binaries.dart');
      return false;
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

    // Build Android separately
    try {
      await _buildForAndroid();
    } catch (e) {
      print('⚠️  Failed to build for Android: $e');
    }
  }

  /// Builds for a specific platform
  Future<void> _buildForPlatform(String platform) async {
    print('');
    print('Building for $platform...');
    print('-' * 30);

    switch (platform) {
      case 'windows':
        await _buildWindows();
        break;
      case 'linux':
        await _buildLinux();
        break;
      case 'macos':
        await _buildMacOS();
        break;
      case 'ios':
        await _buildIOS();
        break;
      case 'android':
        await _buildForAndroid();
        break;
      default:
        throw ArgumentError('Unsupported platform: $platform');
    }

    print('✅ $platform build completed');
  }

  /// Builds Windows DLL
  Future<void> _buildWindows() async {
    final tempBuildDir = 'build/sonix/windows';
    await _createBuildDirectory(tempBuildDir);

    // Configure with CMake
    final configResult = await Process.run('cmake', [
      '-S',
      'native',
      '-B',
      tempBuildDir,
      '-G',
      'Visual Studio 17 2022',
      '-A',
      'x64',
      '-DCMAKE_BUILD_TYPE=Release',
      '-DFFMPEG_ROOT=build/ffmpeg/windows',
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
    final sourceFile = File('$tempBuildDir/Release/sonix_native.dll');
    final targetFile = File('windows/sonix_native.dll');

    if (await sourceFile.exists()) {
      await sourceFile.copy(targetFile.path);
      print('✅ Built and copied: ${targetFile.path}');
    } else {
      throw Exception('Built library not found: ${sourceFile.path}');
    }

    // Build directory preserved for incremental builds
  }

  /// Builds Linux shared library
  Future<void> _buildLinux() async {
    final tempBuildDir = 'build/sonix/linux';
    await _createBuildDirectory(tempBuildDir);

    // Configure with CMake
    final configResult = await Process.run('cmake', ['-S', 'native', '-B', tempBuildDir, '-DCMAKE_BUILD_TYPE=Release', '-DFFMPEG_ROOT=build/ffmpeg/linux']);

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

    // Configure with CMake - output directly to macos/ directory
    final configResult = await Process.run('cmake', [
      '-S', 'native',
      '-B', tempBuildDir,
      '-DCMAKE_BUILD_TYPE=Release',
      '-DFFMPEG_ROOT=build/ffmpeg/macos',
      '-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64', // Universal binary
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

  /// Builds iOS static library
  Future<void> _buildIOS() async {
    final tempBuildDir = 'build/sonix/ios';
    await _createBuildDirectory(tempBuildDir);

    // Configure with CMake for iOS - output directly to ios/ directory
    final configResult = await Process.run('cmake', [
      '-S', 'native',
      '-B', tempBuildDir,
      '-DCMAKE_BUILD_TYPE=Release',
      '-DCMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake', // You'll need an iOS toolchain file
      '-DPLATFORM=OS64COMBINED', // Universal iOS binary
      '-DFFMPEG_ROOT=build/ffmpeg/ios',
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
    final sourceFile = File('$tempBuildDir/libsonix_native.a');
    final targetFile = File('ios/libsonix_native.a');

    if (await sourceFile.exists()) {
      await sourceFile.copy(targetFile.path);
      print('✅ Built and copied: ${targetFile.path}');
    } else {
      throw Exception('Built library not found: ${sourceFile.path}');
    }

    // Build directory preserved for incremental builds
  }

  /// Builds Android libraries for all architectures
  Future<void> _buildForAndroid() async {
    print('');
    print('Building for Android...');
    print('-' * 30);

    for (final arch in androidArchs) {
      await _buildAndroidArch(arch);
    }
  }

  /// Builds Android library for specific architecture
  Future<void> _buildAndroidArch(String arch) async {
    print('Building Android $arch...');

    final tempBuildDir = 'build/android_$arch';
    await _createBuildDirectory(tempBuildDir);

    // Map architecture to NDK ABI
    final abiMap = {'arm64-v8a': 'arm64-v8a', 'armeabi-v7a': 'armeabi-v7a', 'x86_64': 'x86_64'};

    final abi = abiMap[arch]!;
    final outputDir = 'android/src/main/jniLibs/$arch';

    // Ensure output directory exists
    await Directory(outputDir).create(recursive: true);

    // Configure with CMake for Android - output directly to jniLibs directory
    final configResult = await Process.run('cmake', [
      '-S',
      'native',
      '-B',
      tempBuildDir,
      '-DCMAKE_BUILD_TYPE=Release',
      '-DCMAKE_TOOLCHAIN_FILE=\$ANDROID_NDK/build/cmake/android.toolchain.cmake',
      '-DANDROID_ABI=$abi',
      '-DANDROID_PLATFORM=android-21',
      '-DFFMPEG_ROOT=build/ffmpeg/android/$arch',
    ]);

    if (configResult.exitCode != 0) {
      throw Exception('CMake configuration failed for $arch: ${configResult.stderr}');
    }

    // Build
    final buildResult = await Process.run('cmake', ['--build', tempBuildDir, '--config', 'Release']);

    if (buildResult.exitCode != 0) {
      throw Exception('Build failed for $arch: ${buildResult.stderr}');
    }

    // Copy from build directory to plugin directory
    final sourceFile = File('$tempBuildDir/libsonix_native.so');
    final targetFile = File('$outputDir/libsonix_native.so');

    if (await sourceFile.exists()) {
      await sourceFile.copy(targetFile.path);
      print('✅ Built and copied: ${targetFile.path}');
    } else {
      throw Exception('Built library not found: ${sourceFile.path}');
    }

    // Build directory preserved for incremental builds
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
    final buildDirsToClean = [
      'build/sonix/windows',
      'build/sonix/linux',
      'build/sonix/macos',
      'build/sonix/ios',
      ...androidArchs.map((arch) => 'build/android_$arch'),
    ];

    // Clean built binaries from plugin directories
    final filesToClean = [...platformOutputs.values, ...androidArchs.map((arch) => 'android/src/main/jniLibs/$arch/libsonix_native.so')];

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
    if (Platform.isWindows) return 'windows';
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
  dart run tools/build_native_for_distribution.dart [options]

Options:
  -h, --help                    Show this help message
  -p, --platforms <list>        Comma-separated list of platforms to build
                               Options: current, all, windows, linux, macos, ios, android
  -c, --clean                   Clean build artifacts and exit
      --skip-validation         Skip build environment validation

Examples:
  # Build for current platform only
  dart run tools/build_native_for_distribution.dart

  # Build for all platforms
  dart run tools/build_native_for_distribution.dart --platforms all

  # Build for specific platforms
  dart run tools/build_native_for_distribution.dart --platforms windows,linux

  # Clean build artifacts
  dart run tools/build_native_for_distribution.dart --clean

Prerequisites:
  1. CMake 3.10 or later installed
  2. Platform-specific toolchains (MSVC, GCC, Clang, Android NDK)
  3. FFMPEG binaries installed: dart run tools/download_ffmpeg_binaries.dart

Output Locations:
  - Windows: windows/sonix_native.dll
  - Linux: linux/libsonix_native.so
  - macOS: macos/libsonix_native.dylib
  - iOS: ios/libsonix_native.a
  - Android: android/src/main/jniLibs/{arch}/libsonix_native.so

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
