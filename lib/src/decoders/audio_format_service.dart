import 'audio_decoder.dart';

/// Service for handling audio format detection and metadata.
///
/// This service centralizes all format-related logic to avoid duplication
/// between [AudioFormat] enum getters and factory methods.
///
/// Use this service for:
/// - Format detection from file paths
/// - Getting supported formats, extensions, and names
/// - Checking format support
class AudioFormatService {
  /// Private constructor - use static methods
  AudioFormatService._();

  /// All supported audio formats (excluding unknown).
  static const List<AudioFormat> supportedFormats = [AudioFormat.mp3, AudioFormat.wav, AudioFormat.flac, AudioFormat.ogg, AudioFormat.opus, AudioFormat.mp4];

  /// Detect audio format from file path based on extension.
  ///
  /// Returns [AudioFormat.unknown] if the extension is not recognized.
  static AudioFormat detectFromFilePath(String filePath) {
    final extension = _getFileExtension(filePath).toLowerCase();

    for (final format in supportedFormats) {
      if (format.extensions.contains(extension)) {
        return format;
      }
    }

    return AudioFormat.unknown;
  }

  /// Check if a file has a supported audio format.
  static bool isFileSupported(String filePath) {
    return detectFromFilePath(filePath) != AudioFormat.unknown;
  }

  /// Check if an audio format is supported.
  static bool isFormatSupported(AudioFormat format) {
    return format != AudioFormat.unknown;
  }

  /// Get all supported file extensions.
  ///
  /// This is derived from [AudioFormat.extensions] to maintain a single source of truth.
  static List<String> getSupportedExtensions() {
    return supportedFormats.expand((format) => format.extensions).toList();
  }

  /// Get all supported format names.
  ///
  /// This is derived from [AudioFormat.name] to maintain a single source of truth.
  static List<String> getSupportedFormatNames() {
    return supportedFormats.map((format) => format.name).toList();
  }

  /// Get the format for a specific extension.
  ///
  /// Returns [AudioFormat.unknown] if the extension is not recognized.
  static AudioFormat getFormatForExtension(String extension) {
    final ext = extension.toLowerCase();
    for (final format in supportedFormats) {
      if (format.extensions.contains(ext)) {
        return format;
      }
    }
    return AudioFormat.unknown;
  }

  static String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1);
  }
}
