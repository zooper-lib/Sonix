import 'dart:async';
import 'dart:math' as math;

import '../models/waveform_data.dart';
import '../models/audio_data.dart';
import 'resource_manager.dart';

/// Comprehensive performance profiler for Sonix operations
class PerformanceProfiler {
  static final PerformanceProfiler _instance = PerformanceProfiler._internal();
  factory PerformanceProfiler() => _instance;
  PerformanceProfiler._internal();

  final List<ProfiledOperation> _operations = [];
  final Map<String, List<double>> _metrics = {};
  bool _isEnabled = false;

  /// Enable performance profiling
  void enable() {
    _isEnabled = true;
  }

  /// Disable performance profiling
  void disable() {
    _isEnabled = false;
  }

  /// Profile an operation and return its result
  Future<T> profile<T>(String operationName, Future<T> Function() operation, {Map<String, dynamic>? metadata}) async {
    if (!_isEnabled) {
      return await operation();
    }

    final stopwatch = Stopwatch()..start();
    final startMemory = _getCurrentMemoryUsage();
    final startTime = DateTime.now();

    try {
      final result = await operation();
      stopwatch.stop();

      final endMemory = _getCurrentMemoryUsage();
      final memoryDelta = endMemory - startMemory;

      final profiledOp = ProfiledOperation(
        name: operationName,
        duration: stopwatch.elapsed,
        memoryUsage: memoryDelta,
        startTime: startTime,
        endTime: DateTime.now(),
        success: true,
        metadata: metadata ?? {},
      );

      _operations.add(profiledOp);
      _updateMetrics(operationName, stopwatch.elapsedMilliseconds.toDouble());

      return result;
    } catch (e) {
      stopwatch.stop();

      final profiledOp = ProfiledOperation(
        name: operationName,
        duration: stopwatch.elapsed,
        memoryUsage: 0,
        startTime: startTime,
        endTime: DateTime.now(),
        success: false,
        error: e.toString(),
        metadata: metadata ?? {},
      );

      _operations.add(profiledOp);
      rethrow;
    }
  }

  /// Profile a synchronous operation
  T profileSync<T>(String operationName, T Function() operation, {Map<String, dynamic>? metadata}) {
    if (!_isEnabled) {
      return operation();
    }

    final stopwatch = Stopwatch()..start();
    final startMemory = _getCurrentMemoryUsage();
    final startTime = DateTime.now();

    try {
      final result = operation();
      stopwatch.stop();

      final endMemory = _getCurrentMemoryUsage();
      final memoryDelta = endMemory - startMemory;

      final profiledOp = ProfiledOperation(
        name: operationName,
        duration: stopwatch.elapsed,
        memoryUsage: memoryDelta,
        startTime: startTime,
        endTime: DateTime.now(),
        success: true,
        metadata: metadata ?? {},
      );

      _operations.add(profiledOp);
      _updateMetrics(operationName, stopwatch.elapsedMilliseconds.toDouble());

      return result;
    } catch (e) {
      stopwatch.stop();

      final profiledOp = ProfiledOperation(
        name: operationName,
        duration: stopwatch.elapsed,
        memoryUsage: 0,
        startTime: startTime,
        endTime: DateTime.now(),
        success: false,
        error: e.toString(),
        metadata: metadata ?? {},
      );

      _operations.add(profiledOp);
      rethrow;
    }
  }

  /// Get performance statistics for an operation
  OperationStatistics? getStatistics(String operationName) {
    final operations = _operations.where((op) => op.name == operationName).toList();
    if (operations.isEmpty) return null;

    final durations = operations.map((op) => op.duration.inMilliseconds.toDouble()).toList();
    final memoryUsages = operations.map((op) => op.memoryUsage.toDouble()).toList();
    final successCount = operations.where((op) => op.success).length;

    return OperationStatistics(
      operationName: operationName,
      totalExecutions: operations.length,
      successfulExecutions: successCount,
      failureRate: (operations.length - successCount) / operations.length,
      averageDuration: _calculateAverage(durations),
      medianDuration: _calculateMedian(durations),
      minDuration: durations.reduce(math.min),
      maxDuration: durations.reduce(math.max),
      standardDeviation: _calculateStandardDeviation(durations),
      averageMemoryUsage: _calculateAverage(memoryUsages),
      totalMemoryUsage: memoryUsages.reduce((a, b) => a + b),
      operations: operations,
    );
  }

  /// Get all operation statistics
  Map<String, OperationStatistics> getAllStatistics() {
    final result = <String, OperationStatistics>{};
    final operationNames = _operations.map((op) => op.name).toSet();

    for (final name in operationNames) {
      final stats = getStatistics(name);
      if (stats != null) {
        result[name] = stats;
      }
    }

    return result;
  }

