import 'dart:io';

import '../native/native_audio_bindings.dart';
import '../models/audio_data.dart';
import '../exceptions/sonix_exceptions.dart';
import 'audio_decoder.dart';

/// AAC audio decoder using the native library
/// Supports standalone AAC files with ADTS headers
class AACDecoder implements AudioDecoder {
  @override
  Future<AudioData> decode(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw FileNotFoundException(filePath);
    }

    try {
      // Read file data
      final fileBytes = await File(filePath).readAsBytes();
      
      // Call native library to decode AAC
      final result = NativeAudioBindings.decodeAudio(
        fileBytes, 
        AudioFormat.aac,
      );

      return result;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException(
        'Failed to decode AAC file: ${e.toString()}',
      );
    }
  }

  @override
  void dispose() {
    // No resources to dispose for native AAC decoder
  }
}