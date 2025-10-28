/// Manages the lifecycle and communication with background isolates
///
/// This class handles spawning, managing, and disposing of background isolates
/// for audio processing tasks. It provides task queuing, distribution, and
/// resource management across multiple isolates.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'isolate_messages.dart';
import 'processing_isolate.dart';
import 'isolate_health_monitor.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'error_serializer.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/utils/memory_manager.dart';
import 'package:sonix/src/utils/sonix_logger.dart';

import 'isolate_config.dart';

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

  /// When the task was created
  final DateTime createdAt;

  /// Completer for the task result
  final Completer<WaveformData> completer;

  /// Cancellation token
  final CancelToken cancelToken;

  ProcessingTask({required this.id, required this.filePath, required this.config, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now(),
      completer = Completer<WaveformData>(),
      cancelToken = CancelToken();

  /// Get the future for this task's result
  Future<WaveformData> get future => completer.future;

  /// Cancel this task
  void cancel() {
    cancelToken.cancel();
    if (!completer.isCompleted) {
      completer.completeError(TaskCancelledException('Task $id was cancelled'));
    }
  }

  /// Complete this task with a result
  void complete(WaveformData result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  /// Complete this task with an error
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
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
        SonixLogger.isolate(id, 'Failed to parse isolate message: ${error.toString()}', level: 3);
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
    try {
      // Send shutdown message to allow FFMPEG cleanup
      sendPort.send('shutdown');

      // Give isolate a brief moment to cleanup
      Future.delayed(const Duration(milliseconds: 100), () {
        _messageSubscription.cancel();
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      });
    } catch (e) {
      SonixLogger.isolate(id, 'Failed to send shutdown message, proceeding with immediate cleanup: ${e.toString()}', level: 6);
      // If sending shutdown message fails, proceed with immediate cleanup
      _messageSubscription.cancel();
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  /// Get info about this isolate
  IsolateInfo get info =>
      IsolateInfo(id: id, createdAt: createdAt, lastUsed: lastUsed, tasksProcessed: tasksProcessed, isActive: isActive, currentTaskId: currentTaskId);
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

  /// Map of request IDs to isolate IDs for tracking
  final Map<String, String> _requestToIsolateMap = {};

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

  /// Health monitor for isolate crash detection
  late final IsolateHealthMonitor _healthMonitor;

  /// Map of retry attempts for failed tasks
  final Map<String, int> _taskRetryAttempts = {};

  /// Maximum number of retry attempts for failed tasks
  final int maxRetryAttempts;

  /// Whether to enable automatic error recovery
  final bool enableErrorRecovery;

  /// Memory manager for resource optimization
  late final MemoryManager _memoryManager;

  /// Timer for memory pressure monitoring
  Timer? _memoryPressureTimer;

  /// Whether graceful shutdown is in progress
  bool _isShuttingDown = false;

  /// Completer for shutdown completion
  Completer<void>? _shutdownCompleter;

  IsolateManager(this.config, {this.maxRetryAttempts = 3, this.enableErrorRecovery = true}) {
    _healthMonitor = IsolateHealthMonitor();
    _memoryManager = MemoryManager();
    _setupHealthMonitorCallbacks();
    _setupMemoryPressureHandling();
  }

  /// Initialize the isolate manager
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed IsolateManager');
    }

    // Initialize memory manager
    _memoryManager.initialize(memoryLimit: config.maxMemoryUsage);

    // Start cleanup timer
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) => _performCleanup());

    // Start memory pressure monitoring
    _memoryPressureTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkMemoryPressure());

    // Register shutdown handler
    _registerShutdownHandler();

    // Pre-spawn initial isolates if configured
    final initialIsolates = math.min(config.isolatePoolSize, 1);
    for (int i = 0; i < initialIsolates; i++) {
      await _spawnIsolate();
    }
  }

  /// Set up health monitor callbacks for error recovery
  void _setupHealthMonitorCallbacks() {
    _healthMonitor.onIsolateCrashed((isolateId, error) {
      _handleIsolateCrash(isolateId, error);
    });

    _healthMonitor.onHealthChanged((isolateId, health) {
      if (health.needsRestart) {
        _scheduleIsolateRestart(isolateId);
      }
    });
  }

  /// Set up memory pressure handling
  void _setupMemoryPressureHandling() {
    _memoryManager.registerMemoryPressureCallback(() {
      _handleMemoryPressure();
    });

    _memoryManager.registerCriticalMemoryCallback(() {
      _handleCriticalMemoryPressure();
    });
  }

  /// Register shutdown handler for graceful termination
  void _registerShutdownHandler() {
    // Note: In a real implementation, you might want to register with
    // platform-specific shutdown handlers (e.g., ProcessSignal.sigterm on desktop)
    // For now, we'll rely on explicit dispose() calls
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

      // Wait for task completion with dynamic timeout based on file size
      final timeoutDuration = _calculateTimeoutForTask(task);
      return await task.future.timeout(
        timeoutDuration,
        onTimeout: () {
          // Clean up the task and isolate mapping
          _activeTasks.remove(task.id);
          _requestToIsolateMap.remove(task.id);
          _failedTasks++;

          // Report timeout to health monitor
          final isolateId = _requestToIsolateMap[task.id];
          if (isolateId != null) {
            _healthMonitor.reportFailure(isolateId, TimeoutException('Task ${task.id} timed out after ${timeoutDuration.inSeconds} seconds', timeoutDuration));
          }

          throw TimeoutException('Task ${task.id} timed out after ${timeoutDuration.inSeconds} seconds', timeoutDuration);
        },
      );
    } catch (error, stackTrace) {
      _failedTasks++;
      _activeTasks.remove(task.id);
      _requestToIsolateMap.remove(task.id);

      SonixLogger.isolate('task_${task.id}', 'Task execution failed: ${error.toString()}', level: 2);

      // Attempt error recovery if enabled
      if (enableErrorRecovery && _shouldRetryTask(task.id, error)) {
        return await _retryTask(task, error);
      }

      task.completeError(error, stackTrace);
      rethrow;
    }
  }

  /// Check if a task should be retried based on the error type
  bool _shouldRetryTask(String taskId, Object error) {
    // Extract the base task ID without retry suffixes
    final baseTaskId = _extractBaseTaskId(taskId);
    final retryCount = _taskRetryAttempts[baseTaskId] ?? 0;

    if (retryCount >= maxRetryAttempts) {
      return false;
    }

    // For IsolateProcessingException, check the original error type
    if (error is IsolateProcessingException) {
      // Check if the original error type indicates a non-recoverable error
      final originalErrorType = error.originalErrorType ?? '';
      if (originalErrorType.contains('FileNotFoundException') ||
          originalErrorType.contains('CorruptedFileException') ||
          originalErrorType.contains('UnsupportedFormatException') ||
          originalErrorType.contains('DecodingException')) {
        // For DecodingException, check if it's a non-recoverable decoding error
        if (originalErrorType.contains('DecodingException')) {
          final errorMessage = error.originalError.toLowerCase();
          if (errorMessage.contains('file is empty') ||
              errorMessage.contains('empty file') ||
              errorMessage.contains('invalid file') ||
              errorMessage.contains('cannot decode empty') ||
              // Native decoder init failures are not recoverable per-file
              errorMessage.contains('failed to initialize native chunked decoder') ||
              errorMessage.contains('could not initialize native decoder') ||
              errorMessage.contains('failed to initialize native decoder')) {
            return false;
          }
        } else {
          return false;
        }
      }

      // Also check the error message for these patterns
      final errorMessage = error.originalError.toLowerCase();
      if (errorMessage.contains('file not found') ||
          errorMessage.contains('filenotfoundexception') ||
          errorMessage.contains('unsupported') ||
          errorMessage.contains('corrupted') ||
          errorMessage.contains('file is empty') ||
          errorMessage.contains('empty file') ||
          errorMessage.contains('invalid file') ||
          errorMessage.contains('cannot decode empty') ||
          errorMessage.contains('failed to initialize native chunked decoder') ||
          errorMessage.contains('could not initialize native decoder') ||
          errorMessage.contains('failed to initialize native decoder')) {
        return false;
      }
    }

    return ErrorSerializer.isRecoverableError(error);
  }

  /// Extract the base task ID without retry suffixes
  String _extractBaseTaskId(String taskId) {
    // Remove all _retry_N suffixes to get the original task ID
    return taskId.replaceAll(RegExp(r'_retry_\d+'), '');
  }

  /// Retry a failed task with exponential backoff
  Future<WaveformData> _retryTask(ProcessingTask originalTask, Object error) async {
    // Extract the base task ID to track retries correctly
    final baseTaskId = _extractBaseTaskId(originalTask.id);
    final retryCount = (_taskRetryAttempts[baseTaskId] ?? 0) + 1;
    _taskRetryAttempts[baseTaskId] = retryCount;

    // Calculate retry delay
    final delay = ErrorSerializer.getRetryDelay(error, retryCount);
    await Future.delayed(delay);

    // Create a new task for the retry
    // IMPORTANT: Always build the retry task ID from the base task ID to avoid
    // accumulating nested suffixes like _retry_1_retry_1_retry_2, etc.
    final retryTask = ProcessingTask(id: '${baseTaskId}_retry_$retryCount', filePath: originalTask.filePath, config: originalTask.config);

    try {
      return await executeTask(retryTask);
    } catch (retryError) {
      // If retry also fails, check if we should retry again
      if (_shouldRetryTask(baseTaskId, retryError)) {
        return await _retryTask(originalTask, retryError);
      }

      // Max retries exceeded, propagate the error
      _taskRetryAttempts.remove(baseTaskId);
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
      final isolate = await spawnProcessingIsolate(handshakeReceivePort.sendPort);

      // Wait for the isolate to send its SendPort or an error message
      final handshakeResponse = await handshakeReceivePort.first;

      // Check if the isolate sent an error message during initialization
      if (handshakeResponse is Map<String, dynamic>) {
        // Isolate sent an error message - parse it and throw an exception
        final errorMessage = ErrorMessage.fromJson(handshakeResponse);
        throw IsolateProcessingException(
          isolateId,
          errorMessage.errorMessage,
          originalErrorType: errorMessage.errorType,
          details: 'Failed to initialize isolate during handshake',
        );
      }

      // If we get here, it should be a SendPort
      final sendPort = handshakeResponse as SendPort;

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

      // Start health monitoring for this isolate
      _healthMonitor.startMonitoring(isolateId, sendPort);

      // Isolate registered successfully

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

  /// Spawn a processing isolate - can be overridden for testing
  Future<Isolate> spawnProcessingIsolate(SendPort handshakeSendPort) async {
    return await Isolate.spawn(processingIsolateEntryPoint, handshakeSendPort, debugName: 'SonixProcessingIsolate_${_generateIsolateId()}');
  }

  /// Assign a task to a specific isolate
  Future<void> _assignTaskToIsolate(ProcessingTask task, _ManagedIsolate isolate) async {
    isolate.markActive(task.id);

    final request = ProcessingRequest(
      id: task.id, // Use task ID as request ID for proper matching
      timestamp: DateTime.now(),
      filePath: task.filePath,
      config: task.config,
    );

    // Track the mapping between request ID and isolate ID
    _requestToIsolateMap[task.id] = isolate.id;

    isolate.sendMessage(request);
  }

  /// Handle messages received from isolates
  void _handleIsolateMessage(IsolateMessage message) {
    try {
      if (message is ProcessingResponse) {
        _handleProcessingResponse(message);
      } else if (message is ErrorMessage) {
        _handleErrorMessage(message);
      } else if (message.messageType == 'HealthCheckResponse') {
        // Handle health check response - for now just report success
        final isolateId = _findIsolateIdForMessage(message);
        if (isolateId != null) {
          _healthMonitor.reportSuccess(isolateId);
        }
      }
    } catch (error) {
      // Handle message processing errors
      final isolateId = _findIsolateIdForMessage(message);
      if (isolateId != null) {
        _healthMonitor.reportFailure(
          isolateId,
          IsolateCommunicationException.receiveFailure(
            message.messageType,
            isolateId: isolateId,
            cause: error,
            details: 'Failed to process ${message.messageType} message',
          ),
        );
      }
    }
  }

  /// Find the isolate ID that sent a message
  String? _findIsolateIdForMessage(IsolateMessage message) {
    // For messages with request IDs, use the request-to-isolate mapping
    if (message is ProcessingResponse) {
      return _requestToIsolateMap[message.requestId];
    }

    if (message is ErrorMessage && message.requestId != null) {
      return _requestToIsolateMap[message.requestId!];
    }

    // For other messages, we can't easily determine the isolate
    return null;
  }

  /// Handle processing response from isolate
  void _handleProcessingResponse(ProcessingResponse response) {
    final task = _activeTasks[response.requestId];
    if (task == null) return;

    // Find the isolate that sent this response
    final isolateId = _requestToIsolateMap[response.requestId];
    if (isolateId == null) {
      // If we can't find the isolate, the task might have been cancelled or timed out
      return;
    }
    final isolate = _isolates[isolateId];
    if (isolate == null) {
      // Isolate might have been disposed
      return;
    }

    if (response.isComplete) {
      // Task completed
      isolate.markIdle();
      _activeTasks.remove(task.id);
      _requestToIsolateMap.remove(response.requestId);
      _completedTasks++;

      // Record processing time
      final processingTime = DateTime.now().difference(task.createdAt);
      _processingTimes.add(processingTime);
      if (_processingTimes.length > 100) {
        _processingTimes.removeAt(0); // Keep only recent times
      }

      if (response.error != null) {
        // Report failure to health monitor
        final error = IsolateProcessingException(isolateId, response.error!, requestId: response.requestId);
        _healthMonitor.reportFailure(isolateId, error);
        task.completeError(error);
      } else if (response.waveformData != null) {
        // Report success to health monitor
        _healthMonitor.reportSuccess(isolateId);
        task.complete(response.waveformData!);
      } else {
        final error = IsolateProcessingException(isolateId, 'No waveform data received', requestId: response.requestId);
        _healthMonitor.reportFailure(isolateId, error);
        task.completeError(error);
      }
    }
  }

  /// Handle error message from isolate
  void _handleErrorMessage(ErrorMessage error) {
    if (error.requestId != null) {
      final task = _activeTasks[error.requestId!];
      if (task != null) {
        // Find the isolate that sent this error
        final isolateId = _requestToIsolateMap[error.requestId!];
        if (isolateId == null) return;
        final isolate = _isolates[isolateId];
        if (isolate == null) return;

        isolate.markIdle();
        _activeTasks.remove(task.id);
        _requestToIsolateMap.remove(error.requestId!);
        _failedTasks++;

        // Create a proper exception from the error message
        final exception = IsolateProcessingException(
          isolateId,
          error.errorMessage,
          originalErrorType: error.errorType,
          isolateStackTrace: error.stackTrace,
          requestId: error.requestId,
        );

        // Report failure to health monitor
        _healthMonitor.reportFailure(isolateId, exception);

        task.completeError(exception);
      }
    }
  }

  /// Perform periodic cleanup of idle isolates
  void _performCleanup() {
    if (_isDisposed || _isShuttingDown) return;

    final now = DateTime.now();
    final isolatesToRemove = <String>[];

    for (final entry in _isolates.entries) {
      final isolate = entry.value;

      // Remove isolates that have been idle for too long
      if (!isolate.isActive && now.difference(isolate.lastUsed) > config.isolateIdleTimeout) {
        isolatesToRemove.add(entry.key);
      }
    }

    // Always keep at least one isolate if we have any, unless shutting down
    if (isolatesToRemove.length >= _isolates.length && _isolates.isNotEmpty && !_isShuttingDown) {
      isolatesToRemove.removeLast();
    }

    for (final isolateId in isolatesToRemove) {
      final isolate = _isolates.remove(isolateId);
      if (isolate != null) {
        // Resource management handled internally
        isolate.dispose();
      }
    }
  }

  /// Check memory pressure and optimize resources
  void _checkMemoryPressure() {
    if (_isDisposed || _isShuttingDown) return;

    if (_memoryManager.isMemoryPressureCritical) {
      _handleCriticalMemoryPressure();
    } else if (_memoryManager.isMemoryPressureHigh) {
      _handleMemoryPressure();
    }
  }

  /// Handle memory pressure by optimizing resources
  void _handleMemoryPressure() {
    if (_isDisposed || _isShuttingDown) return;

    // Clean up idle isolates more aggressively
    final now = DateTime.now();
    final aggressiveTimeout = Duration(milliseconds: config.isolateIdleTimeout.inMilliseconds ~/ 2);
    final isolatesToRemove = <String>[];

    for (final entry in _isolates.entries) {
      final isolate = entry.value;
      if (!isolate.isActive && now.difference(isolate.lastUsed) > aggressiveTimeout) {
        isolatesToRemove.add(entry.key);
      }
    }

    // Keep at least one isolate for responsiveness
    if (isolatesToRemove.length >= _isolates.length && _isolates.isNotEmpty) {
      isolatesToRemove.removeLast();
    }

    for (final isolateId in isolatesToRemove) {
      final isolate = _isolates.remove(isolateId);
      if (isolate != null) {
        // Resource management handled internally
        isolate.dispose();
      }
    }

    // Force resource cleanup
    // Resource management handled internally
  }

  /// Handle critical memory pressure with aggressive cleanup
  void _handleCriticalMemoryPressure() {
    if (_isDisposed || _isShuttingDown) return;

    // Cancel queued tasks to free memory
    final queuedTasks = _taskQueue.toList();
    _taskQueue.clear();

    for (final task in queuedTasks) {
      task.completeError(IsolateProcessingException('memory_pressure', 'Task cancelled due to critical memory pressure', requestId: task.id));
    }

    // Remove all idle isolates immediately
    final isolatesToRemove = <String>[];
    for (final entry in _isolates.entries) {
      final isolate = entry.value;
      if (!isolate.isActive) {
        isolatesToRemove.add(entry.key);
      }
    }

    for (final isolateId in isolatesToRemove) {
      final isolate = _isolates.remove(isolateId);
      if (isolate != null) {
        // Resource management handled internally
        isolate.dispose();
      }
    }

    // Force aggressive resource cleanup
    // Resource management handled internally
    _memoryManager.forceMemoryCleanup();
  }

  /// Optimize resource usage
  void optimizeResources() {
    if (_isDisposed || _isShuttingDown) return;

    _performCleanup();
    // Resource management handled internally

    // Check if we need to adjust isolate pool size based on usage
    _optimizeIsolatePoolSize();
  }

  /// Optimize isolate pool size based on usage patterns
  void _optimizeIsolatePoolSize() {
    if (_isDisposed || _isShuttingDown) return;

    final stats = getStatistics();
    final utilizationRatio = stats.activeIsolates > 0 ? (stats.queuedTasks + stats.activeIsolates) / stats.activeIsolates : 0.0;

    // If utilization is consistently low, reduce pool size
    if (utilizationRatio < 0.5 && _isolates.length > 1) {
      final idleIsolates = _isolates.values.where((i) => !i.isActive).toList();
      if (idleIsolates.isNotEmpty) {
        final isolateToRemove = idleIsolates.first;
        _isolates.remove(isolateToRemove.id);
        // Resource management handled internally
        isolateToRemove.dispose();
      }
    }
  }

  /// Begin graceful shutdown of the isolate manager
  Future<void> beginGracefulShutdown({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isDisposed || _isShuttingDown) {
      return _shutdownCompleter?.future ?? Future.value();
    }

    _isShuttingDown = true;
    _shutdownCompleter = Completer<void>();

    try {
      // Stop accepting new tasks
      _cleanupTimer?.cancel();
      _memoryPressureTimer?.cancel();

      // Wait for active tasks to complete or timeout
      final activeTaskFutures = _activeTasks.values
          .map(
            (task) => task.future.timeout(
              timeout,
              onTimeout: () {
                // Cancel the task on timeout
                task.cancel();
                throw TimeoutException('Task ${task.id} timed out during shutdown', timeout);
              },
            ),
          )
          .toList();

      if (activeTaskFutures.isNotEmpty) {
        await Future.wait(activeTaskFutures, eagerError: false);
      }

      // Cancel any remaining queued tasks
      for (final task in _taskQueue) {
        task.completeError(IsolateProcessingException('shutdown', 'Task cancelled due to system shutdown', requestId: task.id));
      }
      _taskQueue.clear();

      // Dispose all isolates
      for (final isolate in _isolates.values) {
        // Resource management handled internally
        isolate.dispose();
      }
      _isolates.clear();

      // Clean up managers
      _memoryManager.dispose();
      _healthMonitor.dispose();

      _shutdownCompleter!.complete();
    } catch (error) {
      _shutdownCompleter!.completeError(error);
    }
  }

  /// Cancel a specific task by ID
  ///
  /// Sends a cancellation request to the isolate processing the task
  /// and marks the task as cancelled locally.
  ///
  /// Returns true if the task was found and cancellation was requested,
  /// false if the task was not found.
  bool cancelTask(String taskId) {
    if (_isDisposed || _isShuttingDown) {
      return false;
    }

    final task = _activeTasks[taskId];
    if (task == null) {
      return false;
    }

    // Cancel the task locally
    task.cancel();

    // Find the isolate processing this task
    final isolateId = _requestToIsolateMap[taskId];
    if (isolateId != null) {
      final isolate = _isolates[isolateId];
      if (isolate != null) {
        // Send cancellation request to the isolate
        final cancellationRequest = CancellationRequest(id: 'cancel_${DateTime.now().millisecondsSinceEpoch}', timestamp: DateTime.now(), requestId: taskId);

        isolate.sendMessage(cancellationRequest);

        // Mark isolate as idle since the task is being cancelled
        isolate.markIdle();
      }
    }

    // Clean up task tracking
    _activeTasks.remove(taskId);
    _requestToIsolateMap.remove(taskId);

    return true;
  }

  /// Cancel all active tasks
  ///
  /// Sends cancellation requests to all isolates and cancels all active tasks.
  ///
  /// Returns the number of tasks that were cancelled.
  int cancelAllTasks() {
    if (_isDisposed || _isShuttingDown) {
      return 0;
    }

    final taskIds = _activeTasks.keys.toList();
    int cancelledCount = 0;

    for (final taskId in taskIds) {
      if (cancelTask(taskId)) {
        cancelledCount++;
      }
    }

    return cancelledCount;
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

  /// Handle isolate crash
  void _handleIsolateCrash(String isolateId, Object error) {
    final isolate = _isolates[isolateId];
    if (isolate == null) return;

    // Find any active task on this isolate
    final activeTask = _activeTasks.values.where((task) => isolate.currentTaskId == task.id).firstOrNull;

    if (activeTask != null) {
      // Mark task as failed due to isolate crash
      _activeTasks.remove(activeTask.id);
      _failedTasks++;

      final crashException = IsolateProcessingException(
        isolateId,
        'Isolate crashed during processing',
        originalErrorType: error.runtimeType.toString(),
        requestId: activeTask.id,
        details: 'The isolate processing this task crashed unexpectedly',
      );

      // Attempt to retry the task if recovery is enabled
      if (enableErrorRecovery && _shouldRetryTask(activeTask.id, crashException)) {
        _retryTask(activeTask, crashException).catchError((retryError) {
          activeTask.completeError(crashException);
          // Return empty waveform data as fallback
          return WaveformData.fromAmplitudes([]);
        });
      } else {
        activeTask.completeError(crashException);
      }
    }

    // Remove the crashed isolate
    _removeIsolate(isolateId);
  }

  /// Schedule an isolate restart
  void _scheduleIsolateRestart(String isolateId) {
    // Remove the unhealthy isolate and spawn a new one
    Timer(const Duration(seconds: 1), () async {
      _removeIsolate(isolateId);

      // Spawn a replacement isolate if we're below the pool size
      if (_isolates.length < config.isolatePoolSize) {
        try {
          await _spawnIsolate();
        } catch (error) {
          // Log error but don't crash the manager
          // Log error but don't crash the manager - could use proper logging here
        }
      }
    });
  }

  /// Remove an isolate from management
  void _removeIsolate(String isolateId) {
    final isolate = _isolates.remove(isolateId);
    if (isolate != null) {
      _healthMonitor.removeIsolate(isolateId);
      isolate.dispose();
    }
  }

  /// Get health information for all isolates
  Map<String, IsolateHealth> getIsolateHealth() {
    return _healthMonitor.getAllHealth();
  }

  /// Get health statistics
  Map<String, dynamic> getHealthStatistics() {
    return _healthMonitor.getStatistics();
  }

  /// Dispose of the isolate manager and all isolates
  Future<void> dispose() async {
    if (_isDisposed) return;

    // If not already shutting down, begin graceful shutdown
    if (!_isShuttingDown) {
      await beginGracefulShutdown();
    } else if (_shutdownCompleter != null) {
      // Wait for ongoing shutdown to complete
      await _shutdownCompleter!.future;
    }

    _isDisposed = true;
    _cleanupTimer?.cancel();
    _memoryPressureTimer?.cancel();

    // Cancel all active tasks
    for (final task in _activeTasks.values) {
      task.cancel();
    }
    _activeTasks.clear();
    _taskQueue.clear();
    _taskRetryAttempts.clear();
    _requestToIsolateMap.clear();

    // Dispose of all isolates
    for (final isolate in _isolates.values) {
      isolate.dispose();
    }
    _isolates.clear();
  }

  /// Calculate timeout duration based on file size
  ///
  /// For large files that require chunked processing, we need longer timeouts
  /// to account for the time needed to process all chunks.
  Duration _calculateTimeoutForTask(ProcessingTask task) {
    try {
      final file = File(task.filePath);
      final fileSize = file.lengthSync();

      // Base timeout of 60 seconds for files under 50MB
      const baseTimeout = Duration(seconds: 60);
      const chunkThreshold = 50 * 1024 * 1024; // 50MB

      if (fileSize <= chunkThreshold) {
        return baseTimeout;
      }

      // For large files, calculate timeout based on size
      // Assume roughly 2 seconds per 10MB for chunked processing (more conservative)
      final extraTimeNeeded = Duration(seconds: ((fileSize - chunkThreshold) / (5 * 1024 * 1024)).ceil());

      // Cap the timeout at 15 minutes to avoid infinite waits
      const maxTimeout = Duration(minutes: 15);
      final calculatedTimeout = baseTimeout + extraTimeNeeded;

      return calculatedTimeout > maxTimeout ? maxTimeout : calculatedTimeout;
    } catch (e) {
      // If we can't read the file size, use a longer default timeout
      return const Duration(minutes: 5);
    }
  }
}
