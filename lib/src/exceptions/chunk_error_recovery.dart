import 'dart:async';

import '../models/file_chunk.dart';
import '../models/audio_data.dart';
import '../decoders/chunked_audio_decoder.dart';
import 'chunked_processing_error_handler.dart';

/// Manages chunk-level error recovery and partial processing continuation
class ChunkErrorRecovery {
  /// Error handler for individual chunk errors
  final ChunkedProcessingErrorHandler errorHandler;

  /// Configuration for error tolerance
  final ChunkErrorToleranceConfig toleranceConfig;

  /// Aggregated error information
  final ChunkErrorAggregator _errorAggregator;

  /// Processing state tracker
  final ChunkProcessingState _processingState;

  ChunkErrorRecovery({ChunkedProcessingErrorHandler? errorHandler, ChunkErrorToleranceConfig? toleranceConfig})
    : errorHandler = errorHandler ?? ChunkedProcessingErrorHandler(),
      toleranceConfig = toleranceConfig ?? const ChunkErrorToleranceConfig(),
      _errorAggregator = ChunkErrorAggregator(),
      _processingState = ChunkProcessingState();

  /// Process a stream of file chunks with error recovery and continuation
  Stream<ProcessedChunkResult> processChunksWithRecovery({
    required Stream<FileChunk> fileChunks,
    required ChunkedAudioDecoder decoder,
    required String filePath,
  }) async* {
    int chunkIndex = 0;
    int totalChunks = 0;

    // First pass: count total chunks for progress tracking
    final chunkList = await fileChunks.toList();
    totalChunks = chunkList.length;

    _processingState.initialize(totalChunks, filePath);

    for (final fileChunk in chunkList) {
      final chunkResult = await _processChunkWithRecovery(
        fileChunk: fileChunk,
        decoder: decoder,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        filePath: filePath,
      );

      // Update processing state
      _processingState.updateProgress(chunkIndex, chunkResult);

      // Check if we should continue processing
      if (!_shouldContinueProcessing(chunkResult)) {
        yield ProcessedChunkResult.aborted(chunkIndex: chunkIndex, reason: 'Error tolerance exceeded', errorSummary: _errorAggregator.getSummary());
        break;
      }

      yield chunkResult;
      chunkIndex++;
    }

    // Yield final summary
    yield ProcessedChunkResult.summary(
      totalChunks: totalChunks,
      processedChunks: chunkIndex,
      errorSummary: _errorAggregator.getSummary(),
      processingState: _processingState.getState(),
    );
  }

  /// Process a single chunk with error recovery
  Future<ProcessedChunkResult> _processChunkWithRecovery({
    required FileChunk fileChunk,
    required ChunkedAudioDecoder decoder,
    required int chunkIndex,
    required int totalChunks,
    required String filePath,
  }) async {
    final startTime = DateTime.now();

    try {
      // Attempt normal processing
      final audioChunks = await decoder.processFileChunk(fileChunk);

      // Record successful processing
      _errorAggregator.recordSuccess();

      return ProcessedChunkResult.success(
        chunkIndex: chunkIndex,
        fileChunk: fileChunk,
        audioChunks: audioChunks,
        processingTime: DateTime.now().difference(startTime),
      );
    } catch (error, stackTrace) {
      // Create error context
      final errorContext = ChunkErrorContext.create(
        failedChunk: fileChunk,
        originalError: error,
        stackTrace: stackTrace,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        filePath: filePath,
        metadata: {
          'processingTime': DateTime.now().difference(startTime).inMilliseconds,
          'chunkPosition': '${fileChunk.startPosition}-${fileChunk.endPosition}',
        },
      );

      // Record the error
      _errorAggregator.recordError(errorContext);

      // Attempt recovery
      final recoveryResult = await errorHandler.handleChunkError(context: errorContext, decoder: decoder);

      // Record recovery result
      _errorAggregator.recordRecovery(recoveryResult);

      if (recoveryResult.isSuccessful) {
        return ProcessedChunkResult.recovered(
          chunkIndex: chunkIndex,
          fileChunk: fileChunk,
          audioChunks: recoveryResult.recoveredData ?? [],
          processingTime: DateTime.now().difference(startTime),
          recoveryResult: recoveryResult,
          originalError: error,
        );
      } else {
        return ProcessedChunkResult.failed(
          chunkIndex: chunkIndex,
          fileChunk: fileChunk,
          processingTime: DateTime.now().difference(startTime),
          error: error,
          recoveryResult: recoveryResult,
        );
      }
    }
  }

