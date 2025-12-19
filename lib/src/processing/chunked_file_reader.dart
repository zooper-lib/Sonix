import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Utility class for reading files in chunks.
///
/// This provides efficient chunked file reading for processing large audio files
/// without loading the entire file into memory at once.
class ChunkedFileReader {
  final String filePath;
  final int chunkSize;

  /// Create a chunked file reader.
  ///
  /// [filePath] - Path to the file to read
  /// [chunkSize] - Size of each chunk in bytes (default: 10MB)
  ChunkedFileReader(
    this.filePath, {
    this.chunkSize = 10 * 1024 * 1024,
  });

  /// Read the file in chunks and yield each chunk as a stream.
  ///
  /// Returns a [Stream] of [FileChunk] objects containing the data and metadata.
  ///
  /// Example:
  /// ```dart
  /// final reader = ChunkedFileReader('large.mp3', chunkSize: 5 * 1024 * 1024);
  /// await for (final chunk in reader.readChunks()) {
  ///   print('Read chunk ${chunk.index}: ${chunk.data.length} bytes');
  /// }
  /// ```
  Stream<FileChunk> readChunks() async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();

    var chunkIndex = 0;
    var offset = 0;

    final randomAccessFile = await file.open(mode: FileMode.read);

    try {
      while (offset < fileSize) {
        final remainingBytes = fileSize - offset;
        final bytesToRead = remainingBytes < chunkSize ? remainingBytes : chunkSize;

        await randomAccessFile.setPosition(offset);
        final bytes = await randomAccessFile.read(bytesToRead);

        yield FileChunk(
          data: Uint8List.fromList(bytes),
          index: chunkIndex,
          offset: offset,
          isLast: offset + bytesToRead >= fileSize,
          totalChunks: totalChunks,
          fileSize: fileSize,
        );

        chunkIndex++;
        offset += bytesToRead;
      }
    } finally {
      await randomAccessFile.close();
    }
  }

  /// Read the entire file and return all chunks as a list.
  ///
  /// This is less memory-efficient than using [readChunks] stream,
  /// but can be useful when you need all chunks at once.
  Future<List<FileChunk>> readAllChunks() async {
    return await readChunks().toList();
  }

  /// Get the total number of chunks that would be read.
  Future<int> getChunkCount() async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileSize = await file.length();
    return (fileSize / chunkSize).ceil();
  }
}

/// Represents a chunk of data read from a file.
class FileChunk {
  /// The actual data bytes
  final Uint8List data;

  /// Zero-based index of this chunk
  final int index;

  /// Byte offset in the original file where this chunk starts
  final int offset;

  /// Whether this is the last chunk in the file
  final bool isLast;

  /// Total number of chunks in the file
  final int totalChunks;

  /// Total size of the original file in bytes
  final int fileSize;

  FileChunk({
    required this.data,
    required this.index,
    required this.offset,
    required this.isLast,
    required this.totalChunks,
    required this.fileSize,
  });

  /// Get the progress percentage (0.0 to 1.0)
  double get progress => (index + 1) / totalChunks;

  /// Get the progress percentage as a string (e.g., "75.5%")
  String get progressString => '${(progress * 100).toStringAsFixed(1)}%';

  @override
  String toString() {
    return 'FileChunk(index: $index/$totalChunks, '
        'offset: $offset, '
        'size: ${data.length} bytes, '
        'progress: $progressString, '
        'isLast: $isLast)';
  }
}
