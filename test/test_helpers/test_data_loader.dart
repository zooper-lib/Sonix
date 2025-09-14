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

  /// Get the full path to a test asset
  static String getAssetPath(String assetName) {
    return '$_assetBasePath/$assetName';
  }

  /// Check if a test asset exists
  static Future<bool> assetExists(String assetName) async {
    final file = File(getAssetPath(assetName));
    return await file.exists();
  }

  /// Get a list of available test audio files
  static Future<List<String>> getAvailableAudioFiles() async {
    final directory = Directory(_assetBasePath);
    if (!await directory.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in directory.list()) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (_isAudioFile(name)) {
          files.add(name);
        }
      }
    }

    return files;
  }

  /// Check if a file is an audio file based on extension
  static bool _isAudioFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['wav', 'mp3', 'flac', 'ogg', 'opus'].contains(extension);
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