  /// Check if processing should continue based on error tolerance
  bool _shouldContinueProcessing(ProcessedChunkResult result) {
    final errorSummary = _errorAggregator.getSummary();

    // Check consecutive failure threshold
    if (errorSummary.consecutiveFailures >= toleranceConfig.maxConsecutiveFailures) {
      return false;
    }

    // Check total error rate threshold (only after minimum chunks processed)
    final totalProcessed = _processingState.getState().processedChunks;
    if (totalProcessed >= toleranceConfig.minChunksForErrorRate) {
      final errorRate = errorSummary.totalErrors / totalProcessed;
      if (errorRate > toleranceConfig.maxErrorRate) {
        return false;
      }
    }

    // Check unrecoverable error threshold
    if (errorSummary.unrecoverableErrors >= toleranceConfig.maxUnrecoverableErrors) {
      return false;
    }

    return true;
  }

  /// Get current error statistics
  ChunkErrorSummary getErrorSummary() => _errorAggregator.getSummary();

  /// Get current processing state
  ProcessingStateInfo getProcessingState() => _processingState.getState();

  /// Reset recovery state for new processing session
  void reset() {
    errorHandler.reset();
    _errorAggregator.reset();
    _processingState.reset();
  }
}

/// Configuration for chunk error tolerance thresholds
class ChunkErrorToleranceConfig {
  /// Maximum consecutive failures before aborting
  final int maxConsecutiveFailures;

  /// Maximum error rate (0.0 to 1.0) before aborting
  final double maxErrorRate;

  /// Maximum unrecoverable errors before aborting
  final int maxUnrecoverableErrors;

  /// Whether to continue processing after recoverable errors
  final bool continueAfterRecoverableErrors;

  /// Minimum successful chunks required before applying error rate threshold
  final int minChunksForErrorRate;

  const ChunkErrorToleranceConfig({
    this.maxConsecutiveFailures = 10,
    this.maxErrorRate = 0.5, // 50% error rate
    this.maxUnrecoverableErrors = 5,
    this.continueAfterRecoverableErrors = true,
    this.minChunksForErrorRate = 10,
  });

  /// Create a strict tolerance configuration
  factory ChunkErrorToleranceConfig.strict() {
    return const ChunkErrorToleranceConfig(
      maxConsecutiveFailures: 3,
      maxErrorRate: 0.1, // 10% error rate
      maxUnrecoverableErrors: 1,
      continueAfterRecoverableErrors: false,
    );
  }

  /// Create a lenient tolerance configuration
  factory ChunkErrorToleranceConfig.lenient() {
    return const ChunkErrorToleranceConfig(
      maxConsecutiveFailures: 20,
      maxErrorRate: 0.8, // 80% error rate
      maxUnrecoverableErrors: 10,
      continueAfterRecoverableErrors: true,
    );
  }

  /// Create a configuration optimized for large files
  factory ChunkErrorToleranceConfig.forLargeFiles() {
    return const ChunkErrorToleranceConfig(
      maxConsecutiveFailures: 50,
      maxErrorRate: 0.3, // 30% error rate
      maxUnrecoverableErrors: 20,
      continueAfterRecoverableErrors: true,
      minChunksForErrorRate: 100,
    );
  }
}

/// Aggregates and tracks chunk processing errors
class ChunkErrorAggregator {
  final List<ChunkErrorContext> _errors = [];
  final List<ChunkRecoveryResult> _recoveries = [];
  int _consecutiveFailures = 0;
  int _consecutiveSuccesses = 0;

  /// Record a chunk processing error
  void recordError(ChunkErrorContext errorContext) {
    _errors.add(errorContext);
    _consecutiveFailures++;
    _consecutiveSuccesses = 0;
  }

  /// Record a recovery attempt result
  void recordRecovery(ChunkRecoveryResult recoveryResult) {
    _recoveries.add(recoveryResult);

    if (recoveryResult.isSuccessful) {
      _consecutiveFailures = 0;
      _consecutiveSuccesses++;
    }
  }

