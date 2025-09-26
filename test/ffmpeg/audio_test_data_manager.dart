/// Audio test data manager for FFMPEG integration tests
///
/// This class manages real audio test files and provides expected results
/// for comprehensive FFMPEG testing with actual audio data.
// ignore_for_file: avoid_print

library;

import 'dart:io';
import 'dart:typed_data';

/// Manages real audio test files for FFMPEG integration testing
class AudioTestDataManager {
  /// Test files with their expected properties
  static const Map<String, Map<String, dynamic>> testFiles = {
    'mp3_sample': {
      'filename': 'Double-F the King - Your Blessing.mp3',
      'format': 1, // SONIX_FORMAT_MP3
      'expectedSampleRate': 44100,
      'expectedChannels': 2,
      'minDurationMs': 1000, // At least 1 second
      'description': 'Standard MP3 file for format detection and decoding tests',
    },
    'wav_sample': {
      'filename': 'Double-F the King - Your Blessing.wav',
      'format': 2, // SONIX_FORMAT_WAV
      'expectedSampleRate': 48000, // Actual sample rate from FFMPEG
      'expectedChannels': 2,
      'minDurationMs': 1000,
      'description': 'Standard WAV file for format detection and decoding tests',
    },
    'flac_sample': {
      'filename': 'Double-F the King - Your Blessing.flac',
      'format': 3, // SONIX_FORMAT_FLAC
      'expectedSampleRate': 48000, // Actual sample rate from FFMPEG
      'expectedChannels': 2,
      'minDurationMs': 1000,
      'description': 'Standard FLAC file for format detection and decoding tests',
    },
    'ogg_sample': {
      'filename': 'Double-F the King - Your Blessing.ogg',
      'format': 4, // SONIX_FORMAT_OGG
      'expectedSampleRate': 44100,
      'expectedChannels': 2,
      'minDurationMs': 1000,
      'description': 'Standard OGG file for format detection and decoding tests',
    },
    'mp4_sample': {
      'filename': 'Double-F the King - Your Blessing.mp4',
      'format': 6, // SONIX_FORMAT_MP4
      'expectedSampleRate': 44100,
      'expectedChannels': 2,
      'minDurationMs': 1000,
      'description': 'Standard MP4 file for format detection and decoding tests',
    },
    'opus_sample': {
      'filename': 'Double-F the King - Your Blessing.opus',
      'format': 4, // SONIX_FORMAT_OGG (Opus is contained in OGG container)
      'expectedSampleRate': 48000, // Opus typically uses 48kHz
      'expectedChannels': 2,
      'minDurationMs': 1000,
      'description': 'Standard Opus file for format detection and decoding tests',
    },
    // Small test files for quick tests
    'wav_small': {
      'filename': 'small_test.wav',
      'format': 2, // SONIX_FORMAT_WAV
      'expectedSampleRate': 44100,
      'expectedChannels': 1,
      'minDurationMs': 100,
      'description': 'Small WAV file for quick tests',
    },
    'wav_mono': {
      'filename': 'test_mono_44100.wav',
      'format': 2, // SONIX_FORMAT_WAV
      'expectedSampleRate': 44100,
      'expectedChannels': 1,
      'minDurationMs': 500,
      'description': 'Mono WAV file for channel testing',
    },
    'wav_stereo': {
      'filename': 'test_stereo_44100.wav',
      'format': 2, // SONIX_FORMAT_WAV
      'expectedSampleRate': 44100,
      'expectedChannels': 2,
      'minDurationMs': 500,
      'description': 'Stereo WAV file for channel testing',
    },
    // Large files for chunked processing tests
    'mp3_large': {
      'filename': 'test_large.mp3',
      'format': 0, // SONIX_FORMAT_UNKNOWN (file might be corrupted)
      'expectedSampleRate': 44100,
      'expectedChannels': 2,
      'minDurationMs': 10000, // At least 10 seconds
      'description': 'Large MP3 file for chunked processing tests',
    },
    'wav_large': {
      'filename': 'test_large.wav',
      'format': 2, // SONIX_FORMAT_WAV
      'expectedSampleRate': 44100,
      'expectedChannels': 2,
      'minDurationMs': 10000,
      'description': 'Large WAV file for chunked processing tests',
    },
    // Corrupted files for error handling tests
    'corrupted_wav': {
      'filename': 'corrupted_data.wav',
      'format': 2, // SONIX_FORMAT_WAV (FFMPEG might still detect container format)
      'expectedSampleRate': 0,
      'expectedChannels': 0,
      'minDurationMs': 0,
      'description': 'Corrupted WAV file for error handling tests',
    },
    'corrupted_mp3': {
      'filename': 'corrupted_header.mp3',
      'format': 0, // SONIX_FORMAT_UNKNOWN (should fail)
      'expectedSampleRate': 0,
      'expectedChannels': 0,
      'minDurationMs': 0,
      'description': 'Corrupted MP3 file for error handling tests',
    },
    'empty_file': {
      'filename': 'empty_file.mp3',
      'format': 0, // SONIX_FORMAT_UNKNOWN (should fail)
      'expectedSampleRate': 0,
      'expectedChannels': 0,
      'minDurationMs': 0,
      'description': 'Empty file for error handling tests',
    },
    'invalid_format': {
      'filename': 'invalid_format.xyz',
      'format': 0, // SONIX_FORMAT_UNKNOWN (should fail)
      'expectedSampleRate': 0,
      'expectedChannels': 0,
      'minDurationMs': 0,
      'description': 'Invalid format file for error handling tests',
    },
    'truncated_flac': {
      'filename': 'truncated.flac',
      'format': 3, // SONIX_FORMAT_FLAC (FFMPEG can detect format even if truncated)
      'expectedSampleRate': 0,
      'expectedChannels': 0,
      'minDurationMs': 0,
      'description': 'Truncated FLAC file for error handling tests',
    },
  };

