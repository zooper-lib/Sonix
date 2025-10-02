import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:meta/meta.dart';

import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunked_processing_models.dart';
import 'package:sonix/src/models/mp4_models.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/mp4_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'audio_decoder.dart';
import 'chunked_audio_decoder.dart';

/// MP4 audio decoder with AAC support and chunked processing capabilities
///
/// This decoder handles MP4 container files containing AAC audio streams.
/// It provides both full-file decoding and memory-efficient chunked processing
/// for large files, following the same patterns as other Sonix decoders.
///
/// ## Features
///
/// - Full MP4/AAC decoding support
/// - Memory-efficient chunked processing
/// - Time-based seeking with sample table
/// - Container metadata extraction
/// - Comprehensive error handling
///
/// ## Usage
///
/// ```dart
/// final decoder = MP4Decoder();
///
/// // Full file decoding
/// final audioData = await decoder.decode('audio.mp4');
///
/// // Chunked processing for large files
/// await decoder.initializeChunkedDecoding('large_audio.mp4');
/// // Process chunks...
/// await decoder.cleanupChunkedProcessing();
///
/// decoder.dispose();
/// ```
class MP4Decoder implements ChunkedAudioDecoder {
  // State management
  bool _disposed = false;
  bool _initialized = false;
  String? _currentFilePath;
  Duration _currentPosition = Duration.zero;

  // MP4-specific metadata
  int _sampleRate = 0;
  int _channels = 0;
  Duration? _totalDuration;
  int _bitrate = 0;
  MP4ContainerInfo? _containerInfo;

  // Chunked processing state
  final List<int> _sampleOffsets = [];
  final List<Duration> _sampleTimestamps = [];
  BytesBuilder? _buffer;
  int _bufferSize = 0;
  int _lastDecodedSampleCount = 0;

