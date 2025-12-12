import 'dart:typed_data';
import '../models/audio_data.dart';
import '../native/native_audio_bindings.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// FLAC audio decoder - pure bytes-to-samples transformation.
///
/// This decoder is stateless and handles NO file I/O.
/// It simply transforms encoded FLAC bytes into decoded PCM samples.
///
/// For FLAC format, the native layer (FFmpeg) handles all the parsing,
/// frame decoding, and lossless decompression.
class FLACDecoder implements AudioDecoder {
  @override
  AudioFormat get format => AudioFormat.flac;

  @override
  AudioData decode(Uint8List data) {
    try {
      // Use native bindings to decode the FLAC data
      final audioData = NativeAudioBindings.decodeAudio(data, AudioFormat.flac);
      return audioData;
    } catch (e) {
      throw DecodingException(
        'Failed to decode FLAC data',
        'Error decoding FLAC: $e',
      );
    }
  }

  @override
  void dispose() {
    // FLAC decoder has no persistent state or native resources to clean up
    // The native bindings handle their own cleanup
  }
}
