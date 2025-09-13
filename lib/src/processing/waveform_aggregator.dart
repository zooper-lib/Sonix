/// Waveform aggregator for combining audio chunks into waveform data
library;

import '../models/audio_data.dart';
import '../models/waveform_data.dart';
import 'waveform_generator.dart';
import 'waveform_algorithms.dart';

/// Aggregates audio chunks into waveform chunks for streaming processing
class WaveformAggregator {
  /// Configuration for waveform generation
  final WaveformConfig config;

  /// Accumulated audio samples waiting to be processed
  final List<double> _accumulatedSamples = [];

  /// Total number of samples processed so far
  int _totalSamplesProcessed = 0;

  /// Total duration processed so far
  Duration _totalDurationProcessed = Duration.zero;

  /// Sample rate of the audio (determined from first chunk)
  int? _sampleRate;

  /// Samples per waveform point (calculated based on expected total samples)
  int? _samplesPerPoint;

  /// Expected total samples (for calculating samples per point)
  int? _expectedTotalSamples;

  /// Current waveform point index
  int _currentPointIndex = 0;

  /// Buffer for partial waveform points
  final List<double> _pointBuffer = [];

  /// Statistics tracking
  int _chunksProcessed = 0;
  int _waveformChunksGenerated = 0;

  WaveformAggregator(this.config);

  /// Get total samples processed
  int get totalSamplesProcessed => _totalSamplesProcessed;

  /// Get total duration processed
  Duration get totalDurationProcessed => _totalDurationProcessed;

  /// Get number of chunks processed
  int get chunksProcessed => _chunksProcessed;

  /// Get number of waveform chunks generated
  int get waveformChunksGenerated => _waveformChunksGenerated;

  /// Set expected total samples for better waveform point calculation
  void setExpectedTotalSamples(int totalSamples) {
    _expectedTotalSamples = totalSamples;
    _samplesPerPoint = (totalSamples / config.resolution).ceil();
  }

  /// Process an audio chunk and return a waveform chunk if ready
  WaveformChunk? processAudioChunk(AudioChunk audioChunk) {
    _chunksProcessed++;

    // Initialize parameters from first chunk
    if (_sampleRate == null && audioChunk.samples.isNotEmpty) {
      // We need to estimate sample rate and channels
      // In a real implementation, this would come from the decoder
      _sampleRate = 44100; // Default assumption
      // Default channels assumption would be handled upstream if needed

      // If we don't have expected total samples, use a reasonable default
      if (_expectedTotalSamples == null) {
        _samplesPerPoint = 1024; // Use default chunk size
      }
    }

    // Add samples to accumulator
    _accumulatedSamples.addAll(audioChunk.samples);
    _totalSamplesProcessed += audioChunk.samples.length;

    // Update duration (rough estimate)
    if (_sampleRate != null && _sampleRate! > 0) {
      _totalDurationProcessed = Duration(microseconds: (_totalSamplesProcessed * Duration.microsecondsPerSecond) ~/ _sampleRate!);
    }

    // Check if we have enough samples for waveform generation
    final samplesPerPoint = _samplesPerPoint ?? 1024; // Default if not set

    if (_accumulatedSamples.length >= samplesPerPoint || audioChunk.isLast) {
      return _generateWaveformChunk(audioChunk.isLast);
    }

    return null;
  }

  /// Finalize processing and return any remaining waveform data
  WaveformChunk? finalize() {
    // If we already reached target resolution, don’t emit extra point
    if (_currentPointIndex >= config.resolution) {
      _accumulatedSamples.clear();
      return null;
    }

    if (_accumulatedSamples.isNotEmpty) {
      // Force generation of a chunk with remaining samples
      final amplitude = _calculateAmplitude(_accumulatedSamples);
      final amplitudes = [amplitude];

      final startTime = Duration(
        microseconds: _sampleRate != null && _sampleRate! > 0 ? (_totalSamplesProcessed * Duration.microsecondsPerSecond) ~/ _sampleRate! : 0,
      );

      _accumulatedSamples.clear();
      _waveformChunksGenerated++;

      return WaveformChunk(amplitudes: amplitudes, startTime: startTime, isLast: true);
    }
    return null;
  }

