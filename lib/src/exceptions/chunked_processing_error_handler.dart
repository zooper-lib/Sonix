import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/file_chunk.dart';
import '../models/audio_data.dart';
import '../decoders/chunked_audio_decoder.dart';
import 'sonix_exceptions.dart';

/// Error recovery strategies for chunked processing
enum ErrorRecoveryStrategy {
  /// Skip the failed chunk and continue processing
  skipAndContinue,

  /// Retry with a smaller chunk size
  retryWithSmallerChunk,

  /// Seek to the next format-specific boundary
  seekToNextBoundary,

  /// Fail immediately without recovery
  failFast,
}

/// Context information for chunk processing errors
class ChunkErrorContext {
  /// The chunk that failed to process
  final FileChunk failedChunk;

  /// The original error that occurred
  final Object originalError;

  /// Stack trace of the original error
  final StackTrace? stackTrace;

  /// Position in the overall processing sequence
  final int chunkIndex;

  /// Total number of chunks being processed
  final int totalChunks;

  /// File path being processed
  final String filePath;

  /// Additional context metadata
  final Map<String, dynamic> metadata;

  /// Timestamp when the error occurred
  final DateTime timestamp;

  const ChunkErrorContext({
    required this.failedChunk,
    required this.originalError,
    this.stackTrace,
    required this.chunkIndex,
    required this.totalChunks,
    required this.filePath,
    this.metadata = const {},
    required this.timestamp,
  });

  ChunkErrorContext._withTimestamp({
    required this.failedChunk,
    required this.originalError,
    this.stackTrace,
    required this.chunkIndex,
    required this.totalChunks,
    required this.filePath,
    this.metadata = const {},
    required this.timestamp,
  });

  factory ChunkErrorContext.create({
    required FileChunk failedChunk,
    required Object originalError,
    StackTrace? stackTrace,
    required int chunkIndex,
    required int totalChunks,
    required String filePath,
    Map<String, dynamic> metadata = const {},
  }) {
    return ChunkErrorContext._withTimestamp(
      failedChunk: failedChunk,
      originalError: originalError,
      stackTrace: stackTrace,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      filePath: filePath,
      metadata: metadata,
      timestamp: DateTime.now(),
    );
  }

  /// Progress percentage when error occurred
  double get progressPercentage => totalChunks > 0 ? chunkIndex / totalChunks : 0.0;

  @override
  String toString() {
    return 'ChunkErrorContext(chunkIndex: $chunkIndex/$totalChunks, '
        'chunk: ${failedChunk.startPosition}-${failedChunk.endPosition}, '
        'error: $originalError)';
  }
}

/// Result of a chunk error recovery attempt
class ChunkRecoveryResult {
  /// Whether the recovery was successful
  final bool isSuccessful;

  /// The recovered chunk data (if successful)
  final List<AudioChunk>? recoveredData;

  /// The strategy that was used for recovery
  final ErrorRecoveryStrategy strategy;

  /// Number of retry attempts made
  final int retryAttempts;

  /// Time taken for recovery
  final Duration recoveryTime;

  /// Warning messages from recovery process
  final List<String> warnings;

  /// Error that prevented recovery (if unsuccessful)
  final Object? recoveryError;

  const ChunkRecoveryResult({
    required this.isSuccessful,
    this.recoveredData,
    required this.strategy,
    required this.retryAttempts,
    required this.recoveryTime,
    this.warnings = const [],
    this.recoveryError,
  });

  /// Create a successful recovery result
  factory ChunkRecoveryResult.success({
    required List<AudioChunk> recoveredData,
    required ErrorRecoveryStrategy strategy,
    required int retryAttempts,
    required Duration recoveryTime,
    List<String> warnings = const [],
  }) {
    return ChunkRecoveryResult(
      isSuccessful: true,
      recoveredData: recoveredData,
      strategy: strategy,
      retryAttempts: retryAttempts,
      recoveryTime: recoveryTime,
      warnings: warnings,
    );
  }

