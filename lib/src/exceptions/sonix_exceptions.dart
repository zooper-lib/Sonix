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