  /// Generate a waveform chunk from accumulated samples
  WaveformChunk _generateWaveformChunk(bool isLast) {
    final samplesPerPoint = _samplesPerPoint ?? 1024;
    final amplitudes = <double>[];

    // Process complete points
    int samplesProcessed = 0;
    while (_accumulatedSamples.length >= samplesPerPoint && _currentPointIndex < config.resolution) {
      final pointSamples = _accumulatedSamples.take(samplesPerPoint).toList();
      _accumulatedSamples.removeRange(0, samplesPerPoint);

      final amplitude = _calculateAmplitude(pointSamples);
      amplitudes.add(amplitude);
      samplesProcessed += samplesPerPoint;
      _currentPointIndex++;
    }

    // Handle remaining samples if this is the last chunk
    if (isLast && _accumulatedSamples.isNotEmpty && _currentPointIndex < config.resolution) {
      final amplitude = _calculateAmplitude(_accumulatedSamples);
      amplitudes.add(amplitude);
      samplesProcessed += _accumulatedSamples.length;
      _accumulatedSamples.clear();
      _currentPointIndex++;
    }

    // If no amplitudes were generated but we have samples, create at least one point
    if (amplitudes.isEmpty && _accumulatedSamples.isNotEmpty && _currentPointIndex < config.resolution) {
      final amplitude = _calculateAmplitude(_accumulatedSamples);
      amplitudes.add(amplitude);
      samplesProcessed += _accumulatedSamples.length;
      _accumulatedSamples.clear();
      _currentPointIndex++;
    }

    // Apply post-processing to amplitudes
    List<double> processedAmplitudes = amplitudes;

    // Apply smoothing if enabled and we have enough points
    if (config.enableSmoothing && amplitudes.length >= config.smoothingWindowSize) {
      processedAmplitudes = WaveformAlgorithms.smoothAmplitudes(amplitudes, windowSize: config.smoothingWindowSize);
    }

    // Apply scaling (normalization will be done at the end for streaming)
    if (config.scalingCurve != ScalingCurve.linear || config.scalingFactor != 1.0) {
      processedAmplitudes = WaveformAlgorithms.scaleAmplitudes(processedAmplitudes, scalingCurve: config.scalingCurve, factor: config.scalingFactor);
    }

    _waveformChunksGenerated++;

    // Calculate start time for this chunk
    final startTime = Duration(
      microseconds: _sampleRate != null && _sampleRate! > 0
          ? ((_totalSamplesProcessed - samplesProcessed) * Duration.microsecondsPerSecond) ~/ _sampleRate!
          : 0,
    );

    return WaveformChunk(amplitudes: processedAmplitudes, startTime: startTime, isLast: isLast);
  }

  /// Calculate amplitude for a set of samples using the configured algorithm
  double _calculateAmplitude(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    switch (config.algorithm) {
      case DownsamplingAlgorithm.rms:
        return WaveformAlgorithms.calculateRMS(samples);
      case DownsamplingAlgorithm.peak:
        return WaveformAlgorithms.calculatePeak(samples);
      case DownsamplingAlgorithm.average:
        return WaveformAlgorithms.calculateAverage(samples);
      case DownsamplingAlgorithm.median:
        return WaveformAlgorithms.calculateMedian(samples);
    }
  }

  /// Reset the aggregator state
  void reset() {
    _accumulatedSamples.clear();
    _totalSamplesProcessed = 0;
    _totalDurationProcessed = Duration.zero;
    _sampleRate = null;
    // No channel state kept here
    _samplesPerPoint = null;
    _expectedTotalSamples = null;
    _currentPointIndex = 0;
    _pointBuffer.clear();
    _chunksProcessed = 0;
    _waveformChunksGenerated = 0;
  }

  /// Get current processing statistics
  WaveformAggregatorStats getStats() {
    return WaveformAggregatorStats(
      chunksProcessed: _chunksProcessed,
      waveformChunksGenerated: _waveformChunksGenerated,
      totalSamplesProcessed: _totalSamplesProcessed,
      totalDurationProcessed: _totalDurationProcessed,
      accumulatedSamples: _accumulatedSamples.length,
      currentPointIndex: _currentPointIndex,
      samplesPerPoint: _samplesPerPoint,
    );
  }

  /// Static method to combine multiple waveform chunks into a complete waveform
  static WaveformData combineChunks(List<WaveformChunk> chunks, WaveformConfig config, {Duration? totalDuration, int? sampleRate}) {
    if (chunks.isEmpty) {
      return WaveformData(
        amplitudes: const [],
        duration: totalDuration ?? Duration.zero,
        sampleRate: sampleRate ?? 44100,
        metadata: WaveformMetadata(resolution: 0, type: config.type, normalized: config.normalize, generatedAt: DateTime.now()),
      );
    }

    // Combine all amplitudes
    final allAmplitudes = <double>[];
    Duration maxEndTime = Duration.zero;

    for (final chunk in chunks) {
      allAmplitudes.addAll(chunk.amplitudes);

      // Calculate end time for this chunk
      final endTime =
          chunk.startTime +
          Duration(microseconds: chunk.amplitudes.isNotEmpty ? (chunk.amplitudes.length * Duration.microsecondsPerSecond) ~/ (sampleRate ?? 44100) : 0);

      if (endTime > maxEndTime) {
        maxEndTime = endTime;
      }
    }

    // Apply final normalization if requested
    List<double> finalAmplitudes = allAmplitudes;
    if (config.normalize && allAmplitudes.isNotEmpty) {
      finalAmplitudes = WaveformAlgorithms.normalize(allAmplitudes, method: config.normalizationMethod);
    }

    // Use provided duration or calculated duration
    final finalDuration = totalDuration ?? maxEndTime;

    final metadata = WaveformMetadata(resolution: finalAmplitudes.length, type: config.type, normalized: config.normalize, generatedAt: DateTime.now());

    return WaveformData(amplitudes: finalAmplitudes, duration: finalDuration, sampleRate: sampleRate ?? 44100, metadata: metadata);
  }

