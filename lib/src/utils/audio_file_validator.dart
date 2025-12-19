import 'dart:io';

import '../exceptions/sonix_exceptions.dart';

/// Validates audio files before processing.
///
/// This class provides validation logic to ensure files are suitable
/// for audio processing, catching issues early before they reach
/// the decoder or FFmpeg.
class AudioFileValidator {
  /// Minimum file size in bytes for a valid audio file.
  /// Even the smallest valid audio files need headers.
  static const int minFileSize = 12;

  /// Validates that a file exists and is suitable for audio processing.
  ///
  /// Throws [FileSystemException] if the file does not exist.
  /// Throws [DecodingException] if the file is empty or too small.
  static Future<void> validate(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileSize = await file.length();

    if (fileSize == 0) {
      throw const DecodingException('File is empty', 'Cannot process empty audio file');
    }

    if (fileSize < minFileSize) {
      throw DecodingException('Invalid file', 'File is too small to be valid audio: $fileSize bytes');
    }
  }

  /// Returns the file size if valid, throws otherwise.
  ///
  /// This is useful when you need both validation and file size.
  ///
  /// Throws [FileSystemException] if the file does not exist.
  /// Throws [DecodingException] if the file is empty or too small.
  static Future<int> validateAndGetSize(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileSize = await file.length();

    if (fileSize == 0) {
      throw const DecodingException('File is empty', 'Cannot process empty audio file');
    }

    if (fileSize < minFileSize) {
      throw DecodingException('Invalid file', 'File is too small to be valid audio: $fileSize bytes');
    }

    return fileSize;
  }
}