  /// Create a failed recovery result
  factory ChunkRecoveryResult.failure({
    required ErrorRecoveryStrategy strategy,
    required int retryAttempts,
    required Duration recoveryTime,
    required Object recoveryError,
    List<String> warnings = const [],
  }) {
    return ChunkRecoveryResult(
      isSuccessful: false,
      strategy: strategy,
      retryAttempts: retryAttempts,
      recoveryTime: recoveryTime,
      warnings: warnings,
      recoveryError: recoveryError,
    );
  }

  @override
  String toString() {
    return 'ChunkRecoveryResult(successful: $isSuccessful, strategy: $strategy, '
        'retryAttempts: $retryAttempts, recoveryTime: ${recoveryTime.inMilliseconds}ms)';
  }
}

/// Configuration for chunked processing error handling
class ChunkedProcessingErrorConfig {
  /// Default error recovery strategy
  final ErrorRecoveryStrategy defaultStrategy;

  /// Maximum number of retry attempts per chunk
  final int maxRetryAttempts;

  /// Base delay between retry attempts
  final Duration baseRetryDelay;

  /// Whether to use exponential backoff for retries
  final bool useExponentialBackoff;

  /// Maximum delay between retry attempts
  final Duration maxRetryDelay;

  /// Minimum chunk size for retry attempts (in bytes)
  final int minRetryChunkSize;

  /// Maximum number of consecutive failures before aborting
  final int maxConsecutiveFailures;

  /// Whether to continue processing after recoverable errors
  final bool continueOnRecoverableErrors;

  /// Callback for error notifications
  final void Function(ChunkErrorContext context)? onError;

  /// Callback for recovery notifications
  final void Function(ChunkRecoveryResult result)? onRecovery;

  const ChunkedProcessingErrorConfig({
    this.defaultStrategy = ErrorRecoveryStrategy.skipAndContinue,
    this.maxRetryAttempts = 3,
    this.baseRetryDelay = const Duration(milliseconds: 100),
    this.useExponentialBackoff = true,
    this.maxRetryDelay = const Duration(seconds: 5),
    this.minRetryChunkSize = 1024, // 1KB
    this.maxConsecutiveFailures = 5,
    this.continueOnRecoverableErrors = true,
    this.onError,
    this.onRecovery,
  });

  /// Create a configuration for aggressive error recovery
  factory ChunkedProcessingErrorConfig.aggressive() {
    return const ChunkedProcessingErrorConfig(
      defaultStrategy: ErrorRecoveryStrategy.retryWithSmallerChunk,
      maxRetryAttempts: 5,
      baseRetryDelay: Duration(milliseconds: 50),
      maxConsecutiveFailures: 10,
      continueOnRecoverableErrors: true,
    );
  }

  /// Create a configuration for conservative error handling
  factory ChunkedProcessingErrorConfig.conservative() {
    return const ChunkedProcessingErrorConfig(
      defaultStrategy: ErrorRecoveryStrategy.failFast,
      maxRetryAttempts: 1,
      baseRetryDelay: Duration(milliseconds: 500),
      maxConsecutiveFailures: 2,
      continueOnRecoverableErrors: false,
    );
  }

  /// Create a configuration optimized for large files
  factory ChunkedProcessingErrorConfig.forLargeFiles() {
    return const ChunkedProcessingErrorConfig(
      defaultStrategy: ErrorRecoveryStrategy.seekToNextBoundary,
      maxRetryAttempts: 3,
      baseRetryDelay: Duration(milliseconds: 200),
      maxConsecutiveFailures: 20, // Allow more failures for large files
      continueOnRecoverableErrors: true,
    );
  }
}

/// Comprehensive error handler for chunked audio processing
class ChunkedProcessingErrorHandler {
  /// Error handling configuration
  final ChunkedProcessingErrorConfig config;

