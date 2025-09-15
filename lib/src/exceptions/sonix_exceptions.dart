/// Base exception class for all Sonix audio processing errors.
///
/// This abstract class serves as the foundation for all specific exception
/// types in the Sonix library. It provides a consistent interface for error
/// handling and includes both primary error messages and optional additional
/// details for debugging.
///
/// ## Exception Hierarchy
///
/// All Sonix exceptions inherit from this base class:
/// - [UnsupportedFormatException]: Unsupported audio file formats
/// - [DecodingException]: Audio decoding failures
/// - [MemoryException]: Memory allocation or management issues
/// - [FileAccessException]: File system access problems
/// - [FFIException]: Native library interface errors
/// - [InvalidWaveformDataException]: Waveform data validation failures
///
/// ## Usage in Error Handling
///
/// ```dart
/// try {
///   final waveform = await sonix.generateWaveform('audio.mp3');
/// } on SonixException catch (e) {
///   print('Sonix error: ${e.message}');
///   if (e.details != null) {
///     print('Details: ${e.details}');
///   }
/// } catch (e) {
///   print('Unexpected error: $e');
/// }
/// ```
///
/// ## Error Message Structure
///
/// Each exception provides:
/// - **message**: Primary error description for users
/// - **details**: Technical details for debugging (optional)
/// - **toString()**: Formatted output combining both
abstract class SonixException implements Exception {
  /// Primary error message describing what went wrong.
  ///
  /// This message should be user-friendly and suitable for display in user
  /// interfaces. It provides a clear, concise description of the error that
  /// occurred during audio processing.
  final String message;

  /// Optional additional technical details for debugging and logging.
  ///
  /// Contains technical information that may be useful for developers
  /// debugging issues, such as specific error codes, file paths, or
  /// system-level error messages. May be null for simple errors.
  final String? details;

  const SonixException(this.message, [this.details]);

  @override
  String toString() {
    if (details != null) {
      return 'SonixException: $message\nDetails: $details';
    }
    return 'SonixException: $message';
  }
}

/// Exception thrown when attempting to process an unsupported audio format.
///
/// This exception is raised when the library encounters an audio file format
/// that is not supported by the current configuration. The library supports
/// MP3, OGG, WAV, FLAC, and Opus formats through native codecs.
///
/// ## Common Causes
///
/// - File has an unsupported extension (e.g., .aac, .m4a, .wma)
/// - File is corrupted or not a valid audio file
/// - Required codec is not available on the platform
/// - File uses an unsupported audio encoding variant
///
/// ## How to Handle
///
/// ```dart
/// try {
///   final waveform = await sonix.generateWaveform('audio.aac');
/// } on UnsupportedFormatException catch (e) {
///   // Show user-friendly error message
///   showSnackBar('Unsupported file format: ${e.format}');
///
///   // Log technical details
///   logger.warning('Format error: ${e.details}');
///
///   // Suggest alternatives
///   final supported = Sonix.getSupportedFormats();
///   showDialog('Supported formats: ${supported.join(', ')}');
/// }
/// ```
///
/// ## Prevention
///
/// ```dart
/// // Check format before processing
/// if (Sonix.isFormatSupported(filePath)) {
///   final waveform = await sonix.generateWaveform(filePath);
/// } else {
///   throw UnsupportedFormatException(
///     path.extension(filePath),
///     'File format validation failed'
///   );
/// }
/// ```
class UnsupportedFormatException extends SonixException {
  /// The specific audio format that is not supported.
  ///
  /// This typically contains the file extension (e.g., 'aac', 'm4a') or
  /// MIME type that caused the error. Use this to provide specific feedback
  /// to users about which format was problematic.
  final String format;

  const UnsupportedFormatException(this.format, [String? details]) : super('Unsupported audio format: $format', details);

  @override
  String toString() {
    if (details != null) {
      return 'UnsupportedFormatException: Unsupported audio format: $format\nDetails: $details';
    }
    return 'UnsupportedFormatException: Unsupported audio format: $format';
  }
}

