import 'dart:io';

import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunked_processing_models.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'audio_decoder.dart';
import 'chunked_audio_decoder.dart';

/// Opus audio decoder using FFMPEG library with chunked processing support
class OpusDecoder implements ChunkedAudioDecoder {
  bool _disposed = false;
  bool _initialized = false;
  String? _currentFilePath;
  Duration _currentPosition = Duration.zero;
  int _sampleRate = 0;
  int _channels = 0;
  Duration? _totalDuration;

  // Opus-specific state for chunked processing
  final List<int> _pageOffsets = []; // Byte positions of Opus pages
  final List<Duration> _pageTimestamps = []; // Timestamps for Opus pages
  final List<int> _granulePositions = []; // Granule positions for seeking

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
        throw DecodingException('File is empty', 'Cannot decode empty Opus file: $filePath');
      }

      // Use native bindings to decode with correct Opus format
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.opus);
      return audioData;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode Opus file', 'Error decoding $filePath: $e');
    }
  }

  @override
  Future<void> initializeChunkedDecoding(String filePath, {int chunkSize = 10 * 1024 * 1024, Duration? seekPosition}) async {
    _checkDisposed();

    if (_initialized && _currentFilePath == filePath) {
      return; // Already initialized for this file
    }

    try {
      _currentFilePath = filePath;
      _currentPosition = seekPosition ?? Duration.zero;

      // Analyze the file to get basic info
      final audioData = await decode(filePath);
      _sampleRate = audioData.sampleRate;
      _channels = audioData.channels;
      _totalDuration = audioData.duration;

      // For Opus, we would need to parse the file structure to find page boundaries
      // This is a simplified implementation - in practice, you'd parse the OGG container
      // that typically contains Opus streams
      await _analyzeOpusFile(filePath);

      _initialized = true;

      // Seek to initial position if specified
      if (seekPosition != null) {
        await seekToTime(seekPosition);
      }
    } catch (e) {
      throw DecodingException('Failed to initialize Opus chunked decoding', 'Error initializing $filePath: $e');
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // Extract the chunk data
      final chunkData = fileChunk.data;
      if (chunkData.isEmpty) {
        return []; // Return empty list for empty chunks
      }

      // For Opus files, we would need to handle OGG page boundaries properly
      // This is a simplified implementation using the full decode method
      // In practice, you'd use the native chunked decoder
      final audioData = NativeAudioBindings.decodeAudio(chunkData, AudioFormat.opus);

      // Convert to AudioChunk format
      final audioChunk = AudioChunk(
        samples: audioData.samples,
        startSample: 0, // Would need proper calculation based on position
        isLast: fileChunk.isLast,
      );

      return [audioChunk];
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to process Opus chunk', 'Error processing chunk at ${fileChunk.startPosition}: $e');
    }
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    if (_totalDuration != null && position > _totalDuration!) {
      throw ArgumentError('Seek time $position exceeds file duration $_totalDuration');
    }

    // For Opus, we would need to find the appropriate OGG page
    // This is a simplified implementation
    _currentPosition = position;

    return SeekResult(
      actualPosition: _currentPosition,
      bytePosition: 0, // Would need proper calculation
      isExact: false, // Opus seeking is typically not sample-exact
    );
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    // Opus files benefit from smaller chunks due to their page-based structure
    final baseChunkSize = (fileSize / 50).clamp(64 * 1024, 5 * 1024 * 1024).round(); // 64KB to 5MB
    return ChunkSizeRecommendation(
      recommendedSize: baseChunkSize,
      minSize: 32 * 1024, // 32KB minimum
      maxSize: 10 * 1024 * 1024, // 10MB maximum
      reason: 'Opus format optimization for page-based structure',
    );
  }

  @override
  bool get supportsEfficientSeeking => false; // Opus seeking is not sample-exact

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Future<void> resetDecoderState() async {
    _currentPosition = Duration.zero;
    // Additional state reset if needed
  }

  @override
  Map<String, dynamic> getFormatMetadata() {
    return {
      'decoder': 'OpusDecoder',
      'format': 'Opus',
      'description': 'High-quality, low-latency audio codec',
      'sampleRate': _sampleRate,
      'channels': _channels,
      'supportsEfficientSeeking': supportsEfficientSeeking,
      'fileExtensions': ['opus'],
      'containerFormat': 'OGG',
    };
  }

  @override
  Future<Duration?> estimateDuration() async {
    // Could analyze file headers to estimate duration without full decode
    // For now, return null to indicate estimation is not available
    return null;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> cleanupChunkedProcessing() async {
    _pageOffsets.clear();
    _pageTimestamps.clear();
    _granulePositions.clear();
    _initialized = false;
  }

  /// Analyze Opus file structure for chunked processing
  Future<void> _analyzeOpusFile(String filePath) async {
    // Clear previous analysis data
    _pageOffsets.clear();
    _pageTimestamps.clear();
    _granulePositions.clear();

    // In a full implementation, you would:
    // 1. Parse the OGG container structure
    // 2. Find Opus page boundaries
    // 3. Extract granule positions for seeking
    // 4. Build a map of timestamps to file positions

    // For now, we'll use a simplified approach
    final file = File(filePath);
    final fileSize = await file.length();

    // Create dummy page positions (every 64KB for example)
    const pageSize = 65536; // 64KB
    for (int offset = 0; offset < fileSize; offset += pageSize) {
      _pageOffsets.add(offset);
      // Estimate timestamp based on file position
      final timeMs = (offset / fileSize * (_totalDuration?.inMilliseconds ?? 0)).round();
      _pageTimestamps.add(Duration(milliseconds: timeMs));
      _granulePositions.add(offset ~/ pageSize);
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('OpusDecoder has been disposed');
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _initialized = false;
      _currentFilePath = null;
      _currentPosition = Duration.zero;
      _sampleRate = 0;
      _channels = 0;
      _totalDuration = null;
      _pageOffsets.clear();
      _pageTimestamps.clear();
      _granulePositions.clear();
    }
  }
}
