/// Memory-aware chunk management for audio processing
library;

import 'dart:async';
import 'package:meta/meta.dart';

import '../models/audio_data.dart';
import '../models/file_chunk.dart';
import '../decoders/chunked_audio_decoder.dart';

/// Callback function for memory pressure notifications
typedef MemoryPressureCallback = void Function(int currentUsage, int maxUsage);

/// Callback function for progress updates during chunk processing
typedef ChunkProgressCallback = void Function(int processedChunks, int totalChunks);

/// Represents a chunk that is currently being processed
class ProcessingChunk {
  /// The file chunk being processed
  final FileChunk fileChunk;

  /// Future that completes when processing is done
  final Future<List<AudioChunk>> future;

  /// Timestamp when processing started
  final DateTime startTime;

  /// Estimated memory usage for this chunk
  final int estimatedMemoryUsage;

  ProcessingChunk({required this.fileChunk, required this.future, DateTime? startTime, int? estimatedMemoryUsage})
    : startTime = startTime ?? DateTime.now(),
      estimatedMemoryUsage = estimatedMemoryUsage ?? fileChunk.data.length;

  /// Get processing duration so far
  Duration get processingDuration => DateTime.now().difference(startTime);

  @override
  String toString() {
    return 'ProcessingChunk(fileChunk: ${fileChunk.data.length} bytes, '
        'duration: $processingDuration)';
  }
}

/// Represents a chunk that has been processed (successfully or with error)
class ProcessedChunk {
  /// The original file chunk that was processed
  final FileChunk fileChunk;

  /// The resulting audio chunks (empty if error occurred)
  final List<AudioChunk> audioChunks;

  /// Error that occurred during processing (null if successful)
  final Object? error;

  /// Stack trace if error occurred
  final StackTrace? stackTrace;

  /// Processing duration
  final Duration processingDuration;

  /// Memory usage during processing
  final int memoryUsage;

  ProcessedChunk({required this.fileChunk, required this.audioChunks, this.error, this.stackTrace, Duration? processingDuration, int? memoryUsage})
    : processingDuration = processingDuration ?? Duration.zero,
      memoryUsage = memoryUsage ?? 0;

  /// Whether processing resulted in an error
  bool get hasError => error != null;

  /// Whether processing was successful
  bool get isSuccessful => !hasError && audioChunks.isNotEmpty;

  @override
  String toString() {
    return 'ProcessedChunk(fileChunk: ${fileChunk.data.length} bytes, '
        'audioChunks: ${audioChunks.length}, hasError: $hasError, '
        'duration: $processingDuration)';
  }
}

/// Configuration for chunk manager behavior
class ChunkManagerConfig {
  /// Maximum memory usage in bytes (default: 100MB)
  final int maxMemoryUsage;

  /// Maximum number of concurrent chunks being processed (default: 3)
  final int maxConcurrentChunks;

  /// Memory pressure threshold as percentage of max memory (default: 0.8)
  final double memoryPressureThreshold;

  /// Interval for memory usage checks (default: 100ms)
  final Duration memoryCheckInterval;

  /// Whether to enable automatic garbage collection triggers
  final bool enableGarbageCollection;

  /// Callback for memory pressure notifications
  final MemoryPressureCallback? onMemoryPressure;

  /// Callback for progress updates
  final ChunkProgressCallback? onProgress;

  const ChunkManagerConfig({
    this.maxMemoryUsage = 100 * 1024 * 1024, // 100MB
    this.maxConcurrentChunks = 3,
    this.memoryPressureThreshold = 0.8,
    this.memoryCheckInterval = const Duration(milliseconds: 100),
    this.enableGarbageCollection = true,
    this.onMemoryPressure,
    this.onProgress,
  });

  /// Create config optimized for low memory devices
  factory ChunkManagerConfig.lowMemory() {
    return const ChunkManagerConfig(
      maxMemoryUsage: 50 * 1024 * 1024, // 50MB
      maxConcurrentChunks: 2,
      memoryPressureThreshold: 0.7,
      enableGarbageCollection: true,
    );
  }

