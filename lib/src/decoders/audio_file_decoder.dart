import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../exceptions/sonix_exceptions.dart';
import '../models/audio_data.dart';
import '../native/sonix_bindings.dart';
import 'audio_decoder.dart';
import 'audio_decoder_factory.dart';
import 'audio_format_service.dart';

/// Abstract interface for file-level audio decoding.
///
/// Unlike [AudioDecoder] which handles raw bytes-to-samples transformation,
/// this interface handles file I/O and orchestrates the decoding process.
abstract class AudioFileDecoder {
  /// Decode an audio file and return the audio data.
  ///
  /// [filePath] - Path to the audio file to decode
  /// Returns [AudioData] containing PCM samples and metadata.
  ///
  /// Throws [FileSystemException] if the file cannot be read.
  /// Throws [DecodingException] if the file cannot be decoded.
  /// Throws [UnsupportedError] if the format is not supported.
  Future<AudioData> decode(String filePath);

  /// Release any resources held by this decoder.
  void dispose();
}

/// Simple file decoder that reads the entire file and decodes it at once.
///
/// This is suitable for:
/// - Small to medium-sized files that fit in memory
/// - Cases where you need all audio data before processing
/// - Simpler use cases without streaming requirements
///
/// For large files or progressive processing, use [StreamingAudioFileDecoder].
class SimpleAudioFileDecoder implements AudioFileDecoder {
  AudioDecoder? _decoder;

  @override
  Future<AudioData> decode(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final format = AudioFormatService.detectFromFilePath(filePath);
    if (format == AudioFormat.unknown) {
      throw UnsupportedError('Unsupported audio format: $filePath');
    }

    // Create the appropriate decoder for this format
    _decoder = AudioDecoderFactory.createDecoderFromFormat(format);

    try {
      // Read entire file into memory
      final bytes = await file.readAsBytes();

      // Decode all bytes at once
      return _decoder!.decode(bytes);
    } finally {
      _decoder?.dispose();
      _decoder = null;
    }
  }

  @override
  void dispose() {
    _decoder?.dispose();
    _decoder = null;
  }
}

/// Streaming file decoder that reads and decodes files in chunks.
///
/// This is suitable for:
/// - Large files that shouldn't be loaded entirely into memory
/// - Progressive/real-time waveform updates
/// - Memory-constrained environments
///
/// Uses the native FFmpeg chunked decoder for format-independent streaming decoding.
/// The native decoder reads the file internally and processes it in chunks of
/// approximately 100 packets at a time, which provides memory efficiency for large files.
class StreamingAudioFileDecoder implements AudioFileDecoder {
  ffi.Pointer<SonixChunkedDecoder>? _nativeDecoder;

  /// Create a streaming file decoder.
  StreamingAudioFileDecoder();

  @override
  Future<AudioData> decode(String filePath) async {
    // For the accumulated result, collect all chunks and combine
    final chunks = await decodeStreaming(filePath).toList();

    if (chunks.isEmpty) {
      throw StateError('No audio data decoded from file: $filePath');
    }

    if (chunks.length == 1) {
      return chunks.first;
    }

    return _combineAudioChunks(chunks);
  }

  /// Decode a file progressively, yielding audio data chunks.
  ///
  /// This allows processing audio data as it's read, without waiting
  /// for the entire file to be decoded.
  ///
  /// [filePath] - Path to the audio file to decode
  /// Returns a [Stream] of [AudioData] chunks.
  ///
  /// Example:
  /// ```dart
  /// final decoder = StreamingAudioFileDecoder();
  /// await for (final chunk in decoder.decodeStreaming('large.mp3')) {
  ///   // Process each chunk progressively
  ///   waveformBuilder.addChunk(chunk);
  /// }
  /// ```
  Stream<AudioData> decodeStreaming(String filePath) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final format = AudioFormatService.detectFromFilePath(filePath);
    if (format == AudioFormat.unknown) {
      throw UnsupportedError('Unsupported audio format: $filePath');
    }

    // Convert format to native code
    final formatCode = _formatToNativeCode(format);

    // Convert file path to native string
    final filePathPtr = filePath.toNativeUtf8().cast<ffi.Char>();

