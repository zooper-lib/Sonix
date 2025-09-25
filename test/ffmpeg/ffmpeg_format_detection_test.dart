/// FFMPEG format detection tests using real audio files
///
/// Tests the FFMPEG-based format detection with actual audio file headers
/// and validates that the detection works correctly with real data.
library;

import 'dart:ffi';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

import 'audio_test_data_manager.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('FFMPEG Format Detection Tests', () {
    setUpAll(() async {
      // Print test file status
      await AudioTestDataManager.printTestFileStatus();

      // Initialize FFMPEG
      final initResult = SonixNativeBindings.initFFMPEG();
      if (initResult != 0) {
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        throw StateError('Failed to initialize FFMPEG: $errorMsg');
      }
    });

    tearDownAll(() {
      // Cleanup FFMPEG
      SonixNativeBindings.cleanupFFMPEG();
    });

    group('Valid Format Detection', () {
      test('should detect MP3 format correctly', () async {
        const testKey = 'mp3_sample';

        // Skip test if file doesn't exist
        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping MP3 format detection test - file not found');
          return;
        }

        final mp3Data = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        // Allocate native memory for data
        final dataPtr = malloc<Uint8>(mp3Data.length);
        final dataList = dataPtr.asTypedList(mp3Data.length);
        dataList.setAll(0, mp3Data);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, mp3Data.length);

          expect(detectedFormat, equals(expected['format']), reason: 'MP3 format should be detected correctly');
          expect(detectedFormat, equals(SONIX_FORMAT_MP3), reason: 'Should return MP3 format constant');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should detect WAV format correctly', () async {
        const testKey = 'wav_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping WAV format detection test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, wavData.length);

          expect(detectedFormat, equals(expected['format']), reason: 'WAV format should be detected correctly');
          expect(detectedFormat, equals(SONIX_FORMAT_WAV), reason: 'Should return WAV format constant');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should detect FLAC format correctly', () async {
        const testKey = 'flac_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping FLAC format detection test - file not found');
          return;
        }

        final flacData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(flacData.length);
        final dataList = dataPtr.asTypedList(flacData.length);
        dataList.setAll(0, flacData);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, flacData.length);

          expect(detectedFormat, equals(expected['format']), reason: 'FLAC format should be detected correctly');
          expect(detectedFormat, equals(SONIX_FORMAT_FLAC), reason: 'Should return FLAC format constant');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should detect OGG format correctly', () async {
        const testKey = 'ogg_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping OGG format detection test - file not found');
          return;
        }

        final oggData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(oggData.length);
        final dataList = dataPtr.asTypedList(oggData.length);
        dataList.setAll(0, oggData);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, oggData.length);

          expect(detectedFormat, equals(expected['format']), reason: 'OGG format should be detected correctly');
          expect(detectedFormat, equals(SONIX_FORMAT_OGG), reason: 'Should return OGG format constant');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should detect MP4 format correctly', () async {
        const testKey = 'mp4_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping MP4 format detection test - file not found');
          return;
        }

        final mp4Data = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(mp4Data.length);
        final dataList = dataPtr.asTypedList(mp4Data.length);
        dataList.setAll(0, mp4Data);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, mp4Data.length);

          expect(detectedFormat, equals(expected['format']), reason: 'MP4 format should be detected correctly');
          expect(detectedFormat, equals(SONIX_FORMAT_MP4), reason: 'Should return MP4 format constant');
        } finally {
          malloc.free(dataPtr);
        }
      });
    });

    group('Invalid Format Detection', () {
      test('should handle corrupted WAV file gracefully', () async {
        const testKey = 'corrupted_wav';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping corrupted WAV test - file not found');
          return;
        }

        final corruptedData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(corruptedData.length);
        final dataList = dataPtr.asTypedList(corruptedData.length);
        dataList.setAll(0, corruptedData);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, corruptedData.length);

          // FFMPEG might still detect the container format even if data is corrupted
          expect(detectedFormat, equals(expected['format']), reason: 'Should handle corrupted file gracefully');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should return unknown format for corrupted MP3 file', () async {
        const testKey = 'corrupted_mp3';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping corrupted MP3 test - file not found');
          return;
        }

        final corruptedData = await AudioTestDataManager.loadTestFile(testKey);

        final dataPtr = malloc<Uint8>(corruptedData.length);
        final dataList = dataPtr.asTypedList(corruptedData.length);
        dataList.setAll(0, corruptedData);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, corruptedData.length);

          expect(detectedFormat, equals(SONIX_FORMAT_UNKNOWN), reason: 'Corrupted MP3 file should return unknown format');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle null data gracefully', () {
        final detectedFormat = SonixNativeBindings.detectFormat(nullptr, 0);

        expect(detectedFormat, equals(SONIX_FORMAT_UNKNOWN), reason: 'Null data should return unknown format');

        // Check error message
        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        expect(errorMsg, isNotEmpty, reason: 'Should set error message for null data');
      });

      test('should handle zero size gracefully', () async {
        // Create a small buffer but pass size 0
        final dataPtr = malloc<Uint8>(100);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, 0);

          expect(detectedFormat, equals(SONIX_FORMAT_UNKNOWN), reason: 'Zero size should return unknown format');

          // Check error message
          final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
          expect(errorMsg, isNotEmpty, reason: 'Should set error message for zero size');
        } finally {
          malloc.free(dataPtr);
        }
      });
    });

    group('Format Detection Edge Cases', () {
      test('should handle very small data buffers', () async {
        // Test with just a few bytes
        final smallData = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]); // MP3-like header

        final dataPtr = malloc<Uint8>(smallData.length);
        final dataList = dataPtr.asTypedList(smallData.length);
        dataList.setAll(0, smallData);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, smallData.length);

          // Should either detect format or return unknown, but not crash
          expect(detectedFormat, greaterThanOrEqualTo(0), reason: 'Should handle small buffers without crashing');
          expect(detectedFormat, lessThanOrEqualTo(SONIX_FORMAT_MP4), reason: 'Should return valid format constant');
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle truncated files', () async {
        const testKey = 'truncated_flac';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping truncated FLAC test - file not found');
          return;
        }

        final truncatedData = await AudioTestDataManager.loadTestFile(testKey);

        final dataPtr = malloc<Uint8>(truncatedData.length);
        final dataList = dataPtr.asTypedList(truncatedData.length);
        dataList.setAll(0, truncatedData);

        try {
          final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, truncatedData.length);

          // Truncated files should either be detected or return unknown
          expect(detectedFormat, greaterThanOrEqualTo(0), reason: 'Should handle truncated files gracefully');
          expect(detectedFormat, lessThanOrEqualTo(SONIX_FORMAT_MP4), reason: 'Should return valid format constant');
        } finally {
          malloc.free(dataPtr);
        }
      });
    });

    group('Format Detection Performance', () {
      test('should detect formats quickly for all valid files', () async {
        final validFiles = AudioTestDataManager.getValidTestFiles();
        final stopwatch = Stopwatch()..start();

        for (final testKey in validFiles) {
          if (!await AudioTestDataManager.testFileExists(testKey)) {
            continue;
          }

          final data = await AudioTestDataManager.loadTestFile(testKey);
          final expected = AudioTestDataManager.getExpectedResults(testKey);

          final dataPtr = malloc<Uint8>(data.length);
          final dataList = dataPtr.asTypedList(data.length);
          dataList.setAll(0, data);

          try {
            final detectedFormat = SonixNativeBindings.detectFormat(dataPtr, data.length);

            expect(detectedFormat, equals(expected['format']), reason: 'Format detection should be accurate for $testKey');
          } finally {
            malloc.free(dataPtr);
          }
        }

        stopwatch.stop();
        final avgTimePerFile = stopwatch.elapsedMilliseconds / validFiles.length;

        print(
          'Format detection performance: ${stopwatch.elapsedMilliseconds}ms total, '
          '${avgTimePerFile.toStringAsFixed(2)}ms average per file',
        );

        // Format detection should be fast (less than 100ms per file on average)
        expect(avgTimePerFile, lessThan(100), reason: 'Format detection should be fast');
      });
    });
  });
}
