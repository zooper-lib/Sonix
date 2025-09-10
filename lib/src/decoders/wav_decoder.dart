import 'dart:io';

import '../models/audio_data.dart';
import '../exceptions/sonix_exceptions.dart';
import '../native/native_audio_bindings.dart';
import 'audio_decoder.dart';

/// WAV audio decoder using dr_wav library
class WAVDecoder implements AudioDecoder {
  bool _disposed = false;

  @override
  Future<AudioData> decode(String filePath) async {
    _checkDisposed();

    try {
      // Read the entire file
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }

      final fileData = await file.readAsBytes();
      if (fileData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty WAV file: $filePath');
      }

      // Use native bindings to decode
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.wav);
      return audioData;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode WAV file', 'Error decoding $filePath: $e');
    }
  }

  @override
  Stream<AudioChunk> decodeStream(String filePath) async* {
    _checkDisposed();

    try {
      // For WAV, we decode the entire file first then stream the decoded audio data in chunks
      // WAV files with dr_wav don't support true streaming decode at the native level
      final audioData = await decode(filePath);

      // Stream the decoded samples in chunks of ~1 second worth of audio
      final int chunkSize = (audioData.sampleRate * audioData.channels); // 1 second worth of samples

      final samples = audioData.samples;
      int currentIndex = 0;

      while (currentIndex < samples.length) {
        final endIndex = (currentIndex + chunkSize).clamp(0, samples.length);
        final chunkSamples = samples.sublist(currentIndex, endIndex);
        final isLast = endIndex >= samples.length;

        yield AudioChunk(samples: chunkSamples, startSample: currentIndex, isLast: isLast);

        currentIndex = endIndex;

        // Add a small delay to prevent blocking the UI thread
        if (!isLast) {
          await Future.delayed(const Duration(microseconds: 100));
        }
      }
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to stream WAV file', 'Error streaming $filePath: $e');
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      // Clean up any native resources if needed
      _disposed = true;
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('WAVDecoder has been disposed');
    }
  }
}
