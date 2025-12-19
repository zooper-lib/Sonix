import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/waveform_metadata.dart';
import 'waveform_algorithms.dart';
import 'waveform_config.dart';
import 'waveform_use_case.dart';
import 'downsampling_algorithm.dart';
import 'scaling_curve.dart';

/// Main waveform generation engine with two-tier processing architecture
///
/// This class provides two distinct processing strategies for generating waveforms:
///
/// ## Two-Tier Architecture Overview
///
/// The Sonix library uses a two-tier chunked processing system that automatically
/// selects the optimal strategy based on file size:
///
/// ### 1. In-Memory Processing (`generateInMemory`)
/// - **When used**: Files ≤ 50MB (automatic selection by processing isolate)
/// - **How it works**: Audio data is fully loaded into memory first, then processed
/// - **Memory usage**: High initial load, but fast processing
/// - **Chunking type**: Logical chunking only (downsampling algorithm)
/// - **Performance**: Fastest for small to medium files
///
/// ### 2. File-Level Chunked Processing (`generateChunked`)
/// - **When used**: Files > 50MB (automatic selection by processing isolate)
/// - **How it works**: Audio is read from file in chunks without loading entirely
/// - **Memory usage**: Low and controlled throughout processing
/// - **Chunking type**: Both file-level chunking (memory management) AND logical chunking (downsampling)
/// - **Performance**: Memory-efficient for large files
///
/// ## Important: Both Methods Use "Chunked Processing"
///
/// Both processing strategies perform chunked processing, but in different ways:
///
/// - **Logical Chunking**: Both methods divide the audio into time-based segments
///   for downsampling (e.g., 1000 amplitude points from 10 minutes of audio)
///
/// - **File-Level Chunking**: Only `generateChunked()` additionally reads the
///   audio file in memory-sized chunks to avoid loading large files entirely
///
/// ## Automatic Strategy Selection
///
/// The processing isolate automatically chooses the optimal strategy:
/// ```dart
/// // This selection happens automatically in processing_isolate.dart
/// if (fileSize > 50 * 1024 * 1024 && decoder.supportsChunkedDecoding) {
///   // Use file-level chunked processing
///   result = await WaveformGenerator.generateChunked(...);
/// } else {
///   // Use in-memory processing
///   result = await WaveformGenerator.generateInMemory(...);
/// }
/// ```
///
/// ## Direct Usage
///
/// While the processing isolate handles strategy selection automatically,
/// you can also call these methods directly for specific use cases:
///
/// ```dart
/// // For pre-loaded audio data
/// final waveform = await WaveformGenerator.generateInMemory(audioData);
///
/// // For memory-constrained processing
/// final waveform = await WaveformGenerator.generateChunked(
///   audioData,
///   maxMemoryUsage: 10 * 1024 * 1024 // 10MB limit
/// );
/// ```
class WaveformGenerator {
  /// Generate waveform data from pre-loaded audio data in memory
  ///
  /// This method processes audio data that has already been fully loaded into memory.
  /// It performs logical chunking (downsampling) to create the waveform visualization
  /// but assumes all audio samples are available in the AudioData object.
  ///
  /// **Used for**: Small to medium files (≤ 50MB) where loading the entire file
  /// into memory is acceptable and provides optimal processing performance.
  ///
  /// [audioData] - Complete audio data loaded in memory
  /// [config] - Configuration for waveform generation
  static Future<WaveformData> generateInMemory(AudioData audioData, {WaveformConfig config = const WaveformConfig()}) async {
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

  /// Generate waveform using chunked processing for memory efficiency
  ///
  /// This method processes pre-loaded audio data in memory chunks to minimize
  /// peak memory usage. It's designed for scenarios where audio data has been
  /// loaded into memory but needs to be processed with memory constraints.
  ///
  /// **Note**: This is different from file-level chunking. This method still
  /// requires the complete AudioData in memory but processes it in chunks
  /// during waveform generation to stay within memory limits.
  ///
  /// **Used for**: Special cases where memory-constrained processing is needed
  /// even with pre-loaded audio data.
  ///
  /// [audioData] - Complete audio data loaded in memory
  /// [config] - Configuration for waveform generation
  /// [maxMemoryUsage] - Maximum memory usage in bytes during processing (approximate)
  static Future<WaveformData> generateChunked(
    AudioData audioData, {
    WaveformConfig config = const WaveformConfig(),
    int maxMemoryUsage = 50 * 1024 * 1024, // 50MB default
  }) async {
    if (audioData.samples.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }

    _validateConfig(config);

    // Calculate chunk size based on memory constraints.
    // Note: Typed lists (e.g. Float32List) use fewer bytes per element.
    final bytesPerSample = audioData.samples is TypedData ? (audioData.samples as TypedData).elementSizeInBytes : 8;
    final maxSamplesInMemory = maxMemoryUsage ~/ bytesPerSample;
    final chunkSize = math.min(maxSamplesInMemory, audioData.samples.length);

    if (chunkSize >= audioData.samples.length) {
      // If the entire audio fits in memory, use regular generation
      return generateInMemory(audioData, config: config);
    }

    // Process without allocating per-bin sublists.
    final allAmplitudes = <double>[];
    final channels = audioData.channels;
    final frames = audioData.samples.length ~/ channels;
    final framesPerBin = frames / config.resolution;

    for (int bin = 0; bin < config.resolution; bin++) {
      final startFrame = (bin * framesPerBin).floor();
      final endFrame = math.min(((bin + 1) * framesPerBin).floor(), frames);
      if (startFrame >= frames) break;

      double amplitude;
      switch (config.algorithm) {
        case DownsamplingAlgorithm.rms:
          double sumSquares = 0.0;
          int count = 0;
          for (int frame = startFrame; frame < endFrame; frame++) {
            final base = frame * channels;
            double mixed = 0.0;
            int mixedCount = 0;
            for (int ch = 0; ch < channels; ch++) {
              final idx = base + ch;
              if (idx >= audioData.samples.length) break;
              mixed += audioData.samples[idx];
              mixedCount++;
            }
            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            sumSquares += mixed * mixed;
            count++;
          }
          amplitude = count == 0 ? 0.0 : math.sqrt(sumSquares / count);
          break;

        case DownsamplingAlgorithm.peak:
          double peak = 0.0;
          for (int frame = startFrame; frame < endFrame; frame++) {
            final base = frame * channels;
            double mixed = 0.0;
            int mixedCount = 0;
            for (int ch = 0; ch < channels; ch++) {
              final idx = base + ch;
              if (idx >= audioData.samples.length) break;
              mixed += audioData.samples[idx];
              mixedCount++;
            }
            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            final absValue = mixed.abs();
            if (absValue > peak) peak = absValue;
          }
          amplitude = peak;
          break;

        case DownsamplingAlgorithm.average:
          double sumAbs = 0.0;
          int count = 0;
          for (int frame = startFrame; frame < endFrame; frame++) {
            final base = frame * channels;
            double mixed = 0.0;
            int mixedCount = 0;
            for (int ch = 0; ch < channels; ch++) {
              final idx = base + ch;
              if (idx >= audioData.samples.length) break;
              mixed += audioData.samples[idx];
              mixedCount++;
            }
            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            sumAbs += mixed.abs();
            count++;
          }
          amplitude = count == 0 ? 0.0 : (sumAbs / count);
          break;

        case DownsamplingAlgorithm.median:
          final binSamples = <double>[];
          for (int frame = startFrame; frame < endFrame; frame++) {
            final base = frame * channels;
            double mixed = 0.0;
            int mixedCount = 0;
            for (int ch = 0; ch < channels; ch++) {
              final idx = base + ch;
              if (idx >= audioData.samples.length) break;
              mixed += audioData.samples[idx];
              mixedCount++;
            }
            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            binSamples.add(mixed);
          }
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
