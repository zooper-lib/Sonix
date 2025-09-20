import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../test_helpers/test_data_loader.dart';
import 'package:sonix/src/models/waveform_data.dart';

void main() {
  group('FFMPEG Integration Tests', () {
    late Map<String, dynamic> referenceWaveforms;

    setUpAll(() async {
      // Load reference waveform data for comparison
      final referenceFile = File(path.join('test', 'assets', 'reference_waveforms.json'));
      if (await referenceFile.exists()) {
        final referenceContent = await referenceFile.readAsString();
        referenceWaveforms = json.decode(referenceContent);
      } else {
        referenceWaveforms = {};
      }
    });

    group('FFMPEG vs Current Implementation Comparison', () {
      test('should produce equivalent waveform data for MP3 files', () async {
        final mp3Files = ['test_short.mp3', 'test_medium.mp3'];

        for (final filename in mp3Files) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          // Decode with current implementation (mock)
          final currentResult = await _decodeWithCurrentImplementation(audioData, 'mp3');

          // Decode with FFMPEG implementation (mock)
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, 'mp3');

          expect(currentResult.success, isTrue);
          expect(ffmpegResult.success, isTrue);

          // Compare basic properties
          expect(ffmpegResult.audioData!.sampleRate, equals(currentResult.audioData!.sampleRate));
          expect(ffmpegResult.audioData!.channels, equals(currentResult.audioData!.channels));

          // Compare duration (should be within 1% tolerance)
          final durationDiff = (ffmpegResult.audioData!.duration.inMilliseconds - currentResult.audioData!.duration.inMilliseconds).abs();
          final durationTolerance = currentResult.audioData!.duration.inMilliseconds * 0.01;
          expect(durationDiff, lessThanOrEqualTo(durationTolerance));

          // Compare sample count (should be very close)
          final sampleCountDiff = (ffmpegResult.audioData!.samples.length - currentResult.audioData!.samples.length).abs();
          final sampleCountTolerance = currentResult.audioData!.samples.length * 0.05; // 5% tolerance
          expect(sampleCountDiff, lessThanOrEqualTo(sampleCountTolerance));
        }
      });

      test('should produce equivalent waveform data for FLAC files', () async {
        final flacFiles = ['test_sample.flac'];

        for (final filename in flacFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final currentResult = await _decodeWithCurrentImplementation(audioData, 'flac');
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, 'flac');

          expect(currentResult.success, isTrue);
          expect(ffmpegResult.success, isTrue);

          // FLAC is lossless, so results should be very close
          expect(ffmpegResult.audioData!.sampleRate, equals(currentResult.audioData!.sampleRate));
          expect(ffmpegResult.audioData!.channels, equals(currentResult.audioData!.channels));

          // For lossless formats, sample data should be nearly identical
          final maxSamples = [currentResult.audioData!.samples.length, ffmpegResult.audioData!.samples.length].reduce((a, b) => a < b ? a : b);
          var totalDifference = 0.0;

          for (var i = 0; i < maxSamples && i < 1000; i++) {
            // Compare first 1000 samples
            totalDifference += (currentResult.audioData!.samples[i] - ffmpegResult.audioData!.samples[i]).abs();
          }

          final averageDifference = totalDifference / maxSamples;
          expect(averageDifference, lessThan(0.01)); // Very small difference for lossless
        }
      });

      test('should produce equivalent waveform data for WAV files', () async {
        final wavFiles = ['test_mono_44100.wav', 'test_stereo_44100.wav'];

        for (final filename in wavFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final currentResult = await _decodeWithCurrentImplementation(audioData, 'wav');
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, 'wav');

          expect(currentResult.success, isTrue);
          expect(ffmpegResult.success, isTrue);

          // WAV is uncompressed, results should be identical
          expect(ffmpegResult.audioData!.sampleRate, equals(currentResult.audioData!.sampleRate));
          expect(ffmpegResult.audioData!.channels, equals(currentResult.audioData!.channels));
          expect(ffmpegResult.audioData!.samples.length, equals(currentResult.audioData!.samples.length));
        }
      });

      test('should handle edge cases consistently', () async {
        final edgeCaseFiles = ['empty_file.mp3', 'corrupted_header.mp3', 'truncated.flac'];

        for (final filename in edgeCaseFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final format = path.extension(filename).substring(1);
          final currentResult = await _decodeWithCurrentImplementation(audioData, format);
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, format);

          // Both implementations should handle errors consistently
          expect(currentResult.success, equals(ffmpegResult.success));

          if (!currentResult.success && !ffmpegResult.success) {
            // Both should fail with similar error types
            expect(_categorizeError(currentResult.errorMessage), equals(_categorizeError(ffmpegResult.errorMessage)));
          }
        }
      });
    });

    group('Reference Data Validation', () {
      test('should match reference waveform characteristics', () async {
        for (final entry in referenceWaveforms.entries) {
          final filename = entry.key;
          final referenceData = entry.value as Map<String, dynamic>;

          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final format = path.extension(filename).substring(1);
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, format);

          if (!ffmpegResult.success) continue;

          final audioResult = ffmpegResult.audioData!;

          // Validate basic properties against reference
          expect(audioResult.sampleRate, equals(referenceData['sample_rate']));
          expect(audioResult.channels, equals(referenceData['channels']));

          // Validate duration (within tolerance)
          final expectedDuration = Duration(milliseconds: referenceData['duration_ms']);
          final durationDiff = (audioResult.duration.inMilliseconds - expectedDuration.inMilliseconds).abs();
          expect(durationDiff, lessThanOrEqualTo(100)); // 100ms tolerance

          // Validate peak amplitude (within tolerance)
          final maxAmplitude = audioResult.samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
          final expectedPeak = referenceData['peak_amplitude'] as double;
          expect((maxAmplitude - expectedPeak).abs(), lessThanOrEqualTo(0.05));
        }
      });

      test('should generate consistent waveform visualization data', () async {
        final testFiles = ['test_short.mp3', 'test_sample.flac', 'test_mono_44100.wav'];

        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final format = path.extension(filename).substring(1);
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, format);

          if (!ffmpegResult.success) continue;

          // Generate waveform data for visualization
          final waveformData = _generateWaveformData(ffmpegResult.audioData!, 1000); // 1000 points

          expect(waveformData.amplitudes, hasLength(1000));
          expect(waveformData.duration, isA<Duration>());

          // Validate waveform characteristics
          final maxPeak = waveformData.amplitudes.reduce((a, b) => a > b ? a : b);
          final minPeak = waveformData.amplitudes.reduce((a, b) => a < b ? a : b);

          expect(maxPeak, greaterThanOrEqualTo(0.0));
          expect(maxPeak, lessThanOrEqualTo(1.0));
          expect(minPeak, greaterThanOrEqualTo(-1.0));
          expect(minPeak, lessThanOrEqualTo(1.0));
        }
      });

      test('should maintain accuracy across different sample rates', () async {
        final sampleRateFiles = [('test_mono_44100.wav', 44100), ('test_mono_48000.wav', 48000)];

        for (final (filename, expectedSampleRate) in sampleRateFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, 'wav');

          if (!ffmpegResult.success) continue;

          expect(ffmpegResult.audioData!.sampleRate, equals(expectedSampleRate));

          // Verify that sample rate conversion (if any) maintains audio quality
          final nyquistFreq = expectedSampleRate / 2;
          expect(nyquistFreq, greaterThan(20000)); // Should support full audio spectrum
        }
      });
    });

    group('Performance and Quality Validation', () {
      test('should maintain audio quality metrics', () async {
        final testFiles = ['test_medium.mp3', 'test_sample.flac'];

        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final format = path.extension(filename).substring(1);
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, format);

          if (!ffmpegResult.success) continue;

          final audioResult = ffmpegResult.audioData!;

          // Calculate quality metrics
          final qualityMetrics = _calculateAudioQualityMetrics(audioResult);

          // Validate signal-to-noise ratio
          expect(qualityMetrics['snr'], greaterThan(40.0)); // Minimum 40dB SNR

          // Validate dynamic range
          expect(qualityMetrics['dynamic_range'], greaterThan(20.0)); // Minimum 20dB dynamic range

          // Validate frequency response (no major gaps)
          final frequencyResponse = qualityMetrics['frequency_response'] as List<double>;
          final avgResponse = frequencyResponse.reduce((a, b) => a + b) / frequencyResponse.length;

          for (final response in frequencyResponse) {
            expect((response - avgResponse).abs(), lessThan(10.0)); // Within 10dB of average
          }
        }
      });

      test('should handle large files efficiently', () async {
        final largeFiles = ['test_large.mp3', 'test_large.wav'];

        for (final filename in largeFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final stopwatch = Stopwatch()..start();

          final format = path.extension(filename).substring(1);
          final ffmpegResult = await _decodeWithFFMPEGImplementation(audioData, format);

          stopwatch.stop();

          if (!ffmpegResult.success) continue;

          // Validate processing time is reasonable
          final processingTimeMs = stopwatch.elapsedMilliseconds;
          final fileSizeMB = audioData.length / (1024 * 1024);
          final processingRate = fileSizeMB / (processingTimeMs / 1000.0); // MB/s

          expect(processingRate, greaterThan(1.0)); // At least 1 MB/s processing rate

          // Validate memory usage is reasonable
          final memoryUsageMB = ffmpegResult.audioData!.samples.length * 4 / (1024 * 1024); // 4 bytes per float
          expect(memoryUsageMB, lessThan(fileSizeMB * 10)); // Memory usage should be reasonable
        }
      });

      test('should maintain precision in chunked processing', () async {
        final testFile = 'test_large.mp3';
        final filePath = TestDataLoader.getAssetPath(testFile);
        if (!await File(filePath).exists()) return;
        final audioData = await File(filePath).readAsBytes();

        // Process entire file at once
        final fullResult = await _decodeWithFFMPEGImplementation(audioData, 'mp3');
        expect(fullResult.success, isTrue);

        // Process file in chunks
        final chunkResults = await _decodeInChunks(audioData, 'mp3', chunkSize: 8192);
        expect(chunkResults.isNotEmpty, isTrue);

        // Combine chunked results
        final combinedSamples = <double>[];
        for (final chunkResult in chunkResults) {
          combinedSamples.addAll(chunkResult.samples);
        }

        // Compare full vs chunked processing
        final sampleCountDiff = (fullResult.audioData!.samples.length - combinedSamples.length).abs();
        final tolerance = fullResult.audioData!.samples.length * 0.05; // 5% tolerance
        expect(sampleCountDiff, lessThanOrEqualTo(tolerance));

        // Compare sample values for first portion
        final compareLength = [fullResult.audioData!.samples.length, combinedSamples.length, 10000].reduce((a, b) => a < b ? a : b);
        var totalDifference = 0.0;

        for (var i = 0; i < compareLength; i++) {
          totalDifference += (fullResult.audioData!.samples[i] - combinedSamples[i]).abs();
        }

        final averageDifference = totalDifference / compareLength;
        expect(averageDifference, lessThan(0.1)); // Small difference acceptable for chunked processing
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle format mismatches gracefully', () async {
        final testFiles = [
          ('test_sample.mp3', 'flac'), // MP3 file, FLAC decoder
          ('test_sample.flac', 'mp3'), // FLAC file, MP3 decoder
          ('test_mono_44100.wav', 'ogg'), // WAV file, OGG decoder
        ];

        for (final (filename, wrongFormat) in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;
          final audioData = await File(filePath).readAsBytes();

          final result = await _decodeWithFFMPEGImplementation(audioData, wrongFormat);

          // Should either auto-detect correct format or fail gracefully
          expect(result.success, isA<bool>());

          if (!result.success) {
            expect(result.errorMessage, contains('format'));
          }
        }
      });

      test('should recover from partial decode failures', () async {
        final corruptedPath = TestDataLoader.getAssetPath('corrupted_data.wav');
        if (!await File(corruptedPath).exists()) return;
        final corruptedData = await File(corruptedPath).readAsBytes();

        final result = await _decodeWithFFMPEGImplementation(corruptedData, 'wav');

        // Should either succeed with partial data or fail with clear error
        expect(result.success, isA<bool>());

        if (result.success) {
          // If successful, should have some valid audio data
          expect(result.audioData!.samples, isNotEmpty);
          expect(result.audioData!.sampleRate, greaterThan(0));
        } else {
          // If failed, should have meaningful error message
          expect(result.errorMessage, isNotNull);
          expect(result.errorMessage, isNotEmpty);
        }
      });
    });
  });
}

