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
