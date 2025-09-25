/// Simple test file verification script
///
/// Verifies that all expected test files exist and can be loaded
library;

import 'dart:io';
import 'audio_test_data_manager.dart';

Future<void> main() async {
  print('=== FFMPEG Test File Verification ===');

  // Print test file status
  await AudioTestDataManager.printTestFileStatus();

  // Create test report
  final report = await AudioTestDataManager.createTestReport();

  print('\n=== Test Report ===');
  print('Total files: ${report['totalFiles']}');
  print('Available files: ${report['availableFiles']}');
  print('Missing files: ${(report['missingFiles'] as List).length}');

  if ((report['missingFiles'] as List).isNotEmpty) {
    print('\nMissing files:');
    for (final file in report['missingFiles'] as List<String>) {
      print('  - $file');
    }
  }

  // Test loading a few files
  print('\n=== File Loading Test ===');
  final testKeys = ['mp3_sample', 'wav_sample', 'flac_sample'];

  for (final key in testKeys) {
    if (await AudioTestDataManager.testFileExists(key)) {
      try {
        final data = await AudioTestDataManager.loadTestFile(key);
        final expected = AudioTestDataManager.getExpectedResults(key);
        print('✅ $key: ${data.length} bytes, format ${expected['format']}');
      } catch (e) {
        print('❌ $key: Failed to load - $e');
      }
    } else {
      print('⚠️ $key: File not found');
    }
  }

  print('\n=== Verification Complete ===');
}
