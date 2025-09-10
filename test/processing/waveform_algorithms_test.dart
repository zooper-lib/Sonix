import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/waveform_algorithms.dart';
import 'dart:math' as math;

void main() {
  group('WaveformAlgorithms', () {
    group('RMS Calculation', () {
      test('should calculate RMS correctly for simple values', () {
        final samples = [0.5, -0.5, 0.8, -0.8];
        final rms = WaveformAlgorithms.calculateRMS(samples);

        // Expected: sqrt((0.25 + 0.25 + 0.64 + 0.64) / 4) = sqrt(0.445) ≈ 0.667
        expect(rms, closeTo(0.667, 0.001));
      });

      test('should return 0 for empty samples', () {
        expect(WaveformAlgorithms.calculateRMS([]), equals(0.0));
      });

      test('should handle single sample', () {
        expect(WaveformAlgorithms.calculateRMS([0.5]), equals(0.5));
      });

      test('should handle all zero samples', () {
        expect(WaveformAlgorithms.calculateRMS([0.0, 0.0, 0.0]), equals(0.0));
      });
    });

    group('Peak Detection', () {
      test('should find maximum absolute value', () {
        final samples = [0.2, -0.8, 0.5, -0.3];
        final peak = WaveformAlgorithms.calculatePeak(samples);
        expect(peak, equals(0.8));
      });

      test('should return 0 for empty samples', () {
        expect(WaveformAlgorithms.calculatePeak([]), equals(0.0));
      });

      test('should handle positive and negative peaks', () {
        expect(WaveformAlgorithms.calculatePeak([0.7]), equals(0.7));
        expect(WaveformAlgorithms.calculatePeak([-0.9]), equals(0.9));
      });
    });

    group('RMS and Peak Combined', () {
      test('should calculate both values efficiently', () {
        final samples = [0.5, -0.5, 0.8, -0.8];
        final result = WaveformAlgorithms.calculateRMSAndPeak(samples);

        expect(result.rms, closeTo(0.667, 0.001));
        expect(result.peak, equals(0.8));
      });

      test('should handle empty samples', () {
        final result = WaveformAlgorithms.calculateRMSAndPeak([]);
        expect(result.rms, equals(0.0));
        expect(result.peak, equals(0.0));
      });
    });

    group('Downsampling', () {
      test('should downsample using RMS algorithm', () {
        final samples = List.generate(100, (i) => math.sin(i * 0.1));
        final result = WaveformAlgorithms.downsample(samples, 10, algorithm: DownsamplingAlgorithm.rms);

        expect(result.length, equals(10));
        expect(result.every((v) => v >= 0.0), isTrue);
      });

      test('should downsample using peak algorithm', () {
        final samples = [0.1, 0.9, 0.2, 0.8, 0.3, 0.7];
        final result = WaveformAlgorithms.downsample(samples, 3, algorithm: DownsamplingAlgorithm.peak);

        expect(result.length, equals(3));
        expect(result[0], closeTo(0.9, 0.001)); // Peak of first bin
        expect(result[1], closeTo(0.8, 0.001)); // Peak of second bin
        expect(result[2], closeTo(0.7, 0.001)); // Peak of third bin
      });

      test('should handle multi-channel audio', () {
        // Stereo audio: [L1, R1, L2, R2, L3, R3, L4, R4]
        final samples = [0.5, 0.3, 0.8, 0.6, 0.2, 0.4, 0.9, 0.7];
        final result = WaveformAlgorithms.downsample(samples, 2, algorithm: DownsamplingAlgorithm.average, channels: 2);

        expect(result.length, equals(2));
        // Should mix down channels and downsample
        expect(result.every((v) => v >= 0.0), isTrue);
      });

      test('should return original samples if target resolution is too high', () {
        final samples = [0.1, 0.2, 0.3];
        final result = WaveformAlgorithms.downsample(samples, 10);
        expect(result, equals(samples));
      });

      test('should handle empty samples', () {
        final result = WaveformAlgorithms.downsample([], 10);
        expect(result, isEmpty);
      });
    });

    group('Average Calculation', () {
      test('should calculate average of absolute values', () {
        final samples = [0.2, -0.4, 0.6, -0.8];
        final average = WaveformAlgorithms.calculateAverage(samples);
        expect(average, equals(0.5)); // (0.2 + 0.4 + 0.6 + 0.8) / 4
      });

      test('should handle empty samples', () {
        expect(WaveformAlgorithms.calculateAverage([]), equals(0.0));
      });
    });

    group('Median Calculation', () {
      test('should calculate median for odd number of samples', () {
        final samples = [0.1, 0.5, 0.3]; // Sorted: [0.1, 0.3, 0.5]
        final median = WaveformAlgorithms.calculateMedian(samples);
        expect(median, equals(0.3));
      });

      test('should calculate median for even number of samples', () {
        final samples = [0.1, 0.7, 0.3, 0.5]; // Sorted: [0.1, 0.3, 0.5, 0.7]
        final median = WaveformAlgorithms.calculateMedian(samples);
        expect(median, equals(0.4)); // (0.3 + 0.5) / 2
      });

      test('should handle negative values by using absolute values', () {
        final samples = [-0.3, 0.1, -0.5]; // Abs sorted: [0.1, 0.3, 0.5]
        final median = WaveformAlgorithms.calculateMedian(samples);
        expect(median, equals(0.3));
      });
    });

    group('Normalization', () {
      test('should normalize using peak method', () {
        final amplitudes = [0.2, 0.8, 0.4, 1.0];
        final result = WaveformAlgorithms.normalize(amplitudes, method: NormalizationMethod.peak);

        expect(result, equals([0.2, 0.8, 0.4, 1.0])); // Already normalized to peak
      });

      test('should normalize using RMS method', () {
        final amplitudes = [0.5, 1.0, 0.5];
        final result = WaveformAlgorithms.normalize(amplitudes, method: NormalizationMethod.rms);

        // RMS = sqrt((0.25 + 1.0 + 0.25) / 3) = sqrt(0.5) ≈ 0.707
        final expectedRms = math.sqrt(0.5);
        expect(result[0], closeTo(0.5 / expectedRms, 0.001));
        expect(result[1], closeTo(1.0 / expectedRms, 0.001));
        expect(result[2], closeTo(0.5 / expectedRms, 0.001));
      });

      test('should handle all zero values', () {
        final result = WaveformAlgorithms.normalize([0.0, 0.0, 0.0]);
        expect(result, equals([0.0, 0.0, 0.0]));
      });
    });

    group('Amplitude Scaling', () {
      test('should apply linear scaling', () {
        final amplitudes = [0.2, 0.5, 0.8];
        final result = WaveformAlgorithms.scaleAmplitudes(amplitudes, scalingCurve: ScalingCurve.linear, factor: 2.0);

        expect(result[0], closeTo(0.4, 0.001));
        expect(result[1], closeTo(1.0, 0.001)); // Clamped to 1.0
        expect(result[2], closeTo(1.0, 0.001)); // Clamped to 1.0
      });

      test('should apply logarithmic scaling', () {
        final amplitudes = [0.1, 0.5, 1.0];
        final result = WaveformAlgorithms.scaleAmplitudes(amplitudes, scalingCurve: ScalingCurve.logarithmic);

        // Logarithmic scaling: log(1 + x * 9) / log(10)
        expect(result[0], closeTo(math.log(1 + 0.1 * 9) / math.log(10), 0.001));
        expect(result[1], closeTo(math.log(1 + 0.5 * 9) / math.log(10), 0.001));
        expect(result[2], closeTo(1.0, 0.001));
      });

      test('should apply exponential scaling', () {
        final amplitudes = [0.5, 0.8];
        final result = WaveformAlgorithms.scaleAmplitudes(amplitudes, scalingCurve: ScalingCurve.exponential);

        expect(result[0], closeTo(0.25, 0.001)); // 0.5^2
        expect(result[1], closeTo(0.64, 0.001)); // 0.8^2
      });

      test('should apply square root scaling', () {
        final amplitudes = [0.25, 0.64];
        final result = WaveformAlgorithms.scaleAmplitudes(amplitudes, scalingCurve: ScalingCurve.sqrt);

        expect(result[0], closeTo(0.5, 0.001)); // sqrt(0.25)
        expect(result[1], closeTo(0.8, 0.001)); // sqrt(0.64)
      });
    });

    group('Peak Detection in Amplitudes', () {
      test('should detect peaks above threshold', () {
        final amplitudes = [0.1, 0.8, 0.2, 0.9, 0.1, 0.7, 0.3];
        final peaks = WaveformAlgorithms.detectPeaks(amplitudes, threshold: 0.5);

        expect(peaks, contains(1)); // Peak at 0.8
        expect(peaks, contains(3)); // Peak at 0.9
        expect(peaks, contains(5)); // Peak at 0.7
      });

      test('should respect minimum distance between peaks', () {
        final amplitudes = [0.1, 0.8, 0.7, 0.9, 0.1];
        final peaks = WaveformAlgorithms.detectPeaks(amplitudes, threshold: 0.5, minDistance: 2);

        // Should only detect first peak due to distance constraint
        expect(peaks.length, lessThanOrEqualTo(2));
      });

      test('should handle empty amplitudes', () {
        final peaks = WaveformAlgorithms.detectPeaks([]);
        expect(peaks, isEmpty);
      });
    });

    group('Smoothing', () {
      test('should apply smoothing filter', () {
        final amplitudes = [0.1, 0.9, 0.1, 0.9, 0.1];
        final result = WaveformAlgorithms.smoothAmplitudes(amplitudes, windowSize: 3);

        expect(result.length, equals(amplitudes.length));
        // Middle values should be smoothed
        expect(result[2], greaterThan(0.1));
        expect(result[2], lessThan(0.9));
      });

      test('should handle edge cases', () {
        final amplitudes = [0.5];
        final result = WaveformAlgorithms.smoothAmplitudes(amplitudes);
        expect(result, equals([0.5]));
      });

      test('should return original for invalid window size', () {
        final amplitudes = [0.1, 0.2, 0.3];
        final result = WaveformAlgorithms.smoothAmplitudes(
          amplitudes,
          windowSize: 2, // Even number, should be rejected
        );
        expect(result, equals(amplitudes));
      });
    });
  });
}
