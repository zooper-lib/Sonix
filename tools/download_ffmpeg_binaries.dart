#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';
import 'ffmpeg_binary_downloader.dart';
import 'ffmpeg_binary_validator.dart';
import 'ffmpeg_binary_installer.dart';

/// FFMPEG Binary Download Tool for Sonix Package Development
///
/// ⚠️  IMPORTANT: This tool is for Sonix package developers only, NOT for end users!
///
/// ## Purpose
/// This tool downloads FFMPEG binaries required for Sonix package development and testing.
/// It installs binaries to specific directories needed for the development workflow:
///
/// 1. **native/{platform}/** - Used by the native build system (CMake) to link against FFMPEG
/// 2. **test/fixtures/ffmpeg/** - Required for unit tests to load FFMPEG libraries
/// 3. **example/build/.../** - Enables the example app to run with FFMPEG support
///
/// ## Why This Approach?
/// - Sonix uses FFMPEG via FFI but cannot ship FFMPEG binaries due to licensing
/// - FFMPEG is GPL-licensed, Sonix is MIT-licensed - they cannot be bundled together
/// - End users must provide their own FFMPEG installation or use system libraries
/// - This tool only supports package development, testing, and example app execution
///
/// ## End User Integration
/// End users of the Sonix package will need to:
/// - Install FFMPEG system-wide, OR
/// - Provide FFMPEG libraries in their app's build directories, OR
/// - Use the runtime binary loading features (if implemented)
///
/// The Sonix package documentation should provide clear instructions for end users
/// on how to integrate FFMPEG with their applications.
///
/// Command-line tool for downloading and installing FFMPEG binaries
class FFMPEGBinaryDownloadTool {
  final FFMPEGBinaryDownloader downloader;
  final FFMPEGBinaryValidator validator;
  final FFMPEGBinaryInstaller installer;

  FFMPEGBinaryDownloadTool() : downloader = FFMPEGBinaryDownloader(), validator = FFMPEGBinaryValidator(), installer = FFMPEGBinaryInstaller();

  /// Main entry point for the tool
  Future<void> run(List<String> arguments) async {
    try {
      final options = _parseArguments(arguments);

      if (options['help'] == true) {
        _printUsage();
        return;
      }

      if (options['list-platforms'] == true) {
        _listPlatforms();
        return;
      }

      if (options['verify'] == true) {
        await _verifyInstallation();
        return;
      }

      if (options['uninstall'] == true) {
        await _uninstallBinaries();
        return;
      }

      // Default action: download and install
      await _downloadAndInstall(options);
    } catch (e) {
      print('Error: $e');
      exit(1);
    }
  }

  /// Downloads and installs FFMPEG binaries
  Future<void> _downloadAndInstall(Map<String, dynamic> options) async {
    final targetPath = options['output'] as String?;
    final skipInstall = options['skip-install'] as bool? ?? false;
    final force = options['force'] as bool? ?? false;

    print('FFMPEG Binary Download Tool');
    print('============================');

    // Check if binaries are already installed
    if (!force) {
      final installStatus = await installer.verifyInstallation();
      final allInstalled = installStatus.values.every((installed) => installed);

      if (allInstalled) {
        print('FFMPEG binaries are already installed in all required directories.');
        print('Use --force to reinstall or --verify to check installation status.');
        return;
      }
    }

    // Show platform information
    final platformInfo = PlatformInfo.detect();
    print('Detected platform: ${platformInfo.platform} ${platformInfo.architecture}');
    print('OS version: ${platformInfo.osVersion}');
    print('');

    // Download binaries with progress reporting
    print('Starting download...');
    final result = await downloader.downloadForPlatform(targetPath: targetPath, installToFlutterDirs: !skipInstall, progressCallback: _showProgress);

    if (result.success) {
      print('');
      print('✅ Download completed successfully!');
      print('Downloaded ${result.downloadedFiles.length} files in ${result.downloadTime.inSeconds}s');

      if (!skipInstall) {
        print('');
        print('✅ Installation completed successfully!');
        print('FFMPEG binaries are now available in Flutter build directories.');

        // Show installation status
        await _showInstallationStatus();
      }

      print('');
      print('🎉 Development setup complete! You can now build and test Sonix with FFMPEG support.');
      print('');
      print('📝 Note: This only sets up the development environment.');
      print('   End users will need to provide their own FFMPEG installation.');
    } else {
      print('');
      print('❌ Download failed: ${result.errorMessage}');
      exit(1);
    }
  }