  /// Base path for test assets
  static const String _assetBasePath = 'test/assets';

  /// Load test file data as bytes
  static Future<Uint8List> loadTestFile(String key) async {
    final fileInfo = testFiles[key];
    if (fileInfo == null) {
      throw ArgumentError('Unknown test file key: $key');
    }

    final filename = fileInfo['filename'] as String;
    final filePath = '$_assetBasePath/$filename';
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Test file not found: $filePath');
    }

    return await file.readAsBytes();
  }

  /// Get expected results for a test file
  static Map<String, dynamic> getExpectedResults(String key) {
    final fileInfo = testFiles[key];
    if (fileInfo == null) {
      throw ArgumentError('Unknown test file key: $key');
    }

    return Map<String, dynamic>.from(fileInfo);
  }

  /// Get file path for a test file
  static String getFilePath(String key) {
    final fileInfo = testFiles[key];
    if (fileInfo == null) {
      throw ArgumentError('Unknown test file key: $key');
    }

    final filename = fileInfo['filename'] as String;
    return '$_assetBasePath/$filename';
  }

  /// Check if a test file exists
  static Future<bool> testFileExists(String key) async {
    try {
      final fileInfo = testFiles[key];
      if (fileInfo == null) {
        return false;
      }

      final filename = fileInfo['filename'] as String;
      final filePath = '$_assetBasePath/$filename';
      final file = File(filePath);

      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get all available test files
  static Future<List<String>> getAvailableTestFiles() async {
    final available = <String>[];

    for (final key in testFiles.keys) {
      if (await testFileExists(key)) {
        available.add(key);
      }
    }

    return available;
  }

  /// Get test files by format
  static List<String> getTestFilesByFormat(int format) {
    return testFiles.entries.where((entry) => entry.value['format'] == format).map((entry) => entry.key).toList();
  }

  /// Get valid test files (non-corrupted)
  static List<String> getValidTestFiles() {
    return testFiles.entries
        .where((entry) => entry.value['format'] != 0) // Not UNKNOWN format
        .map((entry) => entry.key)
        .toList();
  }

  /// Get corrupted test files for error testing
  static List<String> getCorruptedTestFiles() {
    return testFiles.entries
        .where((entry) => entry.value['format'] == 0) // UNKNOWN format
        .map((entry) => entry.key)
        .toList();
  }

  /// Get large test files for chunked processing
  static List<String> getLargeTestFiles() {
    return testFiles.entries.where((entry) => entry.key.contains('large') && entry.value['format'] != 0).map((entry) => entry.key).toList();
  }

  /// Get small test files for quick tests
  static List<String> getSmallTestFiles() {
    return testFiles.entries
        .where((entry) => (entry.key.contains('small') || entry.key.contains('mono') || entry.key.contains('stereo')) && entry.value['format'] != 0)
        .map((entry) => entry.key)
        .toList();
  }

  /// Validate that expected test files exist
  static Future<List<String>> validateTestFiles() async {
    final missing = <String>[];

    for (final entry in testFiles.entries) {
      final key = entry.key;
      final filename = entry.value['filename'] as String;
      final filePath = '$_assetBasePath/$filename';
      final file = File(filePath);

      if (!await file.exists()) {
        missing.add('$key ($filename)');
      }
    }

    return missing;
  }

  /// Get file size for a test file
  static Future<int> getFileSize(String key) async {
    final fileInfo = testFiles[key];
    if (fileInfo == null) {
      throw ArgumentError('Unknown test file key: $key');
    }

    final filename = fileInfo['filename'] as String;
    final filePath = '$_assetBasePath/$filename';
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Test file not found: $filePath');
    }

    return await file.length();
  }

  /// Create a test report with file information
  static Future<Map<String, dynamic>> createTestReport() async {
    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'totalFiles': testFiles.length,
      'availableFiles': 0,
      'missingFiles': <String>[],
      'fileDetails': <String, dynamic>{},
    };

    for (final entry in testFiles.entries) {
      final key = entry.key;
      final fileInfo = entry.value;
      final filename = fileInfo['filename'] as String;
      final filePath = '$_assetBasePath/$filename';
      final file = File(filePath);

      final exists = await file.exists();
      if (exists) {
        report['availableFiles'] = (report['availableFiles'] as int) + 1;
        final size = await file.length();
        report['fileDetails'][key] = {'filename': filename, 'exists': true, 'size': size, 'format': fileInfo['format'], 'description': fileInfo['description']};
      } else {
        (report['missingFiles'] as List<String>).add('$key ($filename)');
        report['fileDetails'][key] = {'filename': filename, 'exists': false, 'size': 0, 'format': fileInfo['format'], 'description': fileInfo['description']};
      }
    }

    return report;
  }

  /// Print test file status
  static Future<void> printTestFileStatus() async {
    print('FFMPEG Test File Status:');
    print('========================');

    final available = await getAvailableTestFiles();
    final missing = await validateTestFiles();

    print('Available files: ${available.length}/${testFiles.length}');

    if (available.isNotEmpty) {
      print('\nAvailable test files:');
      for (final key in available) {
        final info = testFiles[key]!;
        print('  ✓ $key: ${info['filename']} (${info['description']})');
      }
    }

    if (missing.isNotEmpty) {
      print('\nMissing test files:');
      for (final file in missing) {
        print('  ✗ $file');
      }
      print('\nNote: Some tests may be skipped due to missing files.');
    }

    print('');
  }
}
