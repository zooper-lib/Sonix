import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/progressive_waveform_generator.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/processing/waveform_algorithms.dart';
import 'package:sonix/src/models/audio_data.dart';

void main() {
  group('ProgressiveWaveformGenerator', () {
    late ProgressiveWaveformGenerator generator;
    late WaveformConfig config;

    setUp(() {
      config = const WaveformConfig(resolution: 100, algorithm: DownsamplingAlgorithm.rms, normalize: true);
      generator = ProgressiveWaveformGenerator(config: config);
    });

    group('generateFromChunks', () {
      test('should generate waveform chunks from processed chunks', () async {
        // Create test processed chunks
        final processedChunks = _createTestProcessedChunks(3, 1000);

        final waveformChunks = <WaveformChunkEnhanced>[];
        await for (final chunk in generator.generateFromChunks(processedChunks)) {
          waveformChunks.add(chunk);
        }

        expect(waveformChunks, isNotEmpty);
        expect(waveformChunks.last.isLast, isTrue);

        // Verify chunk metadata
        for (final chunk in waveformChunks) {
          expect(chunk.amplitudes, isNotEmpty);
          expect(chunk.metadata, isNotNull);
          expect(chunk.stats, isNotNull);
          expect(chunk.startSample, greaterThanOrEqualTo(0));
        }
      });

      test('should handle empty processed chunks', () async {
        final emptyStream = Stream<ProcessedChunk>.empty();

        final waveformChunks = <WaveformChunkEnhanced>[];
        await for (final chunk in generator.generateFromChunks(emptyStream)) {
          waveformChunks.add(chunk);
        }

        expect(waveformChunks, isEmpty);
      });

      test('should handle chunks with errors when continueOnError is true', () async {
        final processedChunks = _createTestProcessedChunksWithErrors(5, 1000);

        final waveformChunks = <WaveformChunkEnhanced>[];
        await for (final chunk in generator.generateFromChunks(processedChunks)) {
          waveformChunks.add(chunk);
        }

        expect(waveformChunks, isNotEmpty);
        expect(generator.hasErrors, isTrue);
        expect(generator.errorCount, greaterThan(0));
      });

      test('should stop on errors when continueOnError is false', () async {
        final errorGenerator = ProgressiveWaveformGenerator(config: config, continueOnError: false);

        final processedChunks = _createTestProcessedChunksWithErrors(5, 1000);

        final waveformChunks = <WaveformChunkEnhanced>[];
        await for (final chunk in errorGenerator.generateFromChunks(processedChunks)) {
          waveformChunks.add(chunk);
        }

        // Should have fewer chunks due to early termination
        expect(waveformChunks.length, lessThan(3));
      });
    });

    group('generateCompleteWaveform', () {
      test('should generate complete waveform from processed chunks', () async {
        final processedChunks = _createTestProcessedChunks(5, 2000);

        final waveformData = await generator.generateCompleteWaveform(processedChunks);

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.duration, greaterThan(Duration.zero));
        expect(waveformData.sampleRate, greaterThan(0));
        expect(waveformData.metadata.resolution, equals(waveformData.amplitudes.length));
        expect(waveformData.metadata.normalized, equals(config.normalize));
      });

      test('should handle single chunk', () async {
        final processedChunks = _createTestProcessedChunks(1, 1000);

        final waveformData = await generator.generateCompleteWaveform(processedChunks);

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.metadata.type, equals(config.type));
      });

      test('should produce normalized waveform when configured', () async {
        final normalizedConfig = config.copyWith(normalize: true);
        final normalizedGenerator = ProgressiveWaveformGenerator(config: normalizedConfig);

        final processedChunks = _createTestProcessedChunks(3, 1000);

        final waveformData = await normalizedGenerator.generateCompleteWaveform(processedChunks);

        expect(waveformData.metadata.normalized, isTrue);

        // Check that amplitudes are normalized (max should be close to 1.0)
        if (waveformData.amplitudes.isNotEmpty) {
          final maxAmplitude = waveformData.amplitudes.reduce(math.max);
          expect(maxAmplitude, lessThanOrEqualTo(1.0));
          expect(maxAmplitude, greaterThan(0.5)); // Should be reasonably high
        }
      });
    });

    group('progress tracking', () {
      test('should report progress through callback', () async {
        final progressUpdates = <ProgressInfo>[];

        final progressGenerator = ProgressiveWaveformGenerator(config: config, onProgress: (info) => progressUpdates.add(info));

        final processedChunks = _createTestProcessedChunks(5, 1000);

        await for (final _ in progressGenerator.generateFromChunks(processedChunks)) {
          // Just consume the stream
        }

        expect(progressUpdates, isNotEmpty);

        // Verify progress increases
        for (int i = 1; i < progressUpdates.length; i++) {
          expect(progressUpdates[i].processedChunks, greaterThanOrEqualTo(progressUpdates[i - 1].processedChunks));
        }
      });

      test('should calculate processing speed', () async {
        final progressUpdates = <ProgressInfo>[];

        final progressGenerator = ProgressiveWaveformGenerator(config: config, onProgress: (info) => progressUpdates.add(info));

        final processedChunks = _createTestProcessedChunks(3, 1000);

        await for (final _ in progressGenerator.generateFromChunks(processedChunks)) {
          // Add small delay to allow speed calculation
          await Future.delayed(const Duration(milliseconds: 1));
        }

        // Should have some progress updates with speed information
        final updatesWithSpeed = progressUpdates.where((p) => p.processingSpeed != null);
        expect(updatesWithSpeed, isNotEmpty);
      });

      test('should provide current progress', () {
        final progress = generator.getCurrentProgress();

        expect(progress.processedChunks, equals(0));
        expect(progress.totalChunks, equals(0));
        expect(progress.hasErrors, isFalse);
        expect(progress.progressPercentage, equals(0.0));
      });
    });

    group('error handling', () {
      test('should collect errors during processing', () async {
        final processedChunks = _createTestProcessedChunksWithErrors(3, 1000);

        await for (final _ in generator.generateFromChunks(processedChunks)) {
          // Just consume the stream
        }

        expect(generator.hasErrors, isTrue);
        expect(generator.getErrors(), isNotEmpty);
      });

      test('should call error callback when provided', () async {
        final errors = <Object>[];

        final errorGenerator = ProgressiveWaveformGenerator(config: config, onError: (error, stackTrace) => errors.add(error));

        final processedChunks = _createTestProcessedChunksWithErrors(2, 1000);

        await for (final _ in errorGenerator.generateFromChunks(processedChunks)) {
          // Just consume the stream
        }

        expect(errors, isNotEmpty);
      });

      test('should respect maxErrors limit', () async {
        final errorGenerator = ProgressiveWaveformGenerator(config: config, maxErrors: 2, continueOnError: true);

        final processedChunks = _createTestProcessedChunksWithManyErrors(10, 1000);

        final waveformChunks = <WaveformChunkEnhanced>[];
        await for (final chunk in errorGenerator.generateFromChunks(processedChunks)) {
          waveformChunks.add(chunk);
        }

        expect(errorGenerator.errorCount, lessThanOrEqualTo(2));
      });
    });

    group('memory estimation', () {
      test('should estimate memory usage in chunk stats', () async {
        final processedChunks = _createTestProcessedChunks(2, 1000);

        final waveformChunks = <WaveformChunkEnhanced>[];
        await for (final chunk in generator.generateFromChunks(processedChunks)) {
          waveformChunks.add(chunk);
        }

        for (final chunk in waveformChunks) {
          expect(chunk.stats?.memoryUsage, greaterThan(0));
        }
      });
    });
  });

  group('ProgressInfo', () {
    test('should calculate progress percentage correctly', () {
      final progress = ProgressInfo(processedChunks: 3, totalChunks: 10);
      expect(progress.progressPercentage, equals(0.3));
    });

    test('should handle zero total chunks', () {
      final progress = ProgressInfo(processedChunks: 5, totalChunks: 0);
      expect(progress.progressPercentage, equals(0.0));
    });

    test('should clamp progress percentage', () {
      final progress = ProgressInfo(processedChunks: 15, totalChunks: 10);
      expect(progress.progressPercentage, equals(1.0));
    });

    test('should detect completion', () {
      final incomplete = ProgressInfo(processedChunks: 3, totalChunks: 10);
      final complete = ProgressInfo(processedChunks: 10, totalChunks: 10);

      expect(incomplete.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });
  });

  group('ChunkProcessingStats', () {
    test('should create stats with required fields', () {
      final stats = ChunkProcessingStats(processingTime: const Duration(milliseconds: 100), samplesProcessed: 1000, memoryUsage: 8192);

      expect(stats.processingTime, equals(const Duration(milliseconds: 100)));
      expect(stats.samplesProcessed, equals(1000));
      expect(stats.memoryUsage, equals(8192));
      expect(stats.warnings, isEmpty);
    });

    test('should include warnings when provided', () {
      final stats = ChunkProcessingStats(
        processingTime: const Duration(milliseconds: 100),
        samplesProcessed: 1000,
        memoryUsage: 8192,
        warnings: ['Test warning'],
      );

      expect(stats.warnings, equals(['Test warning']));
    });
  });
}