  /// Generate performance report
  PerformanceReport generateReport() {
    final allStats = getAllStatistics();
    final totalOperations = _operations.length;
    final successfulOperations = _operations.where((op) => op.success).length;
    final totalDuration = _operations.fold<Duration>(Duration.zero, (sum, op) => sum + op.duration);
    final totalMemoryUsage = _operations.fold<int>(0, (sum, op) => sum + op.memoryUsage);

    // Find bottlenecks
    final bottlenecks = <String>[];
    for (final entry in allStats.entries) {
      final stats = entry.value;
      if (stats.averageDuration > 1000) {
        // Operations taking more than 1 second
        bottlenecks.add('${entry.key}: ${stats.averageDuration.toStringAsFixed(1)}ms avg');
      }
    }

    // Memory-intensive operations
    final memoryIntensive = <String>[];
    for (final entry in allStats.entries) {
      final stats = entry.value;
      if (stats.averageMemoryUsage > 10 * 1024 * 1024) {
        // More than 10MB
        memoryIntensive.add('${entry.key}: ${(stats.averageMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB avg');
      }
    }

    return PerformanceReport(
      totalOperations: totalOperations,
      successfulOperations: successfulOperations,
      failureRate: (totalOperations - successfulOperations) / totalOperations,
      totalDuration: totalDuration,
      totalMemoryUsage: totalMemoryUsage,
      operationStatistics: allStats,
      bottlenecks: bottlenecks,
      memoryIntensiveOperations: memoryIntensive,
      generatedAt: DateTime.now(),
    );
  }

  /// Clear all profiling data
  void clear() {
    _operations.clear();
    _metrics.clear();
  }

  /// Export profiling data to JSON
  Map<String, dynamic> exportToJson() {
    return {'operations': _operations.map((op) => op.toJson()).toList(), 'metrics': _metrics, 'exportedAt': DateTime.now().toIso8601String()};
  }

  /// Benchmark waveform generation performance
  Future<BenchmarkResult> benchmarkWaveformGeneration({required List<int> resolutions, required List<double> durations, int iterations = 3}) async {
    final results = <String, List<double>>{};

    for (final duration in durations) {
      for (final resolution in resolutions) {
        final key = 'duration_${duration}s_resolution_$resolution';
        final times = <double>[];

        for (int i = 0; i < iterations; i++) {
          final audioData = _createTestAudioData(duration);

          final stopwatch = Stopwatch()..start();
          // This would call the actual waveform generation
          // For now, simulate the operation
          await Future.delayed(Duration(milliseconds: (duration * resolution / 1000).round()));
          stopwatch.stop();

          times.add(stopwatch.elapsedMilliseconds.toDouble());
          audioData.dispose();
        }

        results[key] = times;
      }
    }

    return BenchmarkResult(testName: 'Waveform Generation Benchmark', results: results, iterations: iterations, completedAt: DateTime.now());
  }

  /// Benchmark widget rendering performance
  Future<BenchmarkResult> benchmarkWidgetRendering({required List<int> amplitudeCounts, int iterations = 5}) async {
    final results = <String, List<double>>{};

    for (final count in amplitudeCounts) {
      final key = 'amplitudes_$count';
      final times = <double>[];

      for (int i = 0; i < iterations; i++) {
        final waveformData = _createTestWaveformData(count);

        final stopwatch = Stopwatch()..start();
        // Simulate widget rendering time
        await Future.delayed(Duration(microseconds: count ~/ 10));
        stopwatch.stop();

        times.add(stopwatch.elapsedMicroseconds.toDouble());
        waveformData.dispose();
      }

      results[key] = times;
    }

    return BenchmarkResult(testName: 'Widget Rendering Benchmark', results: results, iterations: iterations, completedAt: DateTime.now());
  }

  void _updateMetrics(String operationName, double value) {
    _metrics.putIfAbsent(operationName, () => []).add(value);

    // Keep only last 100 measurements to prevent memory growth
    if (_metrics[operationName]!.length > 100) {
      _metrics[operationName]!.removeAt(0);
    }
  }

  int _getCurrentMemoryUsage() {
    try {
      return ResourceManager().memoryManager.currentMemoryUsage;
    } catch (e) {
      return 0;
    }
  }

  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    } else {
      return sorted[middle];
    }
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = _calculateAverage(values);
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }

  AudioData _createTestAudioData(double durationSeconds) {
    final sampleRate = 44100;
    final samples = List.generate((sampleRate * durationSeconds).round(), (i) => math.sin(2 * math.pi * 440 * i / sampleRate) * 0.5);

    return AudioData(
      samples: samples,
      sampleRate: sampleRate,
      channels: 1,
      duration: Duration(milliseconds: (durationSeconds * 1000).round()),
    );
  }

  WaveformData _createTestWaveformData(int amplitudeCount) {
    final amplitudes = List.generate(amplitudeCount, (i) => math.sin(2 * math.pi * i / amplitudeCount) * 0.5 + 0.5);

    return WaveformData(
      amplitudes: amplitudes,
      duration: const Duration(seconds: 10),
      sampleRate: 44100,
      metadata: WaveformMetadata(resolution: amplitudeCount, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
    );
  }
}

