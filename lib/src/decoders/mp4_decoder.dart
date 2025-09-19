import 'dart:io';

import '../native/native_audio_bindings.dart';
import '../models/audio_data.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// MP4/AAC audio decoder using the native library
class MP4Decoder implements AudioDecoder {
  @override
  Future<AudioData> decode(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw FileNotFoundException(filePath);
    }

    try {
      // Read file data
      final fileBytes = await File(filePath).readAsBytes();
      
      // Call native library to decode
      final result = NativeAudioBindings.decodeAudio(
        fileBytes, 
        AudioFormat.mp4,
      );

      return result;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException(
        'Failed to decode MP4 file: $e',
      );
    }
  }

  @override
  void dispose() {
    // No resources to clean up for MP4 decoder
  }
}