  // MP4-specific processing constants
  static const int _decodeThreshold = 512 * 1024; // 512KB - larger than MP3 due to AAC frame size
  static const int _maxRetainedBuffer = 1024 * 1024; // 1MB - larger buffer for AAC processing
  static const int _headerReadSize = 256 * 1024; // 256KB for container parsing

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
        throw DecodingException('File is empty', 'Cannot decode empty MP4 file: $filePath');
      }

      // Check if file would exceed memory limits first (before validation to save processing)
      if (NativeAudioBindings.wouldExceedMemoryLimits(fileData.length, AudioFormat.mp4)) {
        throw MemoryException('File too large for direct decoding', 'File size exceeds memory limits. Consider using chunked processing instead.');
      }

      // Validate MP4 container format
      await _validateMP4Container(fileData, filePath);

      // Try to use native bindings to decode
      try {
        final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.mp4);
        return audioData;
      } catch (e) {
        // Handle MP4-specific native decoding errors
        final errorMessage = e.toString().toLowerCase();

        if (errorMessage.contains('mp4_container_invalid') || errorMessage.contains('container')) {
          throw MP4ContainerException('Invalid MP4 container structure', details: 'The file appears to be corrupted or not a valid MP4 container: $filePath');
        } else if (errorMessage.contains('mp4_no_audio_track') || errorMessage.contains('no audio')) {
          throw MP4TrackException('No audio track found', details: 'The MP4 file does not contain any audio tracks: $filePath');
        } else if (errorMessage.contains('mp4_unsupported_codec') || errorMessage.contains('unsupported codec')) {
          throw MP4CodecException('AAC', details: 'The MP4 file contains an unsupported audio codec. Only AAC is currently supported: $filePath');
        } else if (errorMessage.contains('opus decoding not yet implemented') || errorMessage.contains('opus')) {
          throw MP4CodecException(
            'Opus',
            details: 'This MP4 file contains Opus audio, which is not yet supported. Please use a file with AAC audio codec instead.',
          );
        } else if (errorMessage.contains('ffmpeg not available') || errorMessage.contains('ffmpeg_not_available')) {
          // FFMPEG backend not available - provide helpful error
          throw UnsupportedFormatException(
            'MP4/AAC',
            'MP4 decoding requires FFMPEG backend which is not available. Please ensure FFMPEG libraries are properly installed and the native library is built with FFMPEG support.',
          );
        } else {
          // Re-throw other native errors as decoding exceptions with more context
          throw DecodingException('Native MP4 decoding failed', 'Error during native MP4 decoding: $e');
        }
      }
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode MP4 file', 'Error decoding $filePath: $e');
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      // Clean up any native resources if needed
      _disposed = true;
    }
  }

  /// Check if the decoder has been disposed and throw an error if so
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('MP4Decoder has been disposed');
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

      // Read header for container parsing and metadata extraction
      final headerSize = math.min(_headerReadSize, fileSize);
      final headerData = await file.openRead(0, headerSize).expand((chunk) => chunk).toList();

      if (headerData.isEmpty) {
        throw DecodingException('File is empty', 'Cannot decode empty MP4 file: $filePath');
      }

      // Parse MP4 container to extract metadata
      await _parseMP4Container(Uint8List.fromList(headerData));

      // Build sample index for efficient seeking
      await _buildSampleIndex(filePath);

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
      throw DecodingException('Failed to initialize MP4 chunked decoding', 'Error initializing $filePath: $e');
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // Initialize buffer if not already done
      _buffer ??= BytesBuilder(copy: false);

      // Append the new chunk data to buffer for AAC frame boundary handling
      _buffer!.add(fileChunk.data);
      _bufferSize += fileChunk.data.length;

      final audioChunks = <AudioChunk>[];

      // For MP4/AAC, we need to handle frame boundaries carefully
      // AAC frames can span chunk boundaries, so we use a buffering approach

      // Try to decode the buffered data if we have enough or if this is the last chunk
      final shouldAttemptDecode = _bufferSize >= _decodeThreshold || fileChunk.isLast;

      if (shouldAttemptDecode) {
        final bufferedData = _buffer!.toBytes();

        try {
          // Attempt to decode the accumulated buffer
          final audioData = NativeAudioBindings.decodeAudio(bufferedData, AudioFormat.mp4);

          if (audioData.samples.isNotEmpty) {
            // Calculate how many new samples we got since the last successful decode
            final totalDecodedSamples = audioData.samples.length;
            final newSamplesCount = totalDecodedSamples - _lastDecodedSampleCount;

            if (newSamplesCount > 0) {
              // Extract only the new samples to avoid duplicates
              final newSamples = audioData.samples.sublist(_lastDecodedSampleCount);

              // Calculate the correct start sample position
              final startSample = (_currentPosition.inMicroseconds * _sampleRate * _channels) ~/ Duration.microsecondsPerSecond;

              // Create audio chunk with proper sample positioning
              audioChunks.add(AudioChunk(samples: newSamples, startSample: startSample, isLast: fileChunk.isLast));

              // Update current position based on the new samples decoded
              final sampleDuration = Duration(microseconds: (newSamplesCount * Duration.microsecondsPerSecond) ~/ (_sampleRate * _channels));
              _currentPosition += sampleDuration;

              // Update the count of samples we've successfully decoded
              _lastDecodedSampleCount = totalDecodedSamples;
            }

            // If this is the last chunk, we can clear everything
            if (fileChunk.isLast) {
              _buffer = BytesBuilder(copy: false);
              _bufferSize = 0;
              _lastDecodedSampleCount = 0;
            } else {
              // For non-final chunks, we keep the buffer but manage its size
              // This handles cases where AAC frames span multiple chunks
              _manageBufferSize();
            }
          } else {
            // No samples decoded - might be incomplete AAC frames
            if (fileChunk.isLast) {
              // If this is the last chunk and we got no samples, there might be an issue
              // But we should still clean up
              _buffer = BytesBuilder(copy: false);
              _bufferSize = 0;
              _lastDecodedSampleCount = 0;
            } else {
              // Keep accumulating data for next chunk
              _manageBufferSize();
            }
          }
        } catch (decodeError) {
          // Decoding failed - this could be due to incomplete AAC frames
          if (fileChunk.isLast) {
            // If this is the last chunk and decoding still fails,
            // we need to handle this gracefully
            _handleLastChunkDecodeFailure(decodeError);
          } else {
            // For non-final chunks, manage buffer size and continue
            _manageBufferSize();

            // If buffer is getting too large without successful decodes,
            // we might have corrupted data
            if (_bufferSize > _maxRetainedBuffer * 2) {
              throw DecodingException(
                'Buffer overflow in MP4 chunked processing',
                'Unable to decode accumulated data after $_bufferSize bytes. '
                    'This may indicate corrupted AAC frames or unsupported codec.',
              );
            }
          }
        }
      }

      return audioChunks;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to process MP4 chunk', 'Error processing chunk: $e');
    }
  }

  /// Manage buffer size to prevent unbounded growth while preserving AAC frame boundaries
  void _manageBufferSize() {
    if (_bufferSize > _maxRetainedBuffer) {
      final bufferedData = _buffer!.toBytes();

      // Try to find a good truncation point that preserves AAC frame boundaries
      // AAC frames typically start with specific sync patterns
      int truncateFrom = _findAACFrameBoundary(bufferedData, _bufferSize - _maxRetainedBuffer);

      if (truncateFrom > 0) {
        // Truncate from a frame boundary to preserve data integrity
        final retainedData = bufferedData.sublist(truncateFrom);
        _buffer = BytesBuilder(copy: false)..add(retainedData);
        _bufferSize = retainedData.length;

        // Adjust the decoded sample count since we're discarding some buffer data
        // This is an approximation - in a real implementation, we'd track this more precisely
        final discardedBytes = truncateFrom;
        final estimatedDiscardedSamples = (discardedBytes / 768 * 1024).round(); // Rough estimate
        _lastDecodedSampleCount = math.max(0, _lastDecodedSampleCount - estimatedDiscardedSamples);
      } else {
        // If we can't find a good boundary, truncate from the end as fallback
        final retainedData = bufferedData.sublist(bufferedData.length - _maxRetainedBuffer);
        _buffer = BytesBuilder(copy: false)..add(retainedData);
        _bufferSize = _maxRetainedBuffer;
        _lastDecodedSampleCount = 0; // Reset since we can't track accurately
      }
    }
  }

  /// Find AAC frame boundary in the buffer to preserve frame integrity
  int _findAACFrameBoundary(Uint8List data, int startSearchFrom) {
    // AAC frames in MP4 typically don't have sync patterns like MP3
    // Instead, they're defined by the sample table in the container
    // For now, we'll use a simple heuristic based on typical frame sizes

    const typicalAACFrameSize = 768;
    int searchStart = math.max(0, startSearchFrom);

    // Look for positions that align with typical AAC frame boundaries
    for (int i = searchStart; i < data.length - typicalAACFrameSize; i += typicalAACFrameSize) {
      // This is a simplified approach - in a real implementation,
      // we'd use the sample table information to find exact boundaries
      if (i > searchStart) {
        return i;
      }
    }

    // Fallback to a position that's at least past our search start
    return math.min(searchStart + typicalAACFrameSize, data.length ~/ 2);
  }

  /// Handle decode failure on the last chunk
  void _handleLastChunkDecodeFailure(dynamic error) {
    // Clean up state
    _buffer = BytesBuilder(copy: false);
    _bufferSize = 0;
    _lastDecodedSampleCount = 0;

    // Log the error but don't throw - we want to return whatever we successfully decoded
    // In a production implementation, this might be logged for debugging
    // For now, we'll just ensure clean state
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // Find the closest sample to the target position using sample table
      final targetMs = position.inMilliseconds;
      int closestSampleIndex = 0;
      int closestTimeDiff = (targetMs - _sampleTimestamps[0].inMilliseconds).abs();

      for (int i = 1; i < _sampleTimestamps.length; i++) {
        final timeDiff = (targetMs - _sampleTimestamps[i].inMilliseconds).abs();
        if (timeDiff < closestTimeDiff) {
          closestTimeDiff = timeDiff;
          closestSampleIndex = i;
        }
      }

      final actualPosition = _sampleTimestamps[closestSampleIndex];
      final bytePosition = _sampleOffsets[closestSampleIndex];
      _currentPosition = actualPosition;

      // MP4/AAC seeking can be quite accurate with sample table
      final isExact = closestTimeDiff < 25; // Consider exact if within 25ms
      final warning = isExact ? null : 'MP4 seeking accuracy depends on sample table precision';

      return SeekResult(actualPosition: actualPosition, bytePosition: bytePosition, isExact: isExact, warning: warning);
    } catch (e) {
      throw DecodingException('Failed to seek in MP4 file', 'Error seeking to $position: $e');
    }
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    // MP4/AAC frames are typically larger than MP3 frames (200-2000 bytes)
    if (fileSize < 2 * 1024 * 1024) {
      // < 2MB
      return ChunkSizeRecommendation(
        recommendedSize: (fileSize * 0.4).clamp(8192, 512 * 1024).round(),
        minSize: 8192, // 8KB minimum
        maxSize: fileSize,
        reason: 'Small MP4 file - using 40% of file size for container efficiency',
        metadata: {'format': 'MP4/AAC', 'avgFrameSize': 768},
      );
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      return ChunkSizeRecommendation(
        recommendedSize: 4 * 1024 * 1024, // 4MB
        minSize: 512 * 1024, // 512KB
        maxSize: 20 * 1024 * 1024, // 20MB
        reason: 'Medium MP4 file - using 4MB chunks for optimal AAC processing',
        metadata: {'format': 'MP4/AAC', 'avgFrameSize': 768},
      );
    } else {
      // >= 100MB
      return ChunkSizeRecommendation(
        recommendedSize: 8 * 1024 * 1024, // 8MB
        minSize: 2 * 1024 * 1024, // 2MB
        maxSize: 50 * 1024 * 1024, // 50MB
        reason: 'Large MP4 file - using 8MB chunks for memory efficiency',
        metadata: {'format': 'MP4/AAC', 'avgFrameSize': 768},
      );
    }
  }

  @override
  bool get supportsEfficientSeeking => true; // MP4 has sample table for accurate seeking

  @override
  Duration get currentPosition {
    _checkDisposed();
    return _currentPosition;
  }

  @override
  Future<void> resetDecoderState() async {
    _checkDisposed();

    _currentPosition = Duration.zero;
    _buffer = BytesBuilder(copy: false);
    _bufferSize = 0;
    _lastDecodedSampleCount = 0;
    // Native decoder state would be reset here in a real implementation
  }

  @override
  Map<String, dynamic> getFormatMetadata() {
    _checkDisposed();
    return {
      'format': 'MP4/AAC',
      'sampleRate': _sampleRate,
      'channels': _channels,
      'duration': _totalDuration?.inMilliseconds,
      'bitrate': _bitrate,
      'sampleCount': _sampleOffsets.length,
      'supportsSeekTable': true,
      'avgFrameSize': 768, // Typical AAC frame size
      'seekingAccuracy': 'high',
      'containerInfo': _containerInfo?.toMap(),
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
        final headerSize = math.min(_headerReadSize, await file.length());
        final headerData = await file.openRead(0, headerSize).expand((chunk) => chunk).toList();

        // Try to extract duration from container metadata
        await _parseMP4Container(Uint8List.fromList(headerData));
        return _totalDuration;
      } catch (e) {
        // Fall back to file size estimation
        return _estimateDurationFromFileSize();
      }
    }

    return null;
  }

  @override
  bool get isInitialized => _initialized;

  /// Get sample offsets for testing
  @visibleForTesting
  List<int> get sampleOffsets => List.unmodifiable(_sampleOffsets);

  /// Get sample timestamps for testing
  @visibleForTesting
  List<Duration> get sampleTimestamps => List.unmodifiable(_sampleTimestamps);

  /// Set sample rate for testing
  @visibleForTesting
  set sampleRate(int value) => _sampleRate = value;

  @override
  Future<void> cleanupChunkedProcessing() async {
    _initialized = false;
    _currentFilePath = null;
    _currentPosition = Duration.zero;
    _sampleRate = 0;
    _channels = 0;
    _totalDuration = null;
    _bitrate = 0;
    _containerInfo = null;
    _sampleOffsets.clear();
    _sampleTimestamps.clear();
    _buffer = null;
    _bufferSize = 0;
    _lastDecodedSampleCount = 0;
  }

  // Helper methods for MP4-specific processing

  /// Validate MP4 container format and basic structure
  Future<void> _validateMP4Container(Uint8List fileData, String filePath) async {
    try {
      // Check minimum file size for MP4 container
      if (fileData.length < 32) {
        throw MP4ContainerException('File too small to be a valid MP4 container');
      }

      // Check for MP4 ftyp box signature
      if (fileData.length >= 8) {
        final hasValidSignature = fileData[4] == 0x66 && fileData[5] == 0x74 && fileData[6] == 0x79 && fileData[7] == 0x70; // 'ftyp'
        if (!hasValidSignature) {
          throw MP4ContainerException('Invalid MP4 container signature', details: 'File does not contain valid MP4 ftyp box');
        }
      }

      // Parse basic container structure to check for audio track
      try {
        final headerSize = math.min(64 * 1024, fileData.length); // Read up to 64KB for validation
        final headerData = fileData.sublist(0, headerSize);
        final containerMetadata = parseMP4Boxes(headerData);

        // Check if we can find any audio track information
        final audioTrack = findAudioTrack(containerMetadata);
        if (audioTrack == null) {
          // This might not be an error if the moov box is at the end of the file
          // We'll let the native decoder handle this case
        }
      } catch (e) {
        // Container parsing errors are not fatal at this stage
        // The native decoder will provide more detailed error information
      }
    } catch (e) {
      if (e is MP4ContainerException || e is MP4TrackException) {
        rethrow;
      }
      throw MP4ContainerException('Container validation failed', details: 'Error validating MP4 container: $e');
    }
  }

  /// Parse MP4 container to extract metadata and audio track information
  Future<void> _parseMP4Container(Uint8List headerData) async {
    try {
      // Parse MP4 boxes to extract container metadata
      final containerMetadata = parseMP4Boxes(headerData);

      // Extract audio track information
      final audioTrack = findAudioTrack(containerMetadata);
      if (audioTrack == null) {
        throw MP4TrackException('No audio track found in MP4 container');
      }

      // Extract basic audio parameters
      _sampleRate = audioTrack['sampleRate'] as int? ?? 44100;
      _channels = audioTrack['channels'] as int? ?? 2;
      _bitrate = audioTrack['bitrate'] as int? ?? 128000;

      // Calculate duration from track metadata
      final trackDuration = audioTrack['duration'] as int? ?? 0;
      final timeScale = audioTrack['timeScale'] as int? ?? 1000;
      _totalDuration = Duration(milliseconds: (trackDuration * 1000 / timeScale).round());

      // Create container info
      _containerInfo = MP4ContainerInfo(
        duration: _totalDuration ?? Duration.zero,
        bitrate: _bitrate,
        maxBitrate: audioTrack['maxBitrate'] as int? ?? _bitrate,
        codecName: audioTrack['codecName'] as String? ?? 'AAC',
        audioTrackId: audioTrack['trackId'] as int? ?? 1,
        sampleTable: [], // Will be populated by _buildSampleIndex
      );
    } catch (e) {
      if (e is MP4ContainerException || e is MP4TrackException) {
        rethrow;
      }
      throw MP4ContainerException('Failed to parse MP4 container', details: e.toString());
    }
  }

  /// Build sample index for efficient seeking
  Future<void> _buildSampleIndex(String filePath) async {
    _sampleOffsets.clear();
    _sampleTimestamps.clear();

    try {
      // Read more header data to get complete sample table information
      final file = File(filePath);
      final fileSize = await file.length();

      // Read larger portion for complete moov box
      final headerSize = math.min(1024 * 1024, fileSize); // Read up to 1MB for moov box
      final headerData = await file.openRead(0, headerSize).expand((chunk) => chunk).toList();

      // Parse container to get sample table information
      final containerMetadata = parseMP4Boxes(Uint8List.fromList(headerData));
      final audioTrack = findAudioTrack(containerMetadata);

      if (audioTrack != null && audioTrack.containsKey('sampleSizes') && audioTrack.containsKey('chunkOffsets')) {
        // Use actual sample table data
        buildSampleIndexFromTables(audioTrack);
      } else {
        // Fall back to estimated sample index
        buildEstimatedSampleIndex(fileSize);
      }

      // Update container info with sample table
      if (_containerInfo != null) {
        final sampleTable = <MP4SampleInfo>[];
        for (int i = 0; i < _sampleOffsets.length; i++) {
          sampleTable.add(
            MP4SampleInfo(
              offset: _sampleOffsets[i],
              size: i + 1 < _sampleOffsets.length ? _sampleOffsets[i + 1] - _sampleOffsets[i] : 768,
              timestamp: _sampleTimestamps[i],
              isKeyframe: true, // Most AAC frames are keyframes
            ),
          );
        }

        _containerInfo = MP4ContainerInfo(
          duration: _containerInfo!.duration,
          bitrate: _containerInfo!.bitrate,
          maxBitrate: _containerInfo!.maxBitrate,
          codecName: _containerInfo!.codecName,
          audioTrackId: _containerInfo!.audioTrackId,
          sampleTable: sampleTable,
        );
      }
    } catch (e) {
      throw MP4TrackException('Failed to build sample index', details: e.toString());
    }
  }

  /// Build sample index from parsed MP4 sample tables
  @visibleForTesting
  void buildSampleIndexFromTables(Map<String, dynamic> audioTrack) {
    final sampleSizes = audioTrack['sampleSizes'] as List<int>? ?? [];
    final chunkOffsets = audioTrack['chunkOffsets'] as List<int>? ?? [];
    final sampleToChunk = audioTrack['sampleToChunk'] as List<Map<String, int>>? ?? [];
    final sampleTimes = audioTrack['sampleTimes'] as List<Map<String, int>>? ?? [];

    if (sampleSizes.isEmpty || chunkOffsets.isEmpty) {
      throw MP4TrackException('Invalid sample table data');
    }

    // Build sample offsets from chunk offsets and sample-to-chunk mapping
    int sampleIndex = 0;
    int currentTime = 0;
    final timeScale = audioTrack['timeScale'] as int? ?? 1000;

    // Process sample timing information
    final sampleDurations = <int>[];
    for (final timeEntry in sampleTimes) {
      final sampleCount = timeEntry['sampleCount'] ?? 0;
      final sampleDelta = timeEntry['sampleDelta'] ?? 0;

      for (int i = 0; i < sampleCount; i++) {
        sampleDurations.add(sampleDelta);
      }
    }

    // Process chunks and samples
    for (int chunkIndex = 0; chunkIndex < chunkOffsets.length; chunkIndex++) {
      int samplesInChunk = 1; // Default to 1 sample per chunk

      // Find samples per chunk for this chunk
      for (final stscEntry in sampleToChunk) {
        final firstChunk = (stscEntry['firstChunk'] ?? 1) - 1; // Convert to 0-based
        if (chunkIndex >= firstChunk) {
          samplesInChunk = stscEntry['samplesPerChunk'] ?? 1;
        }
      }

      int chunkOffset = chunkOffsets[chunkIndex];

      // Add samples for this chunk
      for (int sampleInChunk = 0; sampleInChunk < samplesInChunk && sampleIndex < sampleSizes.length; sampleInChunk++) {
        _sampleOffsets.add(chunkOffset);

        // Calculate timestamp
        final duration = sampleIndex < sampleDurations.length ? sampleDurations[sampleIndex] : 1024;
        final timestamp = Duration(milliseconds: (currentTime * 1000 / timeScale).round());
        _sampleTimestamps.add(timestamp);

        chunkOffset += sampleSizes[sampleIndex];
        currentTime += duration;
        sampleIndex++;
      }
    }
  }

  /// Build estimated sample index when sample table parsing fails
  @visibleForTesting
  void buildEstimatedSampleIndex(int fileSize) {
    const avgFrameSize = 768; // Typical AAC frame size
    const samplesPerFrame = 1024; // AAC frame contains 1024 samples

    int offset = 0;
    int frameIndex = 0;

    // Skip container header (estimated)
    offset = math.min(32 * 1024, fileSize ~/ 10); // Skip first 32KB or 10% of file

    while (offset < fileSize - avgFrameSize) {
      _sampleOffsets.add(offset);

      // Calculate timestamp for this frame
      final timestamp = Duration(milliseconds: (frameIndex * samplesPerFrame * 1000 / _sampleRate).round());
      _sampleTimestamps.add(timestamp);

      offset += avgFrameSize;
      frameIndex++;
    }
  }

  /// Estimate duration from file size and audio format parameters
  Duration _estimateDurationFromFileSize() {
    if (_currentFilePath == null) return Duration.zero;

    try {
      final file = File(_currentFilePath!);
      final fileSize = file.lengthSync();

      // Rough estimation: assume average AAC bitrate
      final estimatedBitrate = _bitrate > 0 ? _bitrate : 128000; // 128kbps default
      final estimatedDurationSeconds = (fileSize * 8) / estimatedBitrate;
      return Duration(milliseconds: (estimatedDurationSeconds * 1000).round());
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Parse MP4 boxes from header data to extract container metadata
  @visibleForTesting
  Map<String, dynamic> parseMP4Boxes(Uint8List data) {
    final metadata = <String, dynamic>{};
    int offset = 0;

    try {
      while (offset < data.length - 8) {
        final box = _parseMP4Box(data, offset);
        if (box == null) break;

        final boxType = box['type'] as String;
        final boxSize = box['size'] as int;
        final boxData = box['data'] as Uint8List?;

        switch (boxType) {
          case 'ftyp':
            metadata['fileType'] = parseFtypBox(boxData);
            break;
          case 'moov':
            if (boxData != null) {
              metadata.addAll(_parseMoovBox(boxData));
            }
            break;
          case 'mdat':
            metadata['mdatOffset'] = offset + 8;
            metadata['mdatSize'] = boxSize - 8;
            break;
        }

        offset += boxSize;
        if (boxSize <= 8) break; // Prevent infinite loop
      }
    } catch (e) {
      throw MP4ContainerException('Error parsing MP4 boxes', details: e.toString());
    }

    return metadata;
  }

  /// Parse a single MP4 box header and data
  Map<String, dynamic>? _parseMP4Box(Uint8List data, int offset) {
    if (offset + 8 > data.length) return null;

    try {
      // Read box size (4 bytes, big-endian)
      final size = readUint32BE(data, offset);
      if (size < 8 || offset + size > data.length) return null;

      // Read box type (4 bytes ASCII)
      final typeBytes = data.sublist(offset + 4, offset + 8);
      final type = String.fromCharCodes(typeBytes);

      // Extract box data (excluding header)
      Uint8List? boxData;
      if (size > 8) {
        boxData = data.sublist(offset + 8, offset + size);
      }

      return {'type': type, 'size': size, 'data': boxData};
    } catch (e) {
      return null;
    }
  }

  /// Parse ftyp box to get file type information
  @visibleForTesting
  Map<String, dynamic> parseFtypBox(Uint8List? data) {
    if (data == null || data.length < 8) {
      return {'majorBrand': 'unknown', 'minorVersion': 0, 'compatibleBrands': <String>[]};
    }

    try {
      final majorBrand = String.fromCharCodes(data.sublist(0, 4));
      final minorVersion = readUint32BE(data, 4);

      final compatibleBrands = <String>[];
      for (int i = 8; i + 4 <= data.length; i += 4) {
        final brand = String.fromCharCodes(data.sublist(i, i + 4));
        compatibleBrands.add(brand);
      }

      return {'majorBrand': majorBrand, 'minorVersion': minorVersion, 'compatibleBrands': compatibleBrands};
    } catch (e) {
      return {'majorBrand': 'unknown', 'minorVersion': 0, 'compatibleBrands': <String>[]};
    }
  }

  /// Parse moov box to extract movie metadata
  Map<String, dynamic> _parseMoovBox(Uint8List data) {
    final metadata = <String, dynamic>{};
    int offset = 0;

    try {
      while (offset < data.length - 8) {
        final box = _parseMP4Box(data, offset);
        if (box == null) break;

        final boxType = box['type'] as String;
        final boxSize = box['size'] as int;
        final boxData = box['data'] as Uint8List?;

        switch (boxType) {
          case 'mvhd':
            if (boxData != null) {
              metadata.addAll(parseMvhdBox(boxData));
            }
            break;
          case 'trak':
            if (boxData != null) {
              final trackInfo = _parseTrakBox(boxData);
              if (trackInfo['mediaType'] == 'soun') {
                metadata['audioTrack'] = trackInfo;
              }
            }
            break;
        }

        offset += boxSize;
        if (boxSize <= 8) break;
      }
    } catch (e) {
      throw MP4ContainerException('Error parsing moov box', details: e.toString());
    }

    return metadata;
  }

  /// Parse mvhd box to get movie header information
  @visibleForTesting
  Map<String, dynamic> parseMvhdBox(Uint8List data) {
    if (data.length < 20) return {};

    try {
      final version = data[0];
      int offset = 4; // Skip version and flags

      // Skip creation and modification times
      if (version == 1) {
        offset += 16; // 64-bit timestamps
      } else {
        offset += 8; // 32-bit timestamps
      }

      if (offset + 8 > data.length) return {};

      final timeScale = readUint32BE(data, offset);
      offset += 4;

      int duration;
      if (version == 1) {
        if (offset + 8 > data.length) return {};
        duration = readUint64BE(data, offset);
      } else {
        if (offset + 4 > data.length) return {};
        duration = readUint32BE(data, offset);
      }

      return {'timeScale': timeScale, 'duration': duration};
    } catch (e) {
      return {};
    }
  }

  /// Parse trak box to extract track information
  Map<String, dynamic> _parseTrakBox(Uint8List data) {
    final trackInfo = <String, dynamic>{};
    int offset = 0;

    try {
      while (offset < data.length - 8) {
        final box = _parseMP4Box(data, offset);
        if (box == null) break;

        final boxType = box['type'] as String;
        final boxSize = box['size'] as int;
        final boxData = box['data'] as Uint8List?;

        switch (boxType) {
          case 'tkhd':
            if (boxData != null) {
              trackInfo.addAll(_parseTkhdBox(boxData));
            }
            break;
          case 'mdia':
            if (boxData != null) {
              trackInfo.addAll(_parseMdiaBox(boxData));
            }
            break;
        }

        offset += boxSize;
        if (boxSize <= 8) break;
      }
    } catch (e) {
      // Return partial track info if parsing fails
    }

    return trackInfo;
  }

  /// Parse tkhd box to get track header information
  Map<String, dynamic> _parseTkhdBox(Uint8List data) {
    if (data.length < 20) return {};

    try {
      final version = data[0];
      int offset = 4; // Skip version and flags

      // Skip creation and modification times
      if (version == 1) {
        offset += 16; // 64-bit timestamps
      } else {
        offset += 8; // 32-bit timestamps
      }

      if (offset + 4 > data.length) return {};

      final trackId = readUint32BE(data, offset);
      offset += 4;

      // Skip reserved field
      offset += 4;

      int duration;
      if (version == 1) {
        if (offset + 8 > data.length) return {};
        duration = readUint64BE(data, offset);
      } else {
        if (offset + 4 > data.length) return {};
        duration = readUint32BE(data, offset);
      }

      return {'trackId': trackId, 'duration': duration};
    } catch (e) {
      return {};
    }
  }

  /// Parse mdia box to extract media information
  Map<String, dynamic> _parseMdiaBox(Uint8List data) {
    final mediaInfo = <String, dynamic>{};
    int offset = 0;

    try {
      while (offset < data.length - 8) {
        final box = _parseMP4Box(data, offset);
        if (box == null) break;

        final boxType = box['type'] as String;
        final boxSize = box['size'] as int;
        final boxData = box['data'] as Uint8List?;

        switch (boxType) {
          case 'mdhd':
            if (boxData != null) {
              mediaInfo.addAll(_parseMdhdBox(boxData));
            }
            break;
          case 'hdlr':
            if (boxData != null) {
              mediaInfo.addAll(_parseHdlrBox(boxData));
            }
            break;
          case 'minf':
            if (boxData != null) {
              mediaInfo.addAll(_parseMinfBox(boxData));
            }
            break;
        }

        offset += boxSize;
        if (boxSize <= 8) break;
      }
    } catch (e) {
      // Return partial media info if parsing fails
    }

    return mediaInfo;
  }

  /// Parse mdhd box to get media header information
  Map<String, dynamic> _parseMdhdBox(Uint8List data) {
    if (data.length < 20) return {};

    try {
      final version = data[0];
      int offset = 4; // Skip version and flags

      // Skip creation and modification times
      if (version == 1) {
        offset += 16; // 64-bit timestamps
      } else {
        offset += 8; // 32-bit timestamps
      }

      if (offset + 8 > data.length) return {};

      final timeScale = readUint32BE(data, offset);
      offset += 4;

      int duration;
      if (version == 1) {
        if (offset + 8 > data.length) return {};
        duration = readUint64BE(data, offset);
      } else {
        if (offset + 4 > data.length) return {};
        duration = readUint32BE(data, offset);
      }

      return {'timeScale': timeScale, 'duration': duration};
    } catch (e) {
      return {};
    }
  }

  /// Parse hdlr box to get handler information
  Map<String, dynamic> _parseHdlrBox(Uint8List data) {
    if (data.length < 20) return {};

    try {
      int offset = 4; // Skip version and flags
      offset += 4; // Skip pre_defined

      if (offset + 4 > data.length) return {};

      final handlerType = String.fromCharCodes(data.sublist(offset, offset + 4));

      return {'mediaType': handlerType};
    } catch (e) {
      return {};
    }
  }

  /// Parse minf box to extract media information
  Map<String, dynamic> _parseMinfBox(Uint8List data) {
    final minfInfo = <String, dynamic>{};
    int offset = 0;

    try {
      while (offset < data.length - 8) {
        final box = _parseMP4Box(data, offset);
        if (box == null) break;

        final boxType = box['type'] as String;
        final boxSize = box['size'] as int;
        final boxData = box['data'] as Uint8List?;

        switch (boxType) {
          case 'stbl':
            if (boxData != null) {
              minfInfo.addAll(_parseStblBox(boxData));
            }
            break;
        }

        offset += boxSize;
        if (boxSize <= 8) break;
      }
    } catch (e) {
      // Return partial minf info if parsing fails
    }

    return minfInfo;
  }

  /// Parse stbl box to extract sample table information
  Map<String, dynamic> _parseStblBox(Uint8List data) {
    final stblInfo = <String, dynamic>{};
    int offset = 0;

    try {
      while (offset < data.length - 8) {
        final box = _parseMP4Box(data, offset);
        if (box == null) break;

        final boxType = box['type'] as String;
        final boxSize = box['size'] as int;
        final boxData = box['data'] as Uint8List?;

        switch (boxType) {
          case 'stsd':
            if (boxData != null) {
              stblInfo.addAll(parseStsdBox(boxData));
            }
            break;
          case 'stts':
            if (boxData != null) {
              stblInfo['sampleTimes'] = parseSttsBox(boxData);
            }
            break;
          case 'stsc':
            if (boxData != null) {
              stblInfo['sampleToChunk'] = _parseStscBox(boxData);
            }
            break;
          case 'stsz':
            if (boxData != null) {
              stblInfo['sampleSizes'] = parseStszBox(boxData);
            }
            break;
          case 'stco':
            if (boxData != null) {
              stblInfo['chunkOffsets'] = parseStcoBox(boxData);
            }
            break;
        }

        offset += boxSize;
        if (boxSize <= 8) break;
      }
    } catch (e) {
      // Return partial stbl info if parsing fails
    }

    return stblInfo;
  }

  /// Parse stsd box to get sample description
  @visibleForTesting
  Map<String, dynamic> parseStsdBox(Uint8List data) {
    if (data.length < 8) return {};

    try {
      int offset = 4; // Skip version and flags

      if (offset + 4 > data.length) return {};
      final entryCount = readUint32BE(data, offset);
      offset += 4;

      if (entryCount > 0 && offset + 8 <= data.length) {
        // Read first sample description
        readUint32BE(data, offset); // Sample description size (not used)
        offset += 4;

        if (offset + 4 <= data.length) {
          final format = String.fromCharCodes(data.sublist(offset, offset + 4));
          offset += 4;

          // For audio samples, extract additional info
          if (format == 'mp4a' && offset + 18 <= data.length) {
            offset += 6; // Skip reserved
            final channelCount = readUint16BE(data, offset);
            offset += 2;
            final sampleSize = readUint16BE(data, offset);
            offset += 2;
            offset += 4; // Skip pre_defined and reserved
            final sampleRate = readUint32BE(data, offset) >> 16; // Fixed-point 16.16

            return {'codecName': 'AAC', 'channels': channelCount, 'sampleSize': sampleSize, 'sampleRate': sampleRate};
          }

          return {'codecName': format};
        }
      }
    } catch (e) {
      // Return empty if parsing fails
    }

    return {};
  }

  /// Parse stts box to get sample timing information
  @visibleForTesting
  List<Map<String, int>> parseSttsBox(Uint8List data) {
    final entries = <Map<String, int>>[];

    if (data.length < 8) return entries;

    try {
      int offset = 4; // Skip version and flags

      if (offset + 4 > data.length) return entries;
      final entryCount = readUint32BE(data, offset);
      offset += 4;

      for (int i = 0; i < entryCount && offset + 8 <= data.length; i++) {
        final sampleCount = readUint32BE(data, offset);
        offset += 4;
        final sampleDelta = readUint32BE(data, offset);
        offset += 4;

        entries.add({'sampleCount': sampleCount, 'sampleDelta': sampleDelta});
      }
    } catch (e) {
      // Return partial entries if parsing fails
    }

    return entries;
  }

  /// Parse stsc box to get sample-to-chunk mapping
  List<Map<String, int>> _parseStscBox(Uint8List data) {
    final entries = <Map<String, int>>[];

    if (data.length < 8) return entries;

    try {
      int offset = 4; // Skip version and flags

      if (offset + 4 > data.length) return entries;
      final entryCount = readUint32BE(data, offset);
      offset += 4;

      for (int i = 0; i < entryCount && offset + 12 <= data.length; i++) {
        final firstChunk = readUint32BE(data, offset);
        offset += 4;
        final samplesPerChunk = readUint32BE(data, offset);
        offset += 4;
        final sampleDescriptionIndex = readUint32BE(data, offset);
        offset += 4;

        entries.add({'firstChunk': firstChunk, 'samplesPerChunk': samplesPerChunk, 'sampleDescriptionIndex': sampleDescriptionIndex});
      }
    } catch (e) {
      // Return partial entries if parsing fails
    }

    return entries;
  }

  /// Parse stsz box to get sample sizes
  @visibleForTesting
  List<int> parseStszBox(Uint8List data) {
    final sizes = <int>[];

    if (data.length < 12) return sizes;

    try {
      int offset = 4; // Skip version and flags

      final sampleSize = readUint32BE(data, offset);
      offset += 4;
      final sampleCount = readUint32BE(data, offset);
      offset += 4;

      if (sampleSize != 0) {
        // All samples have the same size
        for (int i = 0; i < sampleCount; i++) {
          sizes.add(sampleSize);
        }
      } else {
        // Individual sample sizes
        for (int i = 0; i < sampleCount && offset + 4 <= data.length; i++) {
          final size = readUint32BE(data, offset);
          offset += 4;
          sizes.add(size);
        }
      }
    } catch (e) {
      // Return partial sizes if parsing fails
    }

    return sizes;
  }

  /// Parse stco box to get chunk offsets
  @visibleForTesting
  List<int> parseStcoBox(Uint8List data) {
    final offsets = <int>[];

    if (data.length < 8) return offsets;

    try {
      int offset = 4; // Skip version and flags

      if (offset + 4 > data.length) return offsets;
      final entryCount = readUint32BE(data, offset);
      offset += 4;

      for (int i = 0; i < entryCount && offset + 4 <= data.length; i++) {
        final chunkOffset = readUint32BE(data, offset);
        offset += 4;
        offsets.add(chunkOffset);
      }
    } catch (e) {
      // Return partial offsets if parsing fails
    }

    return offsets;
  }

  /// Find audio track from parsed container metadata
  @visibleForTesting
  Map<String, dynamic>? findAudioTrack(Map<String, dynamic> metadata) {
    final audioTrack = metadata['audioTrack'] as Map<String, dynamic>?;
    if (audioTrack == null) return null;

    // Merge movie-level and track-level information
    final movieTimeScale = metadata['timeScale'] as int? ?? 1000;
    final movieDuration = metadata['duration'] as int? ?? 0;

    final result = Map<String, dynamic>.from(audioTrack);

    // Use track duration if available, otherwise use movie duration
    if (!result.containsKey('duration') || result['duration'] == 0) {
      result['duration'] = movieDuration;
      result['timeScale'] = movieTimeScale;
    }

    // Estimate bitrate if not available
    if (!result.containsKey('bitrate')) {
      final sampleRate = result['sampleRate'] as int? ?? 44100;
      final channels = result['channels'] as int? ?? 2;
      result['bitrate'] = estimateBitrate(sampleRate, channels);
      result['maxBitrate'] = result['bitrate'];
    }

    return result;
  }

  /// Estimate bitrate based on sample rate and channels
  @visibleForTesting
  int estimateBitrate(int sampleRate, int channels) {
    // Conservative AAC bitrate estimation
    if (sampleRate >= 44100) {
      return channels == 1 ? 96000 : 128000; // 96kbps mono, 128kbps stereo
    } else if (sampleRate >= 22050) {
      return channels == 1 ? 64000 : 96000; // 64kbps mono, 96kbps stereo
    } else {
      return channels == 1 ? 32000 : 64000; // 32kbps mono, 64kbps stereo
    }
  }

  /// Read 32-bit big-endian unsigned integer
  @visibleForTesting
  int readUint32BE(Uint8List data, int offset) {
    if (offset + 4 > data.length) throw RangeError('Offset out of bounds');
    return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
  }

  /// Read 64-bit big-endian unsigned integer
  @visibleForTesting
  int readUint64BE(Uint8List data, int offset) {
    if (offset + 8 > data.length) throw RangeError('Offset out of bounds');
    final high = readUint32BE(data, offset);
    final low = readUint32BE(data, offset + 4);
    return (high << 32) | low;
  }

  /// Read 16-bit big-endian unsigned integer
  @visibleForTesting
  int readUint16BE(Uint8List data, int offset) {
    if (offset + 2 > data.length) throw RangeError('Offset out of bounds');
    return (data[offset] << 8) | data[offset + 1];
  }
}
