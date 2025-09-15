/// Progress tracking for waveform generation operations
///
/// This file contains the WaveformProgress class for tracking the progress
/// of audio waveform generation operations in the Sonix library.
library;

import 'waveform_data.dart';

/// Represents the progress of a waveform generation operation
///
/// Used to provide real-time updates during audio processing operations,
/// including progress percentage, status messages, and partial results.
class WaveformProgress {
  /// Progress percentage (0.0 to 1.0)
  final double progress;

  /// Optional status message describing current operation
  final String? statusMessage;

  /// Partial waveform data for streaming (optional)
  final WaveformData? partialData;

  /// Whether this is the final progress update
  final bool isComplete;

  /// Error message if processing failed
  final String? error;

  /// Creates a new progress update
  ///
  /// [progress] should be between 0.0 and 1.0, where 1.0 indicates completion.
  /// [statusMessage] provides human-readable status information.
  /// [partialData] can contain intermediate waveform results for streaming.
  /// [isComplete] indicates whether this is the final update.
  /// [error] contains error details if the operation failed.
  const WaveformProgress({required this.progress, this.statusMessage, this.partialData, this.isComplete = false, this.error});

  /// Creates a progress update for the start of an operation
  factory WaveformProgress.started([String? message]) => WaveformProgress(progress: 0.0, statusMessage: message ?? 'Starting waveform generation...');

  /// Creates a progress update for completion
  factory WaveformProgress.completed(WaveformData data) =>
      WaveformProgress(progress: 1.0, statusMessage: 'Waveform generation completed', partialData: data, isComplete: true);

  /// Creates a progress update for an error
  factory WaveformProgress.error(String errorMessage) => WaveformProgress(progress: 0.0, error: errorMessage, isComplete: true);

  @override
  String toString() {
    if (error != null) {
      return 'WaveformProgress(error: $error)';
    }
    return 'WaveformProgress('
        'progress: ${(progress * 100).toStringAsFixed(1)}%'
        '${statusMessage != null ? ', status: $statusMessage' : ''}'
        '${isComplete ? ', complete' : ''}'
        ')';
  }
}
