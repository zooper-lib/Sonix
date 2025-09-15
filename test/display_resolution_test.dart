import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/display_sampler.dart';
import 'package:sonix/src/models/waveform_type.dart';
import 'package:sonix/src/processing/downsample_method.dart';
import 'package:sonix/src/processing/upsample_method.dart';

void main() {
  group('DisplaySampler', () {
    test('should calculate correct display resolution for bars', () {
      // Test with 300px width, 3px bars, 1px spacing
      final resolution = DisplaySampler.calculateDisplayResolution(availableWidth: 300.0, barWidth: 3.0, barSpacing: 1.0, waveformType: WaveformType.bars);

      // 300px ÷ (3px + 1px) = 75 bars
      expect(resolution, equals(75));
    });

    test('should calculate correct display resolution for wide bars', () {
      // Test with 300px width, 6px bars, 2px spacing
      final resolution = DisplaySampler.calculateDisplayResolution(availableWidth: 300.0, barWidth: 6.0, barSpacing: 2.0, waveformType: WaveformType.bars);

      // 300px ÷ (6px + 2px) = 37 bars
      expect(resolution, equals(37));
    });

    test('should downsample amplitude data correctly', () {
      // 1000 data points → 100 display points
      final sourceAmplitudes = List.generate(1000, (i) => (i % 10) / 10.0);

      final result = DisplaySampler.resampleForDisplay(sourceAmplitudes: sourceAmplitudes, targetCount: 100, downsampleMethod: DownsampleMethod.max);

      expect(result.length, equals(100));
      expect(result.every((amplitude) => amplitude >= 0.0 && amplitude <= 1.0), isTrue);
    });

    test('should upsample amplitude data correctly', () {
      // 50 data points → 200 display points
      final sourceAmplitudes = [0.1, 0.5, 0.8, 0.3, 0.9];

      final result = DisplaySampler.resampleForDisplay(sourceAmplitudes: sourceAmplitudes, targetCount: 20, upsampleMethod: UpsampleMethod.linear);

      expect(result.length, equals(20));
      expect(result.first, equals(0.1)); // First point preserved
      expect(result.last, equals(0.9)); // Last point preserved
    });

    test('should handle edge cases', () {
      // Empty input
      final emptyResult = DisplaySampler.resampleForDisplay(sourceAmplitudes: [], targetCount: 10);
      expect(emptyResult, isEmpty);

      // Zero target count
      final zeroResult = DisplaySampler.resampleForDisplay(sourceAmplitudes: [0.1, 0.5, 0.8], targetCount: 0);
      expect(zeroResult, isEmpty);

      // Same size
      final sameResult = DisplaySampler.resampleForDisplay(sourceAmplitudes: [0.1, 0.5, 0.8], targetCount: 3);
      expect(sameResult, equals([0.1, 0.5, 0.8]));
    });

    test('should preserve amplitude ranges during downsampling', () {
      // Create test data with known peaks
      final sourceAmplitudes = [
        0.1, 0.9, 0.1, // Group 1: max = 0.9
        0.2, 0.8, 0.2, // Group 2: max = 0.8
        0.3, 0.7, 0.3, // Group 3: max = 0.7
      ];

      final result = DisplaySampler.resampleForDisplay(sourceAmplitudes: sourceAmplitudes, targetCount: 3, downsampleMethod: DownsampleMethod.max);

      expect(result.length, equals(3));
      expect(result[0], closeTo(0.9, 0.01)); // First group max
      expect(result[1], closeTo(0.8, 0.01)); // Second group max
      expect(result[2], closeTo(0.7, 0.01)); // Third group max
    });

    test('should use different downsampling methods correctly', () {
      final sourceAmplitudes = [0.0, 1.0, 0.0, 1.0]; // Alternating pattern

      // Max method should preserve peaks
      final maxResult = DisplaySampler.resampleForDisplay(sourceAmplitudes: sourceAmplitudes, targetCount: 2, downsampleMethod: DownsampleMethod.max);
      expect(maxResult.every((amp) => amp > 0.5), isTrue); // All should be high values

      // Average method should smooth
      final avgResult = DisplaySampler.resampleForDisplay(sourceAmplitudes: sourceAmplitudes, targetCount: 2, downsampleMethod: DownsampleMethod.average);
      expect(avgResult.every((amp) => amp == 0.5), isTrue); // All should be 0.5
    });
  });
}
