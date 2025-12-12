import 'dart:io';
import 'dart:math' as math;
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'audio_decoder.dart';
import 'audio_decoder_factory.dart';
import 'chunked_audio_decoder.dart';
import '../models/audio_data.dart';
import '../exceptions/sonix_exceptions.dart';
import '../native/native_audio_bindings.dart';
import '../native/sonix_bindings.dart';
import '../utils/sonix_logger.dart';

/// A decorator that wraps an [AudioDecoder] to provide memory-safe decoding.
///
/// This decorator automatically switches between direct decoding and chunked
/// processing based on file size, preventing memory exceptions for large files.
///
/// ## Usage
///
/// ```dart
/// final decoder = MemorySafeDecoder(MP4Decoder());
/// final audioData = await decoder.decode('large_file.mp4');
/// decoder.dispose();
/// ```
///
/// ## How it works
///
/// When [decode] is called:
/// 1. If the file size is below [fileSizeThreshold], it delegates to the
///    wrapped decoder's normal decode method.
/// 2. If the file size exceeds the threshold AND the wrapped decoder supports
///    chunked processing, it uses selective decoding to sample the file
///    at multiple time positions without loading it entirely into memory.
/// 3. If chunked processing isn't supported, it falls back to direct decoding
///    (which may throw a [MemoryException] for very large files).
class MemorySafeDecoder implements AudioDecoder {
  /// The wrapped decoder that handles actual decoding.
  final AudioDecoder _innerDecoder;

  /// File size threshold for switching to chunked processing.
  ///
  /// Files larger than this will use chunked processing if available.
  /// Default is 5MB.
  final int fileSizeThreshold;

  /// Resolution for waveform sampling when using chunked processing.
  ///
  /// This determines how many sample points are extracted from the file.
  /// Default is 1000.
  final int samplingResolution;

  /// Whether this decorator has been disposed.
  bool _disposed = false;

  /// Creates a memory-safe decoder that wraps the given decoder.
  ///
  /// [innerDecoder] - The decoder to wrap.
  /// [fileSizeThreshold] - File size in bytes above which chunked processing
  ///   is used. Default is 5MB.
  /// [samplingResolution] - Number of sample points for chunked processing.
  ///   Default is 1000.
  MemorySafeDecoder(
    this._innerDecoder, {
    this.fileSizeThreshold = 5 * 1024 * 1024, // 5MB
    this.samplingResolution = 1000,
  });

  /// Whether the wrapped decoder supports chunked processing.
  bool get supportsChunkedProcessing => _innerDecoder is ChunkedAudioDecoder;

  @override
  Future<AudioData> decode(String filePath) async {
    _checkDisposed();

    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileAccessException(filePath, 'File does not exist');
    }

    final fileSize = await file.length();

    // Use chunked processing for large files if supported
    if (fileSize > fileSizeThreshold && supportsChunkedProcessing) {
      SonixLogger.debug('Using chunked processing for large file ($fileSize bytes)');
      return _decodeWithChunkedProcessing(filePath);
    }

