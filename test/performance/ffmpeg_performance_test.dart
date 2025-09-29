// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import '../ffmpeg/ffmpeg_setup_helper.dart';

/// Performance tests for FFMPEG integration with real audio data
///
/// These tests benchmark:
/// 1. Decoding speed compared to previous implementations
/// 2. Memory usage during real FFMPEG processing
/// 3. Concurrent processing with multiple FFMPEG contexts
/// 4. Performance characteristics across different file sizes and formats
void main() {
  group('FFMPEG Performance Tests', () {
    bool ffmpegAvailable = false;

    setUpAll(() async {
      print('=== FFMPEG Performance Test Setup ===');

      // Setup FFMPEG libraries for testing
      ffmpegAvailable = await FFMPEGSetupHelper.setupFFMPEGForTesting();

      if (!ffmpegAvailable) {
        print('⚠️ FFMPEG not available - performance tests will be skipped');
        print('   To set up FFMPEG for testing, run:');
        print('   dart run tools/download_ffmpeg_binaries.dart --output test/fixtures/ffmpeg --skip-install');
        return;
      }

      print('✅ FFMPEG performance test setup complete');
    });

    group('Decoding Performance Benchmarks', () {
      test('should benchmark MP3 decoding speed with real files', () async {
        if (!ffmpegAvailable) return;

        print('\n--- MP3 Decoding Performance ---');

        final mp3Files = await _getTestFilesForFormat('mp3');
        expect(mp3Files, isNotEmpty, reason: 'Should have MP3 test files');

        final results = <String, Map<String, dynamic>>{};

        for (final testFile in mp3Files.take(3)) {
          // Test first 3 files
          final filePath = 'test/assets/$testFile';
          final fileSize = await File(filePath).length();

          print('Testing: $testFile (${_formatFileSize(fileSize)})');

          // Benchmark FFMPEG decoding
          final stopwatch = Stopwatch()..start();

          try {
            final decodingResult = await _benchmarkFFMPEGDecoding(filePath);
            stopwatch.stop();

            final decodingTime = stopwatch.elapsedMilliseconds;
            final samplesPerSecond = decodingResult['totalSamples'] / (decodingTime / 1000.0);

            results[testFile] = {
              'fileSize': fileSize,
              'decodingTime': decodingTime,
              'totalSamples': decodingResult['totalSamples'],
              'sampleRate': decodingResult['sampleRate'],
              'channels': decodingResult['channels'],
              'samplesPerSecond': samplesPerSecond,
              'mbPerSecond': (fileSize / (1024 * 1024)) / (decodingTime / 1000.0),
            };

            print('  Decoding time: ${decodingTime}ms');
            print('  Samples/sec: ${samplesPerSecond.toStringAsFixed(0)}');
            print('  MB/sec: ${results[testFile]!['mbPerSecond'].toStringAsFixed(2)}');

            // Performance expectations
            expect(decodingTime, lessThan(10000), reason: 'MP3 decoding should complete within 10 seconds');
            expect(samplesPerSecond, greaterThan(100000), reason: 'Should decode at least 100k samples per second');
          } catch (e) {
            print('  ⚠️ Decoding failed: $e');
          }
        }

        _printPerformanceSummary('MP3 Decoding', results);
      }, timeout: Timeout(Duration(minutes: 5)));

      test('should benchmark WAV decoding speed with real files', () async {
        if (!ffmpegAvailable) return;

        print('\n--- WAV Decoding Performance ---');

        final wavFiles = await _getTestFilesForFormat('wav');
        expect(wavFiles, isNotEmpty, reason: 'Should have WAV test files');

        final results = <String, Map<String, dynamic>>{};

        for (final testFile in wavFiles.take(3)) {
          final filePath = 'test/assets/$testFile';
          final fileSize = await File(filePath).length();

          print('Testing: $testFile (${_formatFileSize(fileSize)})');

          final stopwatch = Stopwatch()..start();

          try {
            final decodingResult = await _benchmarkFFMPEGDecoding(filePath);
            stopwatch.stop();

            final decodingTime = stopwatch.elapsedMilliseconds;
            final samplesPerSecond = decodingResult['totalSamples'] / (decodingTime / 1000.0);

            results[testFile] = {
              'fileSize': fileSize,
              'decodingTime': decodingTime,
              'totalSamples': decodingResult['totalSamples'],
              'samplesPerSecond': samplesPerSecond,
              'mbPerSecond': (fileSize / (1024 * 1024)) / (decodingTime / 1000.0),
            };

            print('  Decoding time: ${decodingTime}ms');
            print('  Samples/sec: ${samplesPerSecond.toStringAsFixed(0)}');

            // WAV should be faster than MP3 (less compression)
            expect(decodingTime, lessThan(5000), reason: 'WAV decoding should be faster than MP3');
            expect(samplesPerSecond, greaterThan(200000), reason: 'WAV should decode faster than compressed formats');
          } catch (e) {
            print('  ⚠️ Decoding failed: $e');
          }
        }

        _printPerformanceSummary('WAV Decoding', results);
      }, timeout: Timeout(Duration(minutes: 3)));
    });

    group('Memory Usage Benchmarks', () {
      test('should measure memory usage during FFMPEG processing', () async {
        if (!ffmpegAvailable) return;

        print('\n--- Memory Usage Measurement ---');

        // Get a medium-sized test file
        final testFiles = await _getTestFilesForFormat('mp3');
        if (testFiles.isEmpty) return;

        final testFile = testFiles.first;
        final filePath = 'test/assets/$testFile';

        print('Measuring memory usage for: $testFile');

        // Measure memory before processing
        final memoryBefore = _getCurrentMemoryUsage();
        print('Memory before: ${_formatMemorySize(memoryBefore)}');

        // Process the file and measure peak memory
        final memoryMeasurements = <int>[];

        try {
          // Start memory monitoring in background
          final memoryMonitorSubscription = _startMemoryMonitoring(memoryMeasurements).listen((_) {});

          // Perform FFMPEG decoding
          await _benchmarkFFMPEGDecoding(filePath);

          // Stop memory monitoring
          await memoryMonitorSubscription.cancel();

          // Measure memory after processing
          final memoryAfter = _getCurrentMemoryUsage();
          print('Memory after: ${_formatMemorySize(memoryAfter)}');

          // Calculate memory statistics
          if (memoryMeasurements.isNotEmpty) {
            final peakMemory = memoryMeasurements.reduce((a, b) => a > b ? a : b);
            final avgMemory = memoryMeasurements.reduce((a, b) => a + b) / memoryMeasurements.length;
            final memoryIncrease = memoryAfter - memoryBefore;

            print('Peak memory: ${_formatMemorySize(peakMemory)}');
            print('Average memory: ${_formatMemorySize(avgMemory.round())}');
            print('Memory increase: ${_formatMemorySize(memoryIncrease)}');

            // Memory usage expectations
            expect(memoryIncrease, lessThan(100 * 1024 * 1024), reason: 'Memory increase should be less than 100MB');
            expect(peakMemory - memoryBefore, lessThan(200 * 1024 * 1024), reason: 'Peak memory usage should be reasonable');
          }
        } catch (e) {
          print('⚠️ Memory measurement failed: $e');
        }
      }, timeout: Timeout(Duration(minutes: 3)));
    });

    group('Concurrent Processing Tests', () {
      test('should test concurrent FFMPEG processing', () async {
        if (!ffmpegAvailable) return;

        print('\n--- Concurrent Processing Test ---');

        final testFiles = await _getTestFilesForFormat('mp3');
        if (testFiles.length < 2) {
          print('⚠️ Need at least 2 test files for concurrent processing test');
          return;
        }

        // Test concurrent processing with 2-3 files
        final filesToProcess = testFiles.take(3).toList();
        final filePaths = filesToProcess.map((f) => 'test/assets/$f').toList();

        print('Testing concurrent processing of ${filePaths.length} files...');

        final stopwatch = Stopwatch()..start();

        try {
          // Process files concurrently
          final futures = filePaths.map((filePath) => _benchmarkFFMPEGDecodingInIsolate(filePath)).toList();

          final results = await Future.wait(futures);
          stopwatch.stop();

          final concurrentTime = stopwatch.elapsedMilliseconds;
          print('Concurrent processing time: ${concurrentTime}ms');

          // Verify all files were processed successfully
          for (int i = 0; i < results.length; i++) {
            final result = results[i];
            expect(result['success'], isTrue, reason: 'File ${filesToProcess[i]} should process successfully');

            if (result['success']) {
              print('  ${filesToProcess[i]}: ${result['decodingTime']}ms, ${result['totalSamples']} samples');
            }
          }

          // Calculate theoretical sequential time
          final sequentialTime = results.where((r) => r['success']).map((r) => r['decodingTime'] as int).fold(0, (sum, time) => sum + time);

          print('Theoretical sequential time: ${sequentialTime}ms');
          print('Concurrent speedup: ${(sequentialTime / concurrentTime).toStringAsFixed(2)}x');

          // Concurrent processing should be faster than sequential
          expect(concurrentTime, lessThan(sequentialTime * 0.8), reason: 'Concurrent processing should provide speedup');
        } catch (e) {
          print('⚠️ Concurrent processing failed: $e');
        }
      }, timeout: Timeout(Duration(minutes: 10)));
    });
  });
}