  /// Counter for consecutive failures
  int _consecutiveFailures = 0;

  /// History of error contexts for analysis
  final List<ChunkErrorContext> _errorHistory = [];

  /// History of recovery results for analysis
  final List<ChunkRecoveryResult> _recoveryHistory = [];

  ChunkedProcessingErrorHandler({ChunkedProcessingErrorConfig? config}) : config = config ?? const ChunkedProcessingErrorConfig();

  /// Handle a chunk processing error and attempt recovery
  Future<ChunkRecoveryResult> handleChunkError({
    required ChunkErrorContext context,
    required ChunkedAudioDecoder decoder,
    ErrorRecoveryStrategy? strategy,
  }) async {
    final recoveryStrategy = strategy ?? config.defaultStrategy;
    final startTime = DateTime.now();

    // Record the error
    _errorHistory.add(context);
    config.onError?.call(context);

    // Check if we should abort due to too many consecutive failures
    _consecutiveFailures++;
    if (_consecutiveFailures >= config.maxConsecutiveFailures) {
      final result = ChunkRecoveryResult.failure(
        strategy: recoveryStrategy,
        retryAttempts: 0,
        recoveryTime: Duration.zero,
        recoveryError: DecodingException(
          'Too many consecutive failures (${config.maxConsecutiveFailures})',
          'Aborting chunked processing due to excessive errors',
        ),
      );
      _recoveryHistory.add(result);
      return result;
    }

    ChunkRecoveryResult result;

    try {
      switch (recoveryStrategy) {
        case ErrorRecoveryStrategy.skipAndContinue:
          result = await _skipAndContinue(context);
          break;
        case ErrorRecoveryStrategy.retryWithSmallerChunk:
          result = await _retryWithSmallerChunk(context, decoder);
          break;
        case ErrorRecoveryStrategy.seekToNextBoundary:
          result = await _seekToNextBoundary(context, decoder);
          break;
        case ErrorRecoveryStrategy.failFast:
          result = ChunkRecoveryResult.failure(
            strategy: recoveryStrategy,
            retryAttempts: 0,
            recoveryTime: DateTime.now().difference(startTime),
            recoveryError: context.originalError,
          );
          break;
      }
    } catch (e) {
      result = ChunkRecoveryResult.failure(strategy: recoveryStrategy, retryAttempts: 0, recoveryTime: DateTime.now().difference(startTime), recoveryError: e);
    }

    // Update consecutive failure counter
    if (result.isSuccessful) {
      _consecutiveFailures = 0;
    }

    // Record the recovery result
    _recoveryHistory.add(result);
    config.onRecovery?.call(result);

    return result;
  }

  /// Skip the failed chunk and continue with empty audio data
  Future<ChunkRecoveryResult> _skipAndContinue(ChunkErrorContext context) async {
    final startTime = DateTime.now();

    // Check if this is a truly unrecoverable error type
    if (context.originalError is FFIException) {
      return ChunkRecoveryResult.failure(
        strategy: ErrorRecoveryStrategy.skipAndContinue,
        retryAttempts: 0,
        recoveryTime: DateTime.now().difference(startTime),
        recoveryError: context.originalError,
        warnings: ['FFI errors cannot be recovered by skipping'],
      );
    }

    // Create empty audio chunk to maintain continuity
    final emptyChunk = AudioChunk(
      samples: List.filled(1024, 0.0), // 1024 silent samples
      startSample: context.failedChunk.startPosition,
      isLast: context.failedChunk.isLast,
    );

    return ChunkRecoveryResult.success(
      recoveredData: [emptyChunk],
      strategy: ErrorRecoveryStrategy.skipAndContinue,
      retryAttempts: 0,
      recoveryTime: DateTime.now().difference(startTime),
      warnings: ['Chunk skipped due to error: ${context.originalError}'],
    );
  }

