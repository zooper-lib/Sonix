/// Core message types for communication between main and background isolates
///
/// This module defines the message protocol used for isolate communication
/// in the Sonix library. All messages must be serializable to work across
/// isolate boundaries.
library;

import '../models/waveform_data.dart';
import '../processing/waveform_generator.dart';

/// Base class for all isolate messages
///
/// Provides common fields and serialization interface for all message types
/// used in isolate communication.
abstract class IsolateMessage {
  /// Unique identifier for this message
  final String id;

  /// Timestamp when the message was created
  final DateTime timestamp;

  /// Message type identifier for deserialization
  String get messageType;

  const IsolateMessage({required this.id, required this.timestamp});

  /// Convert message to JSON for serialization
  Map<String, dynamic> toJson();

  /// Create message from JSON data
  static IsolateMessage fromJson(Map<String, dynamic> json) {
    final messageType = json['messageType'] as String;

    switch (messageType) {
      case 'ProcessingRequest':
        return ProcessingRequest.fromJson(json);
      case 'ProcessingResponse':
        return ProcessingResponse.fromJson(json);
      case 'ProgressUpdate':
        return ProgressUpdate.fromJson(json);
      case 'ErrorMessage':
        return ErrorMessage.fromJson(json);
      case 'CancellationRequest':
        return CancellationRequest.fromJson(json);
      case 'HealthCheckRequest':
        return _HealthCheckRequest.fromJson(json);
      case 'HealthCheckResponse':
        return _HealthCheckResponse.fromJson(json);
      default:
        throw ArgumentError('Unknown message type: $messageType');
    }
  }
}

/// Request message to start processing in a background isolate
class ProcessingRequest extends IsolateMessage {
  /// Path to the audio file to process
  final String filePath;

  /// Configuration for waveform generation
  final WaveformConfig config;

  /// Whether to stream results as they become available
  final bool streamResults;

  @override
  String get messageType => 'ProcessingRequest';

  const ProcessingRequest({required super.id, required super.timestamp, required this.filePath, required this.config, this.streamResults = false});

  @override
  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'filePath': filePath,
      'config': config.toJson(),
      'streamResults': streamResults,
    };
  }

  factory ProcessingRequest.fromJson(Map<String, dynamic> json) {
    return ProcessingRequest(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      filePath: json['filePath'] as String,
      config: WaveformConfig.fromJson(json['config'] as Map<String, dynamic>),
      streamResults: json['streamResults'] as bool? ?? false,
    );
  }
}

/// Response message containing processing results
class ProcessingResponse extends IsolateMessage {
  /// Generated waveform data (null if error occurred)
  final WaveformData? waveformData;

  /// Error message if processing failed
  final String? error;

  /// Whether this is the final response for the request
  final bool isComplete;

  /// Request ID this response corresponds to
  final String requestId;

  @override
  String get messageType => 'ProcessingResponse';

  const ProcessingResponse({required super.id, required super.timestamp, required this.requestId, this.waveformData, this.error, this.isComplete = true});

  @override
  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'requestId': requestId,
      'waveformData': waveformData?.toJson(),
      'error': error,
      'isComplete': isComplete,
    };
  }

  factory ProcessingResponse.fromJson(Map<String, dynamic> json) {
    return ProcessingResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      requestId: json['requestId'] as String,
      waveformData: json['waveformData'] != null ? WaveformData.fromJson(json['waveformData'] as Map<String, dynamic>) : null,
      error: json['error'] as String?,
      isComplete: json['isComplete'] as bool? ?? true,
    );
  }
}

/// Progress update message for long-running operations
class ProgressUpdate extends IsolateMessage {
  /// Progress percentage (0.0 to 1.0)
  final double progress;

  /// Optional status message describing current operation
  final String? statusMessage;

  /// Request ID this progress update corresponds to
  final String requestId;

