#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';
import '../tools/ffmpeg_binary_downloader.dart';
import '../tools/ffmpeg_binary_validator.dart';

/// FFMPEG Setup Tool for Sonix End Users
///
/// This tool helps end users of the Sonix package download and install
/// FFMPEG binaries into their Flutter app's build directories.
///
/// ## Usage
/// Run this tool from your Flutter app's root directory:
/// ```bash
/// dart run sonix:setup_ffmpeg_for_app
/// ```
///
/// ## What it does
/// 1. Downloads FFMPEG binaries for your platform
/// 2. Installs them to your app's build directories
/// 3. Validates the installation
///
/// ## Requirements
/// - Must be run from a Flutter app's root directory (contains pubspec.yaml)
/// - Sonix package must be added as a dependency
///
class FFMPEGAppSetupTool {
  final FFMPEGBinaryDownloader downloader;
  final FFMPEGBinaryValidator validator;

  FFMPEGAppSetupTool() : downloader = FFMPEGBinaryDownloader(), validator = FFMPEGBinaryValidator();

  /// Main entry point for the tool
  Future<void> run(List<String> arguments) async {
    try {
      final options = _parseArguments(arguments);

      if (options['help'] == true) {
        _printUsage();
        return;
      }

      if (options['verify'] == true) {
        await _verifyInstallation();
        return;
      }

      if (options['clean'] == true) {
        await _cleanInstallation();
        return;
      }

      // Default action: setup FFMPEG for the app
      await _setupFFMPEGForApp(options);
    } catch (e) {
      print('Error: $e');
      exit(1);
    }
  }

  /// Sets up FFMPEG binaries for the current Flutter app
  Future<void> _setupFFMPEGForApp(Map<String, dynamic> options) async {
    final force = options['force'] as bool? ?? false;

    print('Sonix FFMPEG Setup Tool');
    print('=======================');
    print('');

    // Validate we're in a Flutter app directory
    if (!await _isFlutterAppDirectory()) {
      print('❌ Error: This tool must be run from a Flutter app\'s root directory.');
      print('   Make sure you\'re in the directory that contains pubspec.yaml');
      exit(1);
    }

    // Check if Sonix is a dependency
    if (!await _isSonixDependency()) {
      print('❌ Error: Sonix package not found in dependencies.');
      print('   Add Sonix to your pubspec.yaml first:');
      print('   dependencies:');
      print('     sonix: ^x.x.x');
      exit(1);
    }

    print('✅ Flutter app detected');
    print('✅ Sonix dependency found');
    print('');

    // Check if already installed
    if (!force) {
      final isInstalled = await _checkExistingInstallation();
      if (isInstalled) {
        print('✅ FFMPEG binaries are already installed.');
        print('   Use --force to reinstall or --verify to check status.');
        return;
      }
    }

    // Show platform information
    final platformInfo = PlatformInfo.detect();
    print('Platform: ${platformInfo.platform} ${platformInfo.architecture}');
    print('');

    // Download binaries
    print('Downloading FFMPEG binaries...');
    final tempDir = 'build/ffmpeg_temp';
    final result = await downloader.downloadForPlatform(
      targetPath: tempDir,
      installToFlutterDirs: false, // We'll handle installation ourselves
      progressCallback: _showProgress,
    );

    if (!result.success) {
      print('');
      print('❌ Download failed: ${result.errorMessage}');
      exit(1);
    }

    print('');
    print('✅ Download completed successfully!');
    print('');

    // Install to app build directories
    print('Installing to app build directories...');
    final installResult = await _installToAppBuildDirs(tempDir, platformInfo);

    if (!installResult) {
      print('❌ Installation failed');
      exit(1);
    }

    // Clean up temp directory
    try {
      await Directory(tempDir).delete(recursive: true);
    } catch (e) {
      // Ignore cleanup errors
    }

    print('');
    print('🎉 FFMPEG setup completed successfully!');
    print('');
    print('Next steps:');
    print('1. Build your Flutter app: flutter build <platform>');
    print('2. The FFMPEG libraries will be included in your app bundle');
    print('3. Sonix will automatically detect and use the libraries');
    print('');
    print('💡 Tip: Run "dart run sonix:setup_ffmpeg_for_app --verify" to check installation');
  }

  /// Verifies the current FFMPEG installation
  Future<void> _verifyInstallation() async {
    print('FFMPEG Installation Verification');
    print('================================');
    print('');

    if (!await _isFlutterAppDirectory()) {
      print('❌ Not a Flutter app directory');
      return;
    }

    final platformInfo = PlatformInfo.detect();
    final buildDirs = _getAppBuildDirectories(platformInfo);
    final expectedLibraries = platformInfo.getExpectedLibraryNames();

    bool allValid = true;

    for (final buildDir in buildDirs) {
      print('Checking: $buildDir');

      bool dirComplete = true;
      for (final libraryName in expectedLibraries) {
        final file = File('$buildDir/$libraryName');
        final exists = await file.exists();

        if (exists) {
          // Validate the binary
          final validation = await validator.validateBinary(file.path);
          if (validation.isValid) {
            print('  ✅ $libraryName (valid)');
          } else {
            print('  ⚠️  $libraryName (invalid: ${validation.errorMessage})');
            dirComplete = false;
            allValid = false;
          }
        } else {
          print('  ❌ $libraryName (missing)');
          dirComplete = false;
          allValid = false;
        }
      }

      if (!dirComplete) {
        print('  Status: ❌ Incomplete');
      } else {
        print('  Status: ✅ Complete');
      }
      print('');
    }

    if (allValid) {
      print('🎉 All FFMPEG binaries are correctly installed and validated!');
    } else {
      print('❌ Some FFMPEG binaries are missing or invalid.');
      print('   Run: dart run sonix:setup_ffmpeg_for_app --force');
    }
  }

