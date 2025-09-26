import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import '../models/audio_data.dart';
import '../models/file_chunk.dart';
import '../models/chunked_processing_models.dart';
import '../exceptions/sonix_exceptions.dart';
import '../native/native_audio_bindings.dart';
import 'audio_decoder.dart';
import 'chunked_audio_decoder.dart';

/// MP3 audio decoder using FFMPEG backend when available, falls back to minimp3 library
/// Maintains full chunked processing support with both backends
class MP3Decoder implements ChunkedAudioDecoder {
  bool _disposed = false;
  bool _initialized = false;
  String? _currentFilePath;
  Duration _currentPosition = Duration.zero;
  int _sampleRate = 0;
  int _channels = 0;
  Duration? _totalDuration;

  // MP3-specific state for chunked processing
  final List<int> _frameOffsets = [];
  final List<Duration> _frameTimestamps = [];
  // Note: frame index retained for potential future accurate seeking; currently unused with buffered decoding

  // Buffered decoding for chunked streaming
  BytesBuilder? _buffer;
  int _bufferSize = 0;
  static const int _decodeThreshold = 256 * 1024; // decode when we have at least 256KB
  static const int _maxRetainedBuffer = 512 * 1024; // cap retained buffer between decodes
  int _lastDecodedSampleCount = 0;

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
        throw DecodingException('File is empty', 'Cannot decode empty MP3 file: $filePath');
      }

      // Check if file would exceed memory limits
      if (NativeAudioBindings.wouldExceedMemoryLimits(fileData.length, AudioFormat.mp3)) {
        throw MemoryException('File too large for direct decoding', 'File size exceeds memory limits. Consider using chunked processing instead.');
      }

      // Use native bindings to decode (automatically uses FFMPEG when available)
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

  @override
  Future<void> initializeChunkedDecoding(String filePath, {int chunkSize = 10 * 1024 * 1024, Duration? seekPosition}) async {
    _checkDisposed();

    try {
      _currentFilePath = filePath;

      // Verify file exists and get file size
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }

      final fileSize = await file.length();

      // Read only first 128KB for metadata extraction instead of entire file
      final headerSize = math.min(128 * 1024, fileSize); // 128KB or file size, whichever is smaller
      final headerData = await file.openRead(0, headerSize).expand((chunk) => chunk).toList();

      if (headerData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty MP3 file: $filePath');
      }

      // Try to extract basic metadata from header only
      try {
        final headerBytes = Uint8List.fromList(headerData);
        final headerAudioData = NativeAudioBindings.decodeAudio(headerBytes, AudioFormat.mp3);
        _sampleRate = headerAudioData.sampleRate;
        _channels = headerAudioData.channels;
        // Estimate total duration based on file size and detected bitrate
        _totalDuration = _estimateDurationFromFileSize(fileSize, _sampleRate, _channels);
      } catch (e) {
        // If header decoding fails, use conservative defaults
        _sampleRate = 44100;
        _channels = 2;
        _totalDuration = _estimateDurationFromFileSize(fileSize, _sampleRate, _channels);
      }

      // Build frame index for seeking (use header data instead of full file)
      await _buildFrameIndex(Uint8List.fromList(headerData));

      // Seek to initial position if specified
      if (seekPosition != null) {
        await seekToTime(seekPosition);
      }

      // Initialize buffered decoding state
      _buffer = BytesBuilder(copy: false);
      _bufferSize = 0;
      _lastDecodedSampleCount = 0;

      _initialized = true;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to initialize MP3 chunked decoding', 'Error initializing $filePath: $e');
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // For MP3, we need to maintain a small buffer for frame boundary handling,
      // but we should only decode the new chunk data, not the entire accumulated buffer
      _buffer ??= BytesBuilder(copy: false);

      // Append the new chunk data
      _buffer!.add(fileChunk.data);
      _bufferSize += fileChunk.data.length;

      // Try to decode the current chunk data directly
      final audioChunks = <AudioChunk>[];

      try {
        // Decode just the new chunk data, not the entire accumulated buffer
        final audioData = NativeAudioBindings.decodeAudio(fileChunk.data, AudioFormat.mp3);

        if (audioData.samples.isNotEmpty) {
          final startSample = (_currentPosition.inMicroseconds * _sampleRate * _channels) ~/ Duration.microsecondsPerSecond;

          audioChunks.add(AudioChunk(samples: audioData.samples, startSample: startSample, isLast: fileChunk.isLast));

          // Update position based on the decoded samples
          final sampleDuration = Duration(microseconds: (audioData.samples.length * Duration.microsecondsPerSecond) ~/ (_sampleRate * _channels));
          _currentPosition += sampleDuration;
        }

        // Clear the buffer since we successfully decoded this chunk
        _buffer = BytesBuilder(copy: false);
        _bufferSize = 0;
      } catch (e) {
        // If decoding fails (likely due to boundary/incomplete frames), keep buffering
        // Only try to decode the combined buffer if we have enough data or this is the last chunk
        final shouldTryBufferedDecode = _bufferSize >= _decodeThreshold || fileChunk.isLast;

        if (shouldTryBufferedDecode) {
          try {
            final combined = _buffer!.toBytes();
            final audioData = NativeAudioBindings.decodeAudio(combined, AudioFormat.mp3);

            if (audioData.samples.isNotEmpty) {
              // Emit only the new samples decoded since the last decode
              final totalSamples = audioData.samples.length;
              final newSamplesCount = totalSamples - _lastDecodedSampleCount;

              if (newSamplesCount > 0) {
                final newSamples = audioData.samples.sublist(_lastDecodedSampleCount);
                final startSample = (_currentPosition.inMicroseconds * _sampleRate * _channels) ~/ Duration.microsecondsPerSecond;

                audioChunks.add(AudioChunk(samples: newSamples, startSample: startSample, isLast: fileChunk.isLast));

                // Update position
                final sampleDuration = Duration(microseconds: (newSamplesCount * Duration.microsecondsPerSecond) ~/ (_sampleRate * _channels));
                _currentPosition += sampleDuration;

                // Update last decoded markers
                _lastDecodedSampleCount = totalSamples;
              }
            }

            // If this was the last chunk, clear the buffer
            if (fileChunk.isLast) {
              _buffer = BytesBuilder(copy: false);
              _bufferSize = 0;
            }
          } catch (bufferDecodeError) {
            // If buffered decode also fails, manage buffer size to prevent unbounded growth
            if (_bufferSize > _maxRetainedBuffer) {
              final combined = _buffer!.toBytes();
              final retainedSlice = combined.sublist(combined.length - _maxRetainedBuffer);
              _buffer = BytesBuilder(copy: false)..add(retainedSlice);
              _bufferSize = _maxRetainedBuffer;
            }
          }
        }
      }

      return audioChunks;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to process MP3 chunk', 'Error processing chunk: $e');
    }
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // Find the closest frame to the target position
      final targetMs = position.inMilliseconds;
      int closestFrameIndex = 0;
      int closestTimeDiff = (targetMs - _frameTimestamps[0].inMilliseconds).abs();

      for (int i = 1; i < _frameTimestamps.length; i++) {
        final timeDiff = (targetMs - _frameTimestamps[i].inMilliseconds).abs();
        if (timeDiff < closestTimeDiff) {
          closestTimeDiff = timeDiff;
          closestFrameIndex = i;
        }
      }

      // Frame indexing is not used in buffered decoding mode
      final actualPosition = _frameTimestamps[closestFrameIndex];
      final bytePosition = _frameOffsets[closestFrameIndex];
      _currentPosition = actualPosition;

      // MP3 seeking is approximate due to frame structure
      final isExact = closestTimeDiff < 50; // Consider exact if within 50ms
      final warning = isExact ? null : 'MP3 seeking is approximate due to frame boundaries';

      return SeekResult(actualPosition: actualPosition, bytePosition: bytePosition, isExact: isExact, warning: warning);
    } catch (e) {
      throw DecodingException('Failed to seek in MP3 file', 'Error seeking to $position: $e');
    }
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    // MP3 frames are typically 144-1728 bytes, so we want chunks that contain multiple frames
    if (fileSize < 1024 * 1024) {
      // < 1MB
      return ChunkSizeRecommendation(
        recommendedSize: (fileSize * 0.5).clamp(4096, 256 * 1024).round(), // 50% of file, 4KB-256KB
        minSize: 4096, // 4KB - enough for several MP3 frames
        maxSize: fileSize,
        reason: 'Small MP3 file - using 50% of file size to ensure frame boundaries',
        metadata: {'format': 'MP3', 'avgFrameSize': 417}, // Average MP3 frame size
      );
    } else if (fileSize < 50 * 1024 * 1024) {
      // < 50MB
      return ChunkSizeRecommendation(
        recommendedSize: 2 * 1024 * 1024, // 2MB
        minSize: 256 * 1024, // 256KB
        maxSize: 10 * 1024 * 1024, // 10MB
        reason: 'Medium MP3 file - using 2MB chunks for optimal frame processing',
        metadata: {'format': 'MP3', 'avgFrameSize': 417},
      );
    } else {
      // >= 50MB
      return ChunkSizeRecommendation(
        recommendedSize: 5 * 1024 * 1024, // 5MB
        minSize: 1024 * 1024, // 1MB
        maxSize: 20 * 1024 * 1024, // 20MB
        reason: 'Large MP3 file - using 5MB chunks for memory efficiency',
        metadata: {'format': 'MP3', 'avgFrameSize': 417},
      );
    }
  }

  @override
  bool get supportsEfficientSeeking => false; // MP3 seeking is approximate

  @override
  Duration get currentPosition {
    _checkDisposed();
    return _currentPosition;
  }

  @override
  Future<void> resetDecoderState() async {
    _checkDisposed();

    _currentPosition = Duration.zero;
    // Reset any frame-based state (unused in buffered mode)
    // Native decoder state would be reset here in a real implementation
  }

  @override
  Map<String, dynamic> getFormatMetadata() {
    _checkDisposed();
    return {
      'format': 'MP3',
      'backend': NativeAudioBindings.backendType,
      'sampleRate': _sampleRate,
      'channels': _channels,
      'duration': _totalDuration?.inMilliseconds,
      'frameCount': _frameOffsets.length,
      'supportsSeekTable': false,
      'avgFrameSize': 417, // Typical MP3 frame size
      'seekingAccuracy': 'approximate',
      'ffmpegAvailable': NativeAudioBindings.isFFMPEGAvailable,
    };
  }

  @override
  Future<Duration?> estimateDuration() async {
    if (_totalDuration != null) {
      return _totalDuration;
    }

    // If not initialized, try to get duration from file header
    if (_currentFilePath != null) {
      try {
        final file = File(_currentFilePath!);
        final fileData = await file.readAsBytes();
        final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.mp3);
        return audioData.duration;
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> cleanupChunkedProcessing() async {
    _initialized = false;
    _currentFilePath = null;
    _currentPosition = Duration.zero;
    _sampleRate = 0;
    _channels = 0;
    _totalDuration = null;
    _frameOffsets.clear();
    _frameTimestamps.clear();
    // Reset any frame-based state (unused in buffered mode)
    _buffer = null;
    _bufferSize = 0;
    _lastDecodedSampleCount = 0;
  }

  // Helper methods for MP3-specific processing

  Future<void> _buildFrameIndex(Uint8List fileData) async {
    _frameOffsets.clear();
    _frameTimestamps.clear();

    // Simplified frame detection - in real implementation would scan for MP3 sync words (0xFFE0+)
    // For now, we'll create a basic frame index based on estimated frame size
    const avgFrameSize = 417; // Typical MP3 frame size at 128kbps
    const samplesPerFrame = 1152; // MP3 frame contains 1152 samples

    int offset = 0;
    int frameIndex = 0;

    while (offset < fileData.length - avgFrameSize) {
      _frameOffsets.add(offset);

      // Calculate timestamp for this frame
      final timestamp = Duration(milliseconds: (frameIndex * samplesPerFrame * 1000 / _sampleRate).round());
      _frameTimestamps.add(timestamp);

      offset += avgFrameSize;
      frameIndex++;
    }
  }

  /// Estimate duration from file size and audio format parameters
  Duration _estimateDurationFromFileSize(int fileSize, int sampleRate, int channels) {
    // Rough estimation: assume average MP3 bitrate of 128kbps
    const estimatedBitrate = 128 * 1000; // 128kbps in bps
    final estimatedDurationSeconds = (fileSize * 8) / estimatedBitrate;
    return Duration(milliseconds: (estimatedDurationSeconds * 1000).round());
  }

  // Note: previous naive per-frame extraction method has been removed in favor of buffered decoding
}
