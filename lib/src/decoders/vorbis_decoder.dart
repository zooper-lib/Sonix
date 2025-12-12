import 'dart:typed_data';
import '../models/audio_data.dart';
import '../native/native_audio_bindings.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// Vorbis (OGG) audio decoder - pure bytes-to-samples transformation.
///
/// This decoder is stateless and handles NO file I/O.
/// It simply transforms encoded Vorbis/OGG bytes into decoded PCM samples.
///
/// For Vorbis format, the native layer (FFmpeg) handles all the parsing,
/// frame decoding, and OGG container handling.
class VorbisDecoder implements AudioDecoder {
  @override
  AudioFormat get format => AudioFormat.ogg;

  @override
  AudioData decode(Uint8List data) {
    try {
      // Use native bindings to decode the Vorbis/OGG data
      final audioData = NativeAudioBindings.decodeAudio(data, AudioFormat.ogg);
      return audioData;
    } catch (e) {
      throw DecodingException(
        'Failed to decode Vorbis/OGG data',
        'Error decoding Vorbis: $e',
      );
    }
  }

  @override
  void dispose() {
    // Vorbis decoder has no persistent state or native resources to clean up
    // The native bindings handle their own cleanup
  }
}
