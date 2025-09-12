import 'dart:io';
import 'dart:typed_data';

import '../models/audio_data.dart';
import '../models/file_chunk.dart';
import '../models/chunked_processing_models.dart';
import '../exceptions/sonix_exceptions.dart';
import '../native/native_audio_bindings.dart';
import '../utils/streaming_memory_manager.dart';
import 'audio_decoder.dart';
import 'chunked_audio_decoder.dart';

/// MP3 audio decoder using minimp3 library with chunked processing support
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
  int _currentFrameIndex = 0;

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

  // ChunkedAudioDecoder implementation

  @override
  Future<void> initializeChunkedDecoding(String filePath, {int chunkSize = 10 * 1024 * 1024, Duration? seekPosition}) async {
    _checkDisposed();

    try {
      _currentFilePath = filePath;

      // Verify file exists
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }

      // Read file header to get basic info
      final fileData = await file.readAsBytes();
      if (fileData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty MP3 file: $filePath');
      }

      // Extract basic metadata using native bindings
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.mp3);
      _sampleRate = audioData.sampleRate;
      _channels = audioData.channels;
      _totalDuration = audioData.duration;

      // Build frame index for seeking (simplified - in real implementation would scan for sync words)
      await _buildFrameIndex(fileData);

      // Seek to initial position if specified
      if (seekPosition != null) {
        await seekToTime(seekPosition);
      }

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
      // For MP3, we need to find frame boundaries within the chunk
      final frameData = _findFramesInChunk(fileChunk);

      if (frameData.isEmpty) {
        // No complete frames in this chunk
        return [];
      }

      // Decode the frames using native bindings
      final audioChunks = <AudioChunk>[];
      int startSample = (_currentPosition.inMilliseconds * _sampleRate * _channels / 1000).round();

      for (final frame in frameData) {
        try {
          final audioData = NativeAudioBindings.decodeAudio(frame, AudioFormat.mp3);

          audioChunks.add(
            AudioChunk(
              samples: audioData.samples,
              startSample: startSample,
              isLast: false, // Will be set by the caller if this is the last chunk
            ),
          );

          startSample += audioData.samples.length;

          // Update current position based on decoded samples
          final frameDuration = Duration(milliseconds: (audioData.samples.length * 1000 / (_sampleRate * _channels)).round());
          _currentPosition += frameDuration;
        } catch (e) {
          // Skip corrupted frames and continue
          continue;
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

      _currentFrameIndex = closestFrameIndex;
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
    _currentFrameIndex = 0;
    // Native decoder state would be reset here in a real implementation
  }

  @override
  Map<String, dynamic> getFormatMetadata() {
    _checkDisposed();
    return {
      'format': 'MP3',
      'sampleRate': _sampleRate,
      'channels': _channels,
      'duration': _totalDuration?.inMilliseconds,
      'frameCount': _frameOffsets.length,
      'supportsSeekTable': false,
      'avgFrameSize': 417, // Typical MP3 frame size
      'seekingAccuracy': 'approximate',
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
    _currentFrameIndex = 0;
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

  List<Uint8List> _findFramesInChunk(FileChunk fileChunk) {
    final frames = <Uint8List>[];

    // Simplified frame extraction - in real implementation would scan for sync words
    // For now, we'll split the chunk into estimated frame-sized pieces
    const avgFrameSize = 417;

    int offset = 0;
    while (offset < fileChunk.data.length - avgFrameSize) {
      final frameData = Uint8List.sublistView(fileChunk.data, offset, (offset + avgFrameSize).clamp(0, fileChunk.data.length));
      frames.add(frameData);
      offset += avgFrameSize;
    }

    return frames;
  }
}