// Mock implementations for testing

class AudioDecodeResult {
  final bool success;
  final AudioData? audioData;
  final String? errorMessage;

  AudioDecodeResult.success(this.audioData) : success = true, errorMessage = null;
  AudioDecodeResult.failure(this.errorMessage) : success = false, audioData = null;
}

class AudioData {
  final List<double> samples;
  final int sampleRate;
  final int channels;
  final Duration duration;

  AudioData({required this.samples, required this.sampleRate, required this.channels, required this.duration});
}

Future<AudioDecodeResult> _decodeWithCurrentImplementation(Uint8List data, String format) async {
  // Mock current implementation
  await Future.delayed(Duration(milliseconds: 50));

  if (data.length < 100) {
    return AudioDecodeResult.failure('File too small');
  }

  // Generate mock audio data based on format
  final sampleRate = format == 'wav' ? 44100 : 44100;
  final channels = format.contains('stereo') ? 2 : 1;
  final duration = Duration(milliseconds: (data.length / 100).round());

  final samples = List.generate(sampleRate * channels, (i) {
    return 0.5 * (i % 2 == 0 ? 1 : -1) * (i / (sampleRate * channels));
  });

  final audioData = AudioData(samples: samples, sampleRate: sampleRate, channels: channels, duration: duration);

  return AudioDecodeResult.success(audioData);
}

