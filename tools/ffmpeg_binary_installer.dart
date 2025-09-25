// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';
import 'ffmpeg_binary_validator.dart';

/// Result of binary installation operation
class InstallationResult {
  final bool success;
  final String? errorMessage;
  final List<String> installedFiles;
  final Map<String, String> installPaths;

  const InstallationResult({required this.success, this.errorMessage, this.installedFiles = const [], this.installPaths = const {}});

  @override
  String toString() {
    if (success) {
      return 'Installation successful: ${installedFiles.length} files installed';
    } else {
      return 'Installation failed: $errorMessage';
    }
  }
}

/// Manages installation of FFMPEG binaries to Flutter build directories
class FFMPEGBinaryInstaller {
  final PlatformInfo platformInfo;
  final FFMPEGBinaryValidator validator;

  FFMPEGBinaryInstaller({PlatformInfo? platformInfo})
    : platformInfo = platformInfo ?? PlatformInfo.detect(),
      validator = FFMPEGBinaryValidator(platformInfo: platformInfo);

  /// Installs binaries to all required Flutter build directories
  Future<InstallationResult> installToFlutterBuildDirs(String sourcePath) async {
    try {
      final installPaths = <String, String>{};
      final installedFiles = <String>[];

      // Get platform-specific build directories
      final buildDirs = _getFlutterBuildDirectories();
      final expectedLibraries = platformInfo.getExpectedLibraryNames();

      // Validate source binaries first
      print('Validating source binaries...');
      final validationResults = await validator.validateAllBinaries(sourcePath);

      for (final entry in validationResults.entries) {
        if (!entry.value.isValid) {
          return InstallationResult(success: false, errorMessage: 'Source binary validation failed for ${entry.key}: ${entry.value.errorMessage}');
        }
      }

      print('Source binaries validated successfully');

      // Install to each build directory
      for (final buildDir in buildDirs) {
        print('Installing to: $buildDir');

        // Create build directory if it doesn't exist
        final dir = Directory(buildDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          print('Created directory: $buildDir');
        }

        // Copy each library file
        for (final libraryName in expectedLibraries) {
          final sourceFile = File('$sourcePath/$libraryName');
          final targetFile = File('$buildDir/$libraryName');

          if (await sourceFile.exists()) {
            await sourceFile.copy(targetFile.path);
            installedFiles.add(targetFile.path);
            installPaths[libraryName] = targetFile.path;
            print('Copied: $libraryName -> $buildDir');
          } else {
            return InstallationResult(success: false, errorMessage: 'Source file not found: ${sourceFile.path}');
          }
        }
      }

      // Also install to test directory for unit tests
      await _installToTestDirectory(sourcePath, installedFiles, installPaths);

      print('Installation completed successfully');
      return InstallationResult(success: true, installedFiles: installedFiles, installPaths: installPaths);
    } catch (e) {
      return InstallationResult(success: false, errorMessage: 'Installation failed: $e');
    }
  }

  /// Gets Flutter build directories for the current platform
  List<String> _getFlutterBuildDirectories() {
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

  /// Installs binaries to test directory for unit test execution
  Future<void> _installToTestDirectory(String sourcePath, List<String> installedFiles, Map<String, String> installPaths) async {
    const testDir = 'test/fixtures/ffmpeg';
    final dir = Directory(testDir);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('Created test directory: $testDir');
    }

    final expectedLibraries = platformInfo.getExpectedLibraryNames();

    for (final libraryName in expectedLibraries) {
      final sourceFile = File('$sourcePath/$libraryName');
      final targetFile = File('$testDir/$libraryName');

      if (await sourceFile.exists()) {
        await sourceFile.copy(targetFile.path);
        installedFiles.add(targetFile.path);
        installPaths['test_$libraryName'] = targetFile.path;
        print('Copied to test directory: $libraryName');
      }
    }
  }

  /// Copies binaries from source to target directory
  Future<InstallationResult> copyBinaries(String sourcePath, String targetPath) async {
    try {
      final installedFiles = <String>[];
      final installPaths = <String, String>{};
      final expectedLibraries = platformInfo.getExpectedLibraryNames();

      // Create target directory if it doesn't exist
      final targetDir = Directory(targetPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Copy each library file
      for (final libraryName in expectedLibraries) {
        final sourceFile = File('$sourcePath/$libraryName');
        final targetFile = File('$targetPath/$libraryName');

        if (await sourceFile.exists()) {
          await sourceFile.copy(targetFile.path);
          installedFiles.add(targetFile.path);
          installPaths[libraryName] = targetFile.path;
          print('Copied: $libraryName -> $targetPath');
        } else {
          return InstallationResult(success: false, errorMessage: 'Source file not found: ${sourceFile.path}');
        }
      }

      return InstallationResult(success: true, installedFiles: installedFiles, installPaths: installPaths);
    } catch (e) {
      return InstallationResult(success: false, errorMessage: 'Copy operation failed: $e');
    }
  }

  /// Verifies that binaries are correctly installed in Flutter build directories
  Future<Map<String, bool>> verifyInstallation() async {
    final results = <String, bool>{};
    final buildDirs = _getFlutterBuildDirectories();
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

      results[buildDir] = allPresent;
    }

    // Also check test directory
    bool testDirComplete = true;
    for (final libraryName in expectedLibraries) {
      final file = File('test/fixtures/ffmpeg/$libraryName');
      if (!await file.exists()) {
        testDirComplete = false;
        break;
      }
    }
    results['test/fixtures/ffmpeg'] = testDirComplete;

    return results;
  }

  /// Removes installed binaries from all Flutter build directories
  Future<bool> uninstallBinaries() async {
    try {
      final buildDirs = _getFlutterBuildDirectories();
      final expectedLibraries = platformInfo.getExpectedLibraryNames();

      // Remove from build directories
      for (final buildDir in buildDirs) {
        for (final libraryName in expectedLibraries) {
          final file = File('$buildDir/$libraryName');
          if (await file.exists()) {
            await file.delete();
            print('Removed: $buildDir/$libraryName');
          }
        }
      }

      // Remove from test directory
      for (final libraryName in expectedLibraries) {
        final file = File('test/fixtures/ffmpeg/$libraryName');
        if (await file.exists()) {
          await file.delete();
          print('Removed: test/fixtures/ffmpeg/$libraryName');
        }
      }

      return true;
    } catch (e) {
      print('Error during uninstallation: $e');
      return false;
    }
  }

  /// Gets the status of binary installation across all directories
  Future<Map<String, Map<String, bool>>> getInstallationStatus() async {
    final status = <String, Map<String, bool>>{};
    final buildDirs = [..._getFlutterBuildDirectories(), 'test/fixtures/ffmpeg'];
    final expectedLibraries = platformInfo.getExpectedLibraryNames();

    for (final buildDir in buildDirs) {
      final dirStatus = <String, bool>{};

      for (final libraryName in expectedLibraries) {
        final file = File('$buildDir/$libraryName');
        dirStatus[libraryName] = await file.exists();
      }

      status[buildDir] = dirStatus;
    }

    return status;
  }

  /// Validates installed binaries in all directories
  Future<Map<String, Map<String, BinaryValidationResult>>> validateInstalledBinaries() async {
    final results = <String, Map<String, BinaryValidationResult>>{};
    final buildDirs = [..._getFlutterBuildDirectories(), 'test/fixtures/ffmpeg'];

    for (final buildDir in buildDirs) {
      if (await Directory(buildDir).exists()) {
        results[buildDir] = await validator.validateAllBinaries(buildDir);
      }
    }

    return results;
  }
}
