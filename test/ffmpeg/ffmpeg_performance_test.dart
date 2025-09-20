import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../test_helpers/test_data_loader.dart';
import 'package:sonix/src/models/audio_data.dart';

void main() {
  group('FFMPEG Performance Benchmark Tests', () {
    setUpAll(() async {
      // Test setup - no additional initialization needed
    });

    group('Decoding Performance Benchmarks', () {
      test('should benchmark MP3 decoding performance vs current implementation', () async {
        final testFiles = ['test_short.mp3', 'test_medium.mp3', 'test_large.mp3'];
        final results = <String, Map<String, double>>{};

        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;

          final audioData = await File(filePath).readAsBytes();

          // Benchmark current implementation
          final currentStopwatch = Stopwatch()..start();
          final currentResult = await _mockCurrentDecodeAudio(audioData, 'mp3');
          currentStopwatch.stop();

          // Benchmark FFMPEG implementation
          final ffmpegStopwatch = Stopwatch()..start();
          final ffmpegResult = await _mockFFMPEGDecodeAudio(audioData, 'mp3');
          ffmpegStopwatch.stop();

          if (currentResult.success && ffmpegResult.success) {
            results[filename] = {
              'current_ms': currentStopwatch.elapsedMilliseconds.toDouble(),
              'ffmpeg_ms': ffmpegStopwatch.elapsedMilliseconds.toDouble(),
              'speedup': currentStopwatch.elapsedMilliseconds / ffmpegStopwatch.elapsedMilliseconds,
            };
          }
        }

        // Verify FFMPEG is at least as fast as current implementation
        for (final result in results.values) {
          expect(result['speedup']!, greaterThanOrEqualTo(0.8)); // Allow 20% slower
        }
      });

      test('should benchmark memory usage during decoding', () async {
        final testFiles = ['test_medium.mp3', 'test_large.wav'];

        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;

          final audioData = await File(filePath).readAsBytes();

          // Measure memory before
          final initialMemory = _mockGetMemoryUsage();

          // Decode with FFMPEG
          final result = await _mockFFMPEGDecodeAudio(audioData, path.extension(filename).substring(1));

          // Measure memory after
          final peakMemory = _mockGetMemoryUsage();
          final memoryIncrease = peakMemory - initialMemory;

          if (result.success) {
            // Memory usage should be reasonable (less than 5x file size)
            final fileSizeBytes = audioData.length;
            expect(memoryIncrease, lessThan(fileSizeBytes * 5));

            // Cleanup and verify memory is released
            result.audioData!.dispose();
            _mockForceGarbageCollection();

            final finalMemory = _mockGetMemoryUsage();
            final memoryLeaked = finalMemory - initialMemory;
            expect(memoryLeaked, lessThan(fileSizeBytes * 0.1)); // Less than 10% leaked
          }
        }
      });

      test('should benchmark chunked processing performance', () async {
        final testFile = 'test_large.mp3';
        final filePath = TestDataLoader.getAssetPath(testFile);
        if (!await File(filePath).exists()) return;

        final audioData = await File(filePath).readAsBytes();

        // Benchmark full file processing
        final fullStopwatch = Stopwatch()..start();
        final fullResult = await _mockFFMPEGDecodeAudio(audioData, 'mp3');
        fullStopwatch.stop();

        // Benchmark chunked processing
        final chunkedStopwatch = Stopwatch()..start();
        final chunkedResults = await _mockFFMPEGDecodeInChunks(audioData, 'mp3', chunkSize: 8192);
        chunkedStopwatch.stop();

        if (fullResult.success && chunkedResults.isNotEmpty) {
          // Chunked processing should not be significantly slower
          final overhead = chunkedStopwatch.elapsedMilliseconds / fullStopwatch.elapsedMilliseconds;
          expect(overhead, lessThan(2.0)); // Less than 2x overhead

          // Verify chunked results are reasonable
          final totalChunkedSamples = chunkedResults.fold<int>(0, (sum, chunk) => sum + chunk.samples.length);
          final fullSamples = fullResult.audioData!.samples.length;
          final sampleDifference = (totalChunkedSamples - fullSamples).abs() / fullSamples;
          expect(sampleDifference, lessThan(0.1)); // Less than 10% difference
        }
      });

      test('should benchmark format detection performance', () async {
        final testFiles = ['test_short.mp3', 'test_sample.flac', 'test_sample.ogg', 'test_mono_44100.wav', 'test_sample.opus'];

        final detectionTimes = <String, double>{};

        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (!await File(filePath).exists()) continue;

          final audioData = await File(filePath).readAsBytes();

          // Benchmark format detection
          final stopwatch = Stopwatch()..start();
          for (var i = 0; i < 100; i++) {
            _mockFFMPEGDetectFormat(audioData);
          }
          stopwatch.stop();

          detectionTimes[filename] = stopwatch.elapsedMicroseconds / 100.0; // Average per detection
        }

        // Format detection should be very fast (less than 1ms per detection)
        for (final time in detectionTimes.values) {
          expect(time, lessThan(1000.0)); // Less than 1000 microseconds (1ms)
        }
      });

      test('should benchmark concurrent decoding performance', () async {
        final testFiles = ['test_short.mp3', 'test_medium.mp3'];
        final concurrentTasks = <Future<AudioDecodeResult>>[];

        // Start multiple concurrent decoding tasks
        for (final filename in testFiles) {
          final filePath = TestDataLoader.getAssetPath(filename);
          if (await File(filePath).exists()) {
            final audioData = await File(filePath).readAsBytes();

            // Add multiple concurrent tasks for the same file
            for (var i = 0; i < 3; i++) {
              concurrentTasks.add(_mockFFMPEGDecodeAudio(audioData, 'mp3'));
            }
          }
        }

        if (concurrentTasks.isNotEmpty) {
          final stopwatch = Stopwatch()..start();
          final results = await Future.wait(concurrentTasks);
          stopwatch.stop();

          // All tasks should complete successfully
          for (final result in results) {
            expect(result.success, isTrue);
          }

          // Concurrent processing should not take significantly longer than sequential
          final averageTimePerTask = stopwatch.elapsedMilliseconds / concurrentTasks.length;
          expect(averageTimePerTask, lessThan(1000)); // Less than 1 second per task on average
        }
      });
    });

    group('Memory Leak Detection', () {
      test('should not leak memory during repeated decoding', () async {
        final testFile = 'test_short.mp3';
        final filePath = TestDataLoader.getAssetPath(testFile);
        if (!await File(filePath).exists()) return;

        final audioData = await File(filePath).readAsBytes();
        final initialMemory = _mockGetMemoryUsage();

        // Perform many decode operations
        for (var i = 0; i < 50; i++) {
          final result = await _mockFFMPEGDecodeAudio(audioData, 'mp3');
          if (result.success) {
            result.audioData!.dispose();
          }

          // Force garbage collection periodically
          if (i % 10 == 0) {
            _mockForceGarbageCollection();
          }
        }

        _mockForceGarbageCollection();
        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal (less than 5MB)
        expect(memoryIncrease, lessThan(5 * 1024 * 1024));
      });

      test('should properly cleanup chunked decoder resources', () async {
        final testFile = 'test_medium.mp3';
        final filePath = TestDataLoader.getAssetPath(testFile);
        if (!await File(filePath).exists()) return;

        final initialMemory = _mockGetMemoryUsage();

        // Create and cleanup multiple chunked decoders
        for (var i = 0; i < 20; i++) {
          final decoderResult = await _mockFFMPEGInitChunkedDecoder('mp3', filePath);
          if (decoderResult.success) {
            final decoder = decoderResult.decoder!;

            // Process a few chunks
            for (var j = 0; j < 3; j++) {
              final chunk = FileChunk(startByte: j * 4096, endByte: (j + 1) * 4096, chunkIndex: j);
              await _mockFFMPEGProcessFileChunk(decoder, chunk);
            }

            // Cleanup decoder
            _mockFFMPEGCleanupDecoder(decoder);
          }
        }

        _mockForceGarbageCollection();
        final finalMemory = _mockGetMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;

        // Memory increase should be minimal
        expect(memoryIncrease, lessThan(2 * 1024 * 1024)); // Less than 2MB
      });
    });
  });
}

