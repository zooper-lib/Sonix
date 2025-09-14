/// Manages the lifecycle and communication with background isolates
///
/// This class handles spawning, managing, and disposing of background isolates
/// for audio processing tasks. It provides task queuing, distribution, and
/// resource management across multiple isolates.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'isolate_messages.dart';
import 'processing_isolate.dart';
import '../models/waveform_data.dart';
import '../processing/waveform_generator.dart';

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

/// Represents a task to be processed in a background isolate
class ProcessingTask {
  /// Unique identifier for this task
  final String id;

  /// Path to the audio file to process
  final String filePath;

  /// Configuration for waveform generation
  final WaveformConfig config;

  /// Whether to stream results as they become available
  final bool streamResults;

  /// When the task was created
  final DateTime createdAt;

  /// Completer for the task result
  final Completer<WaveformData> completer;

  /// Stream controller for progress updates (if streaming)
  final StreamController<ProgressUpdate>? progressController;

  /// Cancellation token
  final CancelToken cancelToken;

  ProcessingTask({required this.id, required this.filePath, required this.config, this.streamResults = false, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now(),
      completer = Completer<WaveformData>(),
      progressController = streamResults ? StreamController<ProgressUpdate>.broadcast() : null,
      cancelToken = CancelToken();

  /// Get the future for this task's result
  Future<WaveformData> get future => completer.future;

  /// Get the stream for progress updates (if streaming)
  Stream<ProgressUpdate>? get progressStream => progressController?.stream;

  /// Cancel this task
  void cancel() {
    cancelToken.cancel();
    if (!completer.isCompleted) {
      completer.completeError(TaskCancelledException('Task $id was cancelled'));
    }
    progressController?.close();
  }

  /// Complete this task with a result
  void complete(WaveformData result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
    progressController?.close();
  }

  /// Complete this task with an error
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    progressController?.close();
  }

  /// Send a progress update
  void sendProgress(ProgressUpdate update) {
    progressController?.add(update);
  }
}

/// Simple cancellation token
class CancelToken {
  bool _isCancelled = false;

  /// Whether this token has been cancelled
  bool get isCancelled => _isCancelled;

  /// Cancel this token
  void cancel() {
    _isCancelled = true;
  }
}

/// Exception thrown when a task is cancelled
class TaskCancelledException implements Exception {
  final String message;
  TaskCancelledException(this.message);

  @override
  String toString() => 'TaskCancelledException: $message';
}

/// Represents a managed isolate instance
class _ManagedIsolate {
  /// Unique identifier for this isolate
  final String id;

  /// The isolate instance
  final Isolate isolate;

  /// Send port for communicating with the isolate
  final SendPort sendPort;

  /// Receive port for receiving messages from the isolate
  final ReceivePort receivePort;

  /// When this isolate was created
  final DateTime createdAt;

  /// When this isolate was last used
  DateTime lastUsed;

  /// Number of tasks processed by this isolate
  int tasksProcessed;

  /// Whether this isolate is currently processing a task
  bool isActive;

  /// Current task being processed (if any)
  String? currentTaskId;

  /// Stream subscription for receiving messages
  late StreamSubscription _messageSubscription;

  _ManagedIsolate({required this.id, required this.isolate, required this.sendPort, required this.receivePort, required this.createdAt})
    : lastUsed = createdAt,
      tasksProcessed = 0,
      isActive = false;

  /// Initialize message handling for this isolate
  void initializeMessageHandling(void Function(IsolateMessage) onMessage) {
    _messageSubscription = receivePort.listen((dynamic message) {
      try {
        if (message is Map<String, dynamic>) {
          final isolateMessage = IsolateMessage.fromJson(message);
          onMessage(isolateMessage);
        }
      } catch (error) {
        // Handle message parsing errors
        print('Error parsing message from isolate $id: $error');
      }
    });
  }

  /// Send a message to this isolate
  void sendMessage(IsolateMessage message) {
    sendPort.send(message.toJson());
  }

  /// Mark this isolate as active with a task
  void markActive(String taskId) {
    isActive = true;
    currentTaskId = taskId;
    lastUsed = DateTime.now();
  }

  /// Mark this isolate as idle
  void markIdle() {
    isActive = false;
    currentTaskId = null;
    tasksProcessed++;
    lastUsed = DateTime.now();
  }

  /// Dispose of this isolate
  void dispose() {
    _messageSubscription.cancel();
    receivePort.close();
    isolate.kill(priority: Isolate.immediate);
  }

