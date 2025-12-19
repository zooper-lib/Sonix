import 'dart:async';

import '../models/audio_data.dart';
import '../decoders/audio_file_decoder.dart';
import '../utils/audio_file_validator.dart';

/// Processes audio files and returns decoded audio data.
///
/// This class orchestrates file decoding by selecting the appropriate
/// strategy based on file size:
/// - Small files: Uses [SimpleAudioFileDecoder] for full load
/// - Large files: Uses [StreamingAudioFileDecoder] for chunked processing
///
/// Callers don't need to know about memory limits or chunking.
/// The processor automatically selects the best strategy.
class AudioFileProcessor {
  /// Size threshold for switching to chunked processing.
  /// Files larger than this use streaming to avoid memory issues.
  static const int defaultChunkThreshold = 50 * 1024 * 1024; // 50MB

  final int chunkThreshold;

  /// Create an AudioFileProcessor with optional custom thresholds.
  ///
  /// [chunkThreshold] - Files larger than this will use streaming (default: 50MB)
  AudioFileProcessor({this.chunkThreshold = defaultChunkThreshold});

  /// Process an audio file and return decoded audio data.
  ///
  /// Automatically selects the appropriate strategy based on file size:
  /// - Small files: Load entirely into memory and decode in one shot
  /// - Large files: Stream in chunks and accumulate results
  ///
  /// The caller never needs to worry about memory limits or exceptions.
  ///
  /// [filePath] - Path to the audio file to process
  /// Returns [AudioData] containing all decoded samples and metadata.
  ///
  /// Throws [FileSystemException] if the file cannot be read.
  /// Throws [DecodingException] if the file cannot be decoded.
  /// Throws [UnsupportedError] if the format is not supported.
  Future<AudioData> process(String filePath) async {
    // Validate file and get size in one call
    final fileSize = await AudioFileValidator.validateAndGetSize(filePath);

    if (fileSize <= chunkThreshold) {
      // SMALL FILE: Use simple decoder
      final decoder = SimpleAudioFileDecoder();
      try {
        return await decoder.decode(filePath);
      } finally {
        decoder.dispose();
      }
    } else {
      // LARGE FILE: Use streaming decoder
      // The native FFmpeg decoder handles chunking internally (100 packets per chunk)
      final decoder = StreamingAudioFileDecoder();
      try {
        return await decoder.decode(filePath);
      } finally {
        decoder.dispose();
      }
    }
  }

  /// Process an audio file using streaming (for very large files).
  ///
  /// Returns a stream of [AudioData] chunks for progressive processing.
  /// This is useful for:
  /// - Real-time waveform updates as file loads
  /// - Processing files too large to fit in memory
  /// - Early preview of long audio files
  ///
  /// [filePath] - Path to the audio file to process
  /// Returns a [Stream] of [AudioData] chunks.
  ///
  /// Example usage:
  /// ```dart
  /// await for (final chunk in processor.processStreaming('large.mp3')) {
  ///   // Update waveform UI with chunk
  ///   waveform.addChunk(chunk);
  /// }
  /// ```
  ///
  /// Throws [FileSystemException] if the file cannot be read.
  /// Throws [DecodingException] if chunks cannot be decoded.
  /// Throws [UnsupportedError] if the format doesn't support streaming.
  Stream<AudioData> processStreaming(String filePath) {
    final decoder = StreamingAudioFileDecoder();
    return decoder.decodeStreaming(filePath);
  }
}