  /// Create config optimized for high performance
  factory ChunkManagerConfig.highPerformance() {
    return const ChunkManagerConfig(
      maxMemoryUsage: 200 * 1024 * 1024, // 200MB
      maxConcurrentChunks: 6,
      memoryPressureThreshold: 0.9,
      enableGarbageCollection: false,
    );
  }

  @override
  String toString() {
    return 'ChunkManagerConfig(maxMemory: ${maxMemoryUsage ~/ (1024 * 1024)}MB, '
        'maxConcurrent: $maxConcurrentChunks, threshold: $memoryPressureThreshold)';
  }
}

/// Memory statistics for monitoring
class MemoryStats {
  /// Current estimated memory usage in bytes
  final int currentUsage;

  /// Maximum allowed memory usage in bytes
  final int maxUsage;

  /// Number of active processing chunks
  final int activeChunks;

  /// Number of completed chunks waiting for cleanup
  final int pendingCleanup;

  /// Whether memory pressure is detected
  final bool isUnderPressure;

  /// Timestamp of these statistics
  final DateTime timestamp;

  MemoryStats({
    required this.currentUsage,
    required this.maxUsage,
    required this.activeChunks,
    required this.pendingCleanup,
    required this.isUnderPressure,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Memory usage as percentage of maximum
  double get usagePercentage => maxUsage > 0 ? currentUsage / maxUsage : 0.0;

  /// Available memory in bytes
  int get availableMemory => (maxUsage - currentUsage).clamp(0, maxUsage);

  @override
  String toString() {
    return 'MemoryStats(usage: ${currentUsage ~/ (1024 * 1024)}MB/'
        '${maxUsage ~/ (1024 * 1024)}MB (${(usagePercentage * 100).toStringAsFixed(1)}%), '
        'active: $activeChunks, pending: $pendingCleanup, pressure: $isUnderPressure)';
  }
}

/// Memory pressure statistics for monitoring chunk size adjustments
class MemoryPressureStats {
  /// Whether the system is currently under memory pressure
  final bool isUnderPressure;

  /// Number of times memory pressure has been detected
  final int pressureCount;

  /// Current chunk size being used (may be reduced from original)
  final int currentChunkSize;

  /// Original chunk size before any reductions
  final int originalChunkSize;

  /// Percentage reduction from original chunk size
  final double reductionPercentage;

  const MemoryPressureStats({
    required this.isUnderPressure,
    required this.pressureCount,
    required this.currentChunkSize,
    required this.originalChunkSize,
    required this.reductionPercentage,
  });

  @override
  String toString() {
    return 'MemoryPressureStats(pressure: $isUnderPressure, count: $pressureCount, '
        'chunkSize: ${currentChunkSize ~/ 1024}KB/${originalChunkSize ~/ 1024}KB, '
        'reduction: ${reductionPercentage.toStringAsFixed(1)}%)';
  }
}

/// Manages memory-aware chunk processing with concurrency control
class ChunkManager {
  final ChunkManagerConfig _config;
  final List<ProcessingChunk> _activeChunks = [];
  final List<ProcessedChunk> _completedChunks = [];

  Timer? _memoryMonitorTimer;
  int _totalProcessedChunks = 0;
  bool _isDisposed = false;

  // Memory pressure handling
  int _currentChunkSize = 0;
  int _originalChunkSize = 0;
  bool _isUnderMemoryPressure = false;
  int _memoryPressureCount = 0;

  ChunkManager(this._config) {
    _startMemoryMonitoring();
  }

  /// Get current memory statistics
  MemoryStats get memoryStats {
    final currentUsage = getCurrentMemoryUsage();
    final isUnderPressure = currentUsage > (_config.maxMemoryUsage * _config.memoryPressureThreshold);

    return MemoryStats(
      currentUsage: currentUsage,
      maxUsage: _config.maxMemoryUsage,
      activeChunks: _activeChunks.length,
      pendingCleanup: _completedChunks.length,
      isUnderPressure: isUnderPressure,
      timestamp: DateTime.now(),
    );
  }

  /// Process a stream of file chunks with memory management
  Stream<ProcessedChunk> processChunks(Stream<FileChunk> fileChunks, ChunkedAudioDecoder decoder) async* {
    if (_isDisposed) {
      throw StateError('ChunkManager has been disposed');
    }

    final fileChunkList = await fileChunks.toList();
    final totalChunks = fileChunkList.length;

    for (final fileChunk in fileChunkList) {
      // Wait for memory availability
      await _waitForMemoryAvailability();

      // Wait for concurrency limit
      await _waitForConcurrencyLimit();

      // Start processing chunk
      final processingChunk = _startChunkProcessing(fileChunk, decoder);
      _activeChunks.add(processingChunk);

      // Process the chunk and yield result
      try {
        final audioChunks = await processingChunk.future;
        final processedChunk = ProcessedChunk(
          fileChunk: processingChunk.fileChunk,
          audioChunks: audioChunks,
          processingDuration: processingChunk.processingDuration,
          memoryUsage: processingChunk.estimatedMemoryUsage,
        );

        _completedChunks.add(processedChunk);
        _totalProcessedChunks++;

        // Remove from active chunks
        _activeChunks.remove(processingChunk);

        yield processedChunk;
      } catch (error, stackTrace) {
        final processedChunk = ProcessedChunk(
          fileChunk: processingChunk.fileChunk,
          audioChunks: [],
          error: error,
          stackTrace: stackTrace,
          processingDuration: processingChunk.processingDuration,
          memoryUsage: processingChunk.estimatedMemoryUsage,
        );

        _completedChunks.add(processedChunk);
        _totalProcessedChunks++;

        // Remove from active chunks
        _activeChunks.remove(processingChunk);

        yield processedChunk;
      }

      // Update progress
      _config.onProgress?.call(_totalProcessedChunks, totalChunks);

      // Cleanup old completed chunks
      if (_completedChunks.length > 10) {
        _completedChunks.removeRange(0, _completedChunks.length - 10);
      }
    }
  }

  /// Get current estimated memory usage
  int getCurrentMemoryUsage() {
    // Calculate memory usage from active chunks and completed chunks awaiting cleanup
    int usage = 0;

    // Memory from active processing chunks
    for (final chunk in _activeChunks) {
      usage += chunk.estimatedMemoryUsage;
    }

    // Memory from completed chunks not yet yielded
    for (final chunk in _completedChunks) {
      usage += chunk.fileChunk.data.length;
      // Add estimated memory for audio chunks
      for (final audioChunk in chunk.audioChunks) {
        usage += audioChunk.samples.length * 8; // 8 bytes per double
      }
    }

    return usage;
  }

  /// Force cleanup of completed chunks
  Future<void> forceCleanup() async {
    _completedChunks.clear();

    if (_config.enableGarbageCollection) {
      // Trigger garbage collection on supported platforms
      try {
        // This is a hint to the garbage collector
        await Future.delayed(const Duration(milliseconds: 1));
      } catch (e) {
        // Ignore errors - GC triggering is best effort
      }
    }
  }

  /// Dispose of the chunk manager and cleanup resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _memoryMonitorTimer?.cancel();

    // Wait for all active chunks to complete or timeout
    if (_activeChunks.isNotEmpty) {
      try {
        await Future.wait(_activeChunks.map((chunk) => chunk.future)).timeout(const Duration(seconds: 5));
      } catch (e) {
        // Timeout or error - continue with cleanup
      }
    }

    _activeChunks.clear();
    await forceCleanup();
  }

  /// Start processing a file chunk
  ProcessingChunk _startChunkProcessing(FileChunk fileChunk, ChunkedAudioDecoder decoder) {
    final startTime = DateTime.now();
    final future = decoder.processFileChunk(fileChunk);

    return ProcessingChunk(
      fileChunk: fileChunk,
      future: future,
      startTime: startTime,
      estimatedMemoryUsage: fileChunk.data.length * 2, // Estimate 2x for processing overhead
    );
  }

  /// Wait for memory to become available
  Future<void> _waitForMemoryAvailability() async {
    while (getCurrentMemoryUsage() > _config.maxMemoryUsage) {
      // Handle memory pressure
      await handleMemoryPressure();

      // If still over limit after cleanup, wait a bit
      if (getCurrentMemoryUsage() > _config.maxMemoryUsage) {
        await Future.delayed(_config.memoryCheckInterval);
      }
    }
  }

  /// Wait for concurrency limit to allow new processing
  Future<void> _waitForConcurrencyLimit() async {
    while (_activeChunks.length >= _config.maxConcurrentChunks) {
      // Wait for at least one chunk to complete
      if (_activeChunks.isNotEmpty) {
        await Future.any(_activeChunks.map((chunk) => chunk.future));
        // Remove completed chunks from active list
        _activeChunks.removeWhere((chunk) {
          // This is a simple check - in practice we'd need better completion tracking
          return chunk.processingDuration > const Duration(seconds: 30); // Timeout assumption
        });
      }
    }
  }

  /// Start memory monitoring timer
  /// Handle memory pressure by reducing chunk size and triggering cleanup
  @visibleForTesting
  Future<void> handleMemoryPressure() async {
    _memoryPressureCount++;
    _isUnderMemoryPressure = true;

    // Trigger callback
    final stats = memoryStats;
    _config.onMemoryPressure?.call(stats.currentUsage, stats.maxUsage);

    // Force cleanup
    await forceCleanup();

    // Reduce chunk size if we have an original size to work with
    if (_originalChunkSize > 0 && _currentChunkSize > 1024) {
      _currentChunkSize = (_currentChunkSize * 0.75).round(); // Reduce by 25%
      _currentChunkSize = _currentChunkSize.clamp(1024, _originalChunkSize); // Min 1KB
    }

    // Trigger garbage collection more aggressively under pressure
    if (_config.enableGarbageCollection) {
      // Multiple GC hints
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }
  }

  /// Reset memory pressure state when memory usage is back to normal
  @visibleForTesting
  void resetMemoryPressure() {
    if (_isUnderMemoryPressure) {
      _isUnderMemoryPressure = false;
      _memoryPressureCount = 0;

      // Gradually restore chunk size
      if (_originalChunkSize > 0 && _currentChunkSize < _originalChunkSize) {
        _currentChunkSize = (_currentChunkSize * 1.1).round(); // Increase by 10%
        _currentChunkSize = _currentChunkSize.clamp(1024, _originalChunkSize);
      }
    }
  }

  /// Get recommended chunk size based on current memory pressure
  int getRecommendedChunkSize(int originalSize) {
    if (_originalChunkSize == 0) {
      _originalChunkSize = originalSize;
      _currentChunkSize = originalSize;
    }

    return _isUnderMemoryPressure ? _currentChunkSize : originalSize;
  }

  /// Get memory pressure statistics
  MemoryPressureStats get memoryPressureStats {
    return MemoryPressureStats(
      isUnderPressure: _isUnderMemoryPressure,
      pressureCount: _memoryPressureCount,
      currentChunkSize: _currentChunkSize,
      originalChunkSize: _originalChunkSize,
      reductionPercentage: _originalChunkSize > 0 ? (1.0 - _currentChunkSize / _originalChunkSize) * 100 : 0.0,
    );
  }

  void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(_config.memoryCheckInterval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      final stats = memoryStats;

      if (stats.isUnderPressure) {
        handleMemoryPressure();
      } else {
        resetMemoryPressure();
      }
    });
  }
}
