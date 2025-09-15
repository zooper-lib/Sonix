import 'dart:async';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'isolate_messages.dart';
import 'cancel_token.dart';

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
