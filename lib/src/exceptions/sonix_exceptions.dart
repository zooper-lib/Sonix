/// Base exception class for all Sonix-related errors
abstract class SonixException implements Exception {
  /// Error message
  final String message;

  /// Additional error details
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

/// Exception thrown when an unsupported audio format is encountered
class UnsupportedFormatException extends SonixException {
  /// The unsupported format
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

/// Exception thrown when audio decoding fails
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