  /// Partial waveform data for streaming (optional)
  final WaveformData? partialData;

  @override
  String get messageType => 'ProgressUpdate';

  const ProgressUpdate({required super.id, required super.timestamp, required this.requestId, required this.progress, this.statusMessage, this.partialData});

  @override
  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'requestId': requestId,
      'progress': progress,
      'statusMessage': statusMessage,
      'partialData': partialData?.toJson(),
    };
  }

  factory ProgressUpdate.fromJson(Map<String, dynamic> json) {
    return ProgressUpdate(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      requestId: json['requestId'] as String,
      progress: (json['progress'] as num).toDouble(),
      statusMessage: json['statusMessage'] as String?,
      partialData: json['partialData'] != null ? WaveformData.fromJson(json['partialData'] as Map<String, dynamic>) : null,
    );
  }
}

/// Error message for communicating failures across isolates
class ErrorMessage extends IsolateMessage {
  /// Error message description
  final String errorMessage;

  /// Error type/code for categorization
  final String errorType;

  /// Request ID this error corresponds to (if applicable)
  final String? requestId;

  /// Stack trace information (if available)
  final String? stackTrace;

  @override
  String get messageType => 'ErrorMessage';

  const ErrorMessage({required super.id, required super.timestamp, required this.errorMessage, required this.errorType, this.requestId, this.stackTrace});

  @override
  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'errorMessage': errorMessage,
      'errorType': errorType,
      'requestId': requestId,
      'stackTrace': stackTrace,
    };
  }

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      errorMessage: json['errorMessage'] as String,
      errorType: json['errorType'] as String,
      requestId: json['requestId'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }
}

/// Request to cancel an ongoing operation
class CancellationRequest extends IsolateMessage {
  /// Request ID to cancel
  final String requestId;

  @override
  String get messageType => 'CancellationRequest';

  const CancellationRequest({required super.id, required super.timestamp, required this.requestId});

  @override
  Map<String, dynamic> toJson() {
    return {'messageType': messageType, 'id': id, 'timestamp': timestamp.toIso8601String(), 'requestId': requestId};
  }

  factory CancellationRequest.fromJson(Map<String, dynamic> json) {
    return CancellationRequest(id: json['id'] as String, timestamp: DateTime.parse(json['timestamp'] as String), requestId: json['requestId'] as String);
  }
}

/// Health check request message (internal implementation)
class _HealthCheckRequest extends IsolateMessage {
  @override
  String get messageType => 'HealthCheckRequest';

  const _HealthCheckRequest({required super.id, required super.timestamp});

  @override
  Map<String, dynamic> toJson() {
    return {'messageType': messageType, 'id': id, 'timestamp': timestamp.toIso8601String()};
  }

  factory _HealthCheckRequest.fromJson(Map<String, dynamic> json) {
    return _HealthCheckRequest(id: json['id'] as String, timestamp: DateTime.parse(json['timestamp'] as String));
  }
}

/// Health check response message (internal implementation)
class _HealthCheckResponse extends IsolateMessage {
  /// Memory usage in bytes (if available)
  final int? memoryUsage;

  /// Number of active tasks
  final int activeTasks;

  /// Isolate status information
  final Map<String, dynamic> statusInfo;

  @override
  String get messageType => 'HealthCheckResponse';

  const _HealthCheckResponse({required super.id, required super.timestamp, this.memoryUsage, required this.activeTasks, required this.statusInfo});

  @override
  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'memoryUsage': memoryUsage,
      'activeTasks': activeTasks,
      'statusInfo': statusInfo,
    };
  }

  factory _HealthCheckResponse.fromJson(Map<String, dynamic> json) {
    return _HealthCheckResponse(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      memoryUsage: json['memoryUsage'] as int?,
      activeTasks: json['activeTasks'] as int? ?? 0,
      statusInfo: json['statusInfo'] as Map<String, dynamic>? ?? {},
    );
  }
}
