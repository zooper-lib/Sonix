/// Integration tests for streaming waveform generation with progress updates
///
/// This test suite verifies the complete streaming functionality including
/// progress updates, error handling, and proper resource cleanup.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';
import '../test_helpers/test_sonix_instance.dart';

void main() {
  group('Streaming Waveform Integration Tests', () {
    late Sonix sonix;

    setUp(() {
      sonix = TestSonixInstance(const TestSonixConfig());
    });

    tearDown(() async {
      if (!sonix.isDisposed) {
        await sonix.dispose();
      }
    });

    group('Progress Updates', () {
      test('should emit progress updates during waveform generation', () async {
        final filePath = 'mock_test.wav';
        final progressUpdates = <WaveformProgress>[];

        await for (final progress in sonix.generateWaveformStream(filePath)) {
          progressUpdates.add(progress);

          if (progress.isComplete) {
            break;
          }
        }

        // Verify we received progress updates
        expect(progressUpdates, isNotEmpty);

        // Verify progress increases monotonically
        for (int i = 1; i < progressUpdates.length; i++) {
          expect(progressUpdates[i].progress, greaterThanOrEqualTo(progressUpdates[i - 1].progress), reason: 'Progress should increase monotonically');
        }

        // Verify final progress is complete
        final finalProgress = progressUpdates.last;
        expect(finalProgress.isComplete, isTrue);
        expect(finalProgress.progress, equals(1.0));
        expect(finalProgress.partialData, isNotNull);
        expect(finalProgress.error, isNull);
      });

      test('should provide meaningful status messages', () async {
        final filePath = 'mock_test.wav';
        final statusMessages = <String>[];

        await for (final progress in sonix.generateWaveformStream(filePath)) {
          if (progress.statusMessage != null) {
            statusMessages.add(progress.statusMessage!);
          }

          if (progress.isComplete) {
            break;
          }
        }

        // Verify we received meaningful status messages
        expect(statusMessages, isNotEmpty);

        // Check for expected processing phases
        final allMessages = statusMessages.join(' ').toLowerCase();
        expect(allMessages, contains('creating'));
        expect(allMessages, contains('decoding'));
        expect(allMessages, contains('generating'));
        expect(allMessages, contains('complete'));
      });

      test('should handle multiple sequential streams', () async {
        final filePath = 'mock_test.wav';

        // Process multiple streams sequentially
        for (int i = 0; i < 2; i++) {
          final result = await _collectStreamResult(sonix.generateWaveformStream(filePath));
          expect(result, isNotNull, reason: 'Stream $i should complete successfully');
          expect(result!.amplitudes, isNotEmpty, reason: 'Stream $i should have waveform data');
        }
      });
    });

    group('Error Handling', () {
      test('should handle unsupported file format in stream', () async {
        expect(() async {
          await for (final _ in sonix.generateWaveformStream('nonexistent.xyz')) {
            // Should not reach here
          }
        }, throwsA(isA<UnsupportedFormatException>()));
      });

      test('should handle stream cancellation gracefully', () async {
        final filePath = 'mock_test.wav';
        final progressUpdates = <WaveformProgress>[];

        final subscription = sonix.generateWaveformStream(filePath).listen((progress) {
          progressUpdates.add(progress);
        });

        // Cancel after a short delay
        await Future.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();

        // Wait a bit more to ensure the operation completes or is cancelled
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not crash and should have received some updates
        expect(progressUpdates, isNotEmpty);
      });
    });

    group('Resource Management', () {
      test('should clean up resources after streaming completion', () async {
        final filePath = 'mock_test.wav';
        final initialStats = sonix.getResourceStatistics();

        // Process multiple streams
        for (int i = 0; i < 3; i++) {
          await for (final progress in sonix.generateWaveformStream(filePath)) {
            if (progress.isComplete) {
              break;
            }
          }
        }

        // Allow some time for cleanup
        await Future.delayed(const Duration(milliseconds: 500));

        final finalStats = sonix.getResourceStatistics();

        // Should not have significantly more active tasks
        expect(finalStats.queuedTasks, lessThanOrEqualTo(initialStats.queuedTasks + 1), reason: 'Should clean up queued tasks after streaming');
      });
    });

    group('Performance', () {
      test('should complete streaming within reasonable time', () async {
        final filePath = 'mock_test.wav';
        final stopwatch = Stopwatch()..start();

        await for (final progress in sonix.generateWaveformStream(filePath)) {
          if (progress.isComplete) {
            break;
          }
        }

        stopwatch.stop();

        // Should complete within reasonable time (adjust based on test environment)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000), reason: 'Streaming should complete within 5 seconds');
      });

      test('should provide timely progress updates', () async {
        final filePath = 'mock_test.wav';
        final progressTimes = <DateTime>[];

        await for (final progress in sonix.generateWaveformStream(filePath)) {
          progressTimes.add(DateTime.now());

          if (progress.isComplete) {
            break;
          }
        }

        // Should receive multiple progress updates
        expect(progressTimes.length, greaterThan(1));

        // Progress updates should be reasonably spaced
        if (progressTimes.length > 1) {
          final totalTime = progressTimes.last.difference(progressTimes.first);
          final averageInterval = totalTime.inMilliseconds / (progressTimes.length - 1);

          // Average interval should be reasonable (not too fast, not too slow)
          expect(averageInterval, lessThan(2000), reason: 'Progress updates should be frequent enough');
        }
      });
    });
  });
}

/// Helper function to collect the final result from a stream
Future<WaveformData?> _collectStreamResult(Stream<WaveformProgress> stream) async {
  WaveformData? result;

  await for (final progress in stream) {
    if (progress.isComplete) {
      result = progress.partialData;
      break;
    }
  }

  return result;
}
