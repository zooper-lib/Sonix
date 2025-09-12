import '../models/file_chunk.dart';
import '../models/chunk_boundary.dart';

/// Abstract base class for format-specific chunk parsing
abstract class FormatChunkParser {
  /// The audio format this parser handles
  String get format;

  /// Parse chunk boundaries within a file chunk for optimal decoding
  List<ChunkBoundary> parseChunkBoundaries(FileChunk fileChunk);

  /// Find the next valid seek point from a given position
  /// Returns the absolute position of the next seek point, or -1 if none found
  Future<int> findNextSeekPoint(int fromPosition);

  /// Validate chunk integrity and format compliance
  ChunkValidationResult validateChunk(FileChunk chunk);

  /// Extract format-specific metadata from a chunk
  FormatMetadata? extractMetadata(FileChunk chunk);

  /// Get recommended chunk size for this format based on file characteristics
  int getRecommendedChunkSize(int fileSize) {
    // Default implementation - can be overridden by specific parsers
    if (fileSize < 10 * 1024 * 1024) {
      // < 10MB
      return 1 * 1024 * 1024; // 1MB
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      return 5 * 1024 * 1024; // 5MB
    } else {
      return 10 * 1024 * 1024; // 10MB
    }
  }

  /// Check if this parser supports efficient seeking
  bool get supportsEfficientSeeking => true;

  /// Get the minimum chunk size this parser can handle effectively
  int get minimumChunkSize => 4096; // 4KB default

  /// Get the maximum chunk size this parser recommends
  int get maximumChunkSize => 50 * 1024 * 1024; // 50MB default
}
