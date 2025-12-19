import 'dart:typed_data';

import '../exceptions/sonix_exceptions.dart';
import '../models/audio_data.dart';
import '../native/native_audio_bindings.dart';
import 'audio_decoder.dart';

/// Universal audio decoder using FFmpeg.
///
/// This decoder handles ALL supported audio formats through FFmpeg's
/// auto-detection capabilities. It is stateless and handles NO file I/O.
/// It simply transforms encoded audio bytes into decoded PCM samples.
///
/// FFmpeg automatically detects the format from the byte content,
/// so format-specific decoders are not needed.
class FFmpegDecoder implements AudioDecoder {
  /// The format hint for buffer estimation (optional).
  /// FFmpeg will auto-detect the actual format from the data.
  final AudioFormat _formatHint;

  /// Create an FFmpeg decoder.
  ///
  /// [formatHint] - Optional hint for buffer size estimation.
  /// If not provided, defaults to [AudioFormat.unknown] and FFmpeg
  /// will use conservative buffer estimates.
  FFmpegDecoder([this._formatHint = AudioFormat.unknown]);

  @override
  AudioFormat get format => _formatHint;

  @override
  AudioData decode(Uint8List data) {
    try {
      // Use native bindings to decode the audio data
      // FFmpeg auto-detects the format; the hint is only for buffer estimation
      final audioData = NativeAudioBindings.decodeAudio(data, _formatHint);
      return audioData;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode audio data', 'Error decoding audio: $e');
    }
  }

  @override
  void dispose() {
    // FFmpeg decoder has no persistent state or native resources to clean up
    // The native bindings handle their own cleanup
  }
}
