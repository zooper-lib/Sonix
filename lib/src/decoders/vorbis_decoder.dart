import 'dart:io';
import 'dart:typed_data';

import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunked_processing_models.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'audio_decoder.dart';
import 'chunked_audio_decoder.dart';

/// OGG Vorbis audio decoder using stb_vorbis library with chunked processing support
class VorbisDecoder implements ChunkedAudioDecoder {
  bool _disposed = false;
  bool _initialized = false;
  String? _currentFilePath;
  Duration _currentPosition = Duration.zero;
  int _sampleRate = 0;
  int _channels = 0;
  Duration? _totalDuration;

  // OGG Vorbis-specific state for chunked processing
  final List<int> _pageOffsets = []; // Byte positions of OGG pages
  final List<Duration> _pageTimestamps = []; // Timestamps for OGG pages
  final List<int> _granulePositions = []; // Granule positions for seeking
  static const int _chunkSize = 64 * 1024; // 64KB chunks for streaming

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
        throw DecodingException('File is empty', 'Cannot decode empty OGG Vorbis file: $filePath');
      }

      // Use native bindings to decode
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.ogg);
      return audioData;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to decode OGG Vorbis file', 'Error decoding $filePath: $e');
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

      // OGG Vorbis supports streaming decode, but for simplicity we'll decode and stream results
      final audioData = await decode(filePath);

      // Stream the decoded samples in chunks
      final samples = audioData.samples;
      int currentIndex = 0;

      while (currentIndex < samples.length) {
        final endIndex = (currentIndex + _chunkSize).clamp(0, samples.length);
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
      throw DecodingException('Failed to stream OGG Vorbis file', 'Error streaming $filePath: $e');
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
      throw StateError('VorbisDecoder has been disposed');
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
        throw DecodingException('File is empty', 'Cannot decode empty OGG Vorbis file: $filePath');
      }

      // Extract metadata using native bindings
      final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.ogg);
      _sampleRate = audioData.sampleRate;
      _channels = audioData.channels;
      _totalDuration = audioData.duration;

      // Parse OGG page structure for seeking
      await _parseOGGPages(fileData);

      // Seek to initial position if specified
      if (seekPosition != null) {
        await seekToTime(seekPosition);
      }

      _initialized = true;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to initialize OGG Vorbis chunked decoding', 'Error initializing $filePath: $e');
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // Find OGG pages within the chunk
      final pageData = _findOGGPagesInChunk(fileChunk);

      if (pageData.isEmpty) {
        // No complete pages in this chunk
        return [];
      }

      // Decode the pages using native bindings
      final audioChunks = <AudioChunk>[];
      int startSample = (_currentPosition.inMilliseconds * _sampleRate * _channels / 1000).round();

      for (final page in pageData) {
        try {
          final audioData = NativeAudioBindings.decodeAudio(page, AudioFormat.ogg);

          audioChunks.add(
            AudioChunk(
              samples: audioData.samples,
              startSample: startSample,
              isLast: false, // Will be set by the caller if this is the last chunk
            ),
          );

          startSample += audioData.samples.length;

          // Update current position based on decoded samples
          final pageDuration = Duration(milliseconds: (audioData.samples.length * 1000 / (_sampleRate * _channels)).round());
          _currentPosition += pageDuration;
        } catch (e) {
          // Skip corrupted pages and continue
          continue;
        }
      }

      return audioChunks;
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Failed to process OGG Vorbis chunk', 'Error processing chunk: $e');
    }
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _checkDisposed();

    if (!_initialized) {
      throw StateError('Decoder not initialized. Call initializeChunkedDecoding first.');
    }

    try {
      // Use granule positions for seeking if available
      if (_granulePositions.isNotEmpty) {
        return await _seekUsingGranulePositions(position);
      } else {
        // Approximate seeking using page timestamps
        return await _approximateSeekUsingPages(position);
      }
    } catch (e) {
      throw DecodingException('Failed to seek in OGG Vorbis file', 'Error seeking to $position: $e');
    }
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    // OGG pages are typically 4KB-8KB, so we want chunks that contain multiple pages
    const avgPageSize = 4096; // Typical OGG page size

    if (fileSize < 2 * 1024 * 1024) {
      // < 2MB
      return ChunkSizeRecommendation(
        recommendedSize: (fileSize * 0.4).clamp(avgPageSize * 8, 1024 * 1024).round(),
        minSize: avgPageSize * 4, // At least 4 pages
        maxSize: fileSize,
        reason: 'Small OGG Vorbis file - using 40% of file size to ensure page boundaries',
        metadata: {'format': 'OGG Vorbis', 'avgPageSize': avgPageSize, 'hasGranulePositions': _granulePositions.isNotEmpty},
      );
    } else if (fileSize < 50 * 1024 * 1024) {
      // < 50MB
      return ChunkSizeRecommendation(
        recommendedSize: 4 * 1024 * 1024, // 4MB
        minSize: 1024 * 1024, // 1MB
        maxSize: 15 * 1024 * 1024, // 15MB
        reason: 'Medium OGG Vorbis file - using 4MB chunks for optimal page processing',
        metadata: {'format': 'OGG Vorbis', 'avgPageSize': avgPageSize, 'hasGranulePositions': _granulePositions.isNotEmpty},
      );
    } else {
      // >= 50MB
      return ChunkSizeRecommendation(
        recommendedSize: 8 * 1024 * 1024, // 8MB
        minSize: 2 * 1024 * 1024, // 2MB
        maxSize: 30 * 1024 * 1024, // 30MB
        reason: 'Large OGG Vorbis file - using 8MB chunks for memory efficiency',
        metadata: {'format': 'OGG Vorbis', 'avgPageSize': avgPageSize, 'hasGranulePositions': _granulePositions.isNotEmpty},
      );
    }
  }

  @override
  bool get supportsEfficientSeeking => _granulePositions.isNotEmpty; // Efficient if granule positions available

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
      'format': 'OGG Vorbis',
      'sampleRate': _sampleRate,
      'channels': _channels,
      'duration': _totalDuration?.inMilliseconds,
      'pageCount': _pageOffsets.length,
      'hasGranulePositions': _granulePositions.isNotEmpty,
      'supportsSeekTable': false, // OGG uses granule positions instead
      'seekingAccuracy': _granulePositions.isNotEmpty ? 'good' : 'approximate',
      'avgPageSize': 4096,
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
        final audioData = NativeAudioBindings.decodeAudio(fileData, AudioFormat.ogg);
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
    _pageOffsets.clear();
    _pageTimestamps.clear();
    _granulePositions.clear();
  }

  // Helper methods for OGG Vorbis-specific processing

  Future<void> _parseOGGPages(Uint8List fileData) async {
    _pageOffsets.clear();
    _pageTimestamps.clear();
    _granulePositions.clear();

    // Simplified OGG page parsing
    // In a real implementation, this would parse actual OGG page headers

    // Look for OGG page signatures (OggS)
    int offset = 0;
    int pageIndex = 0;

    while (offset < fileData.length - 27) {
      // OGG page header is at least 27 bytes
      // Look for OGG page signature
      if (fileData[offset] == 0x4F && fileData[offset + 1] == 0x67 && fileData[offset + 2] == 0x67 && fileData[offset + 3] == 0x53) {
        _pageOffsets.add(offset);

        // Extract granule position (simplified - would need proper parsing)
        final granulePos = _readLittleEndian64(fileData, offset + 6);
        _granulePositions.add(granulePos);

        // Calculate timestamp based on granule position and sample rate
        if (_sampleRate > 0 && granulePos >= 0) {
          final timestamp = Duration(milliseconds: (granulePos * 1000 / _sampleRate).round());
          _pageTimestamps.add(timestamp);
        } else {
          // Estimate timestamp based on page index
          final estimatedTimestamp = Duration(
            milliseconds: (pageIndex * 1000).round(), // Rough estimate
          );
          _pageTimestamps.add(estimatedTimestamp);
        }

        // Skip to next potential page (simplified)
        offset += 4096; // Average page size
        pageIndex++;
      } else {
        offset++;
      }
    }
  }

  List<Uint8List> _findOGGPagesInChunk(FileChunk fileChunk) {
    final pages = <Uint8List>[];

    // Simplified OGG page detection
    // In a real implementation, this would scan for OGG page signatures and parse headers

    int offset = 0;
    while (offset < fileChunk.data.length - 27) {
      // Look for OGG page signature
      if (fileChunk.data[offset] == 0x4F && fileChunk.data[offset + 1] == 0x67 && fileChunk.data[offset + 2] == 0x67 && fileChunk.data[offset + 3] == 0x53) {
        // Extract page (simplified - would need proper page length parsing)
        const avgPageSize = 4096;
        final pageEnd = (offset + avgPageSize).clamp(0, fileChunk.data.length);

        final pageData = Uint8List.sublistView(fileChunk.data, offset, pageEnd);
        pages.add(pageData);

        offset = pageEnd;
      } else {
        offset++;
      }
    }

    return pages;
  }

  Future<SeekResult> _seekUsingGranulePositions(Duration position) async {
    final targetMs = position.inMilliseconds;

    // Find the closest granule position
    int closestIndex = 0;
    int closestTimeDiff = (targetMs - _pageTimestamps[0].inMilliseconds).abs();

    for (int i = 1; i < _pageTimestamps.length; i++) {
      final timeDiff = (targetMs - _pageTimestamps[i].inMilliseconds).abs();
      if (timeDiff < closestTimeDiff) {
        closestTimeDiff = timeDiff;
        closestIndex = i;
      }
    }

    final actualPosition = _pageTimestamps[closestIndex];
    final bytePosition = _pageOffsets[closestIndex];
    _currentPosition = actualPosition;

    // OGG seeking with granule positions is reasonably accurate
    final isExact = closestTimeDiff < 200; // Consider exact if within 200ms

    return SeekResult(
      actualPosition: actualPosition,
      bytePosition: bytePosition,
      isExact: isExact,
      warning: isExact ? null : 'OGG Vorbis seeking accuracy depends on page granularity',
    );
  }

  Future<SeekResult> _approximateSeekUsingPages(Duration position) async {
    // Approximate seeking using page positions
    final targetMs = position.inMilliseconds;
    final totalMs = _totalDuration?.inMilliseconds ?? 0;

    if (totalMs == 0 || _pageOffsets.isEmpty) {
      throw DecodingException('Cannot seek without duration or page information', 'OGG Vorbis file structure unknown');
    }

    final ratio = targetMs / totalMs;
    final pageIndex = (ratio * _pageOffsets.length).round().clamp(0, _pageOffsets.length - 1);

    final actualPosition = _pageTimestamps.isNotEmpty ? _pageTimestamps[pageIndex] : position;
    final bytePosition = _pageOffsets[pageIndex];
    _currentPosition = actualPosition;

    return SeekResult(
      actualPosition: actualPosition,
      bytePosition: bytePosition,
      isExact: false,
      warning: 'Approximate seeking - granule positions not available',
    );
  }

  int _readLittleEndian64(Uint8List data, int offset) {
    // Simplified 64-bit read (would need proper implementation for full range)
    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24);
  }
}
