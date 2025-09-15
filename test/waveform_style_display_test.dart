import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('WaveformStyle Display Resolution', () {
    test('should create WaveformStyle with default display resolution settings', () {
      const style = WaveformStyle();

      expect(style.autoDisplayResolution, isTrue);
      expect(style.fixedDisplayResolution, isNull);
      expect(style.displayDensity, isNull);
      expect(style.downsampleMethod, equals(DownsampleMethod.max));
      expect(style.upsampleMethod, equals(UpsampleMethod.linear));
    });

    test('should create WaveformStyle with custom display resolution settings', () {
      const style = WaveformStyle(
        barWidth: 4.0,
        barSpacing: 2.0,
        autoDisplayResolution: false,
        fixedDisplayResolution: 50,
        displayDensity: 2.0,
        downsampleMethod: DownsampleMethod.rms,
        upsampleMethod: UpsampleMethod.repeat,
      );

      expect(style.barWidth, equals(4.0));
      expect(style.barSpacing, equals(2.0));
      expect(style.autoDisplayResolution, isFalse);
      expect(style.fixedDisplayResolution, equals(50));
      expect(style.displayDensity, equals(2.0));
      expect(style.downsampleMethod, equals(DownsampleMethod.rms));
      expect(style.upsampleMethod, equals(UpsampleMethod.repeat));
    });

    test('should copy WaveformStyle with modified display resolution properties', () {
      const originalStyle = WaveformStyle(barWidth: 2.0, autoDisplayResolution: true);

      final modifiedStyle = originalStyle.copyWith(
        barWidth: 5.0,
        autoDisplayResolution: false,
        fixedDisplayResolution: 100,
        downsampleMethod: DownsampleMethod.average,
      );

      expect(modifiedStyle.barWidth, equals(5.0));
      expect(modifiedStyle.autoDisplayResolution, isFalse);
      expect(modifiedStyle.fixedDisplayResolution, equals(100));
      expect(modifiedStyle.downsampleMethod, equals(DownsampleMethod.average));

      // Other properties should remain unchanged
      expect(modifiedStyle.playedColor, equals(originalStyle.playedColor));
      expect(modifiedStyle.height, equals(originalStyle.height));
    });

    test('should maintain equality for WaveformStyle with same display resolution properties', () {
      const style1 = WaveformStyle(barWidth: 3.0, autoDisplayResolution: true, downsampleMethod: DownsampleMethod.max);

      const style2 = WaveformStyle(barWidth: 3.0, autoDisplayResolution: true, downsampleMethod: DownsampleMethod.max);

      expect(style1, equals(style2));
      expect(style1.hashCode, equals(style2.hashCode));
    });

    test('should not be equal for WaveformStyle with different display resolution properties', () {
      const style1 = WaveformStyle(autoDisplayResolution: true, downsampleMethod: DownsampleMethod.max);

      const style2 = WaveformStyle(autoDisplayResolution: false, downsampleMethod: DownsampleMethod.average);

      expect(style1, isNot(equals(style2)));
    });

    test('should work with WaveformData and display resolution calculations', () {
      // Create test waveform data
      final testAmplitudes = List.generate(1000, (i) => (i % 100) / 100.0);
      final waveformData = WaveformData.fromAmplitudes(testAmplitudes);

      expect(waveformData.amplitudes.length, equals(1000));

      // Test display resolution calculation
      final displayResolution = DisplaySampler.calculateDisplayResolution(
        availableWidth: 300.0,
        barWidth: 2.0,
        barSpacing: 1.0,
        waveformType: WaveformType.bars,
      );

      // Should fit 100 bars in 300px with 2px width + 1px spacing
      expect(displayResolution, equals(100));

      // Test resampling from 1000 to 100 points
      final displayAmplitudes = DisplaySampler.resampleForDisplay(
        sourceAmplitudes: waveformData.amplitudes,
        targetCount: displayResolution,
        downsampleMethod: DownsampleMethod.max,
      );

      expect(displayAmplitudes.length, equals(100));
      expect(displayAmplitudes.every((amp) => amp >= 0.0 && amp <= 1.0), isTrue);
    });
  });
}