  /// Static method to combine waveform chunks with enhanced metadata
  static WaveformData combineChunksEnhanced(
    List<WaveformChunk> chunks,
    WaveformConfig config, {
    required Duration totalDuration,
    required int sampleRate,
    required int totalSamples,
    Map<String, dynamic>? additionalMetadata,
  }) {
    final waveformData = combineChunks(chunks, config, totalDuration: totalDuration, sampleRate: sampleRate);

    // Create enhanced metadata
    final enhancedMetadata = WaveformMetadata(
      resolution: waveformData.amplitudes.length,
      type: config.type,
      normalized: config.normalize,
      generatedAt: DateTime.now(),
    );

    return WaveformData(amplitudes: waveformData.amplitudes, duration: totalDuration, sampleRate: sampleRate, metadata: enhancedMetadata);
  }

  /// Validate chunk sequence for consistency
  static ChunkSequenceValidation validateChunkSequence(List<WaveformChunk> chunks) {
    if (chunks.isEmpty) {
      return ChunkSequenceValidation(isValid: true, warnings: ['Empty chunk sequence'], errors: []);
    }

    final warnings = <String>[];
    final errors = <String>[];

    // Check for proper ordering
    Duration lastEndTime = Duration.zero;
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];

      if (chunk.startTime < lastEndTime) {
        warnings.add('Chunk $i starts before previous chunk ends');
      }

      // Estimate chunk duration (rough calculation)
      final chunkDuration = Duration(microseconds: chunk.amplitudes.isNotEmpty ? (chunk.amplitudes.length * Duration.microsecondsPerSecond) ~/ 44100 : 0);

      lastEndTime = chunk.startTime + chunkDuration;
    }

    // Check if last chunk is marked as last
    if (!chunks.last.isLast) {
      warnings.add('Last chunk is not marked as final');
    }

    // Check for gaps in coverage
    if (chunks.length > 1) {
      for (int i = 1; i < chunks.length; i++) {
        final prevChunk = chunks[i - 1];
        final currentChunk = chunks[i];

        final gap = currentChunk.startTime - prevChunk.startTime;
        if (gap > Duration(milliseconds: 100)) {
          // Allow small gaps
          warnings.add('Large gap detected between chunks ${i - 1} and $i: ${gap.inMilliseconds}ms');
        }
      }
    }

    return ChunkSequenceValidation(isValid: errors.isEmpty, warnings: warnings, errors: errors);
  }
}

/// Statistics about waveform aggregation
class WaveformAggregatorStats {
  /// Number of audio chunks processed
  final int chunksProcessed;

  /// Number of waveform chunks generated
  final int waveformChunksGenerated;

  /// Total audio samples processed
  final int totalSamplesProcessed;

  /// Total duration processed
  final Duration totalDurationProcessed;

  /// Number of samples currently accumulated
  final int accumulatedSamples;

  /// Current waveform point index
  final int currentPointIndex;

  /// Samples per waveform point
  final int? samplesPerPoint;

  const WaveformAggregatorStats({
    required this.chunksProcessed,
    required this.waveformChunksGenerated,
    required this.totalSamplesProcessed,
    required this.totalDurationProcessed,
    required this.accumulatedSamples,
    required this.currentPointIndex,
    this.samplesPerPoint,
  });

  /// Processing efficiency (waveform chunks per audio chunk)
  double get processingEfficiency => chunksProcessed > 0 ? waveformChunksGenerated / chunksProcessed : 0.0;

  /// Average samples per waveform chunk
  double get averageSamplesPerWaveformChunk => waveformChunksGenerated > 0 ? totalSamplesProcessed / waveformChunksGenerated : 0.0;

  @override
  String toString() {
    return 'WaveformAggregatorStats(processed: $chunksProcessed chunks, '
        'generated: $waveformChunksGenerated waveform chunks, '
        'samples: $totalSamplesProcessed, duration: $totalDurationProcessed, '
        'efficiency: ${processingEfficiency.toStringAsFixed(2)})';
  }
}

/// Result of chunk sequence validation
class ChunkSequenceValidation {
  /// Whether the sequence is valid
  final bool isValid;

  /// Warning messages
  final List<String> warnings;

  /// Error messages
  final List<String> errors;

  const ChunkSequenceValidation({required this.isValid, required this.warnings, required this.errors});

  /// Whether there are any issues (warnings or errors)
  bool get hasIssues => warnings.isNotEmpty || errors.isNotEmpty;

  @override
  String toString() {
    return 'ChunkSequenceValidation(valid: $isValid, '
        'warnings: ${warnings.length}, errors: ${errors.length})';
  }
}