  /// Get info about this isolate
  IsolateInfo get info =>
      IsolateInfo(id: id, createdAt: createdAt, lastUsed: lastUsed, tasksProcessed: tasksProcessed, isActive: isActive, currentTaskId: currentTaskId);
}

/// Configuration interface for isolate management
abstract class IsolateConfig {
  int get maxConcurrentOperations;
  int get isolatePoolSize;
  Duration get isolateIdleTimeout;
  int get maxMemoryUsage;
}

/// Manages background isolates for audio processing
class IsolateManager {
  /// Configuration for this isolate manager
  final IsolateConfig config;

  /// Map of managed isolates by ID
  final Map<String, _ManagedIsolate> _isolates = {};

  /// Queue of pending tasks
  final List<ProcessingTask> _taskQueue = [];

  /// Map of active tasks by ID
  final Map<String, ProcessingTask> _activeTasks = {};

  /// Statistics tracking
  int _completedTasks = 0;
  int _failedTasks = 0;
  final List<Duration> _processingTimes = [];

  /// Whether this manager has been disposed
  bool _isDisposed = false;

  /// Timer for cleanup operations
  Timer? _cleanupTimer;

  /// Random number generator for isolate IDs
  final math.Random _random = math.Random();

  IsolateManager(this.config);

  /// Initialize the isolate manager
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed IsolateManager');
    }

