import 'dart:typed_data';
import '../models/audio_data.dart';
import '../native/native_audio_bindings.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// WAV audio decoder - pure bytes-to-samples transformation.
///
/// This decoder is stateless and handles NO file I/O.
/// It simply transforms encoded WAV bytes into decoded PCM samples.
///
/// For WAV format, the native layer (FFmpeg) handles all the parsing,
/// so this is primarily a thin wrapper around the native bindings.
class WAVDecoder implements AudioDecoder {
  @override
  AudioFormat get format => AudioFormat.wav;

  @override
  AudioData decode(Uint8List data) {
    try {
      // Use native bindings to decode the WAV data
      final audioData = NativeAudioBindings.decodeAudio(data, AudioFormat.wav);
      return audioData;
    } catch (e) {
      throw DecodingException(
        'Failed to decode WAV data',
        'Error decoding WAV: $e',
      );
    }
  }

  @override
  void dispose() {
    // WAV decoder has no persistent state or native resources to clean up
    // The native bindings handle their own cleanup
  }
}
