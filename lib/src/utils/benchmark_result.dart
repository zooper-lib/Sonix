import 'dart:math' as math;

/// Result from a benchmark test
///
/// Contains comprehensive benchmark results including timing data for
/// multiple test scenarios and statistical analysis of performance.
class BenchmarkResult {
  /// Name of the benchmark test
  final String testName;

  /// Map of test scenarios to their timing results (in milliseconds)
  final Map<String, List<double>> results;

  /// Number of iterations performed per test
  final int iterations;

  /// When the benchmark was completed
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
