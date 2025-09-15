import 'dart:math' as math;
import '../models/waveform_data.dart';

/// Methods for downsampling when data points exceed display resolution
enum DownsampleMethod {
  /// Use maximum amplitude in each group (preserves peaks)
  max,

  /// Use RMS (Root Mean Square) of each group (preserves energy)
  rms,

  /// Use average amplitude of each group (smooth representation)
  average,

  /// Use both min and max to preserve dynamic range (returns pairs)
  minMax,
}

/// Methods for upsampling when data points are fewer than display resolution
enum UpsampleMethod {
  /// Linear interpolation between points
  linear,

  /// Repeat each point to fill space
  repeat,

  /// Cubic interpolation for smoother curves
  cubic,
}

/// Utility class for converting waveform data resolution to display resolution
///
/// This class handles the conversion between the number of amplitude data points
/// extracted from audio files and the optimal number of visual elements to render
/// based on widget width and style preferences.
class DisplaySampler {
  /// Calculate optimal display resolution based on widget width and style
  ///
  /// [availableWidth] - Width available for rendering the waveform
  /// [barWidth] - Desired width of each bar (for bar-type waveforms)
  /// [barSpacing] - Desired spacing between bars (for bar-type waveforms)
  /// [displayDensity] - Optional density override (points per 100px)
  /// [waveformType] - Type of waveform visualization
  static int calculateDisplayResolution({
    required double availableWidth,
    required double barWidth,
    required double barSpacing,
    double? displayDensity,
    required WaveformType waveformType,
  }) {
    if (availableWidth <= 0) return 0;

    switch (waveformType) {
      case WaveformType.bars:
        // For bars: calculate how many bars fit with desired width and spacing
        final barUnit = barWidth + barSpacing;
        final maxBars = (availableWidth / barUnit).floor();
        return math.max(1, maxBars);

      case WaveformType.line:
        // For lines: use density-based calculation or default to pixel-based
        final density = displayDensity ?? 1.0;
        return math.max(1, (availableWidth * density / 100.0).round());

      case WaveformType.filled:
        // For filled: use moderate density for smooth curves
        final density = displayDensity ?? 0.5;
        return math.max(1, (availableWidth * density / 100.0).round());
    }
  }

  /// Resample amplitude data to match target display resolution
  ///
  /// [sourceAmplitudes] - Original amplitude data from audio processing
  /// [targetCount] - Desired number of display points
  /// [downsampleMethod] - Method to use when reducing data points
  /// [upsampleMethod] - Method to use when increasing data points
  static List<double> resampleForDisplay({
    required List<double> sourceAmplitudes,
    required int targetCount,
    DownsampleMethod downsampleMethod = DownsampleMethod.max,
    UpsampleMethod upsampleMethod = UpsampleMethod.linear,
  }) {
    if (sourceAmplitudes.isEmpty || targetCount <= 0) {
      return <double>[];
    }

    if (sourceAmplitudes.length == targetCount) {
      return List<double>.from(sourceAmplitudes);
    }

    if (sourceAmplitudes.length > targetCount) {
      return _downsample(sourceAmplitudes, targetCount, downsampleMethod);
    } else {
      return _upsample(sourceAmplitudes, targetCount, upsampleMethod);
    }
  }

  /// Downsample amplitude data to fewer points
  static List<double> _downsample(List<double> amplitudes, int targetCount, DownsampleMethod method) {
    final result = <double>[];
    final groupSize = amplitudes.length / targetCount;

    for (int i = 0; i < targetCount; i++) {
      final startIdx = (i * groupSize).floor();
      final endIdx = ((i + 1) * groupSize).ceil().clamp(0, amplitudes.length);
      final group = amplitudes.sublist(startIdx, endIdx);

      if (group.isEmpty) continue;

      switch (method) {
        case DownsampleMethod.max:
          result.add(group.reduce(math.max));
          break;

        case DownsampleMethod.rms:
          final sumOfSquares = group.fold(0.0, (sum, amp) => sum + amp * amp);
          result.add(math.sqrt(sumOfSquares / group.length));
          break;

        case DownsampleMethod.average:
          final sum = group.fold(0.0, (sum, amp) => sum + amp);
          result.add(sum / group.length);
          break;

        case DownsampleMethod.minMax:
          // For minMax, we store the max (min information could be added later if needed)
          result.add(group.reduce(math.max));
          break;
      }
    }

    return result;
  }

  /// Upsample amplitude data to more points
  static List<double> _upsample(List<double> amplitudes, int targetCount, UpsampleMethod method) {
    if (amplitudes.length == 1) {
      // Special case: single point, repeat it
      return List.filled(targetCount, amplitudes.first);
    }

    switch (method) {
      case UpsampleMethod.linear:
        return _linearInterpolation(amplitudes, targetCount);

      case UpsampleMethod.repeat:
        return _repeatSampling(amplitudes, targetCount);

      case UpsampleMethod.cubic:
        // For now, fall back to linear (cubic could be implemented later)
        return _linearInterpolation(amplitudes, targetCount);
    }
  }

  /// Linear interpolation between amplitude points
  static List<double> _linearInterpolation(List<double> amplitudes, int targetCount) {
    final result = <double>[];
    final step = (amplitudes.length - 1) / (targetCount - 1);

    for (int i = 0; i < targetCount; i++) {
      final exactIndex = i * step;
      final lowerIndex = exactIndex.floor();
      final upperIndex = math.min(lowerIndex + 1, amplitudes.length - 1);

      if (lowerIndex == upperIndex) {
        result.add(amplitudes[lowerIndex]);
      } else {
        final fraction = exactIndex - lowerIndex;
        final interpolated = amplitudes[lowerIndex] * (1 - fraction) + amplitudes[upperIndex] * fraction;
        result.add(interpolated);
      }
    }

    return result;
  }

  /// Repeat sampling by distributing points evenly
  static List<double> _repeatSampling(List<double> amplitudes, int targetCount) {
    final result = <double>[];
    final ratio = amplitudes.length / targetCount;

    for (int i = 0; i < targetCount; i++) {
      final sourceIndex = (i * ratio).floor().clamp(0, amplitudes.length - 1);
      result.add(amplitudes[sourceIndex]);
    }

    return result;
  }
}

/// Waveform visualization types (re-exported for convenience)
/// 
/// Note: This references the WaveformType from models/waveform_data.dart
/// Available types: bars, line, filled