    // Start cleanup timer
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) => _performCleanup());

    // Pre-spawn initial isolates if configured
    final initialIsolates = math.min(config.isolatePoolSize, 1);
    for (int i = 0; i < initialIsolates; i++) {
      await _spawnIsolate();
    }
  }

  /// Execute a processing task
  Future<WaveformData> executeTask(ProcessingTask task) async {
    if (_isDisposed) {
      throw StateError('Cannot execute task on disposed IsolateManager');
    }

    // Add task to active tasks
    _activeTasks[task.id] = task;

    try {
      // Try to assign to an available isolate
      final isolate = await _getAvailableIsolate();
      await _assignTaskToIsolate(task, isolate);

      // Wait for task completion
      return await task.future;
    } catch (error, stackTrace) {
      _failedTasks++;
      _activeTasks.remove(task.id);
      task.completeError(error, stackTrace);
      rethrow;
    }
  }

  /// Get an available isolate, creating one if necessary
  Future<_ManagedIsolate> _getAvailableIsolate() async {
    // Look for idle isolates
    for (final isolate in _isolates.values) {
      if (!isolate.isActive) {
        return isolate;
      }
    }

    // If no idle isolates and we haven't reached the pool limit, spawn a new one
    if (_isolates.length < config.isolatePoolSize) {
      return await _spawnIsolate();
    }

    // Wait for an isolate to become available
    while (true) {
      await Future.delayed(const Duration(milliseconds: 100));

      for (final isolate in _isolates.values) {
        if (!isolate.isActive) {
          return isolate;
        }
      }
    }
  }

  /// Spawn a new isolate
  Future<_ManagedIsolate> _spawnIsolate() async {
    final handshakeReceivePort = ReceivePort();
    final isolateId = _generateIsolateId();

    try {
      final isolate = await Isolate.spawn(processingIsolateEntryPoint, handshakeReceivePort.sendPort, debugName: 'SonixProcessingIsolate_$isolateId');

      // Wait for the isolate to send its SendPort
      final sendPort = await handshakeReceivePort.first as SendPort;

      // Close the handshake port as it's no longer needed
      handshakeReceivePort.close();

      // Create a new receive port for ongoing communication
      final communicationReceivePort = ReceivePort();

      final managedIsolate = _ManagedIsolate(
        id: isolateId,
        isolate: isolate,
        sendPort: sendPort,
        receivePort: communicationReceivePort,
        createdAt: DateTime.now(),
      );

      // Initialize message handling
      managedIsolate.initializeMessageHandling(_handleIsolateMessage);

      // Send our receive port's send port to the isolate so it knows where to send responses
      sendPort.send(communicationReceivePort.sendPort);

      _isolates[isolateId] = managedIsolate;

      return managedIsolate;
    } catch (error) {
      handshakeReceivePort.close();
      rethrow;
    }
  }

  /// Generate a unique isolate ID
  String _generateIsolateId() {
    return 'isolate_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }

  /// Assign a task to a specific isolate
  Future<void> _assignTaskToIsolate(ProcessingTask task, _ManagedIsolate isolate) async {
    isolate.markActive(task.id);

    final request = ProcessingRequest(
      id: task.id, // Use task ID as request ID for proper matching
      timestamp: DateTime.now(),
      filePath: task.filePath,
      config: task.config,
      streamResults: task.streamResults,
    );

    isolate.sendMessage(request);
  }

  /// Handle messages received from isolates
  void _handleIsolateMessage(IsolateMessage message) {
    if (message is ProcessingResponse) {
      _handleProcessingResponse(message);
    } else if (message is ProgressUpdate) {
      _handleProgressUpdate(message);
    } else if (message is ErrorMessage) {
      _handleErrorMessage(message);
    }
  }

  /// Handle processing response from isolate
  void _handleProcessingResponse(ProcessingResponse response) {
    final task = _activeTasks[response.requestId];
    if (task == null) return;

    // Find the isolate that sent this response
    final isolate = _isolates.values.firstWhere((iso) => iso.currentTaskId == response.requestId, orElse: () => _isolates.values.first);

    if (response.isComplete) {
      // Task completed
      isolate.markIdle();
      _activeTasks.remove(task.id);
      _completedTasks++;

      // Record processing time
      final processingTime = DateTime.now().difference(task.createdAt);
      _processingTimes.add(processingTime);
      if (_processingTimes.length > 100) {
        _processingTimes.removeAt(0); // Keep only recent times
      }

      if (response.error != null) {
        task.completeError(Exception(response.error));
      } else if (response.waveformData != null) {
        task.complete(response.waveformData!);
      } else {
        task.completeError(Exception('No waveform data received'));
      }
    }
  }

  /// Handle progress update from isolate
  void _handleProgressUpdate(ProgressUpdate update) {
    final task = _activeTasks[update.requestId];
    if (task != null) {
      task.sendProgress(update);
    }
  }

  /// Handle error message from isolate
  void _handleErrorMessage(ErrorMessage error) {
    if (error.requestId != null) {
      final task = _activeTasks[error.requestId!];
      if (task != null) {
        // Find the isolate that sent this error
        final isolate = _isolates.values.firstWhere((iso) => iso.currentTaskId == error.requestId, orElse: () => _isolates.values.first);

        isolate.markIdle();
        _activeTasks.remove(task.id);
        _failedTasks++;

        task.completeError(Exception('${error.errorType}: ${error.errorMessage}'));
      }
    }
  }

  /// Perform periodic cleanup of idle isolates
  void _performCleanup() {
    if (_isDisposed) return;

    final now = DateTime.now();
    final isolatesToRemove = <String>[];

    for (final entry in _isolates.entries) {
      final isolate = entry.value;

      // Remove isolates that have been idle for too long
      if (!isolate.isActive && now.difference(isolate.lastUsed) > config.isolateIdleTimeout) {
        isolatesToRemove.add(entry.key);
      }
    }

    // Always keep at least one isolate if we have any
    if (isolatesToRemove.length >= _isolates.length && _isolates.isNotEmpty) {
      isolatesToRemove.removeLast();
    }

    for (final isolateId in isolatesToRemove) {
      final isolate = _isolates.remove(isolateId);
      isolate?.dispose();
    }
  }

  /// Optimize resource usage
  void optimizeResources() {
    _performCleanup();
  }

  /// Get current statistics
  IsolateStatistics getStatistics() {
    final isolateInfo = <String, IsolateInfo>{};
    for (final entry in _isolates.entries) {
      isolateInfo[entry.key] = entry.value.info;
    }

    final avgProcessingTime = _processingTimes.isEmpty
        ? Duration.zero
        : Duration(microseconds: _processingTimes.map((d) => d.inMicroseconds).reduce((a, b) => a + b) ~/ _processingTimes.length);

    return IsolateStatistics(
      activeIsolates: _isolates.length,
      queuedTasks: _taskQueue.length,
      completedTasks: _completedTasks,
      failedTasks: _failedTasks,
      averageProcessingTime: avgProcessingTime,
      memoryUsage: _estimateMemoryUsage(),
      isolateInfo: isolateInfo,
    );
  }

  /// Estimate memory usage across all isolates
  double _estimateMemoryUsage() {
    // This is a rough estimate - in a real implementation you might
    // want to use more sophisticated memory tracking
    return _isolates.length * 10.0; // MB per isolate estimate
  }

  /// Generate a unique message ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }

  /// Dispose of the isolate manager and all isolates
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _cleanupTimer?.cancel();

    // Cancel all active tasks
    for (final task in _activeTasks.values) {
      task.cancel();
    }
    _activeTasks.clear();
    _taskQueue.clear();

    // Dispose of all isolates
    for (final isolate in _isolates.values) {
      isolate.dispose();
    }
    _isolates.clear();
  }
}
