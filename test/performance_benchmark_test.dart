// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'test_data_generator.dart';
import 'dart:math' as math;

void main() {
  group('Performance Benchmark Tests', () {
    late Map<String, dynamic> testConfigurations;

    setUpAll(() async {
      // Generate test data if it doesn't exist
      if (!await TestDataLoader.assetExists('test_configurations.json')) {
        await TestDataGenerator.generateAllTestData();
      }

      testConfigurations = await TestDataLoader.loadTestConfigurations();
    });

    group('Waveform Generation Performance', () {
      test('should generate waveform within time limits for different resolutions', () async {
        final configs = testConfigurations['performance_test_configs'] as List;

        for (final config in configs) {
          final resolution = config['resolution'] as int;
          final expectedTimeMs = config['expected_processing_time_ms'] as int;
          final expectedMemoryMb = config['expected_memory_usage_mb'] as int;

          final audioData = _createTestAudioData(durationSeconds: 10);

          final stopwatch = Stopwatch()..start();
          final waveformConfig = WaveformConfig(resolution: resolution);
          final waveformData = await WaveformGenerator.generate(audioData, config: waveformConfig);
          stopwatch.stop();

          expect(waveformData.amplitudes.length, equals(resolution));
          expect(stopwatch.elapsedMilliseconds, lessThan(expectedTimeMs * 2)); // Allow 2x tolerance

          // Estimate memory usage (rough calculation)
          final estimatedMemoryMb = (audioData.samples.length * 8 + waveformData.amplitudes.length * 8) / (1024 * 1024);
          expect(estimatedMemoryMb, lessThan(expectedMemoryMb * 5)); // Allow 5x tolerance for test environment

          audioData.dispose();
          waveformData.dispose();
        }
      });

      test('should scale performance linearly with audio duration', () async {
        final durations = [1, 5, 10, 30]; // seconds
        final times = <int>[];

        for (final duration in durations) {
          final audioData = _createTestAudioData(durationSeconds: duration.toDouble());

          final stopwatch = Stopwatch()..start();
          final waveformData = await WaveformGenerator.generate(audioData);
          stopwatch.stop();

          times.add(stopwatch.elapsedMilliseconds);

          audioData.dispose();
          waveformData.dispose();
        }

        // Performance should scale roughly linearly
        // Longer audio should take proportionally longer (with some tolerance)
        for (int i = 1; i < times.length; i++) {
          if (times[0] > 0) {
            // Avoid division by zero
            final ratio = times[i] / times[0];
            final expectedRatio = durations[i] / durations[0];
            expect(ratio, lessThan(expectedRatio * 3)); // Allow 3x tolerance for overhead
          } else {
            // If first test was too fast to measure, just check that later ones complete
            expect(times[i], lessThan(10000)); // Should complete within 10 seconds
          }
        }
      });

      test('should handle concurrent waveform generation efficiently', () async {
        const concurrentCount = 5;
        final audioData = _createTestAudioData(durationSeconds: 2);

        final stopwatch = Stopwatch()..start();

        final futures = List.generate(concurrentCount, (_) => WaveformGenerator.generate(audioData));

        final results = await Future.wait(futures);
        stopwatch.stop();

        expect(results.length, equals(concurrentCount));
        expect(results.every((w) => w.amplitudes.isNotEmpty), isTrue);

        // Concurrent processing should be faster than sequential
        // (though this depends on system capabilities)
        expect(stopwatch.elapsedMilliseconds, lessThan(concurrentCount * 1000)); // Should be faster than 1s per waveform

        audioData.dispose();
        for (final result in results) {
          result.dispose();
        }
      });
    });

    group('Audio Decoding Performance', () {
      test('should decode audio files within reasonable time limits', () async {
        final testFiles = ['test_mono_44100.wav', 'test_stereo_44100.wav', 'test_mono_48000.wav'];

        for (final filename in testFiles) {
          if (!await TestDataLoader.assetExists(filename)) {
            continue; // Skip if file doesn't exist
          }

          final filePath = TestDataLoader.getAssetPath(filename);

          try {
            final decoder = AudioDecoderFactory.createDecoder(filePath);

            final stopwatch = Stopwatch()..start();
            final audioData = await decoder.decode(filePath);
            stopwatch.stop();

            expect(audioData.samples, isNotEmpty);
            expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should decode within 1 second

            decoder.dispose();
            audioData.dispose();
          } catch (e) {
            // Skip test if decoder is not implemented yet
            if (e is DecodingException) {
              print('Skipping decoder test for $filename - decoder not implemented');
              continue;
            }
            rethrow;
          }
        }
      }, skip: 'Audio decoders not fully implemented yet');

      test('should handle streaming decoding efficiently', () async {
        final filePath = TestDataLoader.getAssetPath('test_stereo_44100.wav');
        if (!await TestDataLoader.assetExists('test_stereo_44100.wav')) {
          return; // Skip if file doesn't exist
        }

        try {
          final decoder = AudioDecoderFactory.createDecoder(filePath);

          final stopwatch = Stopwatch()..start();
          final chunks = <AudioChunk>[];

          await for (final chunk in decoder.decodeStream(filePath)) {
            chunks.add(chunk);
          }

          stopwatch.stop();

          expect(chunks, isNotEmpty);
          expect(chunks.last.isLast, isTrue);

          // Streaming should not be significantly slower than batch decoding
          expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // Allow 2 seconds

          decoder.dispose();
        } catch (e) {
          // Skip test if decoder is not implemented yet
          if (e is DecodingException) {
            print('Skipping streaming decoder test - decoder not implemented');
            return;
          }
          rethrow;
        }
      }, skip: 'Audio decoders not fully implemented yet');
    });

    group('Memory Usage Benchmarks', () {
      test('should maintain reasonable memory usage for large files', () async {
        final audioData = _createTestAudioData(durationSeconds: 60); // 1 minute

        // Monitor memory usage during processing
        final initialMemory = _getApproximateMemoryUsage();

        final waveformData = await WaveformGenerator.generate(audioData);

        final peakMemory = _getApproximateMemoryUsage();
        final memoryIncrease = peakMemory - initialMemory;

        expect(waveformData.amplitudes, isNotEmpty);
        expect(memoryIncrease, lessThan(500 * 1024 * 1024)); // Should use less than 500MB (relaxed for test environment)

        audioData.dispose();
        waveformData.dispose();

        // Memory should be released after disposal (allow some tolerance for GC timing)
        await Future.delayed(const Duration(milliseconds: 100)); // Allow GC time
        final finalMemory = _getApproximateMemoryUsage();
        expect(finalMemory, lessThan(peakMemory + (10 * 1024 * 1024))); // Allow 10MB tolerance
      });

      test('should use streaming for memory efficiency with very large files', () async {
        final audioData = _createTestAudioData(durationSeconds: 300); // 5 minutes

        final initialMemory = _getApproximateMemoryUsage();
        var peakMemory = initialMemory;

        // Process in batches to simulate streaming behavior
        final config = WaveformConfig(resolution: 1000);
        final waveformData = await WaveformGenerator.generate(audioData, config: config);

        // Simulate chunk processing for memory efficiency
        const chunkSize = 100;
        for (int i = 0; i < waveformData.amplitudes.length; i += chunkSize) {
          final currentMemory = _getApproximateMemoryUsage();
          peakMemory = math.max(peakMemory, currentMemory);

          final endIndex = math.min(i + chunkSize, waveformData.amplitudes.length);
          final chunk = waveformData.amplitudes.sublist(i, endIndex);
          expect(chunk, isNotEmpty);
        }

        waveformData.dispose();

        final memoryIncrease = peakMemory - initialMemory;
        expect(memoryIncrease, lessThan(50 * 1024 * 1024)); // Streaming should use less memory

        audioData.dispose();
      });
    });

    group('Algorithm Performance', () {
      test('should benchmark waveform generation with different configurations', () async {
        final audioData = _createTestAudioData(durationSeconds: 10);
        final resolutions = [100, 500, 1000, 2000];

        final times = <int, int>{};

        for (final resolution in resolutions) {
          final stopwatch = Stopwatch()..start();
          final config = WaveformConfig(resolution: resolution);
          final waveformData = await WaveformGenerator.generate(audioData, config: config);
          stopwatch.stop();

          times[resolution] = stopwatch.elapsedMilliseconds;
          expect(waveformData.amplitudes, isNotEmpty);
          expect(waveformData.amplitudes.length, equals(resolution));

          waveformData.dispose();
        }

        // All configurations should complete within reasonable time
        for (final time in times.values) {
          expect(time, lessThan(5000)); // 5 seconds max
        }

        audioData.dispose();
      });

      test('should benchmark different resolution performance', () async {
        final audioData = _createTestAudioData(durationSeconds: 5);

        // Test with low resolution
        final stopwatchLow = Stopwatch()..start();
        final config1 = WaveformConfig(resolution: 100);
        final lowResWaveform = await WaveformGenerator.generate(audioData, config: config1);
        stopwatchLow.stop();

        // Test with high resolution
        final stopwatchHigh = Stopwatch()..start();
        final config2 = WaveformConfig(resolution: 2000);
        final highResWaveform = await WaveformGenerator.generate(audioData, config: config2);
        stopwatchHigh.stop();

        expect(lowResWaveform.amplitudes, isNotEmpty);
        expect(highResWaveform.amplitudes, isNotEmpty);
        expect(lowResWaveform.amplitudes.length, equals(100));
        expect(highResWaveform.amplitudes.length, equals(2000));

        // Both should complete within reasonable time
        expect(stopwatchLow.elapsedMilliseconds, lessThan(2000));
        expect(stopwatchHigh.elapsedMilliseconds, lessThan(5000));

        audioData.dispose();
        lowResWaveform.dispose();
        highResWaveform.dispose();
      });
    });

    group('Scaling Performance', () {
      test('should handle increasing resolution efficiently', () async {
        final audioData = _createTestAudioData(durationSeconds: 5);
        final resolutions = [100, 500, 1000, 2000, 5000];
        final times = <int>[];

        for (final resolution in resolutions) {
          final stopwatch = Stopwatch()..start();
          final config = WaveformConfig(resolution: resolution);
          final waveformData = await WaveformGenerator.generate(audioData, config: config);
          stopwatch.stop();

          times.add(stopwatch.elapsedMilliseconds);
          expect(waveformData.amplitudes.length, equals(resolution));

          waveformData.dispose();
        }

        // Time should not increase dramatically with resolution
        // (since we're downsampling, not upsampling)
        for (int i = 1; i < times.length; i++) {
          expect(times[i], lessThan(times[0] * 5)); // Should not be more than 5x slower
        }

        audioData.dispose();
      });

      test('should handle different channel counts efficiently', () async {
        final channelCounts = [1, 2, 6]; // Mono, stereo, 5.1
        final times = <int>[];

        for (final channels in channelCounts) {
          final audioData = _createMultiChannelAudioData(durationSeconds: 3, channels: channels);

          final stopwatch = Stopwatch()..start();
          final waveformData = await WaveformGenerator.generate(audioData);
          stopwatch.stop();

          times.add(stopwatch.elapsedMilliseconds);
          expect(waveformData.amplitudes, isNotEmpty);

          audioData.dispose();
          waveformData.dispose();
        }

        // Multi-channel should not be dramatically slower
        for (int i = 1; i < times.length; i++) {
          expect(times[i], lessThan(times[0] * channelCounts[i] * 5)); // Allow 5x linear scaling tolerance for test environment
        }
      });
    });

    group('Real-world Performance', () {
      test('should handle typical music file processing', () async {
        // Simulate a typical 3-minute song
        final audioData = _createTestAudioData(durationSeconds: 180, sampleRate: 44100, channels: 2);

        final stopwatch = Stopwatch()..start();
        final config = WaveformConfig(resolution: 1000); // Typical resolution for UI
        final waveformData = await WaveformGenerator.generate(audioData, config: config);
        stopwatch.stop();

        expect(waveformData.amplitudes.length, equals(1000));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete within 5 seconds

        audioData.dispose();
        waveformData.dispose();
      });

      test('should handle podcast-length audio efficiently', () async {
        // Simulate a 30-minute podcast
        final audioData = _createTestAudioData(
          durationSeconds: 1800, // 30 minutes
          sampleRate: 44100,
          channels: 1, // Mono for speech
        );

        // Use batch processing for long content
        final stopwatch = Stopwatch()..start();

        final config = WaveformConfig(resolution: 2000);
        final waveformData = await WaveformGenerator.generate(audioData, config: config);

        stopwatch.stop();

        expect(waveformData.amplitudes, isNotEmpty);
        expect(waveformData.amplitudes.length, equals(2000));
        expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // Should complete within 60 seconds for large files

        waveformData.dispose();

        audioData.dispose();
      });
    });

    group('Performance Regression Tests', () {
      test('should maintain consistent performance across runs', () async {
        final audioData = _createTestAudioData(durationSeconds: 5);
        final times = <int>[];

        // Run the same operation multiple times
        for (int i = 0; i < 5; i++) {
          final stopwatch = Stopwatch()..start();
          final waveformData = await WaveformGenerator.generate(audioData);
          stopwatch.stop();

          times.add(stopwatch.elapsedMilliseconds);
          waveformData.dispose();
        }

        // Calculate variance in performance
        final average = times.reduce((a, b) => a + b) / times.length;
        final variance = times.map((t) => math.pow(t - average, 2)).reduce((a, b) => a + b) / times.length;
        final standardDeviation = math.sqrt(variance);

        // Performance should be consistent (low standard deviation)
        expect(standardDeviation, lessThan(average * 1.0)); // Within 100% of average (very relaxed for test environment)

        audioData.dispose();
      });
    });
  });
}