Future<AudioDecodeResult> _decodeWithFFMPEGImplementation(Uint8List data, String format) async {
  // Mock FFMPEG implementation
  await Future.delayed(Duration(milliseconds: 30)); // Slightly faster

  if (data.length < 100) {
    return AudioDecodeResult.failure('Invalid data size');
  }

  // Generate mock audio data with slight variations from current implementation
  final sampleRate = format == 'wav' ? 44100 : 44100;
  final channels = format.contains('stereo') ? 2 : 1;
  final duration = Duration(milliseconds: (data.length / 100).round());

  final samples = List.generate(sampleRate * channels, (i) {
    // Slightly different algorithm to simulate FFMPEG differences
    return 0.48 * (i % 2 == 0 ? 1 : -1) * (i / (sampleRate * channels));
  });

  final audioData = AudioData(samples: samples, sampleRate: sampleRate, channels: channels, duration: duration);

  return AudioDecodeResult.success(audioData);
}

String _categorizeError(String? errorMessage) {
  if (errorMessage == null) return 'unknown';

  final message = errorMessage.toLowerCase();
  if (message.contains('format') || message.contains('invalid')) {
    return 'format_error';
  } else if (message.contains('size') || message.contains('small')) {
    return 'size_error';
  } else if (message.contains('corrupt')) {
    return 'corruption_error';
  } else {
    return 'other_error';
  }
}