/// Exception thrown when audio decoding operations fail.
///
/// This exception occurs when the library can recognize an audio format but
/// encounters errors while actually decoding the audio data. This is different
/// from [UnsupportedFormatException] - the format is supported, but something
/// went wrong during the decoding process.
///
/// ## Common Causes
///
/// - Corrupted or incomplete audio files
/// - Unsupported audio encoding parameters (e.g., unusual sample rates)
/// - Files that are too large for available memory
/// - Network interruption during streaming decode
/// - Insufficient system resources during processing
///
/// ## Recovery Strategies
///
/// ```dart
/// try {
///   final waveform = await sonix.generateWaveform('audio.mp3');
/// } on DecodingException catch (e) {
///   // Try with lower resolution to reduce memory usage
///   try {
///     final waveform = await sonix.generateWaveform(
///       'audio.mp3',
///       resolution: 500, // Reduced from default 1000
///     );
///   } on DecodingException {
///     // Show error to user if retry also fails
///     showErrorDialog('Unable to process audio file: ${e.message}');
///   }
/// }
/// ```
///
/// ## Debugging Information
///
/// The [details] field often contains technical information useful for
/// debugging, such as specific codec error messages or system resource
/// information.
class DecodingException extends SonixException {
  const DecodingException(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'DecodingException: $message\nDetails: $details';
    }
    return 'DecodingException: $message';
  }
}

/// Exception thrown when memory-related issues occur
class MemoryException extends SonixException {
  const MemoryException(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'MemoryException: $message\nDetails: $details';
    }
    return 'MemoryException: $message';
  }
}

/// Exception thrown when file access fails
class FileAccessException extends SonixException {
  /// The file path that caused the error
  final String filePath;

  const FileAccessException(this.filePath, String message, [String? details]) : super(message, details);

  @override
  String toString() {
    if (details != null) {
      return 'FileAccessException: $message (File: $filePath)\nDetails: $details';
    }
    return 'FileAccessException: $message (File: $filePath)';
  }
}

/// Exception thrown when FFI operations fail
class FFIException extends SonixException {
  const FFIException(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'FFIException: $message\nDetails: $details';
    }
    return 'FFIException: $message';
  }
}

/// Exception thrown when waveform data validation fails
class InvalidWaveformDataException extends SonixException {
  const InvalidWaveformDataException(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'InvalidWaveformDataException: $message\nDetails: $details';
    }
    return 'InvalidWaveformDataException: $message';
  }
}

/// Exception thrown when configuration validation fails
class ConfigurationException extends SonixException {
  const ConfigurationException(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'ConfigurationException: $message\nDetails: $details';
    }
    return 'ConfigurationException: $message';
  }
}

/// Exception thrown when streaming operations fail
class StreamingException extends SonixException {
  const StreamingException(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'StreamingException: $message\nDetails: $details';
    }
    return 'StreamingException: $message';
  }
}

/// Exception thrown when a file is not found (alias for FileAccessException)
class FileNotFoundException extends FileAccessException {
  const FileNotFoundException(String filePath, [String? details]) : super(filePath, 'File not found: $filePath', details);

  @override
  String toString() {
    if (details != null) {
      return 'FileNotFoundException: File not found: $filePath\nDetails: $details';
    }
    return 'FileNotFoundException: File not found: $filePath';
  }
}

/// Exception thrown when a file is corrupted or contains invalid data
class CorruptedFileException extends SonixException {
  /// The file path that is corrupted
  final String filePath;

  const CorruptedFileException(this.filePath, [String? details]) : super('Corrupted or invalid audio file: $filePath', details);

  @override
  String toString() {
    if (details != null) {
      return 'CorruptedFileException: Corrupted or invalid audio file: $filePath\nDetails: $details';
    }
    return 'CorruptedFileException: Corrupted or invalid audio file: $filePath';
  }
}

/// General Sonix error (alias for SonixException for backwards compatibility)
class SonixError extends SonixException {
  const SonixError(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'SonixError: $message\nDetails: $details';
    }
    return 'SonixError: $message';
  }
}

/// Exception thrown when an unsupported operation is attempted (alias for UnsupportedFormatException)
class SonixUnsupportedOperationException extends SonixException {
  const SonixUnsupportedOperationException(super.message, [super.details]);

  @override
  String toString() {
    if (details != null) {
      return 'SonixUnsupportedOperationException: $message\nDetails: $details';
    }
    return 'SonixUnsupportedOperationException: $message';
  }
}