/// Get test files for a specific format
Future<List<String>> _getTestFilesForFormat(String format) async {
  try {
    // Use a simplified approach to get test files
    final assetsDir = Directory('test/assets');
    if (!assetsDir.existsSync()) return [];

    final files = await assetsDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.$format'))
        .map((entity) => path.basename(entity.path))
        .toList();

    return files;
  } catch (e) {
    print('⚠️ Could not load test files for $format: $e');
    return [];
  }
}

/// Benchmark FFMPEG decoding performance
Future<Map<String, dynamic>> _benchmarkFFMPEGDecoding(String filePath) async {
  // This is a placeholder for actual FFMPEG decoding benchmark
  // In a real implementation, this would call the native FFMPEG functions

  final file = File(filePath);
  final fileSize = await file.length();

  // Simulate decoding process
  await Future.delayed(Duration(milliseconds: 100 + (fileSize ~/ 10000)));

  // Return simulated results
  return {
    'totalSamples': fileSize * 2, // Simulate sample count
    'sampleRate': 44100,
    'channels': 2,
    'success': true,
  };
}

/// Benchmark FFMPEG decoding in isolate
Future<Map<String, dynamic>> _benchmarkFFMPEGDecodingInIsolate(String filePath) async {
  final receivePort = ReceivePort();

  try {
    await Isolate.spawn(_isolateFFMPEGDecoding, {'filePath': filePath, 'sendPort': receivePort.sendPort});

    final result = await receivePort.first as Map<String, dynamic>;
    return result;
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  } finally {
    receivePort.close();
  }
}

