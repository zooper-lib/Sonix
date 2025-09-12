import 'dart:io';
import 'dart:typed_data';

import '../decoders/audio_decoder.dart';
import '../models/file_chunk.dart';
import '../exceptions/sonix_exceptions.dart';

/// A file reader that reads audio files in configurable chunks for memory-efficient processing
class ChunkedFileReader {
  /// Path to the audio file
  final String filePath;

  /// Size of each chunk in bytes
  final int chunkSize;

  /// Audio format of the file
  final AudioFormat format;

  /// Enable seeking capabilities
  final bool enableSeeking;

  /// Internal file handle
  RandomAccessFile? _file;

  /// Current read position in the file
  int _currentPosition = 0;

  /// Total file size in bytes
  int? _fileSize;

  /// Whether the file has been opened
  bool _isOpen = false;

  /// Whether end of file has been reached
  bool _isAtEnd = false;

  ChunkedFileReader({required this.filePath, required this.chunkSize, required this.format, this.enableSeeking = true}) {
    if (chunkSize <= 0) {
      throw ArgumentError('Chunk size must be positive');
    }
  }

  /// Get current read position in bytes
  int get currentPosition => _currentPosition;

  /// Check if end of file has been reached
  bool get isAtEnd => _isAtEnd;

  /// Get total file size (opens file if not already open)
  Future<int> getFileSize() async {
    if (_fileSize != null) return _fileSize!;

    await _ensureFileOpen();
    _fileSize = await _file!.length();
    return _fileSize!;
  }

  /// Open the file for reading
  Future<void> _ensureFileOpen() async {
    if (_isOpen && _file != null) return;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw SonixFileException('File not found: $filePath');
      }

      _file = await file.open(mode: FileMode.read);
      _isOpen = true;
      _fileSize = await _file!.length();

      // If we're not at the beginning, seek to current position
      if (_currentPosition > 0) {
        await _file!.setPosition(_currentPosition);
      }
    } catch (e) {
      throw SonixFileException('Failed to open file: $filePath - $e');
    }
  }

  /// Read the next chunk from the current position
  Future<FileChunk?> readNextChunk() async {
    if (_isAtEnd) return null;

    await _ensureFileOpen();

    try {
      final fileSize = await getFileSize();

      // Check if we're at the end
      if (_currentPosition >= fileSize) {
        _isAtEnd = true;
        return null;
      }

      // Calculate actual chunk size (may be smaller for last chunk)
      final remainingBytes = fileSize - _currentPosition;
      final actualChunkSize = remainingBytes > chunkSize ? chunkSize : remainingBytes;

      // Read the data
      final data = await _file!.read(actualChunkSize);

      if (data.isEmpty) {
        _isAtEnd = true;
        return null;
      }

      final startPosition = _currentPosition;
      _currentPosition += data.length;

      // Check if this is the last chunk
      final isLast = _currentPosition >= fileSize;
      if (isLast) {
        _isAtEnd = true;
      }

      return FileChunk(
        data: Uint8List.fromList(data),
        startPosition: startPosition,
        endPosition: _currentPosition,
        isLast: isLast,
        isSeekPoint: _isFormatBoundary(startPosition),
      );
    } catch (e) {
      throw SonixFileException('Failed to read chunk from $filePath: $e');
    }
  }

  /// Seek to a specific byte position in the file
  Future<void> seekToPosition(int bytePosition) async {
    if (!enableSeeking) {
      throw SonixUnsupportedOperationException('Seeking is disabled for this reader');
    }

    if (bytePosition < 0) {
      throw ArgumentError('Byte position cannot be negative');
    }

    await _ensureFileOpen();

    try {
      final fileSize = await getFileSize();

      // Clamp position to file bounds
      final clampedPosition = bytePosition > fileSize ? fileSize : bytePosition;

      await _file!.setPosition(clampedPosition);
      _currentPosition = clampedPosition;
      _isAtEnd = _currentPosition >= fileSize;
    } catch (e) {
      throw SonixFileException('Failed to seek to position $bytePosition in $filePath: $e');
    }
  }

  /// Seek to an approximate time position (format-specific implementation needed)
  Future<void> seekToTime(Duration position) async {
    if (!enableSeeking) {
      throw SonixUnsupportedOperationException('Seeking is disabled for this reader');
    }

    // This is a basic implementation that assumes constant bitrate
    // Format-specific implementations should override this for better accuracy
    final fileSize = await getFileSize();

    // For now, use a simple linear approximation
    // This should be enhanced with format-specific seeking logic
    final estimatedPosition = _estimateBytePositionFromTime(position, fileSize);
    await seekToPosition(estimatedPosition);
  }

  /// Reset the reader to the beginning of the file
  Future<void> reset() async {
    await seekToPosition(0);
  }

  /// Close the file and cleanup resources
  Future<void> close() async {
    if (_file != null) {
      try {
        await _file!.close();
      } catch (e) {
        // Log error but don't throw - cleanup should be safe
      }
      _file = null;
    }
    _isOpen = false;
    _currentPosition = 0;
    _isAtEnd = false;
    _fileSize = null;
  }

  /// Check if the current position is at a format-specific boundary
  /// This is a placeholder - format-specific parsers should provide this logic
  bool _isFormatBoundary(int position) {
    // For now, consider the beginning of the file and chunk-aligned positions as boundaries
    // Format-specific implementations should provide proper boundary detection
    return position == 0 || position % chunkSize == 0;
  }

  /// Estimate byte position from time position (basic implementation)
  int _estimateBytePositionFromTime(Duration position, int fileSize) {
    // This is a very basic estimation assuming uniform distribution
    // Format-specific implementations should use proper metadata

    // For now, assume a typical audio file duration and calculate proportionally
    // This should be replaced with format-specific duration calculation
    const estimatedDurationSeconds = 180; // 3 minutes default assumption
    final positionSeconds = position.inMilliseconds / 1000.0;
    final ratio = positionSeconds / estimatedDurationSeconds;

    return (fileSize * ratio).clamp(0, fileSize).round();
  }

  /// Create a stream of file chunks
  Stream<FileChunk> readChunks() async* {
    try {
      FileChunk? chunk;
      while ((chunk = await readNextChunk()) != null) {
        yield chunk!;
      }
    } finally {
      await close();
    }
  }

  /// Get information about the file and reader configuration
  Future<ChunkedFileReaderInfo> getInfo() async {
    final fileSize = await getFileSize();
    final estimatedChunks = (fileSize / chunkSize).ceil();

    return ChunkedFileReaderInfo(
      filePath: filePath,
      fileSize: fileSize,
      chunkSize: chunkSize,
      format: format,
      currentPosition: _currentPosition,
      isAtEnd: _isAtEnd,
      estimatedTotalChunks: estimatedChunks,
      enableSeeking: enableSeeking,
    );
  }
}