  /// Record a successful chunk processing
  void recordSuccess() {
    _consecutiveFailures = 0;
    _consecutiveSuccesses++;
  }

  /// Get aggregated error summary
  ChunkErrorSummary getSummary() {
    final totalErrors = _errors.length;
    final totalRecoveries = _recoveries.length;
    final successfulRecoveries = _recoveries.where((r) => r.isSuccessful).length;
    final unrecoverableErrors = totalErrors - successfulRecoveries;

    // Group errors by type
    final errorsByType = <String, int>{};
    for (final error in _errors) {
      final type = error.originalError.runtimeType.toString();
      errorsByType[type] = (errorsByType[type] ?? 0) + 1;
    }

    // Group errors by chunk position ranges
    final errorsByPosition = <String, int>{};
    for (final error in _errors) {
      final positionRange = _getPositionRange(error.failedChunk.startPosition);
      errorsByPosition[positionRange] = (errorsByPosition[positionRange] ?? 0) + 1;
    }

    return ChunkErrorSummary(
      totalErrors: totalErrors,
      totalRecoveries: totalRecoveries,
      successfulRecoveries: successfulRecoveries,
      unrecoverableErrors: unrecoverableErrors,
      consecutiveFailures: _consecutiveFailures,
      consecutiveSuccesses: _consecutiveSuccesses,
      errorsByType: Map.unmodifiable(errorsByType),
      errorsByPosition: Map.unmodifiable(errorsByPosition),
      recoverySuccessRate: totalRecoveries > 0 ? successfulRecoveries / totalRecoveries : 0.0,
    );
  }

  /// Get position range string for grouping errors
  String _getPositionRange(int position) {
    const rangeSize = 1024 * 1024; // 1MB ranges
    final rangeStart = (position ~/ rangeSize) * rangeSize;
    final rangeEnd = rangeStart + rangeSize;
    return '${rangeStart ~/ 1024}KB-${rangeEnd ~/ 1024}KB';
  }

  /// Reset aggregator state
  void reset() {
    _errors.clear();
    _recoveries.clear();
    _consecutiveFailures = 0;
    _consecutiveSuccesses = 0;
  }
}

/// Tracks the state of chunk processing
class ChunkProcessingState {
  int _totalChunks = 0;
  int _processedChunks = 0;
  int _successfulChunks = 0;
  int _recoveredChunks = 0;
  int _failedChunks = 0;
  String _filePath = '';
  DateTime? _startTime;
  DateTime? _lastUpdateTime;

  /// Initialize processing state
  void initialize(int totalChunks, String filePath) {
    _totalChunks = totalChunks;
    _filePath = filePath;
    _startTime = DateTime.now();
    _lastUpdateTime = _startTime;
    _processedChunks = 0;
    _successfulChunks = 0;
    _recoveredChunks = 0;
    _failedChunks = 0;
  }

  /// Update progress with chunk result
  void updateProgress(int chunkIndex, ProcessedChunkResult result) {
    _processedChunks = chunkIndex + 1;
    _lastUpdateTime = DateTime.now();

    switch (result.status) {
      case ChunkProcessingStatus.success:
        _successfulChunks++;
        break;
      case ChunkProcessingStatus.recovered:
        _recoveredChunks++;
        break;
      case ChunkProcessingStatus.failed:
      case ChunkProcessingStatus.aborted:
        _failedChunks++;
        break;
      case ChunkProcessingStatus.summary:
        // No change for summary
        break;
    }
  }

  /// Get current processing state
  ProcessingStateInfo getState() {
    final now = DateTime.now();
    final elapsedTime = _startTime != null ? now.difference(_startTime!) : Duration.zero;
    final progressPercentage = _totalChunks > 0 ? _processedChunks / _totalChunks : 0.0;

    Duration? estimatedTimeRemaining;
    if (progressPercentage > 0 && progressPercentage < 1.0) {
      final estimatedTotalTime = elapsedTime.inMilliseconds / progressPercentage;
      estimatedTimeRemaining = Duration(milliseconds: (estimatedTotalTime - elapsedTime.inMilliseconds).round());
    }

    return ProcessingStateInfo(
      totalChunks: _totalChunks,
      processedChunks: _processedChunks,
      successfulChunks: _successfulChunks,
      recoveredChunks: _recoveredChunks,
      failedChunks: _failedChunks,
      filePath: _filePath,
      progressPercentage: progressPercentage,
      elapsedTime: elapsedTime,
      estimatedTimeRemaining: estimatedTimeRemaining,
      isComplete: _processedChunks >= _totalChunks,
    );
  }