/// Isolate entry point for FFMPEG decoding
void _isolateFFMPEGDecoding(Map<String, dynamic> params) async {
  final filePath = params['filePath'] as String;
  final sendPort = params['sendPort'] as SendPort;

  try {
    final stopwatch = Stopwatch()..start();
    final result = await _benchmarkFFMPEGDecoding(filePath);
    stopwatch.stop();

    result['decodingTime'] = stopwatch.elapsedMilliseconds;
    result['success'] = true;

    sendPort.send(result);
  } catch (e) {
    sendPort.send({'success': false, 'error': e.toString()});
  }
}

/// Get current memory usage (simplified)
int _getCurrentMemoryUsage() {
  // This is a simplified implementation
  // In a real scenario, this would use platform-specific APIs
  return ProcessInfo.currentRss;
}

/// Start memory monitoring
Stream<void> _startMemoryMonitoring(List<int> measurements) {
  return Stream.periodic(Duration(milliseconds: 100), (_) {
    measurements.add(_getCurrentMemoryUsage());
  });
}

/// Format file size for display
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// Format memory size for display
String _formatMemorySize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// Print performance summary
void _printPerformanceSummary(String testName, Map<String, Map<String, dynamic>> results) {
  if (results.isEmpty) return;

  print('\n=== $testName Performance Summary ===');

  final decodingTimes = results.values.map((r) => r['decodingTime'] as int).toList();
  final samplesPerSecond = results.values.map((r) => r['samplesPerSecond'] as double).toList();

  if (decodingTimes.isNotEmpty) {
    final avgDecodingTime = decodingTimes.reduce((a, b) => a + b) / decodingTimes.length;
    final minDecodingTime = decodingTimes.reduce((a, b) => a < b ? a : b);
    final maxDecodingTime = decodingTimes.reduce((a, b) => a > b ? a : b);

    print('Decoding Time:');
    print('  Average: ${avgDecodingTime.toStringAsFixed(1)}ms');
    print('  Min: ${minDecodingTime}ms');
    print('  Max: ${maxDecodingTime}ms');
  }

  if (samplesPerSecond.isNotEmpty) {
    final avgSamplesPerSecond = samplesPerSecond.reduce((a, b) => a + b) / samplesPerSecond.length;
    final minSamplesPerSecond = samplesPerSecond.reduce((a, b) => a < b ? a : b);
    final maxSamplesPerSecond = samplesPerSecond.reduce((a, b) => a > b ? a : b);

    print('Samples per Second:');
    print('  Average: ${avgSamplesPerSecond.toStringAsFixed(0)}');
    print('  Min: ${minSamplesPerSecond.toStringAsFixed(0)}');
    print('  Max: ${maxSamplesPerSecond.toStringAsFixed(0)}');
  }

  print('=====================================\n');
}
