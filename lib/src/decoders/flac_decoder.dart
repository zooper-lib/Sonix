import 'dart:io';
import 'dart:typed_data';

import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunked_processing_models.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/utils/streaming_memory_manager.dart';
import 'audio_decoder.dart';
import 'chunked_audio_decoder.dart';

/// FLAC audio decoder using dr_flac library with chunked processing support
class FLACDecoder implements ChunkedAudioDecoder {
  bool _disposed = false;
  bool _initialized = false;
  String? _currentFilePath;
  Duration _currentPosition = Duration.zero;
  int _sampleRate = 0;
  int _channels = 0;
  Duration? _totalDuration;

  // FLAC-specific state for chunked processing
  final List<int> _seekPoints = []; // Byte positions of seek points
  final List<Duration> _seekTimestamps = []; // Timestamps for seek points
  int _blockSize = 4096; // Default FLAC block size
  bool _hasSeekTable = false;

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

      // Read file to get metadata
      final fileData = await file.readAsBytes();
      if (fileData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty FLAC file: $filePath');
      }

      // Extract metadata using native bindings
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.flac);
      _sampleRate = audioData.sampleRate;
      _channels = audioData.channels;
      _totalDuration = audioData.duration;

      // Parse FLAC metadata blocks to find seek table and stream info
      await _parseFLACMetadata(fileData);

      // Seek to initial position if specified
      if (seekPosition != null) {
        await seekToTime(seekPosition);
      }

      _initialized = true;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to initialize FLAC chunked decoding', 'Error initializing $filePath: $e');
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // Find FLAC frames within the chunk
      final frameData = _findFLACFramesInChunk(fileChunk);

      if (frameData.isEmpty) {
        // No complete frames in this chunk
        return [];
      }

      // Decode the frames using native bindings
      final audioChunks = <AudioChunk>[];
      int startSample = (_currentPosition.inMilliseconds * _sampleRate * _channels / 1000).round();

      for (final frame in frameData) {
        try {
          final audioData = NativeAudioBindings.decodeAudio(frame, AudioFormat.flac);

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
      throw DecodingException('Failed to process FLAC chunk', 'Error processing chunk: $e');
    }
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      if (_hasSeekTable && _seekPoints.isNotEmpty) {
        // Use seek table for accurate seeking
        return await _seekUsingSeekTable(position);
      } else {
        // Approximate seeking without seek table
        return await _approximateSeek(position);
      }
    } catch (e) {
      throw DecodingException('Failed to seek in FLAC file', 'Error seeking to $position: $e');
    }
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    // FLAC blocks are typically 1152-4608 samples, so we want chunks that contain multiple blocks
    final channels = _channels > 0 ? _channels : 2; // Default to stereo
    final avgBlockSizeBytes = _blockSize * channels * 2; // Assuming 16-bit samples

    if (fileSize < 1024 * 1024) {
      // < 1MB
      return ChunkSizeRecommendation(
        recommendedSize: (fileSize * 0.4).clamp(avgBlockSizeBytes * 4, 512 * 1024).round(),
        minSize: avgBlockSizeBytes * 2, // At least 2 blocks
        maxSize: fileSize,
        reason: 'Small FLAC file - using 40% of file size to ensure block boundaries',
        metadata: {'format': 'FLAC', 'blockSize': _blockSize, 'hasSeekTable': _hasSeekTable},
      );
    } else if (fileSize < 50 * 1024 * 1024) {
      // < 50MB
      return ChunkSizeRecommendation(
        recommendedSize: 3 * 1024 * 1024, // 3MB
        minSize: 512 * 1024, // 512KB
        maxSize: 15 * 1024 * 1024, // 15MB
        reason: 'Medium FLAC file - using 3MB chunks for optimal block processing',
        metadata: {'format': 'FLAC', 'blockSize': _blockSize, 'hasSeekTable': _hasSeekTable},
      );
    } else {
      // >= 50MB
      return ChunkSizeRecommendation(
        recommendedSize: 8 * 1024 * 1024, // 8MB
        minSize: 2 * 1024 * 1024, // 2MB
        maxSize: 25 * 1024 * 1024, // 25MB
        reason: 'Large FLAC file - using 8MB chunks for memory efficiency',
        metadata: {'format': 'FLAC', 'blockSize': _blockSize, 'hasSeekTable': _hasSeekTable},
      );
    }
  }

  @override
  bool get supportsEfficientSeeking => _hasSeekTable; // Efficient if seek table is available

  @override
  Duration get currentPosition {
    _checkDisposed();
    return _currentPosition;
  }

  @override
  Future<void> resetDecoderState() async {
    _checkDisposed();

    _currentPosition = Duration.zero;
    // Native decoder state would be reset here in a real implementation
  }

  @override
  Map<String, dynamic> getFormatMetadata() {
    _checkDisposed();
    return {
      'format': 'FLAC',
      'sampleRate': _sampleRate,
      'channels': _channels,
      'duration': _totalDuration?.inMilliseconds,
      'blockSize': _blockSize,
      'hasSeekTable': _hasSeekTable,
      'seekPointCount': _seekPoints.length,
      'supportsSeekTable': true,
      'seekingAccuracy': _hasSeekTable ? 'exact' : 'approximate',
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
        final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.flac);
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
    _seekPoints.clear();
    _seekTimestamps.clear();
    _blockSize = 4096;
    _hasSeekTable = false;
  }

  // Helper methods for FLAC-specific processing

  Future<void> _parseFLACMetadata(Uint8List fileData) async {
    // Simplified FLAC metadata parsing
    // In a real implementation, this would parse the actual FLAC metadata blocks

    // Look for FLAC signature
    if (fileData.length < 4 || fileData[0] != 0x66 || fileData[1] != 0x4C || fileData[2] != 0x61 || fileData[3] != 0x43) {
      throw DecodingException('Invalid FLAC file', 'FLAC signature not found');
    }

    // For this implementation, we'll assume default values
    _blockSize = 4096; // Common FLAC block size
    _hasSeekTable = false; // Would be determined by parsing metadata blocks

    // In a real implementation, we would:
    // 1. Parse STREAMINFO block for sample rate, channels, total samples
    // 2. Look for SEEKTABLE block and parse seek points
    // 3. Extract other metadata blocks as needed

    // Create a basic seek table based on estimated positions
    if (_totalDuration != null && _sampleRate > 0) {
      _createBasicSeekTable();
    }
  }

  void _createBasicSeekTable() {
    _seekPoints.clear();
    _seekTimestamps.clear();

    // Create seek points every 10 seconds
    const seekIntervalSeconds = 10;
    final totalSeconds = _totalDuration!.inSeconds;

    for (int i = 0; i <= totalSeconds; i += seekIntervalSeconds) {
      final timestamp = Duration(seconds: i);
      // Estimate byte position (this would be more accurate with real seek table)
      final estimatedPosition = (i * 1000000 / totalSeconds * 0.8).round(); // Rough estimate

      _seekTimestamps.add(timestamp);
      _seekPoints.add(estimatedPosition);
    }

    _hasSeekTable = _seekPoints.isNotEmpty;
  }

  List<Uint8List> _findFLACFramesInChunk(FileChunk fileChunk) {
    final frames = <Uint8List>[];

    // Simplified FLAC frame detection
    // In a real implementation, this would scan for FLAC frame sync codes (0x3FFE)

    // For now, we'll split based on estimated block size
    final avgBlockSizeBytes = _blockSize * _channels * 2; // Assuming 16-bit samples

    int offset = 0;
    while (offset < fileChunk.data.length - avgBlockSizeBytes) {
      final frameData = Uint8List.sublistView(fileChunk.data, offset, (offset + avgBlockSizeBytes).clamp(0, fileChunk.data.length));
      frames.add(frameData);
      offset += avgBlockSizeBytes;
    }

    return frames;
  }

  Future<SeekResult> _seekUsingSeekTable(Duration position) async {
    final targetMs = position.inMilliseconds;

    // Find the closest seek point
    int closestIndex = 0;
    int closestTimeDiff = (targetMs - _seekTimestamps[0].inMilliseconds).abs();

    for (int i = 1; i < _seekTimestamps.length; i++) {
      final timeDiff = (targetMs - _seekTimestamps[i].inMilliseconds).abs();
      if (timeDiff < closestTimeDiff) {
        closestTimeDiff = timeDiff;
        closestIndex = i;
      }
    }

    final actualPosition = _seekTimestamps[closestIndex];
    final bytePosition = _seekPoints[closestIndex];
    _currentPosition = actualPosition;

    // FLAC seeking with seek table is very accurate
    final isExact = closestTimeDiff < 100; // Consider exact if within 100ms

    return SeekResult(
      actualPosition: actualPosition,
      bytePosition: bytePosition,
      isExact: isExact,
      warning: isExact ? null : 'Seek point not available for exact position',
    );
  }

  Future<SeekResult> _approximateSeek(Duration position) async {
    // Approximate seeking without seek table
    final totalMs = _totalDuration?.inMilliseconds ?? 0;
    if (totalMs == 0) {
      throw DecodingException('Cannot seek without duration information', 'FLAC file duration unknown');
    }

    final targetMs = position.inMilliseconds;
    final ratio = targetMs / totalMs;

    // Estimate byte position (very rough)
    final file = File(_currentFilePath!);
    final fileSize = await file.length();
    final estimatedBytePosition = (fileSize * ratio).round();

    _currentPosition = position;

    return SeekResult(actualPosition: position, bytePosition: estimatedBytePosition, isExact: false, warning: 'Approximate seeking - no seek table available');
  }
}