  /// Retry processing with progressively smaller chunk sizes
  Future<ChunkRecoveryResult> _retryWithSmallerChunk(ChunkErrorContext context, ChunkedAudioDecoder decoder) async {
    final startTime = DateTime.now();
    final originalChunk = context.failedChunk;
    int retryAttempts = 0;

    // Try with progressively smaller chunks
    final chunkSizes = _generateSmallerChunkSizes(originalChunk.size);

    for (final chunkSize in chunkSizes) {
      if (chunkSize < config.minRetryChunkSize) {
        break;
      }

      retryAttempts++;

      if (retryAttempts > config.maxRetryAttempts) {
        break;
      }

      try {
        // Apply retry delay with exponential backoff
        if (retryAttempts > 1) {
          final delay = _calculateRetryDelay(retryAttempts);
          await Future.delayed(delay);
        }

        // Create smaller chunk
        final smallerChunk = FileChunk(
          data: Uint8List.sublistView(originalChunk.data, 0, chunkSize),
          startPosition: originalChunk.startPosition,
          endPosition: originalChunk.startPosition + chunkSize,
          isLast: false, // Smaller chunks are never the last
          isSeekPoint: originalChunk.isSeekPoint,
          metadata: originalChunk.metadata,
        );

        // Attempt to process the smaller chunk
        final audioChunks = await decoder.processFileChunk(smallerChunk);

        return ChunkRecoveryResult.success(
          recoveredData: audioChunks,
          strategy: ErrorRecoveryStrategy.retryWithSmallerChunk,
          retryAttempts: retryAttempts,
          recoveryTime: DateTime.now().difference(startTime),
          warnings: ['Chunk processed with reduced size: $chunkSize bytes (original: ${originalChunk.size} bytes)'],
        );
      } catch (e) {
        // Continue with next smaller size
        continue;
      }
    }

    // All retry attempts failed
    return ChunkRecoveryResult.failure(
      strategy: ErrorRecoveryStrategy.retryWithSmallerChunk,
      retryAttempts: retryAttempts,
      recoveryTime: DateTime.now().difference(startTime),
      recoveryError: DecodingException('All retry attempts with smaller chunks failed', 'Tried $retryAttempts different chunk sizes'),
    );
  }

