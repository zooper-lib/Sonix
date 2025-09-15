import 'dart:async';
import 'dart:math' as math;

import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/waveform_metadata.dart';
import 'package:sonix/src/models/waveform_chunk.dart';
import 'waveform_algorithms.dart';
import 'waveform_config.dart';
import 'waveform_use_case.dart';
import 'downsampling_algorithm.dart';
import 'scaling_curve.dart';

/// Main waveform generation engine
class WaveformGenerator {
  /// Generate waveform data from audio data
  ///
  /// [audioData] - Input audio data
  /// [config] - Configuration for waveform generation
  static Future<WaveformData> generate(AudioData audioData, {WaveformConfig config = const WaveformConfig()}) async {
    if (audioData.samples.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }

    // Validate configuration
    _validateConfig(config);

    // Step 1: Downsample the audio data
    final amplitudes = WaveformAlgorithms.downsample(audioData.samples, config.resolution, algorithm: config.algorithm, channels: audioData.channels);

    // Step 2: Apply smoothing if enabled
    List<double> processedAmplitudes = amplitudes;
    if (config.enableSmoothing) {
      processedAmplitudes = WaveformAlgorithms.smoothAmplitudes(processedAmplitudes, windowSize: config.smoothingWindowSize);
    }

    // Step 3: Normalize if requested
    if (config.normalize) {
      processedAmplitudes = WaveformAlgorithms.normalize(processedAmplitudes, method: config.normalizationMethod);
    }

    // Step 4: Apply amplitude scaling
    if (config.scalingCurve != ScalingCurve.linear || config.scalingFactor != 1.0) {
      processedAmplitudes = WaveformAlgorithms.scaleAmplitudes(processedAmplitudes, scalingCurve: config.scalingCurve, factor: config.scalingFactor);
    }

    // Create metadata
    final metadata = WaveformMetadata(resolution: processedAmplitudes.length, type: config.type, normalized: config.normalize, generatedAt: DateTime.now());

    return WaveformData(amplitudes: processedAmplitudes, duration: audioData.duration, sampleRate: audioData.sampleRate, metadata: metadata);
  }

  /// Generate waveform data from streaming audio chunks
  ///
  /// [audioStream] - Stream of audio chunks
  /// [config] - Configuration for waveform generation
  /// [chunkSize] - Size of each output chunk (in data points)
  static Stream<WaveformChunk> generateStream(Stream<AudioChunk> audioStream, {WaveformConfig config = const WaveformConfig(), int chunkSize = 100}) async* {
    // Validate configuration
    _validateConfig(config);

    if (chunkSize <= 0) {
      throw ArgumentError('Chunk size must be positive');
    }

    final buffer = <double>[];
    Duration currentTime = Duration.zero;
    int totalSamples = 0;
    int sampleRate = 44100;
    int channels = 1;

    // For normalization across the entire stream
    final allAmplitudes = <double>[];

    await for (final chunk in audioStream) {
      // Note: In streaming mode, we often don't have full metadata; use conservative defaults

      buffer.addAll(chunk.samples);
      totalSamples += chunk.samples.length;

      // Process buffer when we have enough data or this is the last chunk
      final samplesNeeded = (chunkSize * buffer.length) ~/ config.resolution;

      if (buffer.length >= samplesNeeded || chunk.isLast) {
        // Calculate how many samples to process for this chunk
        final samplesToProcess = chunk.isLast ? buffer.length : samplesNeeded;
        final chunkSamples = buffer.take(samplesToProcess).toList();

        // Remove processed samples from buffer
        buffer.removeRange(0, math.min(samplesToProcess, buffer.length));

        if (chunkSamples.isNotEmpty) {
          // Calculate target resolution for this chunk
          final chunkResolution = chunk.isLast ? math.max(1, (config.resolution * chunkSamples.length) ~/ totalSamples) : chunkSize;

          // Generate amplitudes for this chunk
          var chunkAmplitudes = WaveformAlgorithms.downsample(chunkSamples, chunkResolution, algorithm: config.algorithm, channels: channels);

          // Apply smoothing if enabled
          if (config.enableSmoothing) {
            chunkAmplitudes = WaveformAlgorithms.smoothAmplitudes(chunkAmplitudes, windowSize: config.smoothingWindowSize);
          }

          // Store for potential normalization
          if (config.normalize) {
            allAmplitudes.addAll(chunkAmplitudes);
          }

          // Apply scaling (but not normalization yet in streaming mode)
          if (config.scalingCurve != ScalingCurve.linear || config.scalingFactor != 1.0) {
            chunkAmplitudes = WaveformAlgorithms.scaleAmplitudes(chunkAmplitudes, scalingCurve: config.scalingCurve, factor: config.scalingFactor);
          }

          // Calculate time for this chunk (account for channels)
          final chunkDuration = Duration(microseconds: (chunkSamples.length * Duration.microsecondsPerSecond) ~/ (sampleRate * channels));

          yield WaveformChunk(amplitudes: chunkAmplitudes, startTime: currentTime, isLast: chunk.isLast);

          currentTime += chunkDuration;
        }
      }
    }

    // If normalization was requested, we'd need a second pass
    // This is a limitation of streaming processing
    if (config.normalize && allAmplitudes.isNotEmpty) {
      // In a real implementation, you might want to emit normalized chunks
      // in a second stream or provide a callback for post-processing
    }
  }

