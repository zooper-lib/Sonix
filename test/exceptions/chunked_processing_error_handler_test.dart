import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonix/src/exceptions/chunked_processing_error_handler.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/chunked_processing_models.dart';
import 'package:sonix/src/decoders/chunked_audio_decoder.dart';

/// Mock implementation of ChunkedAudioDecoder for testing
class MockChunkedAudioDecoder extends ChunkedAudioDecoder {
  bool _isInitialized = false;
  Duration _currentPosition = Duration.zero;
  bool shouldThrowError = false;
  bool shouldThrowOnSeek = false;
  int processCallCount = 0;
  int seekCallCount = 0;

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

    if (shouldThrowError) {
      throw DecodingException('Mock decoding error for testing');
    }

    // Return mock audio chunks
    return [AudioChunk(samples: List.filled(1024, 0.5), startSample: fileChunk.startPosition, isLast: fileChunk.isLast)];
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    seekCallCount++;

    if (shouldThrowOnSeek) {
      throw DecodingException('Mock seek error for testing');
    }

    _currentPosition = position;
    return SeekResult(
      actualPosition: position,
      bytePosition: position.inMilliseconds * 100, // Mock conversion
      isExact: true,
    );
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
  Future<void> resetDecoderState() async {
    // Mock implementation
  }

  @override
  Map<String, dynamic> getFormatMetadata() {
    return {'format': 'mock', 'sampleRate': 44100, 'channels': 2};
  }

  @override
  Future<Duration?> estimateDuration() async {
    return const Duration(minutes: 3);
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> cleanupChunkedProcessing() async {
    _isInitialized = false;
  }

  // AudioDecoder base class methods (simplified for testing)
  @override
  Future<AudioData> decode(String filePath) async {
    throw UnimplementedError('Not needed for chunked processing tests');
  }

  @override
  Stream<AudioChunk> decodeStream(String filePath) async* {
    throw UnimplementedError('Not needed for chunked processing tests');
  }

  @override
  void dispose() {
    _isInitialized = false;
  }
}

/// Mock decoder that fails on large chunks but succeeds on small ones
class _SizeAwareDecoder extends ChunkedAudioDecoder {
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
    // Fail on chunks larger than 200 bytes, succeed on smaller ones
    if (fileChunk.size >= 200) {
      throw DecodingException('Chunk too large: ${fileChunk.size} bytes');
    }

    return [AudioChunk(samples: List.filled(256, 0.5), startSample: fileChunk.startPosition, isLast: fileChunk.isLast)];
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
    return {'format': 'size-aware-mock'};
  }

