import 'dart:io';

import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/utils/streaming_memory_manager.dart';
import 'audio_decoder.dart';

/// FLAC audio decoder using dr_flac library
class FLACDecoder implements AudioDecoder {
  bool _disposed = false;

  @override
  Future<AudioData> decode(String filePath) async {
    _checkDisposed();

    try {
      // Check file size and memory requirements
      final fileSize = await StreamingMemoryManager.getFileSize(filePath);

      // Check if we should use streaming instead
      if (StreamingMemoryManager.shouldUseStreaming(fileSize, AudioFormat.flac)) {
        final qualityReduction = StreamingMemoryManager.suggestQualityReduction(fileSize, AudioFormat.flac);
        if (qualityReduction['shouldReduce'] == true) {
          throw MemoryException('File too large for direct decoding', 'Consider using streaming decode. ${qualityReduction['reason']}');
        }
      }

      // Read the entire file
      final file = File(filePath);
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

      // Get optimal chunk size based on file size and memory constraints
      final fileSize = await StreamingMemoryManager.getFileSize(filePath);
      final optimalChunkSize = StreamingMemoryManager.calculateOptimalChunkSize(fileSize, AudioFormat.flac);

      // For FLAC, we decode the entire file first due to the compressed nature
      // Then we can stream the decoded audio data in chunks
      final audioData = await decode(filePath);

      // Stream the decoded samples in chunks
      final samples = audioData.samples;
      int currentIndex = 0;

      while (currentIndex < samples.length) {
        // Check memory pressure before each chunk
        StreamingMemoryManager.checkMemoryPressure();

        final endIndex = (currentIndex + optimalChunkSize).clamp(0, samples.length);
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
