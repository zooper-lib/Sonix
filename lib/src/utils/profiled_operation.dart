/// Data class representing a profiled operation
///
/// Contains comprehensive information about a single operation's performance
/// metrics including timing, memory usage, success status, and metadata.
class ProfiledOperation {
  /// Name of the operation
  final String name;

  /// Duration the operation took to complete
  final Duration duration;

  /// Memory usage during the operation in bytes
  final int memoryUsage;

  /// When the operation started
  final DateTime startTime;

  /// When the operation ended
  final DateTime endTime;

  /// Whether the operation completed successfully
  final bool success;

  /// Error message if the operation failed
  final String? error;

  /// Additional metadata about the operation
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

  /// Convert to JSON representation
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