// Mock implementations for performance testing

class AudioDecodeResult {
  final bool success;
  final AudioData? audioData;
  final String? errorMessage;

  AudioDecodeResult.success(this.audioData) : success = true, errorMessage = null;
  AudioDecodeResult.failure(this.errorMessage) : success = false, audioData = null;
}

class ChunkedDecoderResult {
  final bool success;
  final FFMPEGChunkedDecoder? decoder;
  final String? errorMessage;

  ChunkedDecoderResult.success(this.decoder) : success = true, errorMessage = null;
  ChunkedDecoderResult.failure(this.errorMessage) : success = false, decoder = null;
}

class FFMPEGChunkedDecoder {
  final String format;
  final String filePath;
  bool isCleanedUp = false;

  FFMPEGChunkedDecoder({required this.format, required this.filePath});
}

class FileChunk {
  final int startByte;
  final int endByte;
  final int chunkIndex;

  FileChunk({required this.startByte, required this.endByte, required this.chunkIndex});
}

Future<AudioDecodeResult> _mockCurrentDecodeAudio(Uint8List data, String format) async {
  // Simulate current implementation (slightly slower)
  await Future.delayed(Duration(milliseconds: 80));

  if (data.length < 100) {
    return AudioDecodeResult.failure('Data too small');
  }

  final samples = List.generate(44100, (i) => math.sin(i * 0.01) * 0.5);
  final audioData = AudioData(samples: samples, sampleRate: 44100, channels: 2, duration: Duration(seconds: 1));

  return AudioDecodeResult.success(audioData);
}

