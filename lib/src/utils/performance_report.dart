import 'operation_statistics.dart';

/// Comprehensive performance analysis report
///
/// Contains overall performance metrics, bottleneck analysis, and detailed
/// statistics for all profiled operations in the system.
class PerformanceReport {
  /// Total number of operations profiled
  final int totalOperations;
  
  /// Number of operations that completed successfully
  final int successfulOperations;
  
  /// Overall failure rate (0.0 - 1.0)
  final double failureRate;
  
  /// Total duration of all operations combined
  final Duration totalDuration;
  
  /// Total memory usage across all operations in bytes
  final int totalMemoryUsage;
  
  /// Detailed statistics for each operation type
  final Map<String, OperationStatistics> operationStatistics;
  
  /// List of identified performance bottlenecks
  final List<String> bottlenecks;
  
  /// List of operations with high memory usage
  final List<String> memoryIntensiveOperations;
  
  /// When this report was generated
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