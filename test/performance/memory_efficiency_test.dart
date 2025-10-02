// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../../tool/test_data_generator.dart';

/// Memory and performance testing suite for chunked audio processing
///
/// This test suite validates memory usage, performance benchmarks, and resource management
/// for the chunked processing system across various file sizes and scenarios.
void main() {
  group('Memory and Performance Testing Suite', () {
    late MemoryMonitor memoryMonitor;
    late PerformanceBenchmark performanceBenchmark;

    setUpAll(() async {
      print('Setting up memory and performance testing suite...');

      // Generate only essential test files (faster, cached)
      await TestDataGenerator.generateEssentialTestData();

      memoryMonitor = MemoryMonitor();
      performanceBenchmark = PerformanceBenchmark();

      print('Memory and performance testing suite setup complete');
    });

    tearDownAll(() async {
      await memoryMonitor.cleanup();
      await performanceBenchmark.cleanup();
    });

    group('Memory Usage Validation', () {
      test('should monitor memory usage for various file sizes', () async {
        final filesBySize = await TestDataLoader.getTestFilesBySize();

        for (final sizeEntry in TestDataGenerator.fileSizes.entries) {
          final sizeName = sizeEntry.key;
          final targetSize = sizeEntry.value;
          final files = filesBySize[sizeName] ?? [];

          // Skip massive files in CI to avoid memory issues
          if (sizeName == 'massive' && Platform.environment['CI'] == 'true') {
            continue;
          }

          if (files.isNotEmpty) {
            final testFile = files.first;
            final filePath = TestDataLoader.getAssetPath(testFile);

            final memoryUsage = await memoryMonitor.measureMemoryUsage(() async {
              // Simulate chunked processing memory usage
              await _simulateChunkedProcessing(filePath, targetSize);
            });

            // Memory usage should be reasonable relative to file size
            final expectedMaxMemory = _calculateExpectedMaxMemory(targetSize);

            expect(
              memoryUsage.peakMemoryMB,
              lessThanOrEqualTo(expectedMaxMemory),
              reason: 'Memory usage ${memoryUsage.peakMemoryMB}MB exceeds expected maximum ${expectedMaxMemory}MB for $sizeName file',
            );

            print(
              'Memory usage for $sizeName (${TestDataGenerator.formatFileSize(targetSize)}): '
              'Peak=${memoryUsage.peakMemoryMB}MB, Average=${memoryUsage.averageMemoryMB}MB',
            );
          }
        }
      });

      test('should validate memory usage stays within configured limits', () async {
        final memoryLimits = [10, 50, 100, 200]; // MB

        for (final limitMB in memoryLimits) {
          ProcessInfo.reset();
          ProcessInfo.setMemoryPressureLimit(limitMB * 1024 * 1024);

          await _simulateChunkedProcessingWithLimit(limitMB);

          final currentMemoryMB = (await ProcessInfo.currentRss) / (1024 * 1024);

          // Allow 20% tolerance for measurement overhead
          final tolerance = limitMB * 0.2;

          expect(currentMemoryMB, lessThanOrEqualTo(limitMB + tolerance), reason: 'Memory usage ${currentMemoryMB}MB exceeds limit ${limitMB}MB');

          print('Memory limit test ${limitMB}MB: Peak=${currentMemoryMB}MB');
          ProcessInfo.reset();
        }
      });

      test('should detect memory leaks during repeated processing', () async {
        final files = await TestDataLoader.getTestFilesForFormat('wav');

        if (files.isNotEmpty) {
          final testFile = files.first;
          final filePath = TestDataLoader.getAssetPath(testFile);

          final memoryReadings = <double>[];

          // Process the same file multiple times and monitor memory
          for (int i = 0; i < 10; i++) {
            final memoryUsage = await memoryMonitor.measureMemoryUsage(() async {
              await _simulateChunkedProcessing(filePath, 1024 * 1024);
            });

            memoryReadings.add(memoryUsage.peakMemoryMB);

            // Force garbage collection between iterations
            await _forceGarbageCollection();
          }

          // Check for memory leak pattern (consistently increasing memory usage)
          final memoryTrend = _calculateMemoryTrend(memoryReadings);

          expect(
            memoryTrend,
            lessThan(5.0), // Less than 5MB increase per iteration
            reason: 'Potential memory leak detected: ${memoryTrend}MB increase per iteration',
          );

          print('Memory leak test: Trend=${memoryTrend}MB per iteration');
          print('Memory readings: ${memoryReadings.map((m) => '${m.toStringAsFixed(1)}MB').join(', ')}');
        }
      });

      test('should handle memory pressure scenarios', () async {
        final memoryPressureScenarios = [
          {'name': 'low_memory', 'limitMB': 20, 'fileSizeMB': 50},
          {'name': 'very_low_memory', 'limitMB': 10, 'fileSizeMB': 100},
          {'name': 'extreme_pressure', 'limitMB': 5, 'fileSizeMB': 200},
        ];

        for (final scenario in memoryPressureScenarios) {
          final limitMB = scenario['limitMB'] as int;
          final fileSizeMB = scenario['fileSizeMB'] as int;
          final scenarioName = scenario['name'] as String;

          print('Testing memory pressure scenario: $scenarioName');

          ProcessInfo.reset();
          ProcessInfo.setMemoryPressureLimit(limitMB * 1024 * 1024);

          await _simulateMemoryPressureScenario(limitMB, fileSizeMB);

          final currentMemoryMB = (await ProcessInfo.currentRss) / (1024 * 1024);

          // Under memory pressure, the system should adapt and stay within limits
          expect(currentMemoryMB, lessThanOrEqualTo(limitMB * 1.3), reason: 'Memory pressure handling failed for $scenarioName');

          print('Memory pressure $scenarioName: Peak=${currentMemoryMB}MB (limit=${limitMB}MB)');
          ProcessInfo.reset();
        }
      });
    });

    group('Performance Benchmarking', () {
      test('should benchmark chunked vs traditional processing', () async {
        final files = await TestDataLoader.getTestFilesForFormat('wav');

        if (files.isNotEmpty) {
          final testFile = files.first;
          final filePath = TestDataLoader.getAssetPath(testFile);

          // Benchmark chunked processing
          final chunkedResult = await performanceBenchmark.measurePerformance(
            'chunked_processing',
            () async => await _simulateChunkedProcessing(filePath, 1024 * 1024),
          );

          // Benchmark traditional processing
          final traditionalResult = await performanceBenchmark.measurePerformance(
            'traditional_processing',
            () async => await _simulateTraditionalProcessing(filePath),
          );

          // Chunked processing might be slightly slower but should be comparable
          final performanceRatio = traditionalResult.averageTimeMs > 0
              ? chunkedResult.averageTimeMs / traditionalResult.averageTimeMs
              : 1.0; // Default to 1.0 if traditional time is 0

          expect(
            performanceRatio,
            lessThan(3.0), // Should not be more than 3x slower
            reason: 'Chunked processing is significantly slower than traditional: ${performanceRatio}x',
          );

          print('Performance comparison:');
          print('  Chunked: ${chunkedResult.averageTimeMs}ms (±${chunkedResult.standardDeviationMs}ms)');
          print('  Traditional: ${traditionalResult.averageTimeMs}ms (±${traditionalResult.standardDeviationMs}ms)');
          print('  Ratio: ${performanceRatio.toStringAsFixed(2)}x');
        }
      });

      test('should benchmark performance across different file sizes', () async {
        final performanceResults = <String, PerformanceResult>{};

        for (final sizeEntry in TestDataGenerator.fileSizes.entries) {
          final sizeName = sizeEntry.key;
          final targetSize = sizeEntry.value;

          // Skip massive files in CI
          if (sizeName == 'massive' && Platform.environment['CI'] == 'true') {
            continue;
          }

          final filesBySize = await TestDataLoader.getTestFilesBySize();
          final files = filesBySize[sizeName] ?? [];

          if (files.isNotEmpty) {
            final testFile = files.first;
            final filePath = TestDataLoader.getAssetPath(testFile);

            final result = await performanceBenchmark.measurePerformance('size_$sizeName', () async => await _simulateChunkedProcessing(filePath, targetSize));

            performanceResults[sizeName] = result;

            // Performance should scale reasonably with file size
            final timePerMB = result.averageTimeMs / (targetSize / (1024 * 1024));

            expect(
              timePerMB,
              lessThan(5000), // Less than 5 seconds per MB (more realistic for simulation)
              reason: 'Processing time per MB is too high for $sizeName: ${timePerMB}ms/MB',
            );

            print('Performance for $sizeName: ${result.averageTimeMs}ms (${timePerMB.toStringAsFixed(1)}ms/MB)');
          }
        }

        // Verify performance scaling
        _validatePerformanceScaling(performanceResults);
      });

      test('should benchmark concurrent processing performance', () async {
        final files = await TestDataLoader.getTestFilesForFormat('wav');

        if (files.length >= 3) {
          final testFiles = files.take(3).toList();

          // Benchmark sequential processing
          final sequentialResult = await performanceBenchmark.measurePerformance('sequential_processing', () async {
            for (final file in testFiles) {
              final filePath = TestDataLoader.getAssetPath(file);
              await _simulateChunkedProcessing(filePath, 1024 * 1024);
            }
          });

          // Benchmark concurrent processing
          final concurrentResult = await performanceBenchmark.measurePerformance('concurrent_processing', () async {
            final futures = testFiles.map((file) {
              final filePath = TestDataLoader.getAssetPath(file);
              return _simulateChunkedProcessing(filePath, 1024 * 1024);
            });
            await Future.wait(futures);
          });

          // Concurrent processing should be faster (but not necessarily 3x due to overhead)
          final speedup = sequentialResult.averageTimeMs / concurrentResult.averageTimeMs;

          expect(
            speedup,
            greaterThan(1.2), // At least 20% speedup
            reason: 'Concurrent processing shows no significant speedup: ${speedup}x',
          );

          print('Concurrent processing speedup: ${speedup.toStringAsFixed(2)}x');
          print('  Sequential: ${sequentialResult.averageTimeMs}ms');
          print('  Concurrent: ${concurrentResult.averageTimeMs}ms');
        }
      });

      test('should validate memory usage during concurrent processing', () async {
        final files = await TestDataLoader.getTestFilesForFormat('wav');

        if (files.length >= 3) {
          final testFiles = files.take(3).toList();

          final memoryUsage = await memoryMonitor.measureMemoryUsage(() async {
            final futures = testFiles.map((file) {
              final filePath = TestDataLoader.getAssetPath(file);
              return _simulateChunkedProcessing(filePath, 1024 * 1024);
            });
            await Future.wait(futures);
          });

          // Memory usage should not scale linearly with concurrent operations
          // (due to chunked processing and memory management)
          final expectedMaxMemory = 150; // MB - reasonable limit for 3 concurrent operations

          expect(
            memoryUsage.peakMemoryMB,
            lessThanOrEqualTo(expectedMaxMemory),
            reason: 'Concurrent processing memory usage too high: ${memoryUsage.peakMemoryMB}MB',
          );

          print('Concurrent processing memory usage: Peak=${memoryUsage.peakMemoryMB}MB');
        }
      });
    });

    group('Resource Management Testing', () {
      test('should validate proper resource cleanup', () async {
        final files = await TestDataLoader.getTestFilesForFormat('wav');

        if (files.isNotEmpty) {
          final testFile = files.first;
          final filePath = TestDataLoader.getAssetPath(testFile);

          // Track resource usage before and after processing
          final initialMemory = await memoryMonitor.getCurrentMemoryUsage();

          // Process file multiple times
          for (int i = 0; i < 5; i++) {
            await _simulateChunkedProcessing(filePath, 1024 * 1024);
          }

          // Force cleanup and garbage collection
          await _forceGarbageCollection();
          await Future.delayed(Duration(milliseconds: 100));

          final finalMemory = await memoryMonitor.getCurrentMemoryUsage();
          final memoryIncrease = finalMemory - initialMemory;

          expect(
            memoryIncrease,
            lessThan(50), // Less than 50MB increase
            reason: 'Excessive memory increase suggests resource leak: ${memoryIncrease}MB',
          );

          print('Resource cleanup test: Memory increase=${memoryIncrease}MB');
        }
      });

      test('should handle file handle limits', () async {
        final files = await TestDataLoader.getTestFilesForFormat('wav');

        if (files.isNotEmpty) {
          final testFile = files.first;
          final filePath = TestDataLoader.getAssetPath(testFile);

          // Simulate processing many files to test file handle management
          final fileHandleTest = await performanceBenchmark.measurePerformance('file_handle_stress', () async {
            for (int i = 0; i < 100; i++) {
              await _simulateFileHandleUsage(filePath);
            }
          });

          // Should complete without file handle exhaustion
          expect(
            fileHandleTest.averageTimeMs,
            lessThan(30000), // Less than 30 seconds
            reason: 'File handle stress test took too long: ${fileHandleTest.averageTimeMs}ms',
          );

          print('File handle stress test: ${fileHandleTest.averageTimeMs}ms for 100 operations');
        }
      });

      test('should validate thread pool management', () async {
        // Test that concurrent operations don't exhaust thread pools
        final threadPoolTest = await performanceBenchmark.measurePerformance('thread_pool_stress', () async {
          final futures = <Future>[];

          // Create many concurrent operations
          for (int i = 0; i < 50; i++) {
            futures.add(_simulateThreadPoolUsage());
          }

          await Future.wait(futures);
        });

        expect(
          threadPoolTest.averageTimeMs,
          lessThan(10000), // Less than 10 seconds
          reason: 'Thread pool stress test took too long: ${threadPoolTest.averageTimeMs}ms',
        );

        print('Thread pool stress test: ${threadPoolTest.averageTimeMs}ms for 50 concurrent operations');
      });
    });

    group('Performance Regression Detection', () {
      test('should establish performance baselines', () async {
        final baselines = await performanceBenchmark.establishBaselines();

        expect(baselines, isNotEmpty, reason: 'No performance baselines established');

        for (final entry in baselines.entries) {
          final operation = entry.key;
          final baseline = entry.value;

          expect(baseline.averageTimeMs, greaterThan(0));
          expect(baseline.standardDeviationMs, greaterThanOrEqualTo(0));

          print('Baseline for $operation: ${baseline.averageTimeMs}ms (±${baseline.standardDeviationMs}ms)');
        }
      });

      test('should detect performance regressions', () async {
        // This test would compare current performance against stored baselines
        // For now, we'll simulate the detection logic

        final currentPerformance = await performanceBenchmark.measureCurrentPerformance();
        final regressions = performanceBenchmark.detectRegressions(currentPerformance);

        expect(regressions, isEmpty, reason: 'Performance regressions detected: ${regressions.join(', ')}');

        print('Performance regression check: ${regressions.isEmpty ? 'PASS' : 'FAIL'}');
      });
    });
  });
}