  /// Cleans the FFMPEG installation
  Future<void> _cleanInstallation() async {
    print('Cleaning FFMPEG Installation');
    print('============================');
    print('');

    if (!await _isFlutterAppDirectory()) {
      print('❌ Not a Flutter app directory');
      return;
    }

    final platformInfo = PlatformInfo.detect();
    final buildDirs = _getAppBuildDirectories(platformInfo);
    final expectedLibraries = platformInfo.getExpectedLibraryNames();

    for (final buildDir in buildDirs) {
      for (final libraryName in expectedLibraries) {
        final file = File('$buildDir/$libraryName');
        if (await file.exists()) {
          await file.delete();
          print('Removed: $buildDir/$libraryName');
        }
      }
    }

    print('');
    print('✅ FFMPEG binaries have been removed from build directories.');
  }

  /// Installs binaries to app build directories
  Future<bool> _installToAppBuildDirs(String sourcePath, PlatformInfo platformInfo) async {
    try {
      final buildDirs = _getAppBuildDirectories(platformInfo);
      final expectedLibraries = platformInfo.getExpectedLibraryNames();

      for (final buildDir in buildDirs) {
        // Create build directory if it doesn't exist
        final dir = Directory(buildDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          print('Created: $buildDir');
        }

        // Copy each library file
        for (final libraryName in expectedLibraries) {
          final sourceFile = File('$sourcePath/$libraryName');
          final targetFile = File('$buildDir/$libraryName');

          if (await sourceFile.exists()) {
            await sourceFile.copy(targetFile.path);
            print('Installed: $libraryName -> $buildDir');
          } else {
            print('❌ Source file not found: ${sourceFile.path}');
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print('❌ Installation error: $e');
      return false;
    }
  }

  /// Gets build directories for the current app
  List<String> _getAppBuildDirectories(PlatformInfo platformInfo) {
    switch (platformInfo.platform) {
      case 'windows':
        return ['build/windows/x64/runner/Debug', 'build/windows/x64/runner/Release'];
      case 'macos':
        return ['build/macos/Build/Products/Debug', 'build/macos/Build/Products/Release'];
      case 'linux':
        return ['build/linux/x64/debug/bundle/lib', 'build/linux/x64/release/bundle/lib'];
      default:
        throw UnsupportedError('Unsupported platform: ${platformInfo.platform}');
    }
  }

  /// Checks if we're in a Flutter app directory
  Future<bool> _isFlutterAppDirectory() async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      return false;
    }

    // Check if it's a Flutter app (not a package)
    final content = await pubspecFile.readAsString();
    return content.contains('flutter:') && !content.contains('flutter:\n  plugin:') && !content.contains('flutter:\r\n  plugin:');
  }

  /// Checks if Sonix is listed as a dependency
  Future<bool> _isSonixDependency() async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      return false;
    }

    final content = await pubspecFile.readAsString();
    return content.contains('sonix:');
  }

  /// Checks if FFMPEG is already installed
  Future<bool> _checkExistingInstallation() async {
    final platformInfo = PlatformInfo.detect();
    final buildDirs = _getAppBuildDirectories(platformInfo);
    final expectedLibraries = platformInfo.getExpectedLibraryNames();

    for (final buildDir in buildDirs) {
      bool allPresent = true;
      for (final libraryName in expectedLibraries) {
        final file = File('$buildDir/$libraryName');
        if (!await file.exists()) {
          allPresent = false;
          break;
        }
      }
      if (allPresent) {
        return true; // At least one build dir has all libraries
      }
    }

    return false;
  }

  /// Shows download progress
  void _showProgress(String fileName, double progress) {
    final percentage = (progress * 100).toInt();
    final progressBar = _createProgressBar(progress);
    stdout.write('\r$fileName: $progressBar $percentage%');

    if (progress >= 1.0) {
      print(' ✅');
    }
  }

  /// Creates a visual progress bar
  String _createProgressBar(double progress, {int width = 30}) {
    final filled = (progress * width).round();
    final empty = width - filled;
    return '[${'█' * filled}${'░' * empty}]';
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
        case '--force':
        case '-f':
          options['force'] = true;
          break;
        case '--verify':
        case '-v':
          options['verify'] = true;
          break;
        case '--clean':
        case '-c':
          options['clean'] = true;
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
Sonix FFMPEG Setup Tool for Flutter Apps
========================================

Sets up FFMPEG binaries for your Flutter app to use with the Sonix package.

Usage:
  dart run sonix:setup_ffmpeg_for_app [options]

Options:
  -h, --help     Show this help message
  -f, --force    Force reinstall even if binaries exist
  -v, --verify   Verify current installation
  -c, --clean    Remove installed FFMPEG binaries

Examples:
  # Setup FFMPEG for your app
  dart run sonix:setup_ffmpeg_for_app

  # Force reinstall
  dart run sonix:setup_ffmpeg_for_app --force

  # Check installation status
  dart run sonix:setup_ffmpeg_for_app --verify

  # Remove FFMPEG binaries
  dart run sonix:setup_ffmpeg_for_app --clean

Requirements:
  - Run from your Flutter app's root directory
  - Sonix must be added as a dependency in pubspec.yaml

What this tool does:
  1. Downloads FFMPEG binaries for your platform
  2. Installs them to your app's build directories
  3. Validates the installation
  4. Your app can now use Sonix with FFMPEG support

Note: This tool installs FFMPEG binaries into your app's build directories.
The binaries will be included when you build your Flutter app for distribution.
''');
  }
}

/// Main entry point
Future<void> main(List<String> arguments) async {
  final tool = FFMPEGAppSetupTool();
  await tool.run(arguments);
}