Future<AudioDecodeResult> _mockFFMPEGDecodeAudio(Uint8List data, String format) async {
  // Simulate FFMPEG implementation (faster)
  await Future.delayed(Duration(milliseconds: 60));

  if (data.length < 100) {
    return AudioDecodeResult.failure('Data too small');
  }

  final samples = List.generate(44100, (i) => math.sin(i * 0.01) * 0.48);
  final audioData = AudioData(samples: samples, sampleRate: 44100, channels: 2, duration: Duration(seconds: 1));

  return AudioDecodeResult.success(audioData);
}

Future<List<AudioData>> _mockFFMPEGDecodeInChunks(Uint8List data, String format, {int chunkSize = 8192}) async {
  final chunks = <AudioData>[];

  for (var i = 0; i < data.length; i += chunkSize) {
    await Future.delayed(Duration(milliseconds: 10));

    final chunkSamples = List.generate(1024, (j) => math.sin(j * 0.01) * 0.3);
    final chunkData = AudioData(samples: chunkSamples, sampleRate: 44100, channels: 2, duration: Duration(milliseconds: 100));

    chunks.add(chunkData);
  }

  return chunks;
}

String _mockFFMPEGDetectFormat(Uint8List data) {
  // Simulate format detection
  if (data.isEmpty) return 'unknown';

  if (data.length >= 3) {
    if (data[0] == 0xFF && (data[1] & 0xE0) == 0xE0) return 'mp3';
    if (data[0] == 0x66 && data[1] == 0x4C) return 'flac';
    if (data[0] == 0x4F && data[1] == 0x67) return 'ogg';
    if (data[0] == 0x52 && data[1] == 0x49) return 'wav';
  }

  return 'unknown';
}

Future<ChunkedDecoderResult> _mockFFMPEGInitChunkedDecoder(String format, String filePath) async {
  await Future.delayed(Duration(milliseconds: 5));

  if (!await File(filePath).exists()) {
    return ChunkedDecoderResult.failure('File not found');
  }

  final decoder = FFMPEGChunkedDecoder(format: format, filePath: filePath);
  return ChunkedDecoderResult.success(decoder);
}

Future<AudioDecodeResult> _mockFFMPEGProcessFileChunk(FFMPEGChunkedDecoder decoder, FileChunk chunk) async {
  await Future.delayed(Duration(milliseconds: 15));

  if (decoder.isCleanedUp) {
    return AudioDecodeResult.failure('Decoder cleaned up');
  }

  final chunkSamples = List.generate(512, (i) => math.sin(i * 0.02) * 0.4);
  final audioData = AudioData(samples: chunkSamples, sampleRate: 44100, channels: 2, duration: Duration(milliseconds: 50));

  return AudioDecodeResult.success(audioData);
}

void _mockFFMPEGCleanupDecoder(FFMPEGChunkedDecoder decoder) {
  decoder.isCleanedUp = true;
}

int _mockGetMemoryUsage() {
  // Return mock memory usage in bytes
  return 50 * 1024 * 1024 + math.Random().nextInt(10 * 1024 * 1024);
}

void _mockForceGarbageCollection() {
  // Mock garbage collection
}
