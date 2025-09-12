import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/exceptions/chunk_error_recovery.dart';
import 'package:sonix/src/exceptions/chunked_processing_error_handler.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/chunked_processing_models.dart';
import 'package:sonix/src/decoders/chunked_audio_decoder.dart';

/// Mock decoder for testing error recovery
class MockErrorRecoveryDecoder extends ChunkedAudioDecoder {
  bool _isInitialized = false;
  Duration _currentPosition = Duration.zero;

  /// Control which chunks should fail
  final Set<int> failingChunkIndices = {};

  /// Control which chunks should throw unrecoverable errors
  final Set<int> unrecoverableChunkIndices = {};

  int processCallCount = 0;

  @override
  Future<void> initializeChunkedDecoding(String filePath, {int chunkSize = 10 * 1024 * 1024, Duration? seekPosition}) async {
    _isInitialized = true;
    if (seekPosition != null) {
      _currentPosition = seekPosition;
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    processCallCount++;

    // Determine chunk index from start position (assuming 1024 byte chunks)
    final chunkIndex = fileChunk.startPosition ~/ 1024;

    if (unrecoverableChunkIndices.contains(chunkIndex)) {
      throw FFIException('Unrecoverable FFI error for chunk $chunkIndex');
    }

    if (failingChunkIndices.contains(chunkIndex)) {
      throw DecodingException('Recoverable decoding error for chunk $chunkIndex');
    }

    // Return successful audio chunk
    return [AudioChunk(samples: List.filled(512, 0.5), startSample: fileChunk.startPosition, isLast: fileChunk.isLast)];
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _currentPosition = position;
    return SeekResult(actualPosition: position, bytePosition: position.inMilliseconds * 100, isExact: true);
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    return ChunkSizeRecommendation.forLargeFile(fileSize);
  }

  @override
  bool get supportsEfficientSeeking => true;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Future<void> resetDecoderState() async {}

  @override
  Map<String, dynamic> getFormatMetadata() {
    return {'format': 'mock-error-recovery'};
  }

  @override
  Future<Duration?> estimateDuration() async {
    return const Duration(minutes: 5);
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> cleanupChunkedProcessing() async {
    _isInitialized = false;
  }

  @override
  Future<AudioData> decode(String filePath) async {
    throw UnimplementedError('Not needed for tests');
  }

  @override
  Stream<AudioChunk> decodeStream(String filePath) async* {
    throw UnimplementedError('Not needed for tests');
  }

  @override
  void dispose() {
    _isInitialized = false;
  }
}

/// Mock decoder with artificial delays for timing tests
class _DelayedDecoder extends ChunkedAudioDecoder {
  bool _isInitialized = false;
  Duration _currentPosition = Duration.zero;

  @override
  Future<void> initializeChunkedDecoding(String filePath, {int chunkSize = 10 * 1024 * 1024, Duration? seekPosition}) async {
    _isInitialized = true;
    if (seekPosition != null) {
      _currentPosition = seekPosition;
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    // Add artificial delay
    await Future.delayed(const Duration(milliseconds: 10));

    return [AudioChunk(samples: List.filled(512, 0.5), startSample: fileChunk.startPosition, isLast: fileChunk.isLast)];
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    _currentPosition = position;
    return SeekResult(actualPosition: position, bytePosition: position.inMilliseconds * 100, isExact: true);
  }

  @override
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize) {
    return ChunkSizeRecommendation.forLargeFile(fileSize);
  }

  @override
  bool get supportsEfficientSeeking => true;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Future<void> resetDecoderState() async {}

  @override
  Map<String, dynamic> getFormatMetadata() {
    return {'format': 'delayed-mock'};
  }

  @override
  Future<Duration?> estimateDuration() async {
    return const Duration(minutes: 5);
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> cleanupChunkedProcessing() async {
    _isInitialized = false;
  }

  @override
  Future<AudioData> decode(String filePath) async {
    throw UnimplementedError('Not needed for tests');
  }

  @override
  Stream<AudioChunk> decodeStream(String filePath) async* {
    throw UnimplementedError('Not needed for tests');
  }

  @override
  void dispose() {
    _isInitialized = false;
  }
}

void main() {
  group('ChunkErrorRecovery', () {
    late ChunkErrorRecovery errorRecovery;
    late MockErrorRecoveryDecoder mockDecoder;
    late List<FileChunk> testChunks;

    setUp(() {
      errorRecovery = ChunkErrorRecovery();
      mockDecoder = MockErrorRecoveryDecoder();

      // Create test chunks (5 chunks of 1024 bytes each)
      testChunks = List.generate(5, (index) {
        final startPos = index * 1024;
        return FileChunk(
          data: Uint8List.fromList(List.generate(1024, (i) => i % 256)),
          startPosition: startPos,
          endPosition: startPos + 1024,
          isLast: index == 4,
        );
      });
    });

    group('Successful Processing', () {
      test('should process all chunks successfully when no errors occur', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        // Should have 5 chunk results + 1 summary result
        expect(results.length, equals(6));

        // Check individual chunk results
        for (int i = 0; i < 5; i++) {
          expect(results[i].status, equals(ChunkProcessingStatus.success));
          expect(results[i].chunkIndex, equals(i));
          expect(results[i].audioChunks.length, equals(1));
          expect(results[i].isSuccessful, isTrue);
        }

        // Check summary result
        final summary = results.last;
        expect(summary.status, equals(ChunkProcessingStatus.summary));
        expect(summary.processingState!.totalChunks, equals(5));
        expect(summary.processingState!.successfulChunks, equals(5));
        expect(summary.processingState!.failedChunks, equals(0));
      });
    });

    group('Error Recovery', () {
      test('should recover from recoverable errors', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Make chunks 1 and 3 fail (but recoverable)
        mockDecoder.failingChunkIndices.addAll([1, 3]);

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        // Should have 5 chunk results + 1 summary result
        expect(results.length, equals(6));

        // Check that chunks 1 and 3 were recovered
        expect(results[1].status, equals(ChunkProcessingStatus.recovered));
        expect(results[1].recoveryResult, isNotNull);
        expect(results[1].recoveryResult!.isSuccessful, isTrue);

        expect(results[3].status, equals(ChunkProcessingStatus.recovered));
        expect(results[3].recoveryResult, isNotNull);
        expect(results[3].recoveryResult!.isSuccessful, isTrue);

        // Other chunks should be successful
        expect(results[0].status, equals(ChunkProcessingStatus.success));
        expect(results[2].status, equals(ChunkProcessingStatus.success));
        expect(results[4].status, equals(ChunkProcessingStatus.success));

        // Check summary
        final summary = results.last;
        expect(summary.processingState!.successfulChunks, equals(3));
        expect(summary.processingState!.recoveredChunks, equals(2));
        expect(summary.processingState!.failedChunks, equals(0));
        expect(summary.errorSummary!.totalErrors, equals(2));
        expect(summary.errorSummary!.successfulRecoveries, equals(2));
      });

      test('should handle unrecoverable errors', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Make chunk 2 have an unrecoverable error
        mockDecoder.unrecoverableChunkIndices.add(2);

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        // Should have 5 chunk results + 1 summary result
        expect(results.length, equals(6));

        // Check that chunk 2 failed
        expect(results[2].status, equals(ChunkProcessingStatus.failed));
        expect(results[2].recoveryResult, isNotNull);
        expect(results[2].recoveryResult!.isSuccessful, isFalse);

        // Other chunks should be successful
        expect(results[0].status, equals(ChunkProcessingStatus.success));
        expect(results[1].status, equals(ChunkProcessingStatus.success));
        expect(results[3].status, equals(ChunkProcessingStatus.success));
        expect(results[4].status, equals(ChunkProcessingStatus.success));

        // Check summary
        final summary = results.last;
        expect(summary.processingState!.successfulChunks, equals(4));
        expect(summary.processingState!.recoveredChunks, equals(0));
        expect(summary.processingState!.failedChunks, equals(1));
        expect(summary.errorSummary!.unrecoverableErrors, equals(1));
      });
    });

    group('Error Tolerance', () {
      test('should abort when consecutive failure threshold is exceeded', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Configure custom tolerance that focuses on consecutive failures
        final customConfig = const ChunkErrorToleranceConfig(
          maxConsecutiveFailures: 3,
          maxUnrecoverableErrors: 10, // High enough to not trigger first
          maxErrorRate: 1.0, // High enough to not trigger
        );
        errorRecovery = ChunkErrorRecovery(toleranceConfig: customConfig);

        // Make first 4 chunks have unrecoverable errors (exceeds maxConsecutiveFailures = 3)
        mockDecoder.unrecoverableChunkIndices.addAll([0, 1, 2, 3]);

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        // Should abort after 3 consecutive failures
        expect(results.length, equals(4)); // 2 failed chunks + 1 abort result + 1 summary

        // Find the abort result (should be second to last)
        final abortResult = results[results.length - 2];
        expect(abortResult.status, equals(ChunkProcessingStatus.aborted));
        expect(abortResult.additionalInfo, contains('Error tolerance exceeded'));

        // Last result should be summary
        expect(results.last.status, equals(ChunkProcessingStatus.summary));
      });

      test('should abort when error rate threshold is exceeded', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Configure strict tolerance with low error rate
        final strictConfig = const ChunkErrorToleranceConfig(
          maxErrorRate: 0.2, // 20% error rate
          minChunksForErrorRate: 3,
          maxConsecutiveFailures: 10, // High enough to not trigger first
          maxUnrecoverableErrors: 10, // High enough to not trigger first
        );
        errorRecovery = ChunkErrorRecovery(toleranceConfig: strictConfig);

        // Make 2 out of first 3 chunks fail (66% error rate > 20%)
        mockDecoder.unrecoverableChunkIndices.addAll([0, 2]);

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        // Should process at least 3 chunks to evaluate error rate, then abort
        expect(results.length, greaterThanOrEqualTo(4));

        // Find the abort result (should be second to last)
        final abortResult = results[results.length - 2];
        expect(abortResult.status, equals(ChunkProcessingStatus.aborted));

        // Last result should be summary
        expect(results.last.status, equals(ChunkProcessingStatus.summary));
      });

      test('should continue with lenient tolerance configuration', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Configure lenient tolerance
        final lenientConfig = ChunkErrorToleranceConfig.lenient();
        errorRecovery = ChunkErrorRecovery(toleranceConfig: lenientConfig);

        // Make most chunks fail but still within lenient limits
        mockDecoder.unrecoverableChunkIndices.addAll([0, 2, 4]);

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        // Should process all chunks despite failures
        expect(results.length, equals(6)); // 5 chunks + 1 summary
        expect(results.last.status, equals(ChunkProcessingStatus.summary));
        expect(results.last.processingState!.failedChunks, equals(3));
        expect(results.last.processingState!.successfulChunks, equals(2));
      });
    });

    group('Error Aggregation', () {
      test('should aggregate errors by type', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Mix of recoverable and unrecoverable errors
        mockDecoder.failingChunkIndices.addAll([1, 3]); // DecodingException
        mockDecoder.unrecoverableChunkIndices.addAll([2]); // FFIException

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        final errorSummary = errorRecovery.getErrorSummary();
        expect(errorSummary.totalErrors, equals(3));
        expect(errorSummary.errorsByType['DecodingException'], equals(2));
        expect(errorSummary.errorsByType['FFIException'], equals(1));
        expect(errorSummary.mostCommonErrorType, equals('DecodingException'));
      });

      test('should track error positions', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Errors at different positions
        mockDecoder.failingChunkIndices.addAll([0, 1, 4]);

        final results = <ProcessedChunkResult>[];
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          results.add(result);
        }

        final errorSummary = errorRecovery.getErrorSummary();
        expect(errorSummary.errorsByPosition.isNotEmpty, isTrue);

        // All errors should be in the same 1MB range since our test chunks are small
        expect(errorSummary.errorsByPosition.keys.first, equals('0KB-1024KB'));
      });
    });

    group('Processing State', () {
      test('should track processing progress correctly', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        final progressUpdates = <ProcessingStateInfo>[];

        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          if (result.status != ChunkProcessingStatus.summary) {
            progressUpdates.add(errorRecovery.getProcessingState());
          }
        }

        expect(progressUpdates.length, equals(5));

        // Check progress percentages
        for (int i = 0; i < 5; i++) {
          final expectedProgress = (i + 1) / 5;
          expect(progressUpdates[i].progressPercentage, closeTo(expectedProgress, 0.01));
          expect(progressUpdates[i].processedChunks, equals(i + 1));
        }

        // Final state should be complete
        final finalState = errorRecovery.getProcessingState();
        expect(finalState.isComplete, isTrue);
        expect(finalState.progressPercentage, equals(1.0));
      });

      test('should estimate time remaining', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Create a custom decoder with delays for timing tests
        final delayDecoder = _DelayedDecoder();
        await delayDecoder.initializeChunkedDecoding('test.mp3');

        ProcessingStateInfo? midProcessingState;

        int chunkCount = 0;
        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks),
          decoder: delayDecoder,
          filePath: 'test.mp3',
        )) {
          if (result.status != ChunkProcessingStatus.summary) {
            chunkCount++;
            if (chunkCount == 3) {
              // Capture state at 60% progress
              midProcessingState = errorRecovery.getProcessingState();
            }
          }
        }

        expect(midProcessingState, isNotNull);
        expect(midProcessingState?.estimatedTimeRemaining, isNotNull);
        expect(midProcessingState!.elapsedTime.inMilliseconds, greaterThan(0));
      });
    });

    group('Reset Functionality', () {
      test('should reset all state when reset is called', () async {
        await mockDecoder.initializeChunkedDecoding('test.mp3');

        // Process some chunks with errors
        mockDecoder.failingChunkIndices.add(1);

        await for (final result in errorRecovery.processChunksWithRecovery(
          fileChunks: Stream.fromIterable(testChunks.take(2)),
          decoder: mockDecoder,
          filePath: 'test.mp3',
        )) {
          // Process first 2 chunks
          if (result.status == ChunkProcessingStatus.summary) break;
        }

        // Verify there are errors recorded
        var errorSummary = errorRecovery.getErrorSummary();
        expect(errorSummary.totalErrors, greaterThan(0));

        var processingState = errorRecovery.getProcessingState();
        expect(processingState.processedChunks, greaterThan(0));

        // Reset and verify clean state
        errorRecovery.reset();

        errorSummary = errorRecovery.getErrorSummary();
        expect(errorSummary.totalErrors, equals(0));
        expect(errorSummary.totalRecoveries, equals(0));

        processingState = errorRecovery.getProcessingState();
        expect(processingState.processedChunks, equals(0));
        expect(processingState.totalChunks, equals(0));
      });
    });
  });

  group('ChunkErrorToleranceConfig', () {
    test('should create strict configuration correctly', () {
      final config = ChunkErrorToleranceConfig.strict();
      expect(config.maxConsecutiveFailures, equals(3));
      expect(config.maxErrorRate, equals(0.1));
      expect(config.maxUnrecoverableErrors, equals(1));
      expect(config.continueAfterRecoverableErrors, isFalse);
    });

    test('should create lenient configuration correctly', () {
      final config = ChunkErrorToleranceConfig.lenient();
      expect(config.maxConsecutiveFailures, equals(20));
      expect(config.maxErrorRate, equals(0.8));
      expect(config.maxUnrecoverableErrors, equals(10));
      expect(config.continueAfterRecoverableErrors, isTrue);
    });

    test('should create large file configuration correctly', () {
      final config = ChunkErrorToleranceConfig.forLargeFiles();
      expect(config.maxConsecutiveFailures, equals(50));
      expect(config.maxErrorRate, equals(0.3));
      expect(config.maxUnrecoverableErrors, equals(20));
      expect(config.minChunksForErrorRate, equals(100));
    });
  });

  group('ProcessedChunkResult', () {
    test('should create success result correctly', () {
      final chunk = FileChunk(data: Uint8List(100), startPosition: 0, endPosition: 100, isLast: false);

      final audioChunk = AudioChunk(samples: [0.1, 0.2, 0.3], startSample: 0, isLast: false);

      final result = ProcessedChunkResult.success(
        chunkIndex: 0,
        fileChunk: chunk,
        audioChunks: [audioChunk],
        processingTime: const Duration(milliseconds: 100),
      );

      expect(result.status, equals(ChunkProcessingStatus.success));
      expect(result.isSuccessful, isTrue);
      expect(result.audioChunks.length, equals(1));
      expect(result.originalError, isNull);
    });

    test('should create recovered result correctly', () {
      final chunk = FileChunk(data: Uint8List(100), startPosition: 0, endPosition: 100, isLast: false);

      final recoveryResult = ChunkRecoveryResult.success(
        recoveredData: [],
        strategy: ErrorRecoveryStrategy.skipAndContinue,
        retryAttempts: 1,
        recoveryTime: const Duration(milliseconds: 50),
      );

      final result = ProcessedChunkResult.recovered(
        chunkIndex: 0,
        fileChunk: chunk,
        audioChunks: [],
        processingTime: const Duration(milliseconds: 150),
        recoveryResult: recoveryResult,
        originalError: DecodingException('Test error'),
      );

      expect(result.status, equals(ChunkProcessingStatus.recovered));
      expect(result.isSuccessful, isTrue);
      expect(result.recoveryResult, isNotNull);
      expect(result.originalError, isA<DecodingException>());
    });

    test('should create failed result correctly', () {
      final chunk = FileChunk(data: Uint8List(100), startPosition: 0, endPosition: 100, isLast: false);

      final result = ProcessedChunkResult.failed(
        chunkIndex: 0,
        fileChunk: chunk,
        processingTime: const Duration(milliseconds: 100),
        error: DecodingException('Test error'),
      );

      expect(result.status, equals(ChunkProcessingStatus.failed));
      expect(result.isSuccessful, isFalse);
      expect(result.originalError, isA<DecodingException>());
    });
  });
}
