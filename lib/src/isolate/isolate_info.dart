/// Information about a specific isolate
class IsolateInfo {
  /// Unique identifier for the isolate
  final String id;

  /// When the isolate was created
  final DateTime createdAt;

  /// When the isolate was last used
  final DateTime lastUsed;

  /// Number of tasks processed by this isolate
  final int tasksProcessed;

  /// Whether the isolate is currently processing a task
  final bool isActive;

  /// Current task being processed (if any)
  final String? currentTaskId;

  const IsolateInfo({
    required this.id,
    required this.createdAt,
    required this.lastUsed,
    required this.tasksProcessed,
    required this.isActive,
    this.currentTaskId,
  });
}