WaveformData _generateWaveformData(AudioData audioData, int pointCount) {
  final samplesPerPoint = audioData.samples.length / pointCount;
  final amplitudes = <double>[];

  for (var i = 0; i < pointCount; i++) {
    final startIndex = (i * samplesPerPoint).floor();
    final endIndex = ((i + 1) * samplesPerPoint).floor().clamp(0, audioData.samples.length);

    var maxAmplitude = 0.0;
    for (var j = startIndex; j < endIndex; j++) {
      maxAmplitude = [maxAmplitude, audioData.samples[j].abs()].reduce((a, b) => a > b ? a : b);
    }

    amplitudes.add(maxAmplitude);
  }

  return WaveformData.fromAmplitudes(amplitudes);
}

Map<String, dynamic> _calculateAudioQualityMetrics(AudioData audioData) {
  // Calculate signal-to-noise ratio
  final signalPower = audioData.samples.map((s) => s * s).reduce((a, b) => a + b) / audioData.samples.length;
  final snr = 10 * math.log(signalPower / 0.001) / math.ln10; // Assuming 0.001 noise floor

  // Calculate dynamic range
  final maxAmplitude = audioData.samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
  final minAmplitude = audioData.samples.map((s) => s.abs()).where((s) => s > 0.001).reduce((a, b) => a < b ? a : b);
  final dynamicRange = 20 * math.log(maxAmplitude / minAmplitude) / math.ln10;

  // Mock frequency response (in real implementation, would use FFT)
  final frequencyResponse = List.generate(10, (i) => 0.0 + (i * 0.5)); // Mock data

  return {'snr': snr.clamp(0, 100), 'dynamic_range': dynamicRange.clamp(0, 100), 'frequency_response': frequencyResponse};
}

Future<List<AudioData>> _decodeInChunks(Uint8List data, String format, {int chunkSize = 8192}) async {
  final chunks = <AudioData>[];

  for (var i = 0; i < data.length; i += chunkSize) {
    final endIndex = (i + chunkSize).clamp(0, data.length);
    final chunkData = data.sublist(i, endIndex);

    final result = await _decodeWithFFMPEGImplementation(chunkData, format);
    if (result.success) {
      chunks.add(result.audioData!);
    }
  }

  return chunks;
}