  /// Reset processing state
  void reset() {
    _totalChunks = 0;
    _processedChunks = 0;
    _successfulChunks = 0;
    _recoveredChunks = 0;
    _failedChunks = 0;
    _filePath = '';
    _startTime = null;
    _lastUpdateTime = null;
  }
}

/// Result of processing a single chunk with error recovery
class ProcessedChunkResult {
  /// Index of the chunk in the processing sequence
  final int chunkIndex;

  /// The file chunk that was processed
  final FileChunk? fileChunk;

  /// Resulting audio chunks (if successful)
  final List<AudioChunk> audioChunks;

  /// Processing status
  final ChunkProcessingStatus status;

  /// Time taken to process the chunk
  final Duration processingTime;

  /// Original error (if any)
  final Object? originalError;

  /// Recovery result (if recovery was attempted)
  final ChunkRecoveryResult? recoveryResult;

  /// Additional information
  final String? additionalInfo;

  /// Error summary (for summary results)
  final ChunkErrorSummary? errorSummary;

  /// Processing state (for summary results)
  final ProcessingStateInfo? processingState;

  const ProcessedChunkResult._({
    required this.chunkIndex,
    this.fileChunk,
    this.audioChunks = const [],
    required this.status,
    this.processingTime = Duration.zero,
    this.originalError,
    this.recoveryResult,
    this.additionalInfo,
    this.errorSummary,
    this.processingState,
  });

  /// Create a successful processing result
  factory ProcessedChunkResult.success({
    required int chunkIndex,
    required FileChunk fileChunk,
    required List<AudioChunk> audioChunks,
    required Duration processingTime,
  }) {
    return ProcessedChunkResult._(
      chunkIndex: chunkIndex,
      fileChunk: fileChunk,
      audioChunks: audioChunks,
      status: ChunkProcessingStatus.success,
      processingTime: processingTime,
    );
  }

  /// Create a recovered processing result
  factory ProcessedChunkResult.recovered({
    required int chunkIndex,
    required FileChunk fileChunk,
    required List<AudioChunk> audioChunks,
    required Duration processingTime,
    required ChunkRecoveryResult recoveryResult,
    required Object originalError,
  }) {
    return ProcessedChunkResult._(
      chunkIndex: chunkIndex,
      fileChunk: fileChunk,
      audioChunks: audioChunks,
      status: ChunkProcessingStatus.recovered,
      processingTime: processingTime,
      originalError: originalError,
      recoveryResult: recoveryResult,
    );
  }

  /// Create a failed processing result
  factory ProcessedChunkResult.failed({
    required int chunkIndex,
    required FileChunk fileChunk,
    required Duration processingTime,
    required Object error,
    ChunkRecoveryResult? recoveryResult,
  }) {
    return ProcessedChunkResult._(
      chunkIndex: chunkIndex,
      fileChunk: fileChunk,
      status: ChunkProcessingStatus.failed,
      processingTime: processingTime,
      originalError: error,
      recoveryResult: recoveryResult,
    );
  }

  /// Create an aborted processing result
  factory ProcessedChunkResult.aborted({required int chunkIndex, required String reason, ChunkErrorSummary? errorSummary}) {
    return ProcessedChunkResult._(chunkIndex: chunkIndex, status: ChunkProcessingStatus.aborted, additionalInfo: reason, errorSummary: errorSummary);
  }

  /// Create a summary result
  factory ProcessedChunkResult.summary({
    required int totalChunks,
    required int processedChunks,
    required ChunkErrorSummary errorSummary,
    required ProcessingStateInfo processingState,
  }) {
    return ProcessedChunkResult._(
      chunkIndex: processedChunks - 1,
      status: ChunkProcessingStatus.summary,
      errorSummary: errorSummary,
      processingState: processingState,
      additionalInfo: 'Processing complete: $processedChunks/$totalChunks chunks',
    );
  }

