/// Progressive waveform generation for streaming audio processing
library;

import 'dart:async';

import '../models/audio_data.dart';
import '../models/waveform_data.dart';
import 'waveform_generator.dart';
import 'waveform_algorithms.dart';
import 'waveform_aggregator.dart';

/// Progress information for waveform generation
class ProgressInfo {
  /// Number of chunks processed so far
  final int processedChunks;

  /// Total number of chunks to process (may be estimated)
  final int totalChunks;

  /// Whether any errors have occurred during processing
  final bool hasErrors;

  /// The last error that occurred, if any
  final Object? lastError;

  /// Estimated time remaining for completion
  final Duration? estimatedTimeRemaining;

  /// Current processing speed (chunks per second)
  final double? processingSpeed;

  const ProgressInfo({
    required this.processedChunks,
    required this.totalChunks,
    this.hasErrors = false,
    this.lastError,
    this.estimatedTimeRemaining,
    this.processingSpeed,
  });

  /// Progress as a percentage (0.0 to 1.0)
  double get progressPercentage => totalChunks > 0 ? (processedChunks / totalChunks).clamp(0.0, 1.0) : 0.0;

  /// Whether processing is complete
  bool get isComplete => processedChunks >= totalChunks && totalChunks > 0;

  @override
  String toString() {
    return 'ProgressInfo(processed: $processedChunks/$totalChunks, '
        'progress: ${(progressPercentage * 100).toStringAsFixed(1)}%, '
        'hasErrors: $hasErrors, speed: $processingSpeed chunks/sec)';
  }
}

/// Callback function for progress updates
typedef ProgressCallback = void Function(ProgressInfo info);

/// Enhanced waveform chunk with additional metadata
class WaveformChunkEnhanced extends WaveformChunk {
  /// Starting sample index in the overall audio stream
  final int startSample;

  /// Metadata about this chunk
  final WaveformMetadata? metadata;

  /// Processing statistics for this chunk
  final ChunkProcessingStats? stats;

  const WaveformChunkEnhanced({
    required super.amplitudes,
    required super.startTime,
    required super.isLast,
    required this.startSample,
    this.metadata,
    this.stats,
  });

  @override
  String toString() {
    return 'WaveformChunkEnhanced(amplitudes: ${amplitudes.length}, '
        'startTime: $startTime, startSample: $startSample, isLast: $isLast)';
  }
}

/// Statistics about chunk processing
class ChunkProcessingStats {
  /// Time taken to process this chunk
  final Duration processingTime;

  /// Number of audio samples processed
  final int samplesProcessed;

  /// Memory usage during processing (bytes)
  final int memoryUsage;

  /// Any warnings generated during processing
  final List<String> warnings;

  const ChunkProcessingStats({required this.processingTime, required this.samplesProcessed, required this.memoryUsage, this.warnings = const []});
}

/// Processed chunk containing audio data and metadata
class ProcessedChunk {
  /// The original file chunk that was processed
  final Object fileChunk; // Using Object to avoid circular dependency

  /// The resulting audio chunks from processing
  final List<AudioChunk> audioChunks;

  /// Any error that occurred during processing
  final Object? error;

  /// Processing statistics
  final ChunkProcessingStats? stats;

  const ProcessedChunk({required this.fileChunk, required this.audioChunks, this.error, this.stats});

  /// Whether this chunk has an error
  bool get hasError => error != null;

  /// Whether this chunk has valid audio data
  bool get hasAudioData => audioChunks.isNotEmpty && !hasError;
}

/// Progressive waveform generator for streaming audio processing
class ProgressiveWaveformGenerator {
  /// Configuration for waveform generation
  final WaveformConfig config;

  /// Callback for progress updates
  final ProgressCallback? onProgress;

  /// Callback for error handling
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Whether to continue processing after errors
  final bool continueOnError;

  /// Maximum number of errors before stopping
  final int maxErrors;

  /// Internal state
  int _processedChunks = 0;
  int _totalChunks = 0;
  int _errorCount = 0;
  final List<Object> _errors = [];
  DateTime? _startTime;
  final List<double> _processingTimes = [];

  ProgressiveWaveformGenerator({required this.config, this.onProgress, this.onError, this.continueOnError = true, this.maxErrors = 10});

  /// Generate waveform from streaming processed chunks
  Stream<WaveformChunkEnhanced> generateFromChunks(Stream<ProcessedChunk> processedChunks) async* {
    _reset();
    _startTime = DateTime.now();

    final aggregator = WaveformAggregator(config);

    await for (final processedChunk in processedChunks) {
      final chunkStartTime = DateTime.now();

      try {
        if (processedChunk.hasError) {
          _handleChunkError(processedChunk.error!);
          onError?.call(processedChunk.error!, StackTrace.current);
          if (!continueOnError || _errorCount >= maxErrors) {
            break;
          }
          continue;
        }

        // Process audio chunks from this processed chunk
        for (final audioChunk in processedChunk.audioChunks) {
          final waveformChunk = aggregator.processAudioChunk(audioChunk);
          if (waveformChunk != null) {
            final enhancedChunk = WaveformChunkEnhanced(
              amplitudes: waveformChunk.amplitudes,
              startTime: waveformChunk.startTime,
              isLast: waveformChunk.isLast,
              startSample: audioChunk.startSample,
              metadata: WaveformMetadata(
                resolution: waveformChunk.amplitudes.length,
                type: config.type,
                normalized: config.normalize,
                generatedAt: DateTime.now(),
              ),
              stats: ChunkProcessingStats(
                processingTime: DateTime.now().difference(chunkStartTime),
                samplesProcessed: audioChunk.samples.length,
                memoryUsage: _estimateMemoryUsage(audioChunk.samples.length),
                warnings: [],
              ),
            );

            yield enhancedChunk;
          }
        }

        _processedChunks++;
        _updateProgress(chunkStartTime);
      } catch (error, stackTrace) {
        _handleChunkError(error);
        onError?.call(error, stackTrace);

        if (!continueOnError || _errorCount >= maxErrors) {
          break;
        }
      }
    }

    // Yield final chunk if any remaining data
    final finalChunk = aggregator.finalize();
    if (finalChunk != null) {
      yield WaveformChunkEnhanced(
        amplitudes: finalChunk.amplitudes,
        startTime: finalChunk.startTime,
        isLast: true,
        startSample: aggregator.totalSamplesProcessed,
        metadata: WaveformMetadata(resolution: finalChunk.amplitudes.length, type: config.type, normalized: config.normalize, generatedAt: DateTime.now()),
      );
    }
  }

