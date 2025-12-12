import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

import '../models/audio_data.dart';
import '../decoders/audio_decoder.dart';
import '../decoders/audio_decoder_factory.dart';

/// Processes audio files and returns decoded audio data.
///
/// This class orchestrates:
/// - File format detection
/// - File size checking
/// - Strategy selection (full load vs chunked)
/// - Decoder instantiation and lifecycle
///
/// Callers don't need to know about memory limits or chunking.
/// The processor automatically selects the best strategy based on file size.
class AudioFileProcessor {
  /// Size threshold for switching to chunked processing.
  /// Files larger than this use streaming to avoid memory issues.
  static const int defaultChunkThreshold = 50 * 1024 * 1024; // 50MB

  /// Size of each chunk when streaming large files.
  static const int defaultChunkSize = 10 * 1024 * 1024; // 10MB

  final int chunkThreshold;
  final int chunkSize;

  /// Create an AudioFileProcessor with optional custom thresholds.
  ///
  /// [chunkThreshold] - Files larger than this will use streaming (default: 50MB)
  /// [chunkSize] - Size of each chunk when streaming (default: 10MB)
  AudioFileProcessor({this.chunkThreshold = defaultChunkThreshold, this.chunkSize = defaultChunkSize});

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
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileSize = await file.length();
    final format = AudioDecoderFactory.detectFormat(filePath);

    if (format == AudioFormat.unknown) {
      throw UnsupportedError('Unsupported audio format: $filePath');
    }

    // Create decoder (pure bytes-to-samples)
    final decoder = AudioDecoderFactory.createDecoder(format);

    try {
      // Check if file is small enough for full load
      if (fileSize <= chunkThreshold) {
        // SMALL FILE: Load entirely and decode in one shot
        final bytes = await file.readAsBytes();
        return decoder.decode(bytes);
      } else {
        // LARGE FILE: For now, still load fully but decode with V2
        // TODO: Implement true chunked streaming in future iteration
        final bytes = await file.readAsBytes();
        return decoder.decode(bytes);
      }
    } finally {
      decoder.dispose();
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
  Stream<AudioData> processStreaming(String filePath) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final format = AudioDecoderFactory.detectFormat(filePath);
    if (format == AudioFormat.unknown) {
      throw UnsupportedError('Unsupported audio format: $filePath');
    }

    // Use decoder for streaming
    final decoder = AudioDecoderFactory.createDecoder(format);
    try {
      // For now, read full file and yield as single chunk
      // TODO: Implement true chunked streaming in future iteration
      final bytes = await file.readAsBytes();
      final audioData = decoder.decode(bytes);
      yield audioData;
    } finally {
      decoder.dispose();
    }
  }

  /// Process an audio file and accumulate all chunks into a single AudioData.
  ///
  /// This is a convenience method that uses [processStreaming] internally
  /// but accumulates all chunks into one result.
  ///
  /// [filePath] - Path to the audio file to process
  /// Returns [AudioData] containing all decoded samples.
  Future<AudioData> processStreamingAccumulated(String filePath) async {
    final chunks = await processStreaming(filePath).toList();

    if (chunks.isEmpty) {
      throw DecodingException('No data decoded from file: $filePath');
    }

    if (chunks.length == 1) {
      return chunks.first;
    }

    // Combine multiple chunks into one AudioData
    return _combineAudioChunks(chunks);
  }

  /// Combine multiple AudioData chunks into a single AudioData.
  ///
  /// All chunks must have the same sample rate and channel count.
  AudioData _combineAudioChunks(List<AudioData> chunks) {
    if (chunks.isEmpty) {
      throw ArgumentError('Cannot combine empty list of chunks');
    }

    final first = chunks.first;
    final sampleRate = first.sampleRate;
    final channels = first.channels;

    // Verify all chunks are compatible
    for (final chunk in chunks.skip(1)) {
      if (chunk.sampleRate != sampleRate) {
        throw DecodingException(
          'Cannot combine chunks with different sample rates: '
          '$sampleRate vs ${chunk.sampleRate}',
        );
      }
      if (chunk.channels != channels) {
        throw DecodingException(
          'Cannot combine chunks with different channel counts: '
          '$channels vs ${chunk.channels}',
        );
      }
    }

    // Calculate total sample count
    final totalSamples = chunks.fold<int>(0, (sum, chunk) => sum + chunk.samples.length);

    // Combine all samples into one buffer
    final combinedSamples = Float32List(totalSamples);
    var offset = 0;
    for (final chunk in chunks) {
      combinedSamples.setRange(offset, offset + chunk.samples.length, chunk.samples);
      offset += chunk.samples.length;
    }

    return AudioData(
      samples: combinedSamples,
      sampleRate: sampleRate,
      channels: channels,
      duration: Duration(microseconds: (totalSamples / sampleRate * 1000000 / channels).round()),
    );
  }
}
