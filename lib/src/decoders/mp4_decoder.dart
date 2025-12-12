import 'dart:typed_data';
import '../models/audio_data.dart';
import '../native/native_audio_bindings.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// MP4/AAC audio decoder - pure bytes-to-samples transformation.
///
/// This decoder is stateless and handles NO file I/O.
/// It simply transforms encoded MP4/AAC bytes into decoded PCM samples.
///
/// For MP4/AAC format, the native layer (FFmpeg) handles all the parsing,
/// frame decoding, and container handling.
class MP4Decoder implements AudioDecoder {
  @override
  AudioFormat get format => AudioFormat.mp4;

  @override
  AudioData decode(Uint8List data) {
    try {
      // Use native bindings to decode the MP4/AAC data
      final audioData = NativeAudioBindings.decodeAudio(data, AudioFormat.mp4);
      return audioData;
    } catch (e) {
      throw DecodingException(
        'Failed to decode MP4/AAC data',
        'Error decoding MP4: $e',
      );
    }
  }

  @override
  void dispose() {
    // MP4 decoder has no persistent state or native resources to clean up
    // The native bindings handle their own cleanup
  }
}
