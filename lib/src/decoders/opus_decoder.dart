import 'dart:typed_data';
import '../models/audio_data.dart';
import '../native/native_audio_bindings.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// Opus audio decoder - pure bytes-to-samples transformation.
///
/// This decoder is stateless and handles NO file I/O.
/// It simply transforms encoded Opus bytes into decoded PCM samples.
///
/// For Opus format, the native layer (FFmpeg) handles all the parsing,
/// frame decoding, and OGG/Opus container handling.
class OpusDecoder implements AudioDecoder {
  @override
  AudioFormat get format => AudioFormat.opus;

  @override
  AudioData decode(Uint8List data) {
    try {
      // Use native bindings to decode the Opus data
      final audioData = NativeAudioBindings.decodeAudio(data, AudioFormat.opus);
      return audioData;
    } catch (e) {
      throw DecodingException(
        'Failed to decode Opus data',
        'Error decoding Opus: $e',
      );
    }
  }

  @override
  void dispose() {
    // Opus decoder has no persistent state or native resources to clean up
    // The native bindings handle their own cleanup
  }
}