  /// Generate complete waveform from streaming processed chunks
  Future<WaveformData> generateCompleteWaveform(Stream<ProcessedChunk> processedChunks) async {
    final chunks = <WaveformChunkEnhanced>[];
    Duration totalDuration = Duration.zero;
    int totalSamples = 0;
    int sampleRate = 44100; // Default, will be updated from first chunk

    await for (final waveformChunk in generateFromChunks(processedChunks)) {
      chunks.add(waveformChunk);

      // Update total duration and sample information
      if (waveformChunk.stats != null) {
        totalSamples += waveformChunk.stats!.samplesProcessed;
      }

      // Calculate duration from the last chunk's end time
      if (waveformChunk.isLast) {
        totalDuration = waveformChunk.startTime;
      }
    }

    // Combine all chunk amplitudes
    final allAmplitudes = <double>[];
    for (final chunk in chunks) {
      allAmplitudes.addAll(chunk.amplitudes);
    }

    // Apply final normalization if needed
    List<double> finalAmplitudes = allAmplitudes;
    if (config.normalize && allAmplitudes.isNotEmpty) {
      finalAmplitudes = WaveformAlgorithms.normalize(allAmplitudes, method: config.normalizationMethod);
    }

    // Create final metadata
    final metadata = WaveformMetadata(resolution: finalAmplitudes.length, type: config.type, normalized: config.normalize, generatedAt: DateTime.now());

    return WaveformData(amplitudes: finalAmplitudes, duration: totalDuration, sampleRate: sampleRate, metadata: metadata);
  }

  /// Generate waveform with progress tracking and error recovery
  Future<WaveformData> generateWithProgress(Stream<ProcessedChunk> processedChunks, {int? estimatedTotalChunks}) async {
    if (estimatedTotalChunks != null) {
      _totalChunks = estimatedTotalChunks;
    }

    return generateCompleteWaveform(processedChunks);
  }

  /// Reset internal state
  void _reset() {
    _processedChunks = 0;
    _totalChunks = 0;
    _errorCount = 0;
    _errors.clear();
    _startTime = null;
    _processingTimes.clear();
  }

  /// Handle chunk processing error
  void _handleChunkError(Object error) {
    _errorCount++;
    _errors.add(error);
  }

  /// Update progress and notify callback
  void _updateProgress(DateTime chunkStartTime) {
    final processingTime = DateTime.now().difference(chunkStartTime);
    _processingTimes.add(processingTime.inMilliseconds.toDouble());

    // Keep only recent processing times for speed calculation
    if (_processingTimes.length > 10) {
      _processingTimes.removeAt(0);
    }

    // Calculate processing speed
    double? processingSpeed;
    if (_processingTimes.isNotEmpty) {
      final avgTime = _processingTimes.reduce((a, b) => a + b) / _processingTimes.length;
      processingSpeed = avgTime > 0 ? 1000.0 / avgTime : null; // chunks per second
    }

    // Estimate remaining time
    Duration? estimatedTimeRemaining;
    if (processingSpeed != null && _totalChunks > 0) {
      final remainingChunks = _totalChunks - _processedChunks;
      if (remainingChunks > 0) {
        estimatedTimeRemaining = Duration(milliseconds: (remainingChunks / processingSpeed * 1000).round());
      }
    }

    final progressInfo = ProgressInfo(
      processedChunks: _processedChunks,
      totalChunks: _totalChunks,
      hasErrors: _errorCount > 0,
      lastError: _errors.isNotEmpty ? _errors.last : null,
      estimatedTimeRemaining: estimatedTimeRemaining,
      processingSpeed: processingSpeed,
    );

    onProgress?.call(progressInfo);
  }

  /// Estimate memory usage for a given number of samples
  int _estimateMemoryUsage(int sampleCount) {
    // Rough estimate: 8 bytes per double sample + overhead
    return sampleCount * 8 + 1024; // 1KB overhead
  }

  /// Get current processing statistics
  ProgressInfo getCurrentProgress() {
    return ProgressInfo(
      processedChunks: _processedChunks,
      totalChunks: _totalChunks,
      hasErrors: _errorCount > 0,
      lastError: _errors.isNotEmpty ? _errors.last : null,
    );
  }

  /// Get all errors that occurred during processing
  List<Object> getErrors() => List.unmodifiable(_errors);

  /// Whether processing has errors
  bool get hasErrors => _errorCount > 0;

  /// Number of errors encountered
  int get errorCount => _errorCount;
}
