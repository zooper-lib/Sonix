import 'dart:math' as math;
import 'downsampling_algorithm.dart';
import 'normalization_method.dart';
import 'scaling_curve.dart';

/// Core algorithms for waveform data processing
class WaveformAlgorithms {
  /// Calculate RMS (Root Mean Square) amplitude for a segment of audio samples
  ///
  /// RMS provides a better representation of perceived loudness compared to peak values
  /// Formula: RMS = sqrt(sum(x^2) / n)
  static double calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sumOfSquares = 0.0;
    for (final sample in samples) {
      sumOfSquares += sample * sample;
    }

    return math.sqrt(sumOfSquares / samples.length);
  }

  /// Calculate peak amplitude for a segment of audio samples
  ///
  /// Returns the maximum absolute value in the segment
  static double calculatePeak(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double peak = 0.0;
    for (final sample in samples) {
      final absValue = sample.abs();
      if (absValue > peak) {
        peak = absValue;
      }
    }

    return peak;
  }

  /// Calculate both RMS and peak values for a segment
  ///
  /// More efficient than calling both methods separately
  static ({double rms, double peak}) calculateRMSAndPeak(List<double> samples) {
    if (samples.isEmpty) return (rms: 0.0, peak: 0.0);

    double sumOfSquares = 0.0;
    double peak = 0.0;

    for (final sample in samples) {
      final absValue = sample.abs();
      sumOfSquares += sample * sample;

      if (absValue > peak) {
        peak = absValue;
      }
    }

    final rms = math.sqrt(sumOfSquares / samples.length);
    return (rms: rms, peak: peak);
  }

  /// Downsample audio data to target resolution using configurable algorithm
  ///
  /// [samples] - Input audio samples
  /// [targetResolution] - Desired number of output data points
  /// [algorithm] - Algorithm to use for downsampling
  /// [channels] - Number of audio channels (for proper handling)
  static List<double> downsample(List<double> samples, int targetResolution, {DownsamplingAlgorithm algorithm = DownsamplingAlgorithm.rms, int channels = 1}) {
    if (samples.isEmpty || targetResolution <= 0) {
      return <double>[];
    }

    // If target resolution is greater than or equal to sample count, return as-is
    if (targetResolution >= samples.length ~/ channels) {
      return List<double>.from(samples);
    }

    final result = <double>[];
    final samplesPerChannel = samples.length ~/ channels;
    final samplesPerBin = samplesPerChannel / targetResolution;

    for (int i = 0; i < targetResolution; i++) {
      final startFrame = (i * samplesPerBin).floor();
      final endFrame = math.min(((i + 1) * samplesPerBin).floor(), samplesPerChannel);

      if (startFrame >= samplesPerChannel) break;

      // Fast paths: avoid allocating per-bin lists for common algorithms.
      double value;
      switch (algorithm) {
        case DownsamplingAlgorithm.rms:
          double sumSquares = 0.0;
          int count = 0;
          for (int frame = startFrame; frame < endFrame; frame++) {
            final base = frame * channels;

            double mixed = 0.0;
            int mixedCount = 0;
            for (int ch = 0; ch < channels; ch++) {
              final idx = base + ch;
              if (idx >= samples.length) break;
              mixed += samples[idx];
              mixedCount++;
            }

            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            sumSquares += mixed * mixed;
            count++;
          }
          value = count == 0 ? 0.0 : math.sqrt(sumSquares / count);
          break;

        case DownsamplingAlgorithm.peak:
          double peak = 0.0;
          for (int frame = startFrame; frame < endFrame; frame++) {
            final base = frame * channels;

            double mixed = 0.0;
            int mixedCount = 0;
            for (int ch = 0; ch < channels; ch++) {
              final idx = base + ch;
              if (idx >= samples.length) break;
              mixed += samples[idx];
              mixedCount++;
            }

            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            final absValue = mixed.abs();
            if (absValue > peak) peak = absValue;
          }
          value = peak;
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
              if (idx >= samples.length) break;
              mixed += samples[idx];
              mixedCount++;
            }

            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            sumAbs += mixed.abs();
            count++;
          }
          value = count == 0 ? 0.0 : (sumAbs / count);
          break;

        case DownsamplingAlgorithm.median:
          // Median needs access to all bin samples, so allocate only here.
          final binSamples = <double>[];
          for (int frame = startFrame; frame < endFrame; frame++) {
            final base = frame * channels;

            double mixed = 0.0;
            int mixedCount = 0;
            for (int ch = 0; ch < channels; ch++) {
              final idx = base + ch;
              if (idx >= samples.length) break;
              mixed += samples[idx];
              mixedCount++;
            }

            if (mixedCount == 0) continue;
            mixed /= mixedCount;
            binSamples.add(mixed);
          }
          value = calculateMedian(binSamples);
          break;
      }

      result.add(value);
    }

    return result;
  }

  /// Calculate average amplitude for a segment
  static double calculateAverage(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample.abs(); // Use absolute values for amplitude
    }

    return sum / samples.length;
  }

  /// Calculate median amplitude for a segment
  static double calculateMedian(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    final sortedSamples = samples.map((s) => s.abs()).toList()..sort();
    final length = sortedSamples.length;

    if (length.isOdd) {
      return sortedSamples[length ~/ 2];
    } else {
      final mid1 = sortedSamples[(length ~/ 2) - 1];
      final mid2 = sortedSamples[length ~/ 2];
      return (mid1 + mid2) / 2.0;
    }
  }

  /// Normalize amplitude values to 0.0-1.0 range
  ///
  /// [amplitudes] - Input amplitude values
  /// [method] - Normalization method to use
  static List<double> normalize(List<double> amplitudes, {NormalizationMethod method = NormalizationMethod.peak}) {
    if (amplitudes.isEmpty) return <double>[];

    double maxValue;
    switch (method) {
      case NormalizationMethod.peak:
        maxValue = amplitudes.reduce(math.max);
        break;
      case NormalizationMethod.rms:
        maxValue = calculateRMS(amplitudes);
        break;
    }

    if (maxValue == 0.0) return List.filled(amplitudes.length, 0.0);

    return amplitudes.map((amplitude) => amplitude / maxValue).toList();
  }

  /// Apply amplitude scaling with configurable curve
  ///
  /// [amplitudes] - Input amplitude values (should be normalized 0.0-1.0)
  /// [scalingCurve] - Type of scaling curve to apply
  /// [factor] - Scaling factor (default 1.0 = no scaling)
  static List<double> scaleAmplitudes(List<double> amplitudes, {ScalingCurve scalingCurve = ScalingCurve.linear, double factor = 1.0}) {
    if (amplitudes.isEmpty) return <double>[];

    return amplitudes.map((amplitude) {
      double scaledValue;

      switch (scalingCurve) {
        case ScalingCurve.linear:
          scaledValue = amplitude * factor;
          break;
        case ScalingCurve.logarithmic:
          // Logarithmic scaling for better visualization of quiet sounds
          scaledValue = amplitude > 0 ? math.log(1 + amplitude * 9) / math.log(10) * factor : 0.0;
          break;
        case ScalingCurve.exponential:
          // Exponential scaling for emphasizing loud sounds
          scaledValue = math.pow(amplitude, 2.0) * factor;
          break;
        case ScalingCurve.sqrt:
          // Square root scaling for balanced visualization
          scaledValue = math.sqrt(amplitude) * factor;
          break;
      }

      // Clamp to valid range
      return math.max(0.0, math.min(1.0, scaledValue));
    }).toList();
  }

  /// Detect peaks in amplitude data for enhanced visualization
  ///
  /// [amplitudes] - Input amplitude values
  /// [threshold] - Minimum threshold for peak detection (0.0-1.0)
  /// [minDistance] - Minimum distance between peaks (in samples)
  static List<int> detectPeaks(List<double> amplitudes, {double threshold = 0.1, int minDistance = 1}) {
    if (amplitudes.isEmpty || threshold < 0 || threshold > 1) {
      return <int>[];
    }

    final peaks = <int>[];

    for (int i = 1; i < amplitudes.length - 1; i++) {
      final current = amplitudes[i];
      final prev = amplitudes[i - 1];
      final next = amplitudes[i + 1];

      // Check if current sample is a local maximum above threshold
      if (current > threshold && current > prev && current > next) {
        // Check minimum distance constraint
        if (peaks.isEmpty || (i - peaks.last) >= minDistance) {
          peaks.add(i);
        }
      }
    }

    return peaks;
  }

  /// Apply smoothing filter to reduce noise in amplitude data
  ///
  /// [amplitudes] - Input amplitude values
  /// [windowSize] - Size of the smoothing window (must be odd)
  static List<double> smoothAmplitudes(List<double> amplitudes, {int windowSize = 3}) {
    if (amplitudes.isEmpty || windowSize < 3 || windowSize.isEven) {
      return List<double>.from(amplitudes);
    }

    final result = <double>[];
    final halfWindow = windowSize ~/ 2;

    for (int i = 0; i < amplitudes.length; i++) {
      double sum = 0.0;
      int count = 0;

      // Calculate average within window
      for (int j = math.max(0, i - halfWindow); j <= math.min(amplitudes.length - 1, i + halfWindow); j++) {
        sum += amplitudes[j];
        count++;
      }

      result.add(sum / count);
    }

    return result;
  }
}
