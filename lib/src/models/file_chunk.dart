import 'dart:typed_data';

/// Represents a chunk of raw file data for chunked processing
class FileChunk {
  /// Raw file data for this chunk
  final Uint8List data;

  /// Starting byte position in the file
  final int startPosition;

  /// Ending byte position in the file
  final int endPosition;

  /// Whether this is the last chunk in the file
  final bool isLast;

  /// Whether this chunk starts at a format-specific boundary (e.g., MP3 frame, FLAC block)
  final bool isSeekPoint;

  /// Optional metadata associated with this chunk
  final Map<String, dynamic>? metadata;

  const FileChunk({required this.data, required this.startPosition, required this.endPosition, required this.isLast, this.isSeekPoint = false, this.metadata});

  /// Size of this chunk in bytes
  int get size => data.length;

  /// Create a copy of this chunk with modified properties
  FileChunk copyWith({Uint8List? data, int? startPosition, int? endPosition, bool? isLast, bool? isSeekPoint, Map<String, dynamic>? metadata}) {
    return FileChunk(
      data: data ?? this.data,
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      isLast: isLast ?? this.isLast,
      isSeekPoint: isSeekPoint ?? this.isSeekPoint,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'FileChunk(size: $size, startPosition: $startPosition, '
        'endPosition: $endPosition, isLast: $isLast, isSeekPoint: $isSeekPoint)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileChunk &&
        other.startPosition == startPosition &&
        other.endPosition == endPosition &&
        other.isLast == isLast &&
        other.isSeekPoint == isSeekPoint;
  }

  @override
  int get hashCode {
    return Object.hash(startPosition, endPosition, isLast, isSeekPoint);
  }
}

/// Validation result for a file chunk
class ChunkValidationResult {
  /// Whether the chunk is valid
  final bool isValid;

  /// Warning messages (non-critical issues)
  final List<String> warnings;

  /// Error messages (critical issues)
  final List<String> errors;

  const ChunkValidationResult({required this.isValid, this.warnings = const [], this.errors = const []});

  /// Create a valid result
  factory ChunkValidationResult.valid() {
    return const ChunkValidationResult(isValid: true);
  }

  /// Create an invalid result with errors
  factory ChunkValidationResult.invalid(List<String> errors, [List<String>? warnings]) {
    return ChunkValidationResult(isValid: false, errors: errors, warnings: warnings ?? const []);
  }

  /// Whether there are any warnings
  bool get hasWarnings => warnings.isNotEmpty;

  /// Whether there are any errors
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    return 'ChunkValidationResult(isValid: $isValid, warnings: ${warnings.length}, errors: ${errors.length})';
  }
}

/// Utilities for working with file chunks
class FileChunkUtils {
  /// Validate basic chunk properties
  static ChunkValidationResult validateChunk(FileChunk chunk) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check basic properties
    if (chunk.startPosition < 0) {
      errors.add('Start position cannot be negative');
    }

    if (chunk.endPosition < chunk.startPosition) {
      errors.add('End position cannot be before start position');
    }

    if (chunk.data.isEmpty && !chunk.isLast) {
      warnings.add('Empty chunk data (not last chunk)');
    }

    if (chunk.size != (chunk.endPosition - chunk.startPosition)) {
      errors.add('Data size does not match position range');
    }

    return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings);
  }

  /// Split a large chunk into smaller chunks
  static List<FileChunk> splitChunk(FileChunk chunk, int maxChunkSize) {
    if (chunk.size <= maxChunkSize) {
      return [chunk];
    }

    final chunks = <FileChunk>[];
    int currentPosition = chunk.startPosition;
    int dataOffset = 0;

    while (dataOffset < chunk.data.length) {
      final remainingData = chunk.data.length - dataOffset;
      final chunkSize = remainingData > maxChunkSize ? maxChunkSize : remainingData;

      final chunkData = Uint8List.sublistView(chunk.data, dataOffset, dataOffset + chunkSize);

      final isLastSubChunk = dataOffset + chunkSize >= chunk.data.length;

      chunks.add(
        FileChunk(
          data: chunkData,
          startPosition: currentPosition,
          endPosition: currentPosition + chunkSize,
          isLast: chunk.isLast && isLastSubChunk,
          isSeekPoint: dataOffset == 0 ? chunk.isSeekPoint : false,
          metadata: chunk.metadata,
        ),
      );

      currentPosition += chunkSize;
      dataOffset += chunkSize;
    }

    return chunks;
  }

  /// Combine multiple chunks into a single chunk
  static FileChunk combineChunks(List<FileChunk> chunks) {
    if (chunks.isEmpty) {
      throw ArgumentError('Cannot combine empty chunk list');
    }

    if (chunks.length == 1) {
      return chunks.first;
    }

    // Sort chunks by start position
    final sortedChunks = List<FileChunk>.from(chunks)..sort((a, b) => a.startPosition.compareTo(b.startPosition));

    // Validate chunks are contiguous
    for (int i = 1; i < sortedChunks.length; i++) {
      if (sortedChunks[i].startPosition != sortedChunks[i - 1].endPosition) {
        throw ArgumentError('Chunks are not contiguous');
      }
    }

    // Combine data
    final totalSize = sortedChunks.fold<int>(0, (sum, chunk) => sum + chunk.size);
    final combinedData = Uint8List(totalSize);
    int offset = 0;

    for (final chunk in sortedChunks) {
      combinedData.setRange(offset, offset + chunk.size, chunk.data);
      offset += chunk.size;
    }

    return FileChunk(
      data: combinedData,
      startPosition: sortedChunks.first.startPosition,
      endPosition: sortedChunks.last.endPosition,
      isLast: sortedChunks.last.isLast,
      isSeekPoint: sortedChunks.first.isSeekPoint,
      metadata: sortedChunks.first.metadata,
    );
  }

  /// Extract a sub-chunk from a larger chunk
  static FileChunk extractSubChunk(FileChunk chunk, int startOffset, int length) {
    if (startOffset < 0 || startOffset >= chunk.size) {
      throw ArgumentError('Start offset out of bounds');
    }

    if (length <= 0 || startOffset + length > chunk.size) {
      throw ArgumentError('Invalid length');
    }

    final subData = Uint8List.sublistView(chunk.data, startOffset, startOffset + length);

    return FileChunk(
      data: subData,
      startPosition: chunk.startPosition + startOffset,
      endPosition: chunk.startPosition + startOffset + length,
      isLast: false, // Sub-chunks are never the last chunk
      isSeekPoint: startOffset == 0 ? chunk.isSeekPoint : false,
      metadata: chunk.metadata,
    );
  }
}
