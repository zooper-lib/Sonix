import 'dart:io';
import 'dart:typed_data';

import '../models/audio_data.dart';
import '../exceptions/sonix_exceptions.dart';
import '../native/native_audio_bindings.dart';
import 'audio_decoder.dart';

/// FLAC audio decoder using dr_flac library
class FLACDecoder implements AudioDecoder {
  bool _disposed = false;
  static const int _chunkSize = 64 * 1024; // 64KB chunks for streaming

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
        throw DecodingException('File is empty', 'Cannot decode empty FLAC file: $filePath');
      }

      // Use native bindings to decode
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.flac);
      return audioData;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode FLAC file', 'Error decoding $filePath: $e');
    }
  }

  @override
  Stream<AudioChunk> decodeStream(String filePath) async* {
    _checkDisposed();

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }

      // FLAC supports streaming decode, but for simplicity we'll decode and stream results
      final audioData = await decode(filePath);

      // Stream the decoded samples in chunks
      final samples = audioData.samples;
      int currentIndex = 0;

      while (currentIndex < samples.length) {
        final endIndex = (currentIndex + _chunkSize).clamp(0, samples.length);
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
      throw DecodingException('Failed to stream FLAC file', 'Error streaming $filePath: $e');
    }
  }

  @override
  Future<AudioMetadata> getMetadata(String filePath) async {
    _checkDisposed();

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }

      final fileSize = await file.length();

      // FLAC files contain metadata blocks that could be parsed for detailed info
      // This is a simplified implementation
      return AudioMetadata(format: 'flac', fileSize: fileSize);
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to get FLAC metadata', 'Error reading metadata from $filePath: $e');
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
      throw StateError('FLACDecoder has been disposed');
    }
  }
}
