/// Helper for creating temporary files in tests
library;

import 'dart:io';

/// Helper class for creating temporary files in tests
class TempFileHelper {
  static final Map<String, Directory> _tempDirs = {};

  /// Create a temporary file with the given name in a temporary directory
  /// Returns the File object for the temporary file
  static File createTempFile(String filename, {String? testName}) {
    final testKey = testName ?? 'default';

    // Create or reuse temp directory for this test
    _tempDirs[testKey] ??= Directory.systemTemp.createTempSync('sonix_test_${testKey}_');

    return File('${_tempDirs[testKey]!.path}/$filename');
  }

  /// Create a temporary directory for a test
  /// Returns the Directory object
  static Directory createTempDir({String? testName}) {
    final testKey = testName ?? 'default';
    return Directory.systemTemp.createTempSync('sonix_test_${testKey}_');
  }

  /// Clean up temporary files for a specific test
  static void cleanupTest(String testName) {
    final tempDir = _tempDirs[testName];
    if (tempDir != null && tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
        _tempDirs.remove(testName);
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  /// Clean up all temporary files
  static void cleanupAll() {
    for (final entry in _tempDirs.entries) {
      if (entry.value.existsSync()) {
        try {
          entry.value.deleteSync(recursive: true);
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    }
    _tempDirs.clear();
  }
}
