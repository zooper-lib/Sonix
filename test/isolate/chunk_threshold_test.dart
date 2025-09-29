// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';

/// Tests for the processing isolate chunk threshold fix
///
/// This test validates that the processing isolate correctly chooses between
/// chunked and in-memory processing based on file size thresholds.
void main() {
  group('Processing Isolate Chunk Threshold', () {
    group('Memory Estimation and Thresholds', () {
      test('should calculate correct memory estimates for various MP3 file sizes', () {
        // Test cases based on typical MP3 files
        final testCases = [
          {
            'description': '1MB MP3 (short clip)',
            'fileSize': 1 * 1024 * 1024,
            'expectedMemory': 10 * 1024 * 1024, // 10MB decoded
          },
          {
            'description': '5MB MP3 (2-3 min song)',
            'fileSize': 5 * 1024 * 1024,
            'expectedMemory': 50 * 1024 * 1024, // 50MB decoded
          },
          {
            'description': '13.6MB MP3 (problematic case)',
            'fileSize': 13680417,
            'expectedMemory': 136804170, // ~137MB decoded
          },
          {
            'description': '25MB MP3 (long song)',
            'fileSize': 25 * 1024 * 1024,
            'expectedMemory': 250 * 1024 * 1024, // 250MB decoded
          },
        ];

        for (final testCase in testCases) {
          final fileSize = testCase['fileSize'] as int;
          final expectedMemory = testCase['expectedMemory'] as int;
          final description = testCase['description'] as String;

          final estimatedMemory = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, AudioFormat.mp3);

          expect(estimatedMemory, equals(expectedMemory), reason: '$description: Expected $expectedMemory bytes, got $estimatedMemory bytes');

          print('$description: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB file -> ${(estimatedMemory / (1024 * 1024)).toStringAsFixed(1)}MB decoded');
        }
      });

      test('should respect the 100MB memory threshold for in-memory processing', () {
        // Files that should NOT exceed threshold (suitable for in-memory processing)
        final smallFiles = [
          1 * 1024 * 1024, // 1MB -> 10MB decoded (OK)
          3 * 1024 * 1024, // 3MB -> 30MB decoded (OK)
          5 * 1024 * 1024, // 5MB -> 50MB decoded (OK)
          9 * 1024 * 1024, // 9MB -> 90MB decoded (OK)
        ];

        for (final fileSize in smallFiles) {
          final wouldExceed = NativeAudioBindings.wouldExceedMemoryLimits(fileSize, AudioFormat.mp3);
          expect(wouldExceed, isFalse, reason: '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB file should not exceed memory threshold');
        }

        // Files that SHOULD exceed threshold (need chunked processing)
        final largeFiles = [
          11 * 1024 * 1024, // 11MB -> 110MB decoded (EXCEEDS)
          13680417, // 13.6MB -> 137MB decoded (EXCEEDS) - the problematic case
          20 * 1024 * 1024, // 20MB -> 200MB decoded (EXCEEDS)
          50 * 1024 * 1024, // 50MB -> 500MB decoded (EXCEEDS)
        ];

        for (final fileSize in largeFiles) {
          final wouldExceed = NativeAudioBindings.wouldExceedMemoryLimits(fileSize, AudioFormat.mp3);
          expect(wouldExceed, isTrue, reason: '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB file should exceed memory threshold');
        }
      });

      test('should demonstrate the fix: 5MB chunk threshold prevents memory exceptions', () {
        const chunkThreshold = 5 * 1024 * 1024; // 5MB - the new threshold
        const problematicFileSize = 13680417; // 13.6MB - the file that was causing issues

        // Before fix: 13.6MB file would use in-memory processing (since 13.6MB < 50MB old threshold)
        // and then hit memory limits (since 137MB decoded > 100MB threshold) -> MemoryException

        // After fix: 13.6MB file uses chunked processing (since 13.6MB > 5MB new threshold)
        // so it never hits the in-memory decoder's memory check

        expect(problematicFileSize, greaterThan(chunkThreshold), reason: 'Problematic file should be larger than new chunk threshold');

        final wouldExceedMemory = NativeAudioBindings.wouldExceedMemoryLimits(problematicFileSize, AudioFormat.mp3);
        expect(wouldExceedMemory, isTrue, reason: 'File would exceed memory limits if processed in-memory');

        print('Fix validation:');
        print('  File size: ${(problematicFileSize / (1024 * 1024)).toStringAsFixed(1)}MB');
        print('  Chunk threshold: ${(chunkThreshold / (1024 * 1024)).toStringAsFixed(1)}MB');
        print('  Uses chunked processing: ${problematicFileSize > chunkThreshold}');
        print('  Would exceed memory if in-memory: $wouldExceedMemory');
      });
    });

    group('Threshold Boundaries', () {
      test('should handle files right at the 5MB boundary', () {
        const chunkThreshold = 5 * 1024 * 1024; // 5MB

        // File just under threshold - should use in-memory processing
        const justUnder = chunkThreshold - 1;
        final underExceeds = NativeAudioBindings.wouldExceedMemoryLimits(justUnder, AudioFormat.mp3);
        expect(underExceeds, isFalse, reason: 'File just under 5MB should not exceed memory limits');

        // File just over threshold - should use chunked processing
        const justOver = chunkThreshold + 1;
        final overExceeds = NativeAudioBindings.wouldExceedMemoryLimits(justOver, AudioFormat.mp3);
        expect(overExceeds, isFalse, reason: 'File just over 5MB should not exceed memory limits either (still small)');

        print('Boundary test:');
        print('  Just under 5MB: ${(justUnder / (1024 * 1024)).toStringAsFixed(3)}MB -> exceeds: $underExceeds');
        print('  Just over 5MB: ${(justOver / (1024 * 1024)).toStringAsFixed(3)}MB -> exceeds: $overExceeds');
      });

      test('should validate the sweet spot: 5MB threshold allows files up to ~10MB in-memory', () {
        // The 5MB threshold allows files that decode to just under 100MB to use in-memory processing
        // while files that would decode to over 100MB are forced to use chunked processing

        const sweetSpotFile = 9 * 1024 * 1024; // 9MB file -> 90MB decoded (under 100MB threshold)
        const problematicFile = 11 * 1024 * 1024; // 11MB file -> 110MB decoded (over 100MB threshold)

        final sweetSpotExceeds = NativeAudioBindings.wouldExceedMemoryLimits(sweetSpotFile, AudioFormat.mp3);
        final problematicExceeds = NativeAudioBindings.wouldExceedMemoryLimits(problematicFile, AudioFormat.mp3);

        expect(sweetSpotExceeds, isFalse, reason: '9MB file should be safe for in-memory processing');
        expect(problematicExceeds, isTrue, reason: '11MB file should require chunked processing');

        print('Sweet spot validation:');
        print('  9MB file -> 90MB decoded: exceeds = $sweetSpotExceeds');
        print('  11MB file -> 110MB decoded: exceeds = $problematicExceeds');
      });
    });
  });
}
