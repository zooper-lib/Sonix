/// Unit tests for WaveformProgress class
///
/// This test suite verifies the WaveformProgress class functionality
/// including creation, validation, and edge cases.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('WaveformProgress', () {
    group('Construction', () {
      test('should create progress with required fields only', () {
        const progress = WaveformProgress(progress: 0.5);

        expect(progress.progress, equals(0.5));
        expect(progress.statusMessage, isNull);
        expect(progress.partialData, isNull);
        expect(progress.isComplete, isFalse);
        expect(progress.error, isNull);
      });

      test('should create progress with all fields', () {
        final waveformData = WaveformData(
          amplitudes: [0.1, 0.2, 0.3],
          duration: const Duration(seconds: 1),
          sampleRate: 44100,
          metadata: WaveformMetadata(resolution: 3, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
        );

        final progress = WaveformProgress(progress: 0.75, statusMessage: 'Processing audio', partialData: waveformData, isComplete: false, error: null);

        expect(progress.progress, equals(0.75));
        expect(progress.statusMessage, equals('Processing audio'));
        expect(progress.partialData, equals(waveformData));
        expect(progress.isComplete, isFalse);
        expect(progress.error, isNull);
      });

      test('should create completed progress with data', () {
        final waveformData = WaveformData(
          amplitudes: [0.1, 0.2, 0.3, 0.4, 0.5],
          duration: const Duration(seconds: 2),
          sampleRate: 44100,
          metadata: WaveformMetadata(resolution: 5, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
        );

        final progress = WaveformProgress(progress: 1.0, statusMessage: 'Complete', partialData: waveformData, isComplete: true);

        expect(progress.progress, equals(1.0));
        expect(progress.statusMessage, equals('Complete'));
        expect(progress.partialData, equals(waveformData));
        expect(progress.isComplete, isTrue);
        expect(progress.error, isNull);
      });

      test('should create error progress', () {
        const progress = WaveformProgress(progress: 0.8, error: 'Processing failed', isComplete: true);

        expect(progress.progress, equals(0.8));
        expect(progress.statusMessage, isNull);
        expect(progress.partialData, isNull);
        expect(progress.isComplete, isTrue);
        expect(progress.error, equals('Processing failed'));
      });
    });

    group('Validation', () {
      test('should accept valid progress values', () {
        const validProgresses = [0.0, 0.25, 0.5, 0.75, 1.0];

        for (final progressValue in validProgresses) {
          final progress = WaveformProgress(progress: progressValue);
          expect(progress.progress, equals(progressValue));
        }
      });

      test('should handle edge case progress values', () {
        // Test boundary values
        const progress0 = WaveformProgress(progress: 0.0);
        expect(progress0.progress, equals(0.0));

        const progress1 = WaveformProgress(progress: 1.0);
        expect(progress1.progress, equals(1.0));

        // Test very small increments
        const progressSmall = WaveformProgress(progress: 0.001);
        expect(progressSmall.progress, equals(0.001));

        // Test high precision
        const progressPrecise = WaveformProgress(progress: 0.123456789);
        expect(progressPrecise.progress, equals(0.123456789));
      });
    });

    group('State Combinations', () {
      test('should represent initial state correctly', () {
        const progress = WaveformProgress(progress: 0.0, statusMessage: 'Starting');

        expect(progress.progress, equals(0.0));
        expect(progress.statusMessage, equals('Starting'));
        expect(progress.isComplete, isFalse);
        expect(progress.error, isNull);
        expect(progress.partialData, isNull);
      });

      test('should represent intermediate state correctly', () {
        const progress = WaveformProgress(progress: 0.45, statusMessage: 'Decoding audio');

        expect(progress.progress, equals(0.45));
        expect(progress.statusMessage, equals('Decoding audio'));
        expect(progress.isComplete, isFalse);
        expect(progress.error, isNull);
        expect(progress.partialData, isNull);
      });

      test('should represent successful completion correctly', () {
        final waveformData = WaveformData(
          amplitudes: [0.1, 0.2, 0.3],
          duration: const Duration(seconds: 1),
          sampleRate: 44100,
          metadata: WaveformMetadata(resolution: 3, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
        );

        final progress = WaveformProgress(progress: 1.0, statusMessage: 'Waveform generation complete', partialData: waveformData, isComplete: true);

        expect(progress.progress, equals(1.0));
        expect(progress.statusMessage, equals('Waveform generation complete'));
        expect(progress.partialData, isNotNull);
        expect(progress.isComplete, isTrue);
        expect(progress.error, isNull);
      });

      test('should represent error state correctly', () {
        const progress = WaveformProgress(progress: 0.6, statusMessage: 'Processing failed', error: 'File not found', isComplete: true);

        expect(progress.progress, equals(0.6));
        expect(progress.statusMessage, equals('Processing failed'));
        expect(progress.error, equals('File not found'));
        expect(progress.isComplete, isTrue);
        expect(progress.partialData, isNull);
      });

      test('should handle partial data during streaming', () {
        final partialWaveformData = WaveformData(
          amplitudes: [0.1, 0.2],
          duration: const Duration(milliseconds: 500),
          sampleRate: 44100,
          metadata: WaveformMetadata(resolution: 2, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
        );

        final progress = WaveformProgress(progress: 0.3, statusMessage: 'Streaming waveform data', partialData: partialWaveformData, isComplete: false);

        expect(progress.progress, equals(0.3));
        expect(progress.statusMessage, equals('Streaming waveform data'));
        expect(progress.partialData, equals(partialWaveformData));
        expect(progress.isComplete, isFalse);
        expect(progress.error, isNull);
      });
    });

    group('Immutability', () {
      test('should be immutable', () {
        final waveformData = WaveformData(
          amplitudes: [0.1, 0.2, 0.3],
          duration: const Duration(seconds: 1),
          sampleRate: 44100,
          metadata: WaveformMetadata(resolution: 3, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
        );

        final progress = WaveformProgress(progress: 0.8, statusMessage: 'Processing', partialData: waveformData, isComplete: false);

        // All fields should be final and unchangeable
        expect(progress.progress, equals(0.8));
        expect(progress.statusMessage, equals('Processing'));
        expect(progress.partialData, equals(waveformData));
        expect(progress.isComplete, isFalse);

        // Creating a new instance should not affect the original
        const newProgress = WaveformProgress(progress: 0.9, statusMessage: 'Almost done');

        expect(progress.progress, equals(0.8)); // Original unchanged
        expect(newProgress.progress, equals(0.9));
      });
    });
  });
}
