import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/waveform_aggregator.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_algorithms.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_data.dart';

void main() {
  group('WaveformAggregator', () {
    late WaveformAggregator aggregator;
    late WaveformConfig config;

    setUp(() {
      config = const WaveformConfig(
        resolution: 100,
        algorithm: DownsamplingAlgorithm.rms,
        normalize: false, // Don't normalize during streaming
      );
      aggregator = WaveformAggregator(config);
    });

    group('processAudioChunk', () {
      test('should process audio chunks and return waveform chunks', () {
        // Set expected total samples for proper calculation
        aggregator.setExpectedTotalSamples(5000);

        final audioChunk = _createTestAudioChunk(1000, 0);
        final waveformChunk = aggregator.processAudioChunk(audioChunk);

        expect(aggregator.totalSamplesProcessed, equals(1000));
        expect(aggregator.chunksProcessed, equals(1));

        // May or may not return a chunk depending on samples per point
        if (waveformChunk != null) {
          expect(waveformChunk.amplitudes, isNotEmpty);
          expect(waveformChunk.startTime, equals(Duration.zero));
          expect(waveformChunk.isLast, isFalse);
        }
      });

      test('should accumulate samples across multiple chunks', () {
        aggregator.setExpectedTotalSamples(3000);

        // Process multiple small chunks
        final chunk1 = _createTestAudioChunk(500, 0);
        final chunk2 = _createTestAudioChunk(500, 500);
        final chunk3 = _createTestAudioChunk(500, 1000, isLast: true);

        final waveform1 = aggregator.processAudioChunk(chunk1);
        final waveform2 = aggregator.processAudioChunk(chunk2);
        final waveform3 = aggregator.processAudioChunk(chunk3);

        expect(aggregator.totalSamplesProcessed, equals(1500));
        expect(aggregator.chunksProcessed, equals(3));

        // At least the last chunk should produce a waveform
        expect(waveform3, isNotNull);
        expect(waveform3!.isLast, isTrue);
      });

      test('should handle empty audio chunks', () {
        final emptyChunk = AudioChunk(samples: const [], startSample: 0, isLast: false);

        final waveformChunk = aggregator.processAudioChunk(emptyChunk);

        expect(aggregator.totalSamplesProcessed, equals(0));
        expect(aggregator.chunksProcessed, equals(1));
        expect(waveformChunk, isNull);
      });

      test('should generate waveform chunk when isLast is true', () {
        // Process a chunk that wouldn't normally generate output
        final smallChunk = AudioChunk(samples: [0.1, 0.2, 0.3], startSample: 0, isLast: true);

        final waveformChunk = aggregator.processAudioChunk(smallChunk);

        expect(waveformChunk, isNotNull);
        expect(waveformChunk!.isLast, isTrue);
        expect(waveformChunk.amplitudes, isNotEmpty);
      });

      test('should calculate correct start times for chunks', () {
        aggregator.setExpectedTotalSamples(2000);

        final chunk1 = _createTestAudioChunk(1000, 0);
        final chunk2 = _createTestAudioChunk(1000, 1000, isLast: true);

        final waveform1 = aggregator.processAudioChunk(chunk1);
        final waveform2 = aggregator.processAudioChunk(chunk2);

        if (waveform1 != null) {
          expect(waveform1.startTime, equals(Duration.zero));
        }

        if (waveform2 != null) {
          expect(waveform2.startTime.inMicroseconds, greaterThan(0));
        }
      });
    });

    group('finalize', () {
      test('should return remaining samples as waveform chunk', () {
        // Add some samples but not enough to trigger automatic generation
        final smallChunk = AudioChunk(samples: [0.1, 0.2, 0.3, 0.4, 0.5], startSample: 0, isLast: false);

        final waveformChunk = aggregator.processAudioChunk(smallChunk);
        expect(waveformChunk, isNull, reason: 'Should not generate chunk immediately with few samples');

        final finalChunk = aggregator.finalize();

        expect(finalChunk, isNotNull);
        expect(finalChunk!.isLast, isTrue);
        expect(finalChunk.amplitudes, isNotEmpty);
      });

      test('should return null when no samples remain', () {
        final finalChunk = aggregator.finalize();
        expect(finalChunk, isNull);
      });
    });

    group('reset', () {
      test('should reset all internal state', () {
        // Process some data first
        aggregator.setExpectedTotalSamples(1000);
        final chunk = _createTestAudioChunk(500, 0);
        aggregator.processAudioChunk(chunk);

        expect(aggregator.totalSamplesProcessed, greaterThan(0));
        expect(aggregator.chunksProcessed, greaterThan(0));

        // Reset and verify
        aggregator.reset();

        expect(aggregator.totalSamplesProcessed, equals(0));
        expect(aggregator.chunksProcessed, equals(0));
        expect(aggregator.waveformChunksGenerated, equals(0));
        expect(aggregator.totalDurationProcessed, equals(Duration.zero));
      });
    });

    group('getStats', () {
      test('should return accurate statistics', () {
        aggregator.setExpectedTotalSamples(2000);

        final chunk1 = _createTestAudioChunk(1000, 0);
        final chunk2 = _createTestAudioChunk(1000, 1000, isLast: true);

        aggregator.processAudioChunk(chunk1);
        aggregator.processAudioChunk(chunk2);

        final stats = aggregator.getStats();

        expect(stats.chunksProcessed, equals(2));
        expect(stats.totalSamplesProcessed, equals(2000));
        expect(stats.totalDurationProcessed.inMicroseconds, greaterThan(0));
        expect(stats.processingEfficiency, greaterThanOrEqualTo(0.0));
      });

      test('should calculate processing efficiency correctly', () {
        aggregator.setExpectedTotalSamples(1000);

        // Process chunk that should generate waveform output
        final chunk = _createTestAudioChunk(1000, 0, isLast: true);
        aggregator.processAudioChunk(chunk);

        final stats = aggregator.getStats();

        expect(stats.processingEfficiency, greaterThan(0.0));
        expect(stats.averageSamplesPerWaveformChunk, greaterThan(0.0));
      });
    });

    group('setExpectedTotalSamples', () {
      test('should set samples per point correctly', () {
        aggregator.setExpectedTotalSamples(10000);

        final stats = aggregator.getStats();
        expect(stats.samplesPerPoint, equals(100)); // 10000 / 100 resolution
      });

      test('should handle small total samples', () {
        aggregator.setExpectedTotalSamples(50);

        final stats = aggregator.getStats();
        expect(stats.samplesPerPoint, equals(1)); // Minimum 1 sample per point
      });
    });
  });

  group('WaveformAggregator.combineChunks', () {
    test('should combine multiple waveform chunks into complete waveform', () {
      final config = const WaveformConfig(resolution: 100, normalize: false);

      final chunks = [
        WaveformChunk(amplitudes: [0.1, 0.2, 0.3], startTime: Duration.zero, isLast: false),
        WaveformChunk(amplitudes: [0.4, 0.5, 0.6], startTime: const Duration(milliseconds: 100), isLast: false),
        WaveformChunk(amplitudes: [0.7, 0.8, 0.9], startTime: const Duration(milliseconds: 200), isLast: true),
      ];

      final waveformData = WaveformAggregator.combineChunks(chunks, config, totalDuration: const Duration(milliseconds: 300), sampleRate: 44100);

      expect(waveformData.amplitudes.length, equals(9));
      expect(waveformData.amplitudes, equals([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]));
      expect(waveformData.duration, equals(const Duration(milliseconds: 300)));
      expect(waveformData.sampleRate, equals(44100));
      expect(waveformData.metadata.normalized, isFalse);
    });

    test('should handle empty chunk list', () {
      final config = const WaveformConfig();

      final waveformData = WaveformAggregator.combineChunks([], config, totalDuration: Duration.zero, sampleRate: 44100);

      expect(waveformData.amplitudes, isEmpty);
      expect(waveformData.duration, equals(Duration.zero));
      expect(waveformData.metadata.resolution, equals(0));
    });

    test('should apply normalization when requested', () {
      final config = const WaveformConfig(normalize: true);

      final chunks = [
        WaveformChunk(amplitudes: [0.5, 1.0, 0.8], startTime: Duration.zero, isLast: true),
      ];

      final waveformData = WaveformAggregator.combineChunks(chunks, config, sampleRate: 44100);

      expect(waveformData.metadata.normalized, isTrue);

      // Check that max amplitude is 1.0 after normalization
      final maxAmplitude = waveformData.amplitudes.reduce(math.max);
      expect(maxAmplitude, closeTo(1.0, 0.001));
    });
  });

  group('WaveformAggregator.validateChunkSequence', () {
    test('should validate correct chunk sequence', () {
      final chunks = [
        WaveformChunk(amplitudes: [0.1, 0.2], startTime: Duration.zero, isLast: false),
        WaveformChunk(amplitudes: [0.3, 0.4], startTime: const Duration(milliseconds: 50), isLast: false),
        WaveformChunk(amplitudes: [0.5, 0.6], startTime: const Duration(milliseconds: 100), isLast: true),
      ];

      final validation = WaveformAggregator.validateChunkSequence(chunks);

      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
    });

    test('should detect empty sequence', () {
      final validation = WaveformAggregator.validateChunkSequence([]);

      expect(validation.isValid, isTrue);
      expect(validation.warnings, contains('Empty chunk sequence'));
    });

    test('should detect missing final marker', () {
      final chunks = [
        WaveformChunk(amplitudes: [0.1, 0.2], startTime: Duration.zero, isLast: false),
        WaveformChunk(
          amplitudes: [0.3, 0.4],
          startTime: const Duration(milliseconds: 50),
          isLast: false, // Should be true for last chunk
        ),
      ];

      final validation = WaveformAggregator.validateChunkSequence(chunks);

      expect(validation.warnings, contains('Last chunk is not marked as final'));
    });

    test('should detect large gaps between chunks', () {
      final chunks = [
        WaveformChunk(amplitudes: [0.1, 0.2], startTime: Duration.zero, isLast: false),
        WaveformChunk(
          amplitudes: [0.3, 0.4],
          startTime: const Duration(seconds: 1), // Large gap
          isLast: true,
        ),
      ];

      final validation = WaveformAggregator.validateChunkSequence(chunks);

      expect(validation.warnings.any((w) => w.contains('Large gap detected')), isTrue);
    });

    test('should detect overlapping chunks', () {
      final chunks = [
        WaveformChunk(amplitudes: [0.1, 0.2], startTime: const Duration(milliseconds: 100), isLast: false),
        WaveformChunk(
          amplitudes: [0.3, 0.4],
          startTime: const Duration(milliseconds: 50), // Earlier than previous
          isLast: true,
        ),
      ];

      final validation = WaveformAggregator.validateChunkSequence(chunks);

      expect(validation.warnings.any((w) => w.contains('starts before previous chunk ends')), isTrue);
    });
  });

  group('WaveformAggregatorStats', () {
    test('should calculate processing efficiency', () {
      final stats = WaveformAggregatorStats(
        chunksProcessed: 10,
        waveformChunksGenerated: 5,
        totalSamplesProcessed: 1000,
        totalDurationProcessed: const Duration(seconds: 1),
        accumulatedSamples: 100,
        currentPointIndex: 50,
        samplesPerPoint: 20,
      );

      expect(stats.processingEfficiency, equals(0.5)); // 5/10
      expect(stats.averageSamplesPerWaveformChunk, equals(200.0)); // 1000/5
    });

    test('should handle zero values gracefully', () {
      final stats = WaveformAggregatorStats(
        chunksProcessed: 0,
        waveformChunksGenerated: 0,
        totalSamplesProcessed: 0,
        totalDurationProcessed: Duration.zero,
        accumulatedSamples: 0,
        currentPointIndex: 0,
      );

      expect(stats.processingEfficiency, equals(0.0));
      expect(stats.averageSamplesPerWaveformChunk, equals(0.0));
    });
  });

  group('ChunkSequenceValidation', () {
    test('should detect issues correctly', () {
      final validValidation = ChunkSequenceValidation(isValid: true, warnings: [], errors: []);

      final invalidValidation = ChunkSequenceValidation(isValid: false, warnings: ['Warning'], errors: ['Error']);

      expect(validValidation.hasIssues, isFalse);
      expect(invalidValidation.hasIssues, isTrue);
    });
  });
}

/// Helper function to create test audio chunks
AudioChunk _createTestAudioChunk(int sampleCount, int startSample, {bool isLast = false}) {
  final samples = List.generate(sampleCount, (index) {
    // Generate sine wave samples with varying amplitude
    return math.sin(2 * math.pi * (startSample + index) / 100) * 0.5;
  });

  return AudioChunk(samples: samples, startSample: startSample, isLast: isLast);
}