/// Information about a profiled operation
class ProfiledOperation {
  final String name;
  final Duration duration;
  final int memoryUsage;
  final DateTime startTime;
  final DateTime endTime;
  final bool success;
  final String? error;
  final Map<String, dynamic> metadata;

  const ProfiledOperation({
    required this.name,
    required this.duration,
    required this.memoryUsage,
    required this.startTime,
    required this.endTime,
    required this.success,
    this.error,
    required this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'duration_ms': duration.inMilliseconds,
      'memory_usage_bytes': memoryUsage,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'success': success,
      'error': error,
      'metadata': metadata,
    };
  }
}

/// Statistics for a specific operation type
class OperationStatistics {
  final String operationName;
  final int totalExecutions;
  final int successfulExecutions;
  final double failureRate;
  final double averageDuration;
  final double medianDuration;
  final double minDuration;
  final double maxDuration;
  final double standardDeviation;
  final double averageMemoryUsage;
  final double totalMemoryUsage;
  final List<ProfiledOperation> operations;

  const OperationStatistics({
    required this.operationName,
    required this.totalExecutions,
    required this.successfulExecutions,
    required this.failureRate,
    required this.averageDuration,
    required this.medianDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.standardDeviation,
    required this.averageMemoryUsage,
    required this.totalMemoryUsage,
    required this.operations,
  });

  @override
  String toString() {
    return 'OperationStatistics(\n'
        '  operation: $operationName\n'
        '  executions: $totalExecutions ($successfulExecutions successful)\n'
        '  failure rate: ${(failureRate * 100).toStringAsFixed(1)}%\n'
        '  duration: ${averageDuration.toStringAsFixed(1)}ms avg, '
        '${medianDuration.toStringAsFixed(1)}ms median\n'
        '  range: ${minDuration.toStringAsFixed(1)}ms - ${maxDuration.toStringAsFixed(1)}ms\n'
        '  std dev: ${standardDeviation.toStringAsFixed(1)}ms\n'
        '  memory: ${(averageMemoryUsage / 1024).toStringAsFixed(1)}KB avg\n'
        ')';
  }
}

/// Overall performance report
class PerformanceReport {
  final int totalOperations;
  final int successfulOperations;
  final double failureRate;
  final Duration totalDuration;
  final int totalMemoryUsage;
  final Map<String, OperationStatistics> operationStatistics;
  final List<String> bottlenecks;
  final List<String> memoryIntensiveOperations;
  final DateTime generatedAt;

  const PerformanceReport({
    required this.totalOperations,
    required this.successfulOperations,
    required this.failureRate,
    required this.totalDuration,
    required this.totalMemoryUsage,
    required this.operationStatistics,
    required this.bottlenecks,
    required this.memoryIntensiveOperations,
    required this.generatedAt,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== Sonix Performance Report ===');
    buffer.writeln('Generated: $generatedAt');
    buffer.writeln('');
    buffer.writeln('Overall Statistics:');
    buffer.writeln('  Total operations: $totalOperations');
    buffer.writeln('  Successful: $successfulOperations');
    buffer.writeln('  Failure rate: ${(failureRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Total duration: ${totalDuration.inMilliseconds}ms');
    buffer.writeln('  Total memory usage: ${(totalMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB');
    buffer.writeln('');

    if (bottlenecks.isNotEmpty) {
      buffer.writeln('Performance Bottlenecks:');
      for (final bottleneck in bottlenecks) {
        buffer.writeln('  - $bottleneck');
      }
      buffer.writeln('');
    }

    if (memoryIntensiveOperations.isNotEmpty) {
      buffer.writeln('Memory-Intensive Operations:');
      for (final operation in memoryIntensiveOperations) {
        buffer.writeln('  - $operation');
      }
      buffer.writeln('');
    }

    buffer.writeln('Operation Details:');
    for (final stats in operationStatistics.values) {
      buffer.writeln(stats.toString());
    }

    return buffer.toString();
  }
}

/// Result of a benchmark test
class BenchmarkResult {
  final String testName;
  final Map<String, List<double>> results;
  final int iterations;
  final DateTime completedAt;

  const BenchmarkResult({required this.testName, required this.results, required this.iterations, required this.completedAt});

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== $testName ===');
    buffer.writeln('Completed: $completedAt');
    buffer.writeln('Iterations per test: $iterations');
    buffer.writeln('');

    for (final entry in results.entries) {
      final values = entry.value;
      final avg = values.reduce((a, b) => a + b) / values.length;
      final min = values.reduce(math.min);
      final max = values.reduce(math.max);

      buffer.writeln('${entry.key}:');
      buffer.writeln('  Average: ${avg.toStringAsFixed(2)}ms');
      buffer.writeln('  Range: ${min.toStringAsFixed(2)}ms - ${max.toStringAsFixed(2)}ms');
    }

    return buffer.toString();
  }
}
