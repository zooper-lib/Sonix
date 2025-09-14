/// Mock isolate manager for testing cancellation functionality
///
/// This provides a controllable mock implementation of IsolateManager
/// that allows testing cancellation behavior without real isolates.
library;

import 'dart:async';

import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/isolate/isolate_messages.dart';
import 'package:sonix/src/models/waveform_data.dart';

/// Mock isolate manager for testing
class MockIsolateManager extends IsolateManager {
  /// List of messages sent to isolates for verification
  final List<Map<String, dynamic>> _sentMessages = [];

  /// Delay before completing tasks (for testing timing)
  Duration _completionDelay = const Duration(milliseconds: 100);

  /// Stage-specific delays for testing cancellation at different stages
  Map<String, Duration> _stageDelays = {};

  /// Whether to simulate errors
  bool _simulateError = false;

  /// Error to simulate
  Object? _simulatedError;

  /// Mock active tasks map
  final Map<String, ProcessingTask> _activeTasks = {};

  MockIsolateManager(super.config);

  /// Set the delay before completing tasks
  void setCompletionDelay(Duration delay) {
    _completionDelay = delay;
  }

  /// Set delays for different processing stages
  void setStageDelays(Map<String, Duration> delays) {
    _stageDelays = delays;
  }

  /// Configure error simulation
  void simulateError(Object error) {
    _simulateError = true;
    _simulatedError = error;
  }

  /// Clear error simulation
  void clearErrorSimulation() {
    _simulateError = false;
    _simulatedError = null;
  }

  /// Get messages sent to isolates
  List<Map<String, dynamic>> getSentMessages() {
    return List.unmodifiable(_sentMessages);
  }

  /// Clear sent messages history
  void clearSentMessages() {
    _sentMessages.clear();
  }

  @override
  Future<void> initialize() async {
    // Mock initialization - no real isolates to spawn
  }

  @override
  Future<WaveformData> executeTask(ProcessingTask task) async {
    // Track the task
    _activeTasks[task.id] = task;

    try {
      // Simulate processing with cancellation checks
      await _simulateProcessingWithCancellation(task);

      // Check if task was cancelled during processing
      if (task.cancelToken.isCancelled) {
        throw TaskCancelledException('Task ${task.id} was cancelled');
      }

      // Simulate error if configured
      if (_simulateError && _simulatedError != null) {
        throw _simulatedError!;
      }

      // Create mock waveform data
      final waveformData = WaveformData(
        amplitudes: List.generate(task.config.resolution, (i) => (i % 100) / 100.0),
        sampleRate: 44100,
        duration: const Duration(seconds: 30),
        metadata: WaveformMetadata(resolution: task.config.resolution, type: task.config.type, normalized: task.config.normalize, generatedAt: DateTime.now()),
      );

      return waveformData;
    } finally {
      // Clean up task tracking
      _activeTasks.remove(task.id);
    }
  }

  /// Simulate processing with cancellation checks at different stages
  Future<void> _simulateProcessingWithCancellation(ProcessingTask task) async {
    // Stage 1: Decoder creation
    if (task.streamResults) {
      task.sendProgress(
        ProgressUpdate(id: 'progress_1', timestamp: DateTime.now(), requestId: task.id, progress: 0.1, statusMessage: 'Creating audio decoder'),
      );
    }

    final decoderDelay = _stageDelays['decoder_creation'] ?? const Duration(milliseconds: 20);
    await _delayWithCancellationCheck(task, decoderDelay);

    // Stage 2: Audio decoding
    if (task.streamResults) {
      task.sendProgress(ProgressUpdate(id: 'progress_2', timestamp: DateTime.now(), requestId: task.id, progress: 0.5, statusMessage: 'Decoding audio file'));
    }

    final decodingDelay = _stageDelays['audio_decoding'] ?? const Duration(milliseconds: 30);
    await _delayWithCancellationCheck(task, decodingDelay);

    // Stage 3: Waveform generation
    if (task.streamResults) {
      task.sendProgress(ProgressUpdate(id: 'progress_3', timestamp: DateTime.now(), requestId: task.id, progress: 0.9, statusMessage: 'Generating waveform'));
    }

    final waveformDelay = _stageDelays['waveform_generation'] ?? const Duration(milliseconds: 50);
    await _delayWithCancellationCheck(task, waveformDelay);

    // Final progress
    if (task.streamResults) {
      task.sendProgress(ProgressUpdate(id: 'progress_final', timestamp: DateTime.now(), requestId: task.id, progress: 1.0, statusMessage: 'Complete'));
    }
  }

  /// Delay with periodic cancellation checks
  Future<void> _delayWithCancellationCheck(ProcessingTask task, Duration delay) async {
    final checkInterval = const Duration(milliseconds: 10);
    final totalChecks = (delay.inMilliseconds / checkInterval.inMilliseconds).ceil();

    for (int i = 0; i < totalChecks; i++) {
      if (task.cancelToken.isCancelled) {
        return; // Exit early if cancelled
      }
      await Future.delayed(checkInterval);
    }
  }

  @override
  bool cancelTask(String taskId) {
    final task = _activeTasks[taskId];
    if (task != null) {
      // Record the cancellation message
      _sentMessages.add({
        'messageType': 'CancellationRequest',
        'id': 'cancel_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'requestId': taskId,
      });

      // Cancel the task
      task.cancel();
      _activeTasks.remove(taskId);
      return true;
    }
    return false;
  }

  @override
  int cancelAllTasks() {
    final taskIds = _activeTasks.keys.toList();
    int cancelledCount = 0;

    for (final taskId in taskIds) {
      if (cancelTask(taskId)) {
        cancelledCount++;
      }
    }

    return cancelledCount;
  }

  @override
  IsolateStatistics getStatistics() {
    return IsolateStatistics(
      activeIsolates: 1, // Mock single isolate
      queuedTasks: 0,
      completedTasks: 0,
      failedTasks: 0,
      averageProcessingTime: _completionDelay,
      memoryUsage: 1024 * 1024, // 1MB mock usage
      isolateInfo: {
        'mock_isolate': IsolateInfo(
          id: 'mock_isolate',
          createdAt: DateTime.now(),
          lastUsed: DateTime.now(),
          tasksProcessed: 0,
          isActive: _activeTasks.isNotEmpty,
        ),
      },
    );
  }

  @override
  void optimizeResources() {
    // Mock optimization - nothing to do
  }

  @override
  Future<void> dispose() async {
    // Cancel all active tasks
    cancelAllTasks();

    // Clear tracking
    _sentMessages.clear();
    _stageDelays.clear();
  }
}