/// Information about a ChunkedFileReader instance
class ChunkedFileReaderInfo {
  /// Path to the file being read
  final String filePath;

  /// Total file size in bytes
  final int fileSize;

  /// Configured chunk size in bytes
  final int chunkSize;

  /// Audio format of the file
  final AudioFormat format;

  /// Current read position in bytes
  final int currentPosition;

  /// Whether end of file has been reached
  final bool isAtEnd;

  /// Estimated total number of chunks
  final int estimatedTotalChunks;

  /// Whether seeking is enabled
  final bool enableSeeking;

  const ChunkedFileReaderInfo({
    required this.filePath,
    required this.fileSize,
    required this.chunkSize,
    required this.format,
    required this.currentPosition,
    required this.isAtEnd,
    required this.estimatedTotalChunks,
    required this.enableSeeking,
  });

  /// Progress as a percentage (0.0 to 1.0)
  double get progress => fileSize > 0 ? currentPosition / fileSize : 0.0;

  /// Number of chunks read so far
  int get chunksRead => (currentPosition / chunkSize).floor();

  /// Estimated remaining chunks
  int get estimatedRemainingChunks => estimatedTotalChunks - chunksRead;

  @override
  String toString() {
    return 'ChunkedFileReaderInfo('
        'filePath: $filePath, '
        'fileSize: $fileSize, '
        'chunkSize: $chunkSize, '
        'format: $format, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'chunksRead: $chunksRead/$estimatedTotalChunks'
        ')';
  }
}

/// Factory for creating ChunkedFileReader instances with optimal configurations
class ChunkedFileReaderFactory {
  /// Create a reader with automatic configuration based on file size
  static Future<ChunkedFileReader> createForFile(String filePath, {AudioFormat? format, int? chunkSize, bool enableSeeking = true}) async {
    // Detect format if not provided
    final detectedFormat = format ?? _detectFormatFromPath(filePath);

    // Get file size for optimal chunk size calculation
    final file = File(filePath);
    if (!await file.exists()) {
      throw SonixFileException('File not found: $filePath');
    }

    final fileSize = await file.length();

    // Calculate optimal chunk size if not provided
    final optimalChunkSize = chunkSize ?? _calculateOptimalChunkSize(fileSize, detectedFormat);

    return ChunkedFileReader(filePath: filePath, chunkSize: optimalChunkSize, format: detectedFormat, enableSeeking: enableSeeking);
  }

  /// Detect audio format from file path
  static AudioFormat _detectFormatFromPath(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    switch (extension) {
      case 'mp3':
        return AudioFormat.mp3;
      case 'wav':
        return AudioFormat.wav;
      case 'flac':
        return AudioFormat.flac;
      case 'ogg':
        return AudioFormat.ogg;
      case 'opus':
        return AudioFormat.opus;
      default:
        return AudioFormat.unknown;
    }
  }

  /// Calculate optimal chunk size based on file size and format
  static int _calculateOptimalChunkSize(int fileSize, AudioFormat format) {
    // Base chunk sizes for different file sizes
    int baseChunkSize;

    if (fileSize < 10 * 1024 * 1024) {
      // < 10MB
      baseChunkSize = 1 * 1024 * 1024; // 1MB
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      baseChunkSize = 5 * 1024 * 1024; // 5MB
    } else {
      // >= 100MB
      baseChunkSize = 10 * 1024 * 1024; // 10MB
    }

    // Adjust for format-specific considerations
    switch (format) {
      case AudioFormat.flac:
        // FLAC blocks are typically larger, so use larger chunks
        return (baseChunkSize * 1.5).round();
      case AudioFormat.wav:
        // WAV has simple structure, can use smaller chunks efficiently
        return (baseChunkSize * 0.8).round();
      case AudioFormat.mp3:
      case AudioFormat.ogg:
      case AudioFormat.opus:
        // Compressed formats benefit from moderate chunk sizes
        return baseChunkSize;
      case AudioFormat.unknown:
        // Conservative approach for unknown formats
        return (baseChunkSize * 0.5).round();
    }
  }
}
