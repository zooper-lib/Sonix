import 'profiled_operation.dart';

/// Statistical analysis for a specific operation type
///
/// Provides comprehensive statistics including timing metrics, success rates,
/// and memory usage analysis for operations of the same type.
class OperationStatistics {
  /// Name of the operation being analyzed
  final String operationName;

  /// Total number of executions recorded
  final int totalExecutions;

  /// Number of successful executions
  final int successfulExecutions;

  /// Percentage of operations that failed (0.0 - 1.0)
  final double failureRate;

  /// Average duration in milliseconds
  final double averageDuration;

  /// Median duration in milliseconds
  final double medianDuration;

  /// Minimum duration recorded in milliseconds
  final double minDuration;

  /// Maximum duration recorded in milliseconds
  final double maxDuration;

  /// Standard deviation of durations
  final double standardDeviation;

  /// Average memory usage in bytes
  final double averageMemoryUsage;

  /// Total memory usage across all operations in bytes
  final double totalMemoryUsage;

  /// List of all profiled operations
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
