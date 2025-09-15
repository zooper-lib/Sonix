import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/waveform_type.dart';

void main() {
  group('Simplified Waveform Data Tests', () {
    test('should create WaveformData from amplitude list', () {
      final amplitudes = [0.1, 0.5, 0.8, 0.3, 0.9, 0.2];
      final waveformData = WaveformData.fromAmplitudes(amplitudes);

      expect(waveformData.amplitudes, equals(amplitudes));
      expect(waveformData.metadata.resolution, equals(6));
      expect(waveformData.metadata.type, equals(WaveformType.bars));
      expect(waveformData.metadata.normalized, isTrue);
    });

    test('should create WaveformData from amplitude JSON string', () {
      final amplitudeString = '[0.1, 0.5, 0.8, 0.3, 0.9, 0.2]';
      final waveformData = WaveformData.fromAmplitudeString(amplitudeString);

      expect(waveformData.amplitudes, equals([0.1, 0.5, 0.8, 0.3, 0.9, 0.2]));
      expect(waveformData.amplitudes.length, equals(6));
    });

    test('should handle empty amplitude list', () {
      final waveformData = WaveformData.fromAmplitudes([]);
      expect(waveformData.amplitudes, isEmpty);
      expect(waveformData.metadata.resolution, equals(0));
    });

    test('should handle single amplitude value', () {
      final waveformData = WaveformData.fromAmplitudes([0.7]);
      expect(waveformData.amplitudes, equals([0.7]));
      expect(waveformData.metadata.resolution, equals(1));
    });

    test('should preserve original JSON serialization', () {
      final originalData = {
        'amplitudes': [0.1, 0.5, 0.8, 0.3, 0.9, 0.2],
        'duration': 5000000,
        'sampleRate': 44100,
        'metadata': {'resolution': 6, 'type': 'bars', 'normalized': true, 'generatedAt': '2023-12-01T10:30:00.000Z'},
      };

      final waveformData = WaveformData.fromJson(originalData);
      expect(waveformData.amplitudes, equals([0.1, 0.5, 0.8, 0.3, 0.9, 0.2]));
      expect(waveformData.duration.inSeconds, equals(5));
      expect(waveformData.sampleRate, equals(44100));
    });
  });
}
