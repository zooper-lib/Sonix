import 'dart:io';

import '../models/audio_data.dart';
import '../exceptions/sonix_exceptions.dart';
import '../native/native_audio_bindings.dart';
import '../utils/streaming_memory_manager.dart';
import 'audio_decoder.dart';

/// MP3 audio decoder using minimp3 library
class MP3Decoder implements AudioDecoder {
  bool _disposed = false;
  static const int _chunkSize = 64 * 1024; // 64KB chunks for streaming

  @override
  Future<AudioData> decode(String filePath) async {
    _checkDisposed();

    try {
      // Check file size and memory requirements
      final fileSize = await StreamingMemoryManager.getFileSize(filePath);

      // Check if we should use streaming instead
      if (StreamingMemoryManager.shouldUseStreaming(fileSize, AudioFormat.mp3)) {
        final qualityReduction = StreamingMemoryManager.suggestQualityReduction(fileSize, AudioFormat.mp3);
        if (qualityReduction['shouldReduce'] == true) {
          throw MemoryException('File too large for direct decoding', 'Consider using streaming decode. ${qualityReduction['reason']}');
        }
      }

      // Read the entire file
      final file = File(filePath);
      final fileData = await file.readAsBytes();
      if (fileData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty MP3 file: $filePath');
      }

      // Use native bindings to decode
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.mp3);
      return audioData;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode MP3 file', 'Error decoding $filePath: $e');
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
      final optimalChunkSize = StreamingMemoryManager.calculateOptimalChunkSize(fileSize, AudioFormat.mp3);

      // For MP3, we need to decode the entire file first due to the nature of MP3 format
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
      throw DecodingException('Failed to stream MP3 file', 'Error streaming $filePath: $e');
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

      // For basic metadata, we can estimate bitrate from file size and duration
      // This is a simplified implementation - full ID3 parsing would be more complex
      return AudioMetadata(
        format: 'mp3',
        fileSize: fileSize,
        // Additional metadata would require ID3 tag parsing
      );
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to get MP3 metadata', 'Error reading metadata from $filePath: $e');
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
      throw StateError('MP3Decoder has been disposed');
    }
  }
}