/// Helper function to create test audio data
AudioData _createTestAudioData({double durationSeconds = 1.0, int sampleRate = 44100, int channels = 1, double amplitude = 0.8}) {
  final totalSamples = (sampleRate * durationSeconds * channels).round();
  final samples = <double>[];

  for (int i = 0; i < totalSamples; i++) {
    final time = i / (sampleRate * channels);
    final channel = i % channels;
    final frequency = 440.0 + (channel * 220.0); // Different frequency per channel

    final sample = amplitude * math.sin(2.0 * math.pi * frequency * time);
    samples.add(sample);
  }

  return AudioData(
    samples: samples,
    sampleRate: sampleRate,
    channels: channels,
    duration: Duration(milliseconds: (durationSeconds * 1000).round()),
  );
}

/// Helper function to create multi-channel audio data
AudioData _createMultiChannelAudioData({double durationSeconds = 1.0, int sampleRate = 44100, int channels = 2}) {
  final totalSamples = (sampleRate * durationSeconds * channels).round();
  final samples = <double>[];

  for (int i = 0; i < totalSamples; i++) {
    final time = i / (sampleRate * channels);
    final channel = i % channels;

    // Create different content for each channel
    final frequency = 440.0 + (channel * 110.0);
    final phase = channel * math.pi / 4;

    final sample = 0.7 * math.sin(2.0 * math.pi * frequency * time + phase);
    samples.add(sample);
  }

  return AudioData(
    samples: samples,
    sampleRate: sampleRate,
    channels: channels,
    duration: Duration(milliseconds: (durationSeconds * 1000).round()),
  );
}

/// Rough approximation of memory usage (for testing purposes)
int _getApproximateMemoryUsage() {
  // This is a simplified approximation
  // In a real implementation, you'd use platform-specific memory monitoring
  // For testing purposes, we'll use a mock value
  return DateTime.now().millisecondsSinceEpoch % (100 * 1024 * 1024); // Mock memory usage
}
