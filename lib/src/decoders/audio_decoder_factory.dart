import 'audio_decoder.dart';
import 'mp3_decoder.dart';
import 'wav_decoder.dart';
import 'flac_decoder.dart';
import 'vorbis_decoder.dart';
import 'opus_decoder.dart';
import 'mp4_decoder.dart';

/// Factory for creating audio decoders based on format.
///
/// This factory creates stateless decoders that transform
/// audio bytes to PCM samples without any file I/O.
class AudioDecoderFactory {
  /// Create a decoder for the given file path or audio format.
  ///
  /// Can accept either:
  /// - A file path (String) - will auto-detect format from extension
  /// - An AudioFormat enum value - will create decoder for that format
  ///
  /// Optional parameters:
  /// - [memorySafe]: Deprecated, ignored (kept for backward compatibility)
  /// - [samplingResolution]: Deprecated, ignored (kept for backward compatibility)
  ///
  /// Returns a decoder that implements AudioDecoder.
  /// Throws [UnsupportedError] if the format is unknown or unsupported.
  static AudioDecoder createDecoder(dynamic formatOrPath, {bool? memorySafe, int? samplingResolution}) {
    final AudioFormat format;

    if (formatOrPath is String) {
      // File path provided - detect format from extension
      format = detectFormat(formatOrPath);
    } else if (formatOrPath is AudioFormat) {
      // Format enum provided directly
      format = formatOrPath;
    } else {
      throw ArgumentError('formatOrPath must be either a String (file path) or AudioFormat enum');
    }

    switch (format) {
      case AudioFormat.mp3:
        return MP3Decoder();
      case AudioFormat.wav:
        return WAVDecoder();
      case AudioFormat.flac:
        return FLACDecoder();
      case AudioFormat.ogg:
        return VorbisDecoder();
      case AudioFormat.opus:
        return OpusDecoder();
      case AudioFormat.mp4:
        return MP4Decoder();
      case AudioFormat.unknown:
        throw UnsupportedError('Cannot create decoder for unknown format');
    }
  }

  /// Check if a format or file is supported.
  ///
  /// Can accept either:
  /// - A file path (String) - will check if file extension is supported
  /// - An AudioFormat enum value - will check if format is supported
  ///
  /// Returns true if the format/file is supported, false otherwise.
  static bool isFormatSupported(dynamic formatOrPath) {
    if (formatOrPath is String) {
      // File path provided - check if extension is supported
      return isFileSupported(formatOrPath);
    } else if (formatOrPath is AudioFormat) {
      // Format enum provided - check if it's supported
      return formatOrPath != AudioFormat.unknown;
    } else {
      throw ArgumentError('formatOrPath must be either a String (file path) or AudioFormat enum');
    }
  }

  /// Get list of supported formats.
  static List<AudioFormat> getSupportedFormats() {
    return [AudioFormat.mp3, AudioFormat.wav, AudioFormat.flac, AudioFormat.ogg, AudioFormat.opus, AudioFormat.mp4];
  }

  /// Detect audio format from file path
  static AudioFormat detectFormat(String filePath) {
    // First try to detect by file extension
    final extension = _getFileExtension(filePath).toLowerCase();

    switch (extension) {
      case 'mp3':
        return AudioFormat.mp3;
      case 'wav':
      case 'wave':
        return AudioFormat.wav;
      case 'flac':
        return AudioFormat.flac;
      case 'ogg':
        return AudioFormat.ogg;
      case 'opus':
        return AudioFormat.opus;
      case 'm4a':
      case 'mp4':
      case 'aac':
        return AudioFormat.mp4;
      default:
        return AudioFormat.unknown;
    }
  }

  /// Check if a file format is supported based on file path
  static bool isFileSupported(String filePath) {
    return detectFormat(filePath) != AudioFormat.unknown;
  }

  /// Get list of supported format names
  static List<String> getSupportedFormatNames() {
    return ['MP3', 'WAV', 'FLAC', 'OGG', 'Opus', 'M4A/MP4/AAC'];
  }

  /// Get list of supported file extensions
  static List<String> getSupportedExtensions() {
    return ['mp3', 'wav', 'wave', 'flac', 'ogg', 'opus', 'm4a', 'mp4', 'aac'];
  }

  static String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1);
  }
}
