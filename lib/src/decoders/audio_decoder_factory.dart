import 'dart:io';

import 'audio_decoder.dart';
import 'mp3_decoder.dart';
import 'wav_decoder.dart';
import 'flac_decoder.dart';
import 'vorbis_decoder.dart';
import 'mp4_decoder.dart';
import '../exceptions/sonix_exceptions.dart';

/// Factory for creating appropriate audio decoders
class AudioDecoderFactory {
  /// Create a decoder for the given file path
  static AudioDecoder createDecoder(String filePath) {
    final format = detectFormat(filePath);

    switch (format) {
      case AudioFormat.mp3:
        return MP3Decoder();
      case AudioFormat.wav:
        return WAVDecoder();
      case AudioFormat.flac:
        return FLACDecoder();
      case AudioFormat.ogg:
        return VorbisDecoder();
      case AudioFormat.mp4:
        return MP4Decoder();
      case AudioFormat.unknown:
        throw UnsupportedFormatException(_getFileExtension(filePath), 'Unable to determine audio format for file: $filePath');
    }
  }

  /// Detect audio format from file path and optionally file content
  static AudioFormat detectFormat(String filePath) {
    // First try to detect by file extension
    final extension = _getFileExtension(filePath).toLowerCase();

    switch (extension) {
      case 'mp3':
        return AudioFormat.mp3;
      case 'wav':
        return AudioFormat.wav;
      case 'flac':
        return AudioFormat.flac;
      case 'ogg':
        return AudioFormat.ogg;
      case 'mp4':
      case 'm4a':
        return AudioFormat.mp4;
      default:
        // Try to detect by file content if extension is unknown
        return _detectFormatByContent(filePath);
    }
  }

  /// Detect format by examining file content (magic bytes)
  static AudioFormat _detectFormatByContent(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return AudioFormat.unknown;
      }

      // Read first few bytes to check magic numbers
      final bytes = file.readAsBytesSync().take(12).toList();

      if (bytes.length < 4) {
        return AudioFormat.unknown;
      }

      // Check for various format signatures
      if (_checkMP3Signature(bytes)) {
        return AudioFormat.mp3;
      }

      if (_checkWAVSignature(bytes)) {
        return AudioFormat.wav;
      }

      if (_checkFLACSignature(bytes)) {
        return AudioFormat.flac;
      }

      if (_checkOggSignature(bytes)) {
        return AudioFormat.ogg; // Could be Vorbis or Opus
      }

      if (_checkMP4Signature(bytes)) {
        return AudioFormat.mp4;
      }

      return AudioFormat.unknown;
    } catch (e) {
      return AudioFormat.unknown;
    }
  }

  /// Check if bytes match MP3 signature
  static bool _checkMP3Signature(List<int> bytes) {
    // MP3 files can start with ID3 tag or sync frame
    if (bytes.length >= 3) {
      // ID3v2 tag
      if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        return true;
      }

      // MP3 sync frame (first 11 bits are 1)
      if (bytes.length >= 2) {
        final syncWord = (bytes[0] << 8) | bytes[1];
        if ((syncWord & 0xFFE0) == 0xFFE0) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if bytes match WAV signature
  static bool _checkWAVSignature(List<int> bytes) {
    if (bytes.length >= 12) {
      // RIFF header
      return bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          // WAVE format
          bytes[8] == 0x57 &&
          bytes[9] == 0x41 &&
          bytes[10] == 0x56 &&
          bytes[11] == 0x45;
    }
    return false;
  }

  /// Check if bytes match FLAC signature
  static bool _checkFLACSignature(List<int> bytes) {
    if (bytes.length >= 4) {
      // fLaC signature
      return bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43;
    }
    return false;
  }

  /// Check if bytes match OGG signature
  static bool _checkOggSignature(List<int> bytes) {
    if (bytes.length >= 4) {
      // OggS signature
      return bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53;
    }
    return false;
  }

  /// Check if bytes match MP4 signature
  static bool _checkMP4Signature(List<int> bytes) {
    if (bytes.length >= 8) {
      // Check for MP4 ftyp box signature
      // Skip first 4 bytes (box size), check for 'ftyp'
      return bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70;
    }
    return false;
  }

  /// Get file extension from path
  static String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1);
  }

  /// Check if a format is supported
  static bool isFormatSupported(String filePath) {
    final format = detectFormat(filePath);
    return format != AudioFormat.unknown;
  }

  /// Get list of supported file extensions
  static List<String> getSupportedExtensions() {
    return [
      ...AudioFormat.mp3.extensions,
      ...AudioFormat.wav.extensions,
      ...AudioFormat.flac.extensions,
      ...AudioFormat.ogg.extensions,
      ...AudioFormat.mp4.extensions,
    ];
  }

  /// Get list of supported formats
  static List<AudioFormat> getSupportedFormats() {
    return [AudioFormat.mp3, AudioFormat.wav, AudioFormat.flac, AudioFormat.ogg, AudioFormat.mp4];
  }

  /// Get human-readable list of supported formats
  static List<String> getSupportedFormatNames() {
    return getSupportedFormats().map((format) => format.name).toList();
  }
}
