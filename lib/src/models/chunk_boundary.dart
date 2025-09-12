/// Represents a boundary within a file chunk for format-specific parsing
class ChunkBoundary {
  /// Absolute position in the file where this boundary occurs
  final int position;

  /// Type of boundary (frame start, block start, etc.)
  final BoundaryType type;

  /// Whether this boundary can be used as a seek point
  final bool isSeekable;

  /// Optional metadata associated with this boundary
  final Map<String, dynamic>? metadata;

  const ChunkBoundary({required this.position, required this.type, required this.isSeekable, this.metadata});

  @override
  String toString() {
    return 'ChunkBoundary(position: $position, type: $type, isSeekable: $isSeekable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChunkBoundary && other.position == position && other.type == type && other.isSeekable == isSeekable;
  }

  @override
  int get hashCode => Object.hash(position, type, isSeekable);
}

/// Types of boundaries that can be found in audio files
enum BoundaryType {
  /// Start of an audio frame (MP3, FLAC)
  frameStart,

  /// End of an audio frame
  frameEnd,

  /// Start of a data block (FLAC metadata blocks)
  blockStart,

  /// End of a data block
  blockEnd,

  /// Start of a page (OGG)
  pageStart,

  /// End of a page
  pageEnd,

  /// Start of a chunk (WAV, RIFF)
  chunkStart,

  /// End of a chunk
  chunkEnd,

  /// ID3 tag or other metadata
  metadata,

  /// Sync word or other synchronization marker
  syncMarker,
}

/// Format-specific metadata extracted from boundaries
class FormatMetadata {
  /// The audio format this metadata belongs to
  final String format;

  /// Metadata key-value pairs
  final Map<String, dynamic> data;

  const FormatMetadata({required this.format, required this.data});

  /// Get a specific metadata value
  T? getValue<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }

  /// Check if metadata contains a specific key
  bool hasKey(String key) => data.containsKey(key);

  @override
  String toString() {
    return 'FormatMetadata(format: $format, keys: ${data.keys.toList()})';
  }
}
