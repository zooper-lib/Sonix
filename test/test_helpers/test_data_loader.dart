/// Test data loader helper for accessing test assets
///
/// This helper provides utilities for loading test audio files
/// and checking their existence.
library;

import 'dart:io';

/// Helper class for loading test data and assets
class TestDataLoader {
  /// Base path for test assets
  static const String _assetBasePath = 'test/assets';

  /// Path for generated test assets
  static const String _generatedBasePath = 'test/assets/generated';

  /// Path for large generated test assets
  static const String _largeFilesBasePath = 'test/assets/generated/large_files';

  /// Get the full path to a test asset
  /// Checks generated directories first, then falls back to main assets directory
  static String getAssetPath(String assetName) {
    final largeFilesPath = '$_largeFilesBasePath/$assetName';
    final generatedPath = '$_generatedBasePath/$assetName';
    final mainPath = '$_assetBasePath/$assetName';

    // Check if file exists in large files directory first
    if (File(largeFilesPath).existsSync()) {
      return largeFilesPath;
    }

    // Check if file exists in generated directory
    if (File(generatedPath).existsSync()) {
      return generatedPath;
    }

    // Fall back to main assets directory
    return mainPath;
  }

  /// Check if a test asset exists
  /// Checks large files, generated, and main assets directories
  static Future<bool> assetExists(String assetName) async {
    // Check large files directory first
    final largeFile = File('$_largeFilesBasePath/$assetName');
    if (await largeFile.exists()) {
      return true;
    }

    // Check generated directory
    final generatedFile = File('$_generatedBasePath/$assetName');
    if (await generatedFile.exists()) {
      return true;
    }

    // Check main assets directory
    final mainFile = File('$_assetBasePath/$assetName');
    return await mainFile.exists();
  }

  /// Get a list of available test audio files
  /// Scans large files, generated, and main assets directories
  static Future<List<String>> getAvailableAudioFiles() async {
    final files = <String>{}; // Use Set to avoid duplicates

    // Check large files directory first
    final largeFilesDirectory = Directory(_largeFilesBasePath);
    if (await largeFilesDirectory.exists()) {
      await for (final entity in largeFilesDirectory.list()) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (_isAudioFile(name)) {
            files.add(name);
          }
        }
      }
    }

    // Check generated directory
    final generatedDirectory = Directory(_generatedBasePath);
    if (await generatedDirectory.exists()) {
      await for (final entity in generatedDirectory.list()) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (_isAudioFile(name)) {
            files.add(name);
          }
        }
      }
    }

    // Check main assets directory
    final mainDirectory = Directory(_assetBasePath);
    if (await mainDirectory.exists()) {
      await for (final entity in mainDirectory.list()) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (_isAudioFile(name)) {
            files.add(name);
          }
        }
      }
    }

    return files.toList();
  }

  /// Check if a file is an audio file based on extension
  static bool _isAudioFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['wav', 'mp3', 'flac', 'ogg'].contains(extension);
  }

  /// Get a small test file for quick tests
  static Future<String?> getSmallTestFile() async {
    final candidates = ['test_mono_44100.wav', 'wav_tiny_44100_1ch.wav', 'small_test.wav', 'small.wav'];

    for (final candidate in candidates) {
      if (await assetExists(candidate)) {
        return getAssetPath(candidate);
      }
    }

    return null;
  }

  /// Get a medium-sized test file for performance tests
  static Future<String?> getMediumTestFile() async {
    final candidates = ['test_stereo_44100.wav', 'wav_medium_44100_2ch.wav', 'test_medium.wav'];

    for (final candidate in candidates) {
      if (await assetExists(candidate)) {
        return getAssetPath(candidate);
      }
    }

    return null;
  }
}
