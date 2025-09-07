// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'package:sonix/sonix.dart';

/// Example demonstrating waveform generation capabilities
void main() async {
  print('🎵 Sonix Waveform Generation Example\n');

  // Create sample audio data (sine wave)
  final samples = List.generate(4410, (i) => math.sin(i * 0.02) * 0.8);
  final audioData = AudioData(samples: samples, sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 100));

  print('📊 Generated audio data:');
  print('   Samples: ${audioData.samples.length}');
  print('   Sample Rate: ${audioData.sampleRate} Hz');
  print('   Duration: ${audioData.duration.inMilliseconds} ms\n');

  // Example 1: Basic waveform generation
  print('🔧 Example 1: Basic Waveform Generation');
  final basicWaveform = await WaveformGenerator.generate(audioData);
  print('   Resolution: ${basicWaveform.amplitudes.length}');
  print('   Max amplitude: ${basicWaveform.amplitudes.reduce(math.max).toStringAsFixed(3)}');
  print('   Normalized: ${basicWaveform.metadata.normalized}\n');

  // Example 2: High-resolution waveform for detailed analysis
  print('🔍 Example 2: High-Resolution Analysis');
  final highResConfig = const WaveformConfig(resolution: 2000, algorithm: DownsamplingAlgorithm.rms, normalize: true);
  final highResWaveform = await WaveformGenerator.generate(audioData, config: highResConfig);
  print('   Resolution: ${highResWaveform.amplitudes.length}');
  print('   Algorithm: RMS');
  print('   Peak value: ${highResWaveform.amplitudes.reduce(math.max).toStringAsFixed(3)}\n');

  // Example 3: Music visualization optimized
  print('🎶 Example 3: Music Visualization');
  final musicConfig = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.musicVisualization, customResolution: 500);
  final musicWaveform = await WaveformGenerator.generate(audioData, config: musicConfig);
  print('   Resolution: ${musicWaveform.amplitudes.length}');
  print('   Algorithm: ${musicConfig.algorithm}');
  print('   Scaling: ${musicConfig.scalingCurve}');
  print('   Smoothing: ${musicConfig.enableSmoothing}\n');

  // Example 4: Peak detection for audio editing
  print('🎯 Example 4: Peak Detection');
  final peakConfig = WaveformGenerator.getOptimalConfig(useCase: WaveformUseCase.peakDetection);
  final peakWaveform = await WaveformGenerator.generate(audioData, config: peakConfig);

  // Detect peaks in the waveform
  final peaks = WaveformAlgorithms.detectPeaks(peakWaveform.amplitudes, threshold: 0.7, minDistance: 10);
  print('   Detected ${peaks.length} peaks above 0.7 threshold');
  print('   Peak positions: ${peaks.take(5).toList()}...\n');

  // Example 5: Memory-efficient processing
  print('💾 Example 5: Memory-Efficient Processing');
  final memoryWaveform = await WaveformGenerator.generateMemoryEfficient(
    audioData,
    maxMemoryUsage: 1024, // 1KB limit
  );
  print('   Resolution: ${memoryWaveform.amplitudes.length}');
  print('   Memory-optimized processing completed\n');

  // Example 6: Different scaling curves comparison
  print('📈 Example 6: Scaling Curves Comparison');
  final scalingCurves = [ScalingCurve.linear, ScalingCurve.logarithmic, ScalingCurve.exponential, ScalingCurve.sqrt];

  for (final curve in scalingCurves) {
    final config = WaveformConfig(resolution: 100, scalingCurve: curve, normalize: true);
    final waveform = await WaveformGenerator.generate(audioData, config: config);
    final avgAmplitude = waveform.amplitudes.reduce((a, b) => a + b) / waveform.amplitudes.length;
    print('   ${curve.name}: avg amplitude = ${avgAmplitude.toStringAsFixed(3)}');
  }
  print('');

  // Example 7: Streaming processing simulation
  print('🌊 Example 7: Streaming Processing');
  final chunks = <AudioChunk>[];
  const chunkSize = 500;

  for (int i = 0; i < audioData.samples.length; i += chunkSize) {
    final end = math.min(i + chunkSize, audioData.samples.length);
    final chunkSamples = audioData.samples.sublist(i, end);
    chunks.add(AudioChunk(samples: chunkSamples, startSample: i, isLast: end >= audioData.samples.length));
  }

  final audioStream = Stream.fromIterable(chunks);
  final waveformChunks = <WaveformChunk>[];

  await for (final chunk in WaveformGenerator.generateStream(audioStream, chunkSize: 50)) {
    waveformChunks.add(chunk);
  }

  print('   Processed ${waveformChunks.length} waveform chunks');
  print('   Total amplitude points: ${waveformChunks.fold<int>(0, (sum, chunk) => sum + chunk.amplitudes.length)}');
  print('   Last chunk time: ${waveformChunks.last.startTime.inMilliseconds} ms\n');

  // Example 8: Serialization
  print('💾 Example 8: Waveform Data Serialization');
  final jsonString = basicWaveform.toJsonString();
  final deserializedWaveform = WaveformData.fromJsonString(jsonString);

  print('   Original amplitudes: ${basicWaveform.amplitudes.length}');
  print('   Deserialized amplitudes: ${deserializedWaveform.amplitudes.length}');
  print('   Data integrity: ${basicWaveform.amplitudes.first == deserializedWaveform.amplitudes.first ? "✅" : "❌"}');
  print('   JSON size: ${jsonString.length} characters\n');

  print('🎉 All examples completed successfully!');
  print('   The waveform generation engine is ready for use.');
}