/// Exception thrown when file operations fail (alias for FileAccessException)
class SonixFileException extends FileAccessException {
  const SonixFileException(String message, [String? details]) : super('', message, details);

  @override
  String toString() {
    if (details != null) {
      return 'SonixFileException: $message\nDetails: $details';
    }
    return 'SonixFileException: $message';
  }
}

/// Exception thrown when processing fails in a background isolate
class IsolateProcessingException extends SonixException {
  /// The ID of the isolate where the error occurred
  final String isolateId;

  /// The original error message from the isolate
  final String originalError;

  /// The type of the original error
  final String? originalErrorType;

  /// Stack trace from the isolate (if available)
  final String? isolateStackTrace;

  /// Request ID that was being processed when the error occurred
  final String? requestId;

  const IsolateProcessingException(this.isolateId, this.originalError, {this.originalErrorType, this.isolateStackTrace, this.requestId, String? details})
    : super('Processing failed in isolate $isolateId: $originalError', details);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('IsolateProcessingException: Processing failed in isolate $isolateId: $originalError');

    if (originalErrorType != null) {
      buffer.write('\nError Type: $originalErrorType');
    }

    if (requestId != null) {
      buffer.write('\nRequest ID: $requestId');
    }

    if (details != null) {
      buffer.write('\nDetails: $details');
    }

    if (isolateStackTrace != null) {
      buffer.write('\nIsolate Stack Trace:\n$isolateStackTrace');
    }

    return buffer.toString();
  }

  /// Create an IsolateProcessingException from serialized error data
  factory IsolateProcessingException.fromErrorData(String isolateId, Map<String, dynamic> errorData) {
    return IsolateProcessingException(
      isolateId,
      errorData['message'] as String? ?? 'Unknown error',
      originalErrorType: errorData['type'] as String?,
      isolateStackTrace: errorData['stackTrace'] as String?,
      requestId: errorData['requestId'] as String?,
      details: errorData['details'] as String?,
    );
  }

  /// Convert this exception to serializable data
  Map<String, dynamic> toErrorData() {
    return {
      'message': originalError,
      'type': originalErrorType ?? 'IsolateProcessingException',
      'stackTrace': isolateStackTrace,
      'requestId': requestId,
      'details': details,
      'isolateId': isolateId,
    };
  }
}

/// Exception thrown when communication with isolates fails
class IsolateCommunicationException extends SonixException {
  /// The type of message that failed to communicate
  final String messageType;

  /// The ID of the isolate involved in the communication failure
  final String? isolateId;

  /// The direction of communication (send/receive)
  final String communicationDirection;

  /// The underlying cause of the communication failure
  final Object? cause;

  const IsolateCommunicationException(this.messageType, this.communicationDirection, {this.isolateId, this.cause, String? details})
    : super(
        'Failed to $communicationDirection message of type $messageType'
        '${isolateId != null ? ' with isolate $isolateId' : ''}',
        details,
      );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('IsolateCommunicationException: Failed to $communicationDirection message of type $messageType');

    if (isolateId != null) {
      buffer.write(' with isolate $isolateId');
    }

    if (cause != null) {
      buffer.write('\nCause: $cause');
    }

    if (details != null) {
      buffer.write('\nDetails: $details');
    }

    return buffer.toString();
  }

  /// Create a communication exception for message sending failures
  factory IsolateCommunicationException.sendFailure(String messageType, {String? isolateId, Object? cause, String? details}) {
    return IsolateCommunicationException(messageType, 'send', isolateId: isolateId, cause: cause, details: details);
  }

  /// Create a communication exception for message receiving failures
  factory IsolateCommunicationException.receiveFailure(String messageType, {String? isolateId, Object? cause, String? details}) {
    return IsolateCommunicationException(messageType, 'receive', isolateId: isolateId, cause: cause, details: details);
  }

  /// Create a communication exception for message parsing failures
  factory IsolateCommunicationException.parseFailure(String messageType, {String? isolateId, Object? cause, String? details}) {
    return IsolateCommunicationException(messageType, 'parse', isolateId: isolateId, cause: cause, details: details);
  }
}

/// Exception thrown when a task is cancelled
class TaskCancelledException implements Exception {
  final String message;
  TaskCancelledException(this.message);

  @override
  String toString() => 'TaskCancelledException: $message';
}