  /// Whether this result represents successful processing
  bool get isSuccessful => status == ChunkProcessingStatus.success || status == ChunkProcessingStatus.recovered;

  @override
  String toString() {
    return 'ProcessedChunkResult(index: $chunkIndex, status: $status, '
        'audioChunks: ${audioChunks.length}, processingTime: ${processingTime.inMilliseconds}ms)';
  }
}

/// Status of chunk processing
enum ChunkProcessingStatus { success, recovered, failed, aborted, summary }

/// Summary of chunk processing errors
class ChunkErrorSummary {
  /// Total number of errors encountered
  final int totalErrors;

  /// Total number of recovery attempts
  final int totalRecoveries;

  /// Number of successful recoveries
  final int successfulRecoveries;

  /// Number of unrecoverable errors
  final int unrecoverableErrors;

  /// Current consecutive failures
  final int consecutiveFailures;

  /// Current consecutive successes
  final int consecutiveSuccesses;

  /// Errors grouped by type
  final Map<String, int> errorsByType;

  /// Errors grouped by file position ranges
  final Map<String, int> errorsByPosition;

  /// Recovery success rate (0.0 to 1.0)
  final double recoverySuccessRate;

  const ChunkErrorSummary({
    required this.totalErrors,
    required this.totalRecoveries,
    required this.successfulRecoveries,
    required this.unrecoverableErrors,
    required this.consecutiveFailures,
    required this.consecutiveSuccesses,
    required this.errorsByType,
    required this.errorsByPosition,
    required this.recoverySuccessRate,
  });

  /// Whether there are any errors
  bool get hasErrors => totalErrors > 0;

  /// Whether there are any unrecovered errors
  bool get hasUnrecoveredErrors => unrecoverableErrors > 0;

  /// Most common error type
  String? get mostCommonErrorType {
    if (errorsByType.isEmpty) return null;
    return errorsByType.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Position range with most errors
  String? get mostProblematicPosition {
    if (errorsByPosition.isEmpty) return null;
    return errorsByPosition.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  @override
  String toString() {
    return 'ChunkErrorSummary(totalErrors: $totalErrors, '
        'successfulRecoveries: $successfulRecoveries/$totalRecoveries, '
        'recoveryRate: ${(recoverySuccessRate * 100).toStringAsFixed(1)}%, '
        'consecutiveFailures: $consecutiveFailures)';
  }
}

/// Information about processing state
class ProcessingStateInfo {
  /// Total number of chunks to process
  final int totalChunks;

  /// Number of chunks processed so far
  final int processedChunks;

  /// Number of successfully processed chunks
  final int successfulChunks;

  /// Number of recovered chunks
  final int recoveredChunks;

  /// Number of failed chunks
  final int failedChunks;

  /// File path being processed
  final String filePath;

  /// Progress percentage (0.0 to 1.0)
  final double progressPercentage;

  /// Time elapsed since processing started
  final Duration elapsedTime;

  /// Estimated time remaining
  final Duration? estimatedTimeRemaining;

  /// Whether processing is complete
  final bool isComplete;

  const ProcessingStateInfo({
    required this.totalChunks,
    required this.processedChunks,
    required this.successfulChunks,
    required this.recoveredChunks,
    required this.failedChunks,
    required this.filePath,
    required this.progressPercentage,
    required this.elapsedTime,
    this.estimatedTimeRemaining,
    required this.isComplete,
  });

  /// Success rate (0.0 to 1.0)
  double get successRate {
    return processedChunks > 0 ? successfulChunks / processedChunks : 0.0;
  }

  /// Recovery rate (0.0 to 1.0)
  double get recoveryRate {
    return processedChunks > 0 ? recoveredChunks / processedChunks : 0.0;
  }

  /// Failure rate (0.0 to 1.0)
  double get failureRate {
    return processedChunks > 0 ? failedChunks / processedChunks : 0.0;
  }

  @override
  String toString() {
    return 'ProcessingStateInfo(progress: ${(progressPercentage * 100).toStringAsFixed(1)}%, '
        'processed: $processedChunks/$totalChunks, '
        'success: $successfulChunks, recovered: $recoveredChunks, failed: $failedChunks)';
  }
}