    try {
      // Initialize native chunked decoder
      _nativeDecoder = SonixNativeBindings.initChunkedDecoder(formatCode, filePathPtr);

      if (_nativeDecoder == null || _nativeDecoder == ffi.nullptr) {
        final errorPtr = SonixNativeBindings.getErrorMessage();
        final errorMsg = errorPtr != ffi.nullptr ? errorPtr.cast<Utf8>().toDartString() : 'Unknown error';
        throw DecodingException('Failed to initialize chunked decoder', 'Error: $errorMsg');
      }

      // Process file in chunks using the native decoder
      // The native decoder reads the file internally using FFmpeg
      // Each call to processFileChunk reads up to 100 packets
      var chunkIndex = 0;
      var isFinalChunk = false;

      while (!isFinalChunk) {
        // Create native file chunk structure with current chunk index
        final nativeChunk = calloc<SonixFileChunk>();
        nativeChunk.ref.chunk_index = chunkIndex;
        // Note: start_byte and end_byte are not used by the native decoder
        // FFmpeg reads the file sequentially internally

        try {
          // Process next chunk through native decoder
          final result = SonixNativeBindings.processFileChunk(_nativeDecoder!, nativeChunk);

          if (result == ffi.nullptr) {
            final errorPtr = SonixNativeBindings.getErrorMessage();
            final errorMsg = errorPtr != ffi.nullptr ? errorPtr.cast<Utf8>().toDartString() : 'Unknown error';
            throw DecodingException('Failed to process chunk $chunkIndex', 'Error: $errorMsg');
          }

          try {
            // Check if processing was successful
            if (result.ref.success == 0) {
              final errorMsg = result.ref.error_message != ffi.nullptr ? result.ref.error_message.cast<Utf8>().toDartString() : 'Unknown error';
              throw DecodingException('Chunk processing failed', 'Error: $errorMsg');
            }

            // Check if this is the final chunk
            isFinalChunk = result.ref.is_final_chunk == 1;

            // Extract audio data from result
            final audioDataPtr = result.ref.audio_data;
            if (audioDataPtr != ffi.nullptr) {
              final audioData = _extractAudioData(audioDataPtr);
              yield audioData;
            }

            chunkIndex++;
          } finally {
            // Free the chunk result
            SonixNativeBindings.freeChunkResult(result);
          }
        } finally {
          // Free the native chunk structure
          calloc.free(nativeChunk);
        }
      }
    } finally {
      // Cleanup native decoder
      if (_nativeDecoder != null && _nativeDecoder != ffi.nullptr) {
        SonixNativeBindings.cleanupChunkedDecoder(_nativeDecoder!);
        _nativeDecoder = null;
      }
      // Free the file path string
      calloc.free(filePathPtr);
    }
  }

  @override
  void dispose() {
    if (_nativeDecoder != null && _nativeDecoder != ffi.nullptr) {
      SonixNativeBindings.cleanupChunkedDecoder(_nativeDecoder!);
      _nativeDecoder = null;
    }
  }

  /// Convert AudioFormat to native format code
  int _formatToNativeCode(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        return SONIX_FORMAT_MP3;
      case AudioFormat.wav:
        return SONIX_FORMAT_WAV;
      case AudioFormat.flac:
        return SONIX_FORMAT_FLAC;
      case AudioFormat.ogg:
        return SONIX_FORMAT_OGG;
      case AudioFormat.opus:
        return SONIX_FORMAT_OPUS;
      case AudioFormat.mp4:
        return SONIX_FORMAT_MP4;
      case AudioFormat.unknown:
        return SONIX_FORMAT_UNKNOWN;
    }
  }

  /// Extract AudioData from native pointer
  AudioData _extractAudioData(ffi.Pointer<SonixAudioData> ptr) {
    final sampleCount = ptr.ref.sample_count;
    final sampleRate = ptr.ref.sample_rate;
    final channels = ptr.ref.channels;
    final durationMs = ptr.ref.duration_ms;

    // Copy samples from native memory
    final samples = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = ptr.ref.samples[i];
    }

    return AudioData(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
      duration: Duration(milliseconds: durationMs),
    );
  }

  /// Combine multiple AudioData chunks into a single AudioData.
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
        throw StateError(
          'Cannot combine chunks with different sample rates: '
          '$sampleRate vs ${chunk.sampleRate}',
        );
      }
      if (chunk.channels != channels) {
        throw StateError(
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
