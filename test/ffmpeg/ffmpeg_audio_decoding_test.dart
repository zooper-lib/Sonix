/// FFMPEG audio decoding tests using real audio files
///
/// Tests the FFMPEG-based audio decoding with actual audio files
/// and validates sample extraction accuracy and audio properties.
library;

import 'dart:ffi';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

import 'audio_test_data_manager.dart';
import 'package:sonix/src/native/sonix_bindings.dart';

void main() {
  group('FFMPEG Audio Decoding Tests', () {
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

    group('Valid Audio Decoding', () {
      test('should decode MP3 audio correctly', () async {
        const testKey = 'mp3_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping MP3 decoding test - file not found');
          return;
        }

        final mp3Data = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(mp3Data.length);
        final dataList = dataPtr.asTypedList(mp3Data.length);
        dataList.setAll(0, mp3Data);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, mp3Data.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode MP3 audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            // Verify basic audio properties
            expect(audioData.samples, isNot(equals(nullptr)), reason: 'Should have valid sample data');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples');
            expect(audioData.sample_rate, equals(expected['expectedSampleRate']), reason: 'Should have correct sample rate');
            expect(audioData.channels, equals(expected['expectedChannels']), reason: 'Should have correct channel count');
            expect(audioData.duration_ms, greaterThanOrEqualTo(expected['minDurationMs']), reason: 'Should have minimum expected duration');

            // Verify sample data is reasonable
            final sampleCount = audioData.sample_count;
            final samples = audioData.samples.asTypedList(sampleCount);

            // Check that samples are in reasonable range [-1.0, 1.0]
            var validSamples = 0;
            var totalAbsValue = 0.0;

            for (int i = 0; i < sampleCount; i++) {
              final sample = samples[i];
              if (sample >= -1.0 && sample <= 1.0) {
                validSamples++;
                totalAbsValue += sample.abs();
              }
            }

            expect(validSamples, greaterThan(sampleCount * 0.95), reason: 'At least 95% of samples should be in valid range');

            final avgAbsValue = totalAbsValue / validSamples;
            expect(avgAbsValue, greaterThan(0.001), reason: 'Audio should have some signal (not just silence)');

            print(
              'MP3 decode results: ${audioData.sample_count} samples, '
              '${audioData.sample_rate}Hz, ${audioData.channels}ch, '
              '${audioData.duration_ms}ms, avg abs value: ${avgAbsValue.toStringAsFixed(4)}',
            );

            // Cleanup
            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should decode WAV audio correctly', () async {
        const testKey = 'wav_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping WAV decoding test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode WAV audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            expect(audioData.samples, isNot(equals(nullptr)), reason: 'Should have valid sample data');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples');
            expect(audioData.sample_rate, equals(expected['expectedSampleRate']), reason: 'Should have correct sample rate');
            expect(audioData.channels, equals(expected['expectedChannels']), reason: 'Should have correct channel count');
            expect(audioData.duration_ms, greaterThanOrEqualTo(expected['minDurationMs']), reason: 'Should have minimum expected duration');

            print(
              'WAV decode results: ${audioData.sample_count} samples, '
              '${audioData.sample_rate}Hz, ${audioData.channels}ch, '
              '${audioData.duration_ms}ms',
            );

            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should decode FLAC audio correctly', () async {
        const testKey = 'flac_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping FLAC decoding test - file not found');
          return;
        }

        final flacData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(flacData.length);
        final dataList = dataPtr.asTypedList(flacData.length);
        dataList.setAll(0, flacData);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, flacData.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode FLAC audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            expect(audioData.samples, isNot(equals(nullptr)), reason: 'Should have valid sample data');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples');
            expect(audioData.sample_rate, equals(expected['expectedSampleRate']), reason: 'Should have correct sample rate');
            expect(audioData.channels, equals(expected['expectedChannels']), reason: 'Should have correct channel count');
            expect(audioData.duration_ms, greaterThanOrEqualTo(expected['minDurationMs']), reason: 'Should have minimum expected duration');

            print(
              'FLAC decode results: ${audioData.sample_count} samples, '
              '${audioData.sample_rate}Hz, ${audioData.channels}ch, '
              '${audioData.duration_ms}ms',
            );

            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should decode OGG audio correctly', () async {
        const testKey = 'ogg_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping OGG decoding test - file not found');
          return;
        }

        final oggData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(oggData.length);
        final dataList = dataPtr.asTypedList(oggData.length);
        dataList.setAll(0, oggData);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, oggData.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode OGG audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            expect(audioData.samples, isNot(equals(nullptr)), reason: 'Should have valid sample data');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples');
            expect(audioData.sample_rate, equals(expected['expectedSampleRate']), reason: 'Should have correct sample rate');
            expect(audioData.channels, equals(expected['expectedChannels']), reason: 'Should have correct channel count');
            expect(audioData.duration_ms, greaterThanOrEqualTo(expected['minDurationMs']), reason: 'Should have minimum expected duration');

            print(
              'OGG decode results: ${audioData.sample_count} samples, '
              '${audioData.sample_rate}Hz, ${audioData.channels}ch, '
              '${audioData.duration_ms}ms',
            );

            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should decode MP4 audio correctly', () async {
        const testKey = 'mp4_sample';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping MP4 decoding test - file not found');
          return;
        }

        final mp4Data = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(mp4Data.length);
        final dataList = dataPtr.asTypedList(mp4Data.length);
        dataList.setAll(0, mp4Data);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, mp4Data.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode MP4 audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            expect(audioData.samples, isNot(equals(nullptr)), reason: 'Should have valid sample data');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples');
            expect(audioData.sample_rate, equals(expected['expectedSampleRate']), reason: 'Should have correct sample rate');
            expect(audioData.channels, equals(expected['expectedChannels']), reason: 'Should have correct channel count');
            expect(audioData.duration_ms, greaterThanOrEqualTo(expected['minDurationMs']), reason: 'Should have minimum expected duration');

            print(
              'MP4 decode results: ${audioData.sample_count} samples, '
              '${audioData.sample_rate}Hz, ${audioData.channels}ch, '
              '${audioData.duration_ms}ms',
            );

            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });
    });

    group('Channel Configuration Tests', () {
      test('should decode mono audio correctly', () async {
        const testKey = 'wav_mono';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping mono audio test - file not found');
          return;
        }

        final monoData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(monoData.length);
        final dataList = dataPtr.asTypedList(monoData.length);
        dataList.setAll(0, monoData);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, monoData.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode mono audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            expect(audioData.channels, equals(1), reason: 'Should have 1 channel for mono audio');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples');

            print(
              'Mono decode results: ${audioData.sample_count} samples, '
              '${audioData.sample_rate}Hz, ${audioData.channels}ch',
            );

            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should decode stereo audio correctly', () async {
        const testKey = 'wav_stereo';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping stereo audio test - file not found');
          return;
        }

        final stereoData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(stereoData.length);
        final dataList = dataPtr.asTypedList(stereoData.length);
        dataList.setAll(0, stereoData);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, stereoData.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode stereo audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            expect(audioData.channels, equals(2), reason: 'Should have 2 channels for stereo audio');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples');

            // For stereo, sample_count should be divisible by 2
            expect(audioData.sample_count % 2, equals(0), reason: 'Stereo sample count should be even');

            print(
              'Stereo decode results: ${audioData.sample_count} samples, '
              '${audioData.sample_rate}Hz, ${audioData.channels}ch',
            );

            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });
    });

    group('Error Handling Tests', () {
      test('should handle corrupted audio data gracefully', () async {
        const testKey = 'corrupted_wav';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping corrupted WAV decoding test - file not found');
          return;
        }

        final corruptedData = await AudioTestDataManager.loadTestFile(testKey);

        final dataPtr = malloc<Uint8>(corruptedData.length);
        final dataList = dataPtr.asTypedList(corruptedData.length);
        dataList.setAll(0, corruptedData);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, corruptedData.length, SONIX_FORMAT_WAV);

          // FFMPEG is robust and might successfully decode even corrupted data
          if (audioDataPtr == nullptr) {
            final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
            expect(errorMsg, isNotEmpty, reason: 'Should set error message for corrupted data');
            print('Corrupted WAV error: $errorMsg');
          } else {
            // FFMPEG successfully handled corrupted data
            final audioData = audioDataPtr.ref;
            print('FFMPEG successfully decoded corrupted data: ${audioData.sample_count} samples');
            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle null data gracefully', () {
        final audioDataPtr = SonixNativeBindings.decodeAudio(nullptr, 0, SONIX_FORMAT_MP3);

        expect(audioDataPtr, equals(nullptr), reason: 'Should return null for null data');

        final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
        expect(errorMsg, isNotEmpty, reason: 'Should set error message for null data');
      });

      test('should handle invalid format gracefully', () async {
        const testKey = 'wav_small';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping invalid format test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          // Try to decode WAV data as MP3 format
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, SONIX_FORMAT_MP3);

          // This might succeed or fail depending on FFMPEG's robustness
          if (audioDataPtr == nullptr) {
            final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
            expect(errorMsg, isNotEmpty, reason: 'Should set error message for format mismatch');
            print('Format mismatch error: $errorMsg');
          } else {
            // If it succeeds, cleanup
            SonixNativeBindings.freeAudioData(audioDataPtr);
            print('FFMPEG was able to decode despite format mismatch');
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle unsupported format gracefully', () async {
        const testKey = 'wav_small';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping unsupported format test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          // Try with invalid format code
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, 999); // Invalid format

          // FFMPEG might handle format mismatches gracefully
          if (audioDataPtr == nullptr) {
            final errorMsg = SonixNativeBindings.getErrorMessage().cast<Utf8>().toDartString();
            expect(errorMsg, isNotEmpty, reason: 'Should set error message for unsupported format');
            print('Unsupported format error: $errorMsg');
          } else {
            // FFMPEG successfully handled format mismatch
            final audioData = audioDataPtr.ref;
            print('FFMPEG successfully decoded despite format mismatch: ${audioData.sample_count} samples');
            SonixNativeBindings.freeAudioData(audioDataPtr);
          }
        } finally {
          malloc.free(dataPtr);
        }
      });
    });

    group('Memory Management Tests', () {
      test('should properly cleanup audio data', () async {
        const testKey = 'wav_small';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping memory cleanup test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, expected['format'] as int);

          expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode audio');

          if (audioDataPtr != nullptr) {
            final audioData = audioDataPtr.ref;

            // Verify data is valid before cleanup
            expect(audioData.samples, isNot(equals(nullptr)), reason: 'Should have valid samples before cleanup');
            expect(audioData.sample_count, greaterThan(0), reason: 'Should have sample count before cleanup');

            // Cleanup
            SonixNativeBindings.freeAudioData(audioDataPtr);

            // After cleanup, we can't safely access the data anymore
            // but the function should not crash
            print('Audio data cleaned up successfully');
          }
        } finally {
          malloc.free(dataPtr);
        }
      });

      test('should handle multiple decode/cleanup cycles', () async {
        const testKey = 'wav_small';

        if (!await AudioTestDataManager.testFileExists(testKey)) {
          print('Skipping multiple cycles test - file not found');
          return;
        }

        final wavData = await AudioTestDataManager.loadTestFile(testKey);
        final expected = AudioTestDataManager.getExpectedResults(testKey);

        final dataPtr = malloc<Uint8>(wavData.length);
        final dataList = dataPtr.asTypedList(wavData.length);
        dataList.setAll(0, wavData);

        try {
          // Perform multiple decode/cleanup cycles
          for (int i = 0; i < 5; i++) {
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, wavData.length, expected['format'] as int);

            expect(audioDataPtr, isNot(equals(nullptr)), reason: 'Should successfully decode audio in cycle $i');

            if (audioDataPtr != nullptr) {
              final audioData = audioDataPtr.ref;
              expect(audioData.sample_count, greaterThan(0), reason: 'Should have samples in cycle $i');

              SonixNativeBindings.freeAudioData(audioDataPtr);
            }
          }

          print('Multiple decode/cleanup cycles completed successfully');
        } finally {
          malloc.free(dataPtr);
        }
      });
    });

    group('Performance Tests', () {
      test('should decode small files quickly', () async {
        final smallFiles = AudioTestDataManager.getSmallTestFiles();
        final stopwatch = Stopwatch()..start();

        for (final testKey in smallFiles) {
          if (!await AudioTestDataManager.testFileExists(testKey)) {
            continue;
          }

          final data = await AudioTestDataManager.loadTestFile(testKey);
          final expected = AudioTestDataManager.getExpectedResults(testKey);

          final dataPtr = malloc<Uint8>(data.length);
          final dataList = dataPtr.asTypedList(data.length);
          dataList.setAll(0, data);

          try {
            final audioDataPtr = SonixNativeBindings.decodeAudio(dataPtr, data.length, expected['format'] as int);

            if (audioDataPtr != nullptr) {
              SonixNativeBindings.freeAudioData(audioDataPtr);
            }
          } finally {
            malloc.free(dataPtr);
          }
        }

        stopwatch.stop();
        final avgTimePerFile = stopwatch.elapsedMilliseconds / smallFiles.length;

        print(
          'Small file decoding performance: ${stopwatch.elapsedMilliseconds}ms total, '
          '${avgTimePerFile.toStringAsFixed(2)}ms average per file',
        );

        // Small files should decode quickly (less than 500ms per file on average)
        expect(avgTimePerFile, lessThan(500), reason: 'Small file decoding should be fast');
      });
    });
  });
}