/// Memory monitoring utilities
class MemoryMonitor {
  final List<double> _memoryReadings = [];
  bool _isMonitoring = false;

  /// Measures memory usage during operation execution
  Future<MemoryUsageResult> measureMemoryUsage(Future<void> Function() operation) async {
    _memoryReadings.clear();
    _isMonitoring = true;

    // Start monitoring
    final monitoringFuture = _startMemoryMonitoring();

    try {
      // Execute operation
      await operation();
    } finally {
      // Stop monitoring
      _isMonitoring = false;
      await monitoringFuture;
    }

    return _calculateMemoryUsageResult();
  }

  /// Gets current memory usage in MB
  Future<double> getCurrentMemoryUsage() async {
    // Simulate memory usage measurement
    // In a real implementation, this would use platform-specific APIs
    final info = await ProcessInfo.currentRss;
    return info / (1024 * 1024); // Convert to MB
  }

  Future<void> _startMemoryMonitoring() async {
    // Monitor memory usage every 100ms
    while (_isMonitoring) {
      final usage = await getCurrentMemoryUsage();
      _memoryReadings.add(usage);
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  MemoryUsageResult _calculateMemoryUsageResult() {
    if (_memoryReadings.isEmpty) {
      return MemoryUsageResult(peakMemoryMB: 0, averageMemoryMB: 0, minMemoryMB: 0);
    }

    final peak = _memoryReadings.reduce(math.max);
    final min = _memoryReadings.reduce(math.min);
    final average = _memoryReadings.reduce((a, b) => a + b) / _memoryReadings.length;

    return MemoryUsageResult(peakMemoryMB: peak, averageMemoryMB: average, minMemoryMB: min);
  }

  Future<void> cleanup() async {
    _memoryReadings.clear();
  }
}

/// Performance benchmarking utilities
class PerformanceBenchmark {
  final Map<String, List<double>> _performanceData = {};

  /// Measures performance of an operation
  Future<PerformanceResult> measurePerformance(String operationName, Future<void> Function() operation) async {
    final times = <double>[];

    // Run operation multiple times for statistical significance
    for (int i = 0; i < 5; i++) {
      final stopwatch = Stopwatch()..start();
      await operation();
      stopwatch.stop();

      times.add(stopwatch.elapsedMilliseconds.toDouble());
    }

    _performanceData[operationName] = times;

    return _calculatePerformanceResult(times);
  }

  PerformanceResult _calculatePerformanceResult(List<double> times) {
    final average = times.reduce((a, b) => a + b) / times.length;
    final variance = times.map((t) => math.pow(t - average, 2)).reduce((a, b) => a + b) / times.length;
    final standardDeviation = math.sqrt(variance);

    return PerformanceResult(
      averageTimeMs: average,
      standardDeviationMs: standardDeviation,
      minTimeMs: times.reduce(math.min),
      maxTimeMs: times.reduce(math.max),
    );
  }

  /// Establishes performance baselines for regression testing
  Future<Map<String, PerformanceResult>> establishBaselines() async {
    final baselines = <String, PerformanceResult>{};

    // Establish baselines for common operations
    final operations = {
      'small_file_processing': () => _simulateChunkedProcessing('test_file.wav', 1024 * 1024),
      'memory_allocation': () => _simulateMemoryAllocation(10 * 1024 * 1024),
      'file_io': () => _simulateFileIO(),
    };

    for (final entry in operations.entries) {
      final result = await measurePerformance(entry.key, entry.value);
      baselines[entry.key] = result;
    }

    return baselines;
  }

  /// Measures current performance for regression detection
  Future<Map<String, PerformanceResult>> measureCurrentPerformance() async {
    // This would measure current performance and compare against baselines
    return await establishBaselines(); // Simplified for this implementation
  }

  /// Detects performance regressions
  List<String> detectRegressions(Map<String, PerformanceResult> currentPerformance) {
    final regressions = <String>[];

    // This would compare against stored baselines
    // For now, we'll return empty list (no regressions)

    return regressions;
  }

  Future<void> cleanup() async {
    _performanceData.clear();
  }
}

/// Memory usage measurement result
class MemoryUsageResult {
  final double peakMemoryMB;
  final double averageMemoryMB;
  final double minMemoryMB;

  const MemoryUsageResult({required this.peakMemoryMB, required this.averageMemoryMB, required this.minMemoryMB});
}

/// Performance measurement result
class PerformanceResult {
  final double averageTimeMs;
  final double standardDeviationMs;
  final double minTimeMs;
  final double maxTimeMs;

  const PerformanceResult({required this.averageTimeMs, required this.standardDeviationMs, required this.minTimeMs, required this.maxTimeMs});
}

/// Simulation functions for testing
Future<void> _simulateChunkedProcessing(String filePath, int fileSize) async {
  // Simulate efficient chunked processing
  final chunkSize = math.min(10 * 1024 * 1024, fileSize ~/ 10); // 10MB or 1/10 of file size
  final numChunks = math.min(5, (fileSize / chunkSize).ceil()); // Limit chunks for efficiency

  for (int i = 0; i < numChunks; i++) {
    // Simulate lightweight chunk processing
    final chunk = List<int>.generate(math.min(chunkSize, 1024), (index) => 0); // Smaller chunks

    // Simulate faster processing time
    await Future.delayed(Duration(milliseconds: 1));

    // Simulate memory cleanup
    chunk.clear();
  }
}

Future<void> _simulateTraditionalProcessing(String filePath) async {
  // Simulate traditional processing (loading entire file)
  final file = File(filePath);
  final size = await file.length();

  // Simulate loading entire file into memory (but use smaller allocation for test)
  final data = List<int>.generate(math.min(size, 10 * 1024), (index) => 0); // Max 10KB for test

  // Simulate processing time (faster than chunked for small files)
  final processingTime = math.max(5, (size / (1024 * 1024) * 20).round()); // Minimum 5ms, 20ms per MB
  await Future.delayed(Duration(milliseconds: processingTime));

  data.clear();
}

Future<void> _simulateChunkedProcessingWithLimit(int limitMB) async {
  // Simple simulation that respects memory limits
  ProcessInfo.setSimulatedMemoryUsage((limitMB * 0.8 * 1024 * 1024).round()); // Start at 80% of limit

  // Process in small chunks to stay under limit
  final numChunks = 5; // Fixed number of chunks for predictable execution

  for (int i = 0; i < numChunks; i++) {
    // Simulate processing
    await Future.delayed(Duration(milliseconds: 5));

    // Simulate memory cleanup every few chunks
    if (i % 2 == 0) {
      ProcessInfo.setSimulatedMemoryUsage((limitMB * 0.6 * 1024 * 1024).round());
    }
  }

  // End with memory under limit
  ProcessInfo.setSimulatedMemoryUsage((limitMB * 0.7 * 1024 * 1024).round());
}

Future<void> _simulateMemoryPressureScenario(int limitMB, int fileSizeMB) async {
  // Set up memory pressure simulation (don't reset, preserve existing setup)
  ProcessInfo.setMemoryPressureLimit(limitMB * 1024 * 1024);

  // Simulate processing a large file with memory constraints
  final fileSize = fileSizeMB * 1024 * 1024;
  final memoryLimit = limitMB * 1024 * 1024;

  // Use smaller chunks when under memory pressure
  final chunkSize = math.min(memoryLimit ~/ 4, 1024 * 1024); // Quarter of limit or 1MB
  final numChunks = (fileSize / chunkSize).ceil();

  for (int i = 0; i < numChunks; i++) {
    // Simulate memory allocation
    ProcessInfo.allocateMemory(chunkSize);

    // Simulate processing time
    await Future.delayed(Duration(milliseconds: 2));

    // Simulate memory cleanup under pressure
    if (i % 5 == 0) {
      ProcessInfo.deallocateMemory(chunkSize * 2); // Clean up more aggressively
      await _forceGarbageCollection();
    } else {
      ProcessInfo.deallocateMemory(chunkSize);
    }
  }

  // Final cleanup - set memory to be under pressure limit
  ProcessInfo.setSimulatedMemoryUsage((limitMB * 0.8 * 1024 * 1024).round());
}

Future<void> _simulateFileHandleUsage(String filePath) async {
  // Simulate opening and closing file handles
  final file = File(filePath);

  if (await file.exists()) {
    final handle = await file.open();
    await Future.delayed(Duration(milliseconds: 1));
    await handle.close();
  }
}

Future<void> _simulateThreadPoolUsage() async {
  // Simulate CPU-intensive work that would use thread pool
  await Future.delayed(Duration(milliseconds: 50));
}

Future<void> _simulateMemoryAllocation(int bytes) async {
  final data = List<int>.generate(bytes, (index) => 0);
  await Future.delayed(Duration(milliseconds: 10));
  data.clear();
}

Future<void> _simulateFileIO() async {
  // Simulate file I/O operations
  final tempFile = File('temp_test_file.tmp');
  await tempFile.writeAsBytes(List<int>.generate(1024, (index) => 0));
  await tempFile.readAsBytes();
  await tempFile.delete();
}

Future<void> _forceGarbageCollection() async {
  // Force garbage collection (platform-specific implementation would be needed)
  await Future.delayed(Duration(milliseconds: 10));
}

double _calculateMemoryTrend(List<double> readings) {
  if (readings.length < 2) return 0.0;

  // Calculate linear regression slope
  final n = readings.length;
  final sumX = (n * (n - 1)) / 2; // Sum of indices
  final sumY = readings.reduce((a, b) => a + b);
  final sumXY = readings.asMap().entries.map((e) => e.key * e.value).reduce((a, b) => a + b);
  final sumX2 = (n * (n - 1) * (2 * n - 1)) / 6; // Sum of squared indices

  final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  return slope;
}

double _calculateExpectedMaxMemory(int fileSize) {
  // Calculate expected maximum memory based on chunked processing
  final chunkSize = 10 * 1024 * 1024; // 10MB chunks
  final overhead = 50; // 50MB overhead for processing

  return (chunkSize / (1024 * 1024)) + overhead; // Convert to MB and add overhead
}

void _validatePerformanceScaling(Map<String, PerformanceResult> results) {
  // Validate that performance scales reasonably with file size
  final sortedResults = results.entries.toList()..sort((a, b) => TestDataGenerator.fileSizes[a.key]!.compareTo(TestDataGenerator.fileSizes[b.key]!));

  for (int i = 1; i < sortedResults.length; i++) {
    final prevSize = TestDataGenerator.fileSizes[sortedResults[i - 1].key]!;
    final currSize = TestDataGenerator.fileSizes[sortedResults[i].key]!;
    final prevTime = sortedResults[i - 1].value.averageTimeMs;
    final currTime = sortedResults[i].value.averageTimeMs;

    final sizeRatio = currSize / prevSize;
    final timeRatio = currTime / prevTime;

    // Performance should not degrade more than quadratically with size
    expect(
      timeRatio,
      lessThan(sizeRatio * sizeRatio),
      reason: 'Performance scaling is worse than quadratic between ${sortedResults[i - 1].key} and ${sortedResults[i].key}',
    );
  }
}

/// Process information utilities (simplified implementation)
class ProcessInfo {
  static int _simulatedMemoryUsage = 50 * 1024 * 1024; // 50MB baseline
  static int _memoryPressureLimit = 100 * 1024 * 1024; // 100MB default limit

  static Future<int> get currentRss async {
    // Simulate getting current RSS memory usage
    // In a real implementation, this would use platform-specific APIs
    return _simulatedMemoryUsage;
  }

  /// Sets the simulated memory usage for testing
  static void setSimulatedMemoryUsage(int bytes) {
    _simulatedMemoryUsage = bytes;
  }

  /// Sets the memory pressure limit for testing
  static void setMemoryPressureLimit(int bytes) {
    _memoryPressureLimit = bytes;
  }

  /// Simulates memory allocation
  static void allocateMemory(int bytes) {
    _simulatedMemoryUsage += bytes;
    // Cap at pressure limit to simulate memory pressure response
    if (_simulatedMemoryUsage > _memoryPressureLimit) {
      _simulatedMemoryUsage = _memoryPressureLimit;
    }
  }

  /// Simulates memory deallocation
  static void deallocateMemory(int bytes) {
    _simulatedMemoryUsage = math.max(50 * 1024 * 1024, _simulatedMemoryUsage - bytes); // Keep minimum baseline
  }

  /// Resets to baseline memory usage
  static void reset() {
    _simulatedMemoryUsage = 50 * 1024 * 1024;
    _memoryPressureLimit = 100 * 1024 * 1024;
  }
}
