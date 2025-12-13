import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';
import 'audio_format_service.dart';
import 'ffmpeg_decoder.dart';

/// Factory for creating audio decoders based on format.
///
/// This factory creates stateless decoders that transform
/// audio bytes to PCM samples without any file I/O.
///
/// All decoding is handled by FFmpeg, which auto-detects the format.
/// The format parameter is only used as a hint for buffer estimation.
///
/// For format detection and metadata, use [AudioFormatService] directly.
class AudioDecoderFactory {
  /// Create a decoder for the given audio format.
  ///
  /// The format is used as a hint for buffer size estimation.
  /// FFmpeg will auto-detect the actual format from the audio data.
  ///
  /// Returns a decoder that implements AudioDecoder.
  /// Throws [UnsupportedFormatException] if the format is unknown or unsupported.
  static AudioDecoder createDecoderFromFormat(AudioFormat format) {
    if (format == AudioFormat.unknown) {
      throw UnsupportedFormatException('Cannot create decoder for unknown format');
    }
    return FFmpegDecoder(format);
  }

  /// Create a decoder for the given file path.
  ///
  /// Auto-detects format from the file extension for buffer estimation.
  /// FFmpeg will auto-detect the actual format from the audio data.
  ///
  /// Returns a decoder that implements AudioDecoder.
  /// Throws [UnsupportedFormatException] if the format is unknown or unsupported.
  static AudioDecoder createDecoderFromPath(String filePath) {
    final format = AudioFormatService.detectFromFilePath(filePath);
    return createDecoderFromFormat(format);
  }
}
