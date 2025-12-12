import 'dart:typed_data';
import '../models/audio_data.dart';
import '../native/native_audio_bindings.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// MP3 audio decoder - pure bytes-to-samples transformation.
///
/// This decoder is stateless and handles NO file I/O.
/// It simply transforms encoded MP3 bytes into decoded PCM samples.
///
/// For MP3 format, the native layer (FFmpeg) handles all the parsing,
/// frame decoding, and bitstream processing.
class MP3Decoder implements AudioDecoder {
  @override
  AudioFormat get format => AudioFormat.mp3;

  @override
  AudioData decode(Uint8List data) {
    try {
      // Use native bindings to decode the MP3 data
      final audioData = NativeAudioBindings.decodeAudio(data, AudioFormat.mp3);
      return audioData;
    } catch (e) {
      throw DecodingException(
        'Failed to decode MP3 data',
        'Error decoding MP3: $e',
      );
    }
  }

  @override
  void dispose() {
    // MP3 decoder has no persistent state or native resources to clean up
    // The native bindings handle their own cleanup
  }
}
