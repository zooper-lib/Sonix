/// Utilities for serializing and deserializing errors across isolate boundaries
///
/// This module provides functionality to safely transfer error information
/// between isolates, including stack traces and error details.
library;

import '../exceptions/sonix_exceptions.dart';

/// Serializes errors for cross-isolate communication
class ErrorSerializer {
  /// Serialize an error object to a JSON-compatible map
  static Map<String, dynamic> serializeError(Object error, [StackTrace? stackTrace]) {
    final Map<String, dynamic> errorData = {'timestamp': DateTime.now().toIso8601String(), 'stackTrace': stackTrace?.toString()};

    if (error is SonixException) {
      errorData.addAll({'type': error.runtimeType.toString(), 'message': error.message, 'details': error.details});

      // Add specific fields for isolate exceptions
      if (error is IsolateProcessingException) {
        errorData.addAll({
          'isolateId': error.isolateId,
          'originalError': error.originalError,
          'originalErrorType': error.originalErrorType,
          'isolateStackTrace': error.isolateStackTrace,
          'requestId': error.requestId,
        });
      } else if (error is IsolateCommunicationException) {
        errorData.addAll({
          'messageType': error.messageType,
          'isolateId': error.isolateId,
          'communicationDirection': error.communicationDirection,
          'cause': error.cause?.toString(),
        });
      } else if (error is FileAccessException) {
        errorData['filePath'] = error.filePath;
      } else if (error is UnsupportedFormatException) {
        errorData['format'] = error.format;
      } else if (error is CorruptedFileException) {
        errorData['filePath'] = error.filePath;
      } else if (error is FFIException) {
        // Handle FFMPEG-related FFI exceptions
        errorData['isFFMPEGRelated'] = error.message.contains('FFMPEG');
      }
    } else {
      // Handle non-Sonix exceptions
      errorData.addAll({'type': error.runtimeType.toString(), 'message': error.toString()});
    }

    return errorData;
  }

  /// Deserialize an error from a JSON-compatible map
  static SonixException deserializeError(Map<String, dynamic> errorData) {
    final String type = errorData['type'] as String? ?? 'SonixException';
    final String message = errorData['message'] as String? ?? 'Unknown error';
    final String? details = errorData['details'] as String?;

    switch (type) {
      case 'IsolateProcessingException':
        return IsolateProcessingException(
          errorData['isolateId'] as String? ?? 'unknown',
          errorData['originalError'] as String? ?? message,
          originalErrorType: errorData['originalErrorType'] as String?,
          isolateStackTrace: errorData['isolateStackTrace'] as String?,
          requestId: errorData['requestId'] as String?,
          details: details,
        );

      case 'IsolateCommunicationException':
        return IsolateCommunicationException(
          errorData['messageType'] as String? ?? 'unknown',
          errorData['communicationDirection'] as String? ?? 'unknown',
          isolateId: errorData['isolateId'] as String?,
          cause: errorData['cause'] as String?,
          details: details,
        );

      case 'UnsupportedFormatException':
        return UnsupportedFormatException(errorData['format'] as String? ?? 'unknown', details);

      case 'DecodingException':
        return DecodingException(message, details);

      case 'MemoryException':
        return MemoryException(message, details);

      case 'FileAccessException':
        return FileAccessException(errorData['filePath'] as String? ?? 'unknown', message, details);

      case 'FileNotFoundException':
        return FileNotFoundException(errorData['filePath'] as String? ?? 'unknown', details);

      case 'CorruptedFileException':
        return CorruptedFileException(errorData['filePath'] as String? ?? 'unknown', details);

      case 'FFIException':
        return FFIException(message, details);

      case 'InvalidWaveformDataException':
        return InvalidWaveformDataException(message, details);

      case 'ConfigurationException':
        return ConfigurationException(message, details);

      case 'StreamingException':
        return StreamingException(message, details);

      case 'FFMPEGException':
        return FFIException(message, details); // Map FFMPEG errors to FFI exceptions

      default:
        // Fallback to generic SonixException
        return SonixError(message, details);
    }
  }

  /// Create an error message for isolate communication
  static Map<String, dynamic> createErrorMessage({required String messageId, required Object error, StackTrace? stackTrace, String? requestId}) {
    final errorData = serializeError(error, stackTrace);

    return {
      'messageType': 'ErrorMessage',
      'id': messageId,
      'timestamp': DateTime.now().toIso8601String(),
      'errorMessage': errorData['message'],
      'errorType': errorData['type'],
      'requestId': requestId,
      'stackTrace': errorData['stackTrace'],
      'errorData': errorData,
    };
  }

  /// Extract error from an error message
  static SonixException extractError(Map<String, dynamic> errorMessage) {
    final errorData = errorMessage['errorData'] as Map<String, dynamic>?;

    if (errorData != null) {
      return deserializeError(errorData);
    }

    // Fallback to basic error information
    return SonixError(errorMessage['errorMessage'] as String? ?? 'Unknown error', errorMessage['stackTrace'] as String?);
  }

  /// Check if an error is recoverable
  static bool isRecoverableError(Object error) {
    if (error is IsolateCommunicationException) {
      // Communication errors might be recoverable with retry
      return true;
    }

    if (error is MemoryException) {
      // Memory errors might be recoverable after cleanup
      return true;
    }

    if (error is DecodingException) {
      // Check if it's a non-recoverable decoding error
      final message = error.message.toLowerCase();
      final details = error.details?.toLowerCase() ?? '';
      
      // Empty files, invalid files, and severely corrupted files are not recoverable
      if (message.contains('file is empty') ||
          message.contains('empty file') ||
          message.contains('invalid file') ||
          message.contains('cannot decode empty') ||
          details.contains('file is empty') ||
          details.contains('empty file') ||
          details.contains('invalid file') ||
          details.contains('cannot decode empty')) {
        return false;
      }
      
      // Other decoding errors might be temporary (e.g., due to incomplete file write)
      return true;
    }

    // File not found, corrupted files, unsupported formats are not recoverable
    if (error is FileNotFoundException || error is CorruptedFileException || error is UnsupportedFormatException) {
      return false;
    }

    // Default to recoverable for unknown errors
    return true;
  }

  /// Get retry delay for recoverable errors
  static Duration getRetryDelay(Object error, int attemptNumber) {
    // Exponential backoff with jitter
    final baseDelay = Duration(milliseconds: 100 * (1 << attemptNumber));
    final jitter = Duration(milliseconds: (baseDelay.inMilliseconds * 0.1).round());

    if (error is IsolateCommunicationException) {
      // Shorter delays for communication errors
      return Duration(milliseconds: baseDelay.inMilliseconds ~/ 2) + jitter;
    }

    if (error is MemoryException) {
      // Longer delays for memory errors to allow cleanup
      return baseDelay * 2 + jitter;
    }

    return baseDelay + jitter;
  }
}