    // Use direct decoding for smaller files or when chunked processing isn't available
    SonixLogger.debug('Using direct decoding for file ($fileSize bytes)');
    return _innerDecoder.decode(filePath);
  }

  @override
  void dispose() {
    if (!_disposed) {
      _innerDecoder.dispose();
      _disposed = false;
    }
  }

  /// Check if the decoder has been disposed.
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('MemorySafeDecoder has been disposed');
    }
  }

  /// Decode a large file using chunked/selective processing.
  ///
  /// This method seeks to multiple time positions in the file and extracts
  /// audio samples at each position, creating a representative waveform
  /// without loading the entire file into memory.
  Future<AudioData> _decodeWithChunkedProcessing(String filePath) async {
    final format = AudioDecoderFactory.detectFormat(filePath);
    final nativeFormatCode = NativeAudioBindings.formatEnumToCode(format);

    // Initialize native chunked decoder
    final filePathNative = filePath.toNativeUtf8();
    final nativeDecoder = SonixNativeBindings.initChunkedDecoder(nativeFormatCode, filePathNative.cast());

    if (nativeDecoder.address == 0) {
      malloc.free(filePathNative);
      throw DecodingException('Failed to initialize native chunked decoder', 'Could not initialize native decoder for $filePath');
    }

    try {
      return await _processChunkedDecoding(nativeDecoder, filePath, format);
    } finally {
      SonixNativeBindings.cleanupChunkedDecoder(nativeDecoder);
      malloc.free(filePathNative);
    }
  }

  /// Process the file using the native chunked decoder.
  Future<AudioData> _processChunkedDecoding(ffi.Pointer<SonixChunkedDecoder> nativeDecoder, String filePath, AudioFormat format) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // Get media info from native decoder
    int sampleRate = 44100;
    int channels = 2;
    Duration actualDuration = const Duration(seconds: 180);

    final durPtr = malloc<ffi.Uint32>();
    final srPtr = malloc<ffi.Uint32>();
    final chPtr = malloc<ffi.Uint32>();

    try {
      final infoRes = SonixNativeBindings.getDecoderMediaInfo(nativeDecoder, durPtr, srPtr, chPtr);

      if (infoRes == 0) {
        final durMs = durPtr.value;
        if (durMs > 0) actualDuration = Duration(milliseconds: durMs);
        if (srPtr.value > 0) sampleRate = srPtr.value;
        if (chPtr.value > 0) channels = chPtr.value;
      } else {
        // Estimate duration from file size and typical bitrate
        final estimatedSeconds = (fileSize * 8) / format.typicalBitrate;
        actualDuration = Duration(milliseconds: (estimatedSeconds * 1000).round());
      }
    } finally {
      malloc.free(durPtr);
      malloc.free(srPtr);
      malloc.free(chPtr);
    }

    // Sample the file at multiple time positions
    final amplitudes = <double>[];
    final durationMs = math.max(0, actualDuration.inMilliseconds - 5);

    for (int i = 0; i < samplingResolution; i++) {
      final amplitude = await _sampleAtPosition(nativeDecoder, i, samplingResolution, durationMs);
      amplitudes.add(amplitude);
    }

    return AudioData(samples: amplitudes, sampleRate: sampleRate, channels: channels, duration: actualDuration);
  }

  /// Sample audio amplitude at a specific position in the file.
  Future<double> _sampleAtPosition(ffi.Pointer<SonixChunkedDecoder> nativeDecoder, int index, int totalPoints, int durationMs) async {
    try {
      final progress = totalPoints <= 1 ? 0.5 : index / (totalPoints - 1);
      int timePositionMs = (durationMs * progress).round();
      if (index == totalPoints - 1) {
        timePositionMs = durationMs;
      }

      final seekResult = SonixNativeBindings.seekToTime(nativeDecoder, timePositionMs);

      if (seekResult != 0) {
        return 0.0;
      }

      final chunkPtr = malloc<SonixFileChunk>();
      chunkPtr.ref.chunk_index = index;
      chunkPtr.ref.start_byte = 0;
      chunkPtr.ref.end_byte = 0;

      try {
        final result = SonixNativeBindings.processFileChunk(nativeDecoder, chunkPtr);

        if (result.address == 0) {
          return 0.0;
        }

        try {
          final resultData = result.ref;
          if (resultData.success != 1 || resultData.audio_data.address == 0) {
            return 0.0;
          }

          final audioData = resultData.audio_data.ref;
          final sampleCount = audioData.sample_count;

          if (sampleCount <= 0 || audioData.samples.address == 0) {
            return 0.0;
          }

          final samples = audioData.samples.asTypedList(sampleCount);
          return _calculateRmsAmplitude(samples, sampleCount);
        } finally {
          SonixNativeBindings.freeChunkResult(result);
        }
      } finally {
        malloc.free(chunkPtr);
      }
    } catch (e) {
      SonixLogger.debug('Failed to decode at position $index: $e');
      return 0.0;
    }
  }

  /// Calculate RMS amplitude from samples.
  double _calculateRmsAmplitude(List<double> samples, int sampleCount) {
    double sum = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final sample = samples[i];
      sum += sample * sample;
    }
    return math.sqrt(sum / sampleCount);
  }
}