/// Helper function to create test processed chunks
Stream<ProcessedChunk> _createTestProcessedChunks(int chunkCount, int samplesPerChunk) async* {
  for (int i = 0; i < chunkCount; i++) {
    final samples = List.generate(samplesPerChunk, (index) {
      // Generate sine wave samples
      return math.sin(2 * math.pi * (i * samplesPerChunk + index) / 100) * 0.5;
    });

    final audioChunk = AudioChunk(samples: samples, startSample: i * samplesPerChunk, isLast: i == chunkCount - 1);

    yield ProcessedChunk(
      fileChunk: 'test_file_chunk_$i',
      audioChunks: [audioChunk],
      stats: ChunkProcessingStats(processingTime: const Duration(milliseconds: 10), samplesProcessed: samplesPerChunk, memoryUsage: samplesPerChunk * 8),
    );
  }
}

/// Helper function to create test processed chunks with some errors
Stream<ProcessedChunk> _createTestProcessedChunksWithErrors(int chunkCount, int samplesPerChunk) async* {
  for (int i = 0; i < chunkCount; i++) {
    if (i == 1) {
      // Create an error chunk
      yield ProcessedChunk(fileChunk: 'test_file_chunk_$i', audioChunks: [], error: Exception('Test error in chunk $i'));
    } else {
      final samples = List.generate(samplesPerChunk, (index) {
        return math.sin(2 * math.pi * (i * samplesPerChunk + index) / 100) * 0.5;
      });

      final audioChunk = AudioChunk(samples: samples, startSample: i * samplesPerChunk, isLast: i == chunkCount - 1);

      yield ProcessedChunk(fileChunk: 'test_file_chunk_$i', audioChunks: [audioChunk]);
    }
  }
}

/// Helper function to create test processed chunks with many errors
Stream<ProcessedChunk> _createTestProcessedChunksWithManyErrors(int chunkCount, int samplesPerChunk) async* {
  for (int i = 0; i < chunkCount; i++) {
    if (i % 2 == 1) {
      // Create error chunks for odd indices
      yield ProcessedChunk(fileChunk: 'test_file_chunk_$i', audioChunks: [], error: Exception('Test error in chunk $i'));
    } else {
      final samples = List.generate(samplesPerChunk, (index) {
        return math.sin(2 * math.pi * (i * samplesPerChunk + index) / 100) * 0.5;
      });

      final audioChunk = AudioChunk(samples: samples, startSample: i * samplesPerChunk, isLast: i == chunkCount - 1);

      yield ProcessedChunk(fileChunk: 'test_file_chunk_$i', audioChunks: [audioChunk]);
    }
  }
}
