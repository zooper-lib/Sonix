/// Data models for chunked audio processing
library;

/// Result of a seek operation in chunked processing
class SeekResult {
  /// The actual position that was seeked to
  final Duration actualPosition;

  /// The byte position in the file corresponding to the actual position
  final int bytePosition;

  /// Whether the seek was exact or approximate
  final bool isExact;

  /// Optional warning message if the seek was not exact
  final String? warning;

  const SeekResult({required this.actualPosition, required this.bytePosition, required this.isExact, this.warning});

  @override
  String toString() {
    return 'SeekResult(actualPosition: $actualPosition, bytePosition: $bytePosition, '
        'isExact: $isExact, warning: $warning)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeekResult &&
        other.actualPosition == actualPosition &&
        other.bytePosition == bytePosition &&
        other.isExact == isExact &&
        other.warning == warning;
  }

  @override
  int get hashCode {
    return Object.hash(actualPosition, bytePosition, isExact, warning);
  }
}

/// Recommendation for optimal chunk size based on format and file characteristics
class ChunkSizeRecommendation {
  /// The recommended chunk size in bytes
  final int recommendedSize;

  /// The minimum safe chunk size in bytes
  final int minSize;

  /// The maximum efficient chunk size in bytes
  final int maxSize;

  /// Explanation for the recommendation
  final String reason;

  /// Format-specific metadata that influenced the recommendation
  final Map<String, dynamic>? metadata;

  const ChunkSizeRecommendation({required this.recommendedSize, required this.minSize, required this.maxSize, required this.reason, this.metadata});

  /// Create a recommendation for small files
  factory ChunkSizeRecommendation.forSmallFile(int fileSize) {
    return ChunkSizeRecommendation(
      recommendedSize: (fileSize * 0.25).clamp(1024, 1024 * 1024).round(), // 25% of file, 1KB-1MB
      minSize: 1024, // 1KB
      maxSize: fileSize,
      reason: 'Small file optimization - using 25% of file size',
    );
  }

  /// Create a recommendation for large files
  factory ChunkSizeRecommendation.forLargeFile(int fileSize) {
    return ChunkSizeRecommendation(
      recommendedSize: 10 * 1024 * 1024, // 10MB
      minSize: 1024 * 1024, // 1MB
      maxSize: 50 * 1024 * 1024, // 50MB
      reason: 'Large file optimization - using fixed 10MB chunks',
    );
  }

  /// Create a recommendation based on available memory
  factory ChunkSizeRecommendation.forMemoryConstraint(int availableMemory) {
    final recommendedSize = (availableMemory * 0.1).clamp(1024, 10 * 1024 * 1024).round(); // 10% of available memory
    return ChunkSizeRecommendation(
      recommendedSize: recommendedSize,
      minSize: 1024, // 1KB
      maxSize: (availableMemory * 0.25).round(), // 25% of available memory
      reason: 'Memory constraint optimization - using 10% of available memory',
    );
  }

  @override
  String toString() {
    return 'ChunkSizeRecommendation(recommendedSize: ${recommendedSize ~/ 1024}KB, '
        'minSize: ${minSize ~/ 1024}KB, maxSize: ${maxSize ~/ 1024}KB, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChunkSizeRecommendation &&
        other.recommendedSize == recommendedSize &&
        other.minSize == minSize &&
        other.maxSize == maxSize &&
        other.reason == reason;
  }

  @override
  int get hashCode {
    return Object.hash(recommendedSize, minSize, maxSize, reason);
  }
}