  @override
  Future<Duration?> estimateDuration() async {
    return const Duration(minutes: 3);
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
  group('ChunkedProcessingErrorHandler', () {
    late ChunkedProcessingErrorHandler errorHandler;
    late MockChunkedAudioDecoder mockDecoder;
    late FileChunk testChunk;
    late ChunkErrorContext testContext;

    setUp(() {
      errorHandler = ChunkedProcessingErrorHandler();
      mockDecoder = MockChunkedAudioDecoder();

      testChunk = FileChunk(data: Uint8List.fromList(List.generate(2048, (i) => i % 256)), startPosition: 0, endPosition: 2048, isLast: false);

      testContext = ChunkErrorContext.create(
        failedChunk: testChunk,
        originalError: DecodingException('Test error'),
        chunkIndex: 0,
        totalChunks: 10,
        filePath: 'test.mp3',
      );
    });

    group('Error Recovery Strategies', () {
      test('skipAndContinue should return empty audio chunk', () async {
        final result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.skipAndContinue);

        expect(result.isSuccessful, isTrue);
        expect(result.strategy, equals(ErrorRecoveryStrategy.skipAndContinue));
        expect(result.recoveredData, isNotNull);
        expect(result.recoveredData!.length, equals(1));
        expect(result.recoveredData!.first.samples.length, equals(1024));
        expect(result.warnings.length, equals(1));
        expect(result.warnings.first, contains('Chunk skipped'));
      });

      test('retryWithSmallerChunk should succeed with smaller chunk', () async {
        // Create a custom decoder that fails on large chunks but succeeds on small ones
        final customDecoder = _SizeAwareDecoder();
        await customDecoder.initializeChunkedDecoding('test.mp3');

        // Use a configuration with smaller minimum retry chunk size and more attempts
        final config = const ChunkedProcessingErrorConfig(minRetryChunkSize: 50, maxRetryAttempts: 10);
        final customErrorHandler = ChunkedProcessingErrorHandler(config: config);

        final result = await customErrorHandler.handleChunkError(
          context: testContext,
          decoder: customDecoder,
          strategy: ErrorRecoveryStrategy.retryWithSmallerChunk,
        );

        expect(result.isSuccessful, isTrue);
        expect(result.strategy, equals(ErrorRecoveryStrategy.retryWithSmallerChunk));
        expect(result.retryAttempts, greaterThan(0));
        if (result.warnings.isNotEmpty) {
          expect(result.warnings.first, contains('reduced size'));
        }
      });

      test('retryWithSmallerChunk should fail when all sizes fail', () async {
        mockDecoder.shouldThrowError = true;

        final result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.retryWithSmallerChunk);

        expect(result.isSuccessful, isFalse);
        expect(result.strategy, equals(ErrorRecoveryStrategy.retryWithSmallerChunk));
        expect(result.recoveryError, isA<DecodingException>());
      });

      test('seekToNextBoundary should succeed when seek works', () async {
        mockDecoder.shouldThrowOnSeek = false;

        final result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.seekToNextBoundary);

        expect(result.isSuccessful, isTrue);
        expect(result.strategy, equals(ErrorRecoveryStrategy.seekToNextBoundary));
        expect(mockDecoder.seekCallCount, equals(1));
      });

      test('seekToNextBoundary should fail when seek fails', () async {
        mockDecoder.shouldThrowOnSeek = true;

        final result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.seekToNextBoundary);

        expect(result.isSuccessful, isFalse);
        expect(result.strategy, equals(ErrorRecoveryStrategy.seekToNextBoundary));
        expect(result.recoveryError, isA<DecodingException>());
      });

      test('failFast should immediately return failure', () async {
        final result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.failFast);

        expect(result.isSuccessful, isFalse);
        expect(result.strategy, equals(ErrorRecoveryStrategy.failFast));
        expect(result.retryAttempts, equals(0));
        expect(result.recoveryError, equals(testContext.originalError));
      });
    });

    group('Consecutive Failure Handling', () {
      test('should abort after max consecutive failures', () async {
        final config = const ChunkedProcessingErrorConfig(maxConsecutiveFailures: 2);
        errorHandler = ChunkedProcessingErrorHandler(config: config);

        // Set up decoder to always fail
        mockDecoder.shouldThrowError = true;

        // First failure - should try to recover but fail
        var result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.retryWithSmallerChunk);
        expect(result.isSuccessful, isFalse);

        // Second failure - should try to recover but fail
        result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.retryWithSmallerChunk);
        expect(result.isSuccessful, isFalse);

        // Third failure should abort due to consecutive failures
        result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.retryWithSmallerChunk);
        expect(result.isSuccessful, isFalse);
        expect(result.recoveryError, isA<DecodingException>());
        expect(result.recoveryError.toString(), contains('Too many consecutive failures'));
      });

      test('should reset consecutive failures after successful recovery', () async {
        final config = const ChunkedProcessingErrorConfig(maxConsecutiveFailures: 2);
        errorHandler = ChunkedProcessingErrorHandler(config: config);

        // First failure
        var result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.skipAndContinue);
        expect(result.isSuccessful, isTrue);

        // Successful recovery should reset counter
        expect(errorHandler.shouldContinueProcessing(), isTrue);

        // Another failure should not abort immediately
        result = await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.skipAndContinue);
        expect(result.isSuccessful, isTrue);
      });
    });

    group('Error Statistics', () {
      test('should track error and recovery statistics', () async {
        // Generate some errors and recoveries
        await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.skipAndContinue);

        mockDecoder.shouldThrowError = true;
        await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.retryWithSmallerChunk);

        final stats = errorHandler.getErrorStatistics();
        expect(stats.totalErrors, equals(2));
        expect(stats.totalRecoveries, equals(2));
        expect(stats.successfulRecoveries, equals(1)); // Only skipAndContinue succeeded
        expect(stats.recoverySuccessRate, equals(0.5));
        expect(stats.hasUnrecoveredErrors, isTrue);
      });

      test('should identify most common error type', () async {
        // Add multiple errors of the same type
        for (int i = 0; i < 3; i++) {
          await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.skipAndContinue);
        }

        final stats = errorHandler.getErrorStatistics();
        expect(stats.mostCommonErrorType, equals('DecodingException'));
      });

      test('should identify most successful strategy', () async {
        // Use skipAndContinue multiple times (always succeeds)
        for (int i = 0; i < 3; i++) {
          await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.skipAndContinue);
        }

        final stats = errorHandler.getErrorStatistics();
        expect(stats.mostSuccessfulStrategy, equals(ErrorRecoveryStrategy.skipAndContinue));
      });
    });

    group('Configuration', () {
      test('aggressive config should have higher retry limits', () {
        final config = ChunkedProcessingErrorConfig.aggressive();
        expect(config.maxRetryAttempts, equals(5));
        expect(config.maxConsecutiveFailures, equals(10));
        expect(config.continueOnRecoverableErrors, isTrue);
      });

      test('conservative config should have lower retry limits', () {
        final config = ChunkedProcessingErrorConfig.conservative();
        expect(config.maxRetryAttempts, equals(1));
        expect(config.maxConsecutiveFailures, equals(2));
        expect(config.continueOnRecoverableErrors, isFalse);
      });

      test('large file config should allow more failures', () {
        final config = ChunkedProcessingErrorConfig.forLargeFiles();
        expect(config.maxConsecutiveFailures, equals(20));
        expect(config.defaultStrategy, equals(ErrorRecoveryStrategy.seekToNextBoundary));
      });
    });

    group('Error Context', () {
      test('should calculate progress percentage correctly', () {
        final context = ChunkErrorContext.create(
          failedChunk: testChunk,
          originalError: DecodingException('Test'),
          chunkIndex: 5,
          totalChunks: 10,
          filePath: 'test.mp3',
        );

        expect(context.progressPercentage, equals(0.5));
      });

      test('should handle zero total chunks', () {
        final context = ChunkErrorContext.create(
          failedChunk: testChunk,
          originalError: DecodingException('Test'),
          chunkIndex: 0,
          totalChunks: 0,
          filePath: 'test.mp3',
        );

        expect(context.progressPercentage, equals(0.0));
      });
    });

    group('Reset Functionality', () {
      test('should reset all tracking when reset is called', () async {
        // Generate some errors
        await errorHandler.handleChunkError(context: testContext, decoder: mockDecoder, strategy: ErrorRecoveryStrategy.skipAndContinue);

        var stats = errorHandler.getErrorStatistics();
        expect(stats.totalErrors, equals(1));

        // Reset and verify
        errorHandler.reset();
        stats = errorHandler.getErrorStatistics();
        expect(stats.totalErrors, equals(0));
        expect(stats.totalRecoveries, equals(0));
        expect(stats.consecutiveFailures, equals(0));
      });
    });
  });

  group('ChunkErrorContext', () {
    test('should create context with timestamp', () {
      final context = ChunkErrorContext.create(
        failedChunk: FileChunk(data: Uint8List(100), startPosition: 0, endPosition: 100, isLast: false),
        originalError: DecodingException('Test error'),
        chunkIndex: 1,
        totalChunks: 5,
        filePath: 'test.mp3',
        metadata: {'key': 'value'},
      );

      expect(context.timestamp, isNotNull);
      expect(context.metadata['key'], equals('value'));
      expect(context.toString(), contains('chunkIndex: 1/5'));
    });
  });

  group('ChunkRecoveryResult', () {
    test('should create successful result correctly', () {
      final audioChunk = AudioChunk(samples: [0.1, 0.2, 0.3], startSample: 0, isLast: false);

      final result = ChunkRecoveryResult.success(
        recoveredData: [audioChunk],
        strategy: ErrorRecoveryStrategy.skipAndContinue,
        retryAttempts: 1,
        recoveryTime: const Duration(milliseconds: 100),
        warnings: ['Test warning'],
      );

      expect(result.isSuccessful, isTrue);
      expect(result.recoveredData!.length, equals(1));
      expect(result.warnings.length, equals(1));
      expect(result.recoveryError, isNull);
    });

    test('should create failure result correctly', () {
      final result = ChunkRecoveryResult.failure(
        strategy: ErrorRecoveryStrategy.failFast,
        retryAttempts: 0,
        recoveryTime: const Duration(milliseconds: 50),
        recoveryError: DecodingException('Recovery failed'),
      );

      expect(result.isSuccessful, isFalse);
      expect(result.recoveredData, isNull);
      expect(result.recoveryError, isA<DecodingException>());
    });
  });
}
