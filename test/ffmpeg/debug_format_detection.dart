/// Debug format detection to see what FFMPEG actually detects
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'audio_test_data_manager.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

Future<void> main() async {
  print('=== Debug Format Detection ===');

  // Initialize FFMPEG
  final initResult = SonixNativeBindings.initFFMPEG();
  if (initResult != 0) {
    final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
    print('Failed to initialize FFMPEG: $errorMsg');
    return;
  }

  print('FFMPEG initialized successfully');

  // Test all files
  final allFiles = AudioTestDataManager.testFiles.keys.toList();

  for (final testKey in allFiles) {
    if (!await AudioTestDataManager.testFileExists(testKey)) {
      print('$testKey: File not found');
      continue;
    }

    try {
      final data = await AudioTestDataManager.loadTestFile(testKey);
      final expected = AudioTestDataManager.getExpectedResults(testKey);

      final dataPtr = malloc<Uint8>(data.length);
      final dataList = dataPtr.asTypedList(data.length);
      dataList.setAll(0, data);

      try {
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, data.length);
        final expectedFormat = expected['format'];

        final status = detectedFormat == expectedFormat ? '✅' : '❌';
        print('$status $testKey: detected=$detectedFormat, expected=$expectedFormat (${expected['filename']})');

        if (detectedFormat != expectedFormat) {
          print('   Mismatch: ${expected['filename']}');
        }
      } finally {
        malloc.free(dataPtr);
      }
    } catch (e) {
      print('❌ $testKey: Error loading - $e');
    }
  }

  // Cleanup
  SonixNativeBindings.cleanupFFMPEG();
  print('\n=== Debug Complete ===');
}