  /// Verifies the current installation
  Future<void> _verifyInstallation() async {
    print('FFMPEG Binary Installation Verification');
    print('=======================================');

    final installStatus = await installer.getInstallationStatus();
    final validationResults = await installer.validateInstalledBinaries();

    bool allValid = true;

    for (final entry in installStatus.entries) {
      final directory = entry.key;
      final fileStatus = entry.value;

      print('');
      print('Directory: $directory');
      print('-' * (directory.length + 11));

      for (final fileEntry in fileStatus.entries) {
        final fileName = fileEntry.key;
        final isPresent = fileEntry.value;

        if (isPresent) {
          // Check validation result if available
          final validation = validationResults[directory]?[fileName];
          if (validation?.isValid == true) {
            print('✅ $fileName (valid, version: ${validation?.detectedVersion ?? 'unknown'})');
          } else {
            print('⚠️  $fileName (present but validation failed: ${validation?.errorMessage ?? 'unknown error'})');
            allValid = false;
          }
        } else {
          print('❌ $fileName (missing)');
          allValid = false;
        }
      }
    }

    print('');
    if (allValid) {
      print('✅ All FFMPEG binaries are correctly installed and validated.');
    } else {
      print('❌ Some FFMPEG binaries are missing or invalid.');
      print('Run: dart run tools/download_ffmpeg_binaries.dart --force');
    }
  }

  /// Uninstalls FFMPEG binaries
  Future<void> _uninstallBinaries() async {
    print('FFMPEG Binary Uninstallation');
    print('============================');

    print('Removing FFMPEG binaries from all directories...');
    final success = await installer.uninstallBinaries();

    if (success) {
      print('✅ FFMPEG binaries have been successfully removed.');
    } else {
      print('❌ Failed to remove some FFMPEG binaries.');
      exit(1);
    }
  }

  /// Shows installation status
  Future<void> _showInstallationStatus() async {
    final installStatus = await installer.verifyInstallation();

    print('Installation Status:');
    for (final entry in installStatus.entries) {
      final directory = entry.key;
      final isComplete = entry.value;
      final status = isComplete ? '✅' : '❌';
      print('  $status $directory');
    }
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

  /// Lists supported platforms
  void _listPlatforms() {
    print('Supported Platforms:');
    print('===================');

    final configs = FFMPEGBinaryDownloader.getAllConfigurations();

    for (final entry in configs.entries) {
      final platform = entry.key;
      final config = entry.value;

      print('');
      print('Platform: $platform');
      print('  Architecture: ${config.architecture}');
      print('  Version: ${config.version}');
      print('  Libraries: ${config.libraryPaths.keys.join(', ')}');
    }
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
        case '--platform':
        case '-p':
          if (i + 1 < arguments.length) {
            options['platform'] = arguments[++i];
          }
          break;
        case '--output':
        case '-o':
          if (i + 1 < arguments.length) {
            options['output'] = arguments[++i];
          }
          break;
        case '--skip-install':
          options['skip-install'] = true;
          break;
        case '--force':
        case '-f':
          options['force'] = true;
          break;
        case '--verify':
        case '-v':
          options['verify'] = true;
          break;
        case '--uninstall':
        case '-u':
          options['uninstall'] = true;
          break;
        case '--list-platforms':
        case '-l':
          options['list-platforms'] = true;
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
FFMPEG Binary Download Tool for Sonix Package Development
=========================================================

⚠️  FOR SONIX PACKAGE DEVELOPERS ONLY - NOT FOR END USERS!

This tool downloads FFMPEG binaries required for Sonix package development,
testing, and example app execution. It does NOT solve FFMPEG integration
for end users of the Sonix package.

Purpose:
  - Downloads FFMPEG binaries for package development
  - Installs to native/{platform}/ for CMake builds  
  - Installs to test/fixtures/ffmpeg/ for unit tests
  - Installs to example/build/ for example app execution

End User Note:
  If you're using Sonix in your app, this tool won't help you.
  See the Sonix documentation for proper FFMPEG integration in your app.

Usage:
  dart run tools/download_ffmpeg_binaries.dart [options]

Options:
  -h, --help              Show this help message
  -p, --platform <name>   Target platform (windows, macos, linux)
  -o, --output <path>     Output directory for downloaded binaries
  -f, --force             Force download even if binaries exist
  -v, --verify            Verify current installation
  -u, --uninstall         Remove installed binaries
  -l, --list-platforms    List supported platforms
      --skip-install      Download only, don't install to Flutter directories

Examples:
  # Download and install for current platform
  dart run tools/download_ffmpeg_binaries.dart

  # Force reinstall
  dart run tools/download_ffmpeg_binaries.dart --force

  # Verify installation
  dart run tools/download_ffmpeg_binaries.dart --verify

  # Download to custom directory without installing
  dart run tools/download_ffmpeg_binaries.dart --output ./custom --skip-install

  # Remove installed binaries
  dart run tools/download_ffmpeg_binaries.dart --uninstall

Development Notes:
  - Binaries are installed to package development directories only
  - Test directory installation enables unit test execution  
  - Example app installation enables local testing
  - Use --verify to check if installation is complete and valid
  - This does NOT install FFMPEG for end users of the Sonix package

Licensing Note:
  - FFMPEG is GPL-licensed, Sonix is MIT-licensed
  - Cannot ship FFMPEG binaries with the package
  - End users must provide their own FFMPEG installation
''');
  }
}

/// Main entry point
Future<void> main(List<String> arguments) async {
  final tool = FFMPEGBinaryDownloadTool();
  await tool.run(arguments);
}
