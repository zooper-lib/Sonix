/// Debug audio decoding to see what FFMPEG errors are occurring
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'audio_test_data_manager.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

Future<void> main() async {
  print('=== Debug Audio Decoding ===');

  // Initialize FFMPEG
  final initResult = SonixNativeBindings.initFFMPEG();
  if (initResult != 0) {
    final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
    print('Failed to initialize FFMPEG: $errorMsg');
    return;
  }

  print('FFMPEG initialized successfully');

  // Test a few key files
  final testFiles = ['mp3_sample', 'wav_sample', 'flac_sample', 'mp4_sample'];

  for (final testKey in testFiles) {
    if (!await AudioTestDataManager.testFileExists(testKey)) {
      print('$testKey: File not found');
      continue;
    }

    try {
      final data = await AudioTestDataManager.loadTestFile(testKey);
      final expected = AudioTestDataManager.getExpectedResults(testKey);

      print('\n--- Testing $testKey (${expected['filename']}) ---');
      print('File size: ${data.length} bytes');
      print('Expected format: ${expected['format']}');

      final dataPtr = malloc<Uint8>(data.length);
      final dataList = dataPtr.asTypedList(data.length);
      dataList.setAll(0, data);

      try {
        // First test format detection
        final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, data.length);
        print('Detected format: $detectedFormat');

        // Then test decoding
        final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, data.length, expected['format'] as int);

        if (audioDataPtr != nullptr) {
          final audioData = audioDataPtr.ref;
          print('✅ Decode SUCCESS:');
          print('  Samples: ${audioData.sample_count}');
          print('  Sample rate: ${audioData.sample_rate}Hz');
          print('  Channels: ${audioData.channels}');
          print('  Duration: ${audioData.duration_ms}ms');

          SonixNativeBindings.freeAudioData(audioDataPtr);
        } else {
          final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
          print('❌ Decode FAILED: $errorMsg');
        }
      } finally {
        malloc.free(dataPtr);
      }
    } catch (e) {
      print('❌ $testKey: Exception - $e');
    }
  }

  // Cleanup
  SonixNativeBindings.cleanupFFMPEG();
  print('\n=== Debug Complete ===');
}