  /// Seek to the next format-specific boundary and continue processing
  Future<ChunkRecoveryResult> _seekToNextBoundary(ChunkErrorContext context, ChunkedAudioDecoder decoder) async {
    final startTime = DateTime.now();

    try {
      // Attempt to seek to a safe position
      final seekResult = await decoder.seekToTime(Duration(milliseconds: (context.failedChunk.startPosition / 1000).round()));

      if (!seekResult.isExact) {
        return ChunkRecoveryResult.success(
          recoveredData: [], // Empty data, but processing can continue
          strategy: ErrorRecoveryStrategy.seekToNextBoundary,
          retryAttempts: 1,
          recoveryTime: DateTime.now().difference(startTime),
          warnings: ['Seeked to approximate position: ${seekResult.actualPosition}', if (seekResult.warning != null) seekResult.warning!],
        );
      }

      return ChunkRecoveryResult.success(
        recoveredData: [], // Empty data, but processing can continue
        strategy: ErrorRecoveryStrategy.seekToNextBoundary,
        retryAttempts: 1,
        recoveryTime: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return ChunkRecoveryResult.failure(
        strategy: ErrorRecoveryStrategy.seekToNextBoundary,
        retryAttempts: 1,
        recoveryTime: DateTime.now().difference(startTime),
        recoveryError: e,
      );
    }
  }

  /// Generate progressively smaller chunk sizes for retry attempts
  List<int> _generateSmallerChunkSizes(int originalSize) {
    final sizes = <int>[];
    int currentSize = originalSize;

    // Generate sizes: 75%, 50%, 25%, 12.5%, etc.
    while (currentSize >= config.minRetryChunkSize) {
      currentSize = (currentSize * 0.75).round();
      if (currentSize >= config.minRetryChunkSize) {
        sizes.add(currentSize);
      }
    }

    return sizes;
  }

  /// Calculate retry delay with optional exponential backoff
  Duration _calculateRetryDelay(int attemptNumber) {
    if (!config.useExponentialBackoff) {
      return config.baseRetryDelay;
    }

    final multiplier = math.pow(2, attemptNumber - 1);
    final delayMs = (config.baseRetryDelay.inMilliseconds * multiplier).round();
    final delay = Duration(milliseconds: delayMs);

    // Cap at maximum delay
    return delay > config.maxRetryDelay ? config.maxRetryDelay : delay;
  }

  /// Get error statistics for analysis
  ChunkErrorStatistics getErrorStatistics() {
    return ChunkErrorStatistics(
      totalErrors: _errorHistory.length,
      totalRecoveries: _recoveryHistory.length,
      successfulRecoveries: _recoveryHistory.where((r) => r.isSuccessful).length,
      consecutiveFailures: _consecutiveFailures,
      errorHistory: List.unmodifiable(_errorHistory),
      recoveryHistory: List.unmodifiable(_recoveryHistory),
    );
  }

  /// Reset error tracking (useful for processing new files)
  void reset() {
    _consecutiveFailures = 0;
    _errorHistory.clear();
    _recoveryHistory.clear();
  }

  /// Check if processing should continue based on error tolerance
  bool shouldContinueProcessing() {
    if (!config.continueOnRecoverableErrors) {
      return _consecutiveFailures == 0;
    }

    return _consecutiveFailures < config.maxConsecutiveFailures;
  }
}

/// Statistics about chunk processing errors and recoveries
class ChunkErrorStatistics {
  /// Total number of errors encountered
  final int totalErrors;

  /// Total number of recovery attempts
  final int totalRecoveries;

  /// Number of successful recoveries
  final int successfulRecoveries;

  /// Current consecutive failures
  final int consecutiveFailures;

  /// Complete error history
  final List<ChunkErrorContext> errorHistory;

  /// Complete recovery history
  final List<ChunkRecoveryResult> recoveryHistory;

  const ChunkErrorStatistics({
    required this.totalErrors,
    required this.totalRecoveries,
    required this.successfulRecoveries,
    required this.consecutiveFailures,
    required this.errorHistory,
    required this.recoveryHistory,
  });

  /// Recovery success rate (0.0 to 1.0)
  double get recoverySuccessRate {
    return totalRecoveries > 0 ? successfulRecoveries / totalRecoveries : 0.0;
  }

  /// Whether there are any unrecovered errors
  bool get hasUnrecoveredErrors {
    return totalErrors > successfulRecoveries;
  }

  /// Most common error type
  String? get mostCommonErrorType {
    if (errorHistory.isEmpty) return null;

    final errorTypes = <String, int>{};
    for (final error in errorHistory) {
      final type = error.originalError.runtimeType.toString();
      errorTypes[type] = (errorTypes[type] ?? 0) + 1;
    }

    return errorTypes.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Most successful recovery strategy
  ErrorRecoveryStrategy? get mostSuccessfulStrategy {
    if (recoveryHistory.isEmpty) return null;

    final strategySuccess = <ErrorRecoveryStrategy, int>{};
    for (final recovery in recoveryHistory) {
      if (recovery.isSuccessful) {
        strategySuccess[recovery.strategy] = (strategySuccess[recovery.strategy] ?? 0) + 1;
      }
    }

    if (strategySuccess.isEmpty) return null;

    return strategySuccess.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  @override
  String toString() {
    return 'ChunkErrorStatistics(totalErrors: $totalErrors, '
        'successfulRecoveries: $successfulRecoveries/$totalRecoveries, '
        'recoveryRate: ${(recoverySuccessRate * 100).toStringAsFixed(1)}%, '
        'consecutiveFailures: $consecutiveFailures)';
  }
}
