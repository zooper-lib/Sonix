import 'isolate_info.dart';

/// Statistics about isolate resource usage
class IsolateStatistics {
  /// Number of currently active isolates
  final int activeIsolates;

  /// Number of tasks currently queued for processing
  final int queuedTasks;

  /// Number of tasks completed since manager creation
  final int completedTasks;

  /// Number of tasks that failed since manager creation
  final int failedTasks;

  /// Average processing time per task
  final Duration averageProcessingTime;

  /// Memory usage across all isolates (estimated)
  final double memoryUsage;

  /// Individual isolate statistics
  final Map<String, IsolateInfo> isolateInfo;

  const IsolateStatistics({
    required this.activeIsolates,
    required this.queuedTasks,
    required this.completedTasks,
    required this.failedTasks,
    required this.averageProcessingTime,
    required this.memoryUsage,
    required this.isolateInfo,
  });
}