  /// Generate waveform with memory-efficient streaming for large files
  ///
  /// This method processes audio in chunks to minimize memory usage
  /// [audioData] - Input audio data
  /// [config] - Configuration for waveform generation
  /// [maxMemoryUsage] - Maximum memory usage in bytes (approximate)
  static Future<WaveformData> generateMemoryEfficient(
    AudioData audioData, {
    WaveformConfig config = const WaveformConfig(),
    int maxMemoryUsage = 50 * 1024 * 1024, // 50MB default
  }) async {
    if (audioData.samples.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }

    _validateConfig(config);

    // Calculate chunk size based on memory constraints
    final bytesPerSample = 8; // double = 8 bytes
    final maxSamplesInMemory = maxMemoryUsage ~/ bytesPerSample;
    final chunkSize = math.min(maxSamplesInMemory, audioData.samples.length);

    if (chunkSize >= audioData.samples.length) {
      // If the entire audio fits in memory, use regular generation
      return generate(audioData, config: config);
    }

    // Process in chunks
    final allAmplitudes = <double>[];
    final samplesPerBin = audioData.samples.length / config.resolution;

    for (int i = 0; i < config.resolution; i++) {
      final startIdx = (i * samplesPerBin).floor();
      final endIdx = math.min(((i + 1) * samplesPerBin).floor(), audioData.samples.length);

      if (startIdx >= audioData.samples.length) break;

      // Extract samples for this bin
      final binSamples = audioData.samples.sublist(startIdx, endIdx);

      // Calculate amplitude using the specified algorithm
      double amplitude;
      switch (config.algorithm) {
        case DownsamplingAlgorithm.rms:
          amplitude = WaveformAlgorithms.calculateRMS(binSamples);
          break;
        case DownsamplingAlgorithm.peak:
          amplitude = WaveformAlgorithms.calculatePeak(binSamples);
          break;
        case DownsamplingAlgorithm.average:
          amplitude = WaveformAlgorithms.calculateAverage(binSamples);
          break;
        case DownsamplingAlgorithm.median:
          amplitude = WaveformAlgorithms.calculateMedian(binSamples);
          break;
      }

      allAmplitudes.add(amplitude);
    }

    // Apply post-processing
    List<double> processedAmplitudes = allAmplitudes;

    if (config.enableSmoothing) {
      processedAmplitudes = WaveformAlgorithms.smoothAmplitudes(processedAmplitudes, windowSize: config.smoothingWindowSize);
    }

    if (config.normalize) {
      processedAmplitudes = WaveformAlgorithms.normalize(processedAmplitudes, method: config.normalizationMethod);
    }

    if (config.scalingCurve != ScalingCurve.linear || config.scalingFactor != 1.0) {
      processedAmplitudes = WaveformAlgorithms.scaleAmplitudes(processedAmplitudes, scalingCurve: config.scalingCurve, factor: config.scalingFactor);
    }

    final metadata = WaveformMetadata(resolution: processedAmplitudes.length, type: config.type, normalized: config.normalize, generatedAt: DateTime.now());

    return WaveformData(amplitudes: processedAmplitudes, duration: audioData.duration, sampleRate: audioData.sampleRate, metadata: metadata);
  }

  /// Validate waveform generation configuration
  static void _validateConfig(WaveformConfig config) {
    if (config.resolution <= 0) {
      throw ArgumentError('Resolution must be positive');
    }

    if (config.scalingFactor < 0) {
      throw ArgumentError('Scaling factor must be non-negative');
    }

    if (config.smoothingWindowSize < 3 || config.smoothingWindowSize.isEven) {
      throw ArgumentError('Smoothing window size must be odd and >= 3');
    }
  }

  /// Get optimal configuration for different use cases
  static WaveformConfig getOptimalConfig({required WaveformUseCase useCase, int? customResolution}) {
    switch (useCase) {
      case WaveformUseCase.musicVisualization:
        return WaveformConfig(
          resolution: customResolution ?? 1000,
          algorithm: DownsamplingAlgorithm.rms,
          normalize: true,
          scalingCurve: ScalingCurve.logarithmic,
          enableSmoothing: true,
        );

      case WaveformUseCase.speechAnalysis:
        return WaveformConfig(
          resolution: customResolution ?? 2000,
          algorithm: DownsamplingAlgorithm.rms,
          normalize: true,
          scalingCurve: ScalingCurve.linear,
          enableSmoothing: false,
        );

      case WaveformUseCase.peakDetection:
        return WaveformConfig(
          resolution: customResolution ?? 500,
          algorithm: DownsamplingAlgorithm.peak,
          normalize: true,
          scalingCurve: ScalingCurve.linear,
          enableSmoothing: false,
        );

      case WaveformUseCase.memoryEfficient:
        return WaveformConfig(
          resolution: customResolution ?? 200,
          algorithm: DownsamplingAlgorithm.average,
          normalize: true,
          scalingCurve: ScalingCurve.linear,
          enableSmoothing: false,
        );
    }
  }
}
