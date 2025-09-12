import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/processing/chunk_manager.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/file_chunk.dart';
import 'package:sonix/src/models/chunked_processing_models.dart';
import 'package:sonix/src/decoders/chunked_audio_decoder.dart';
import 'dart:typed_data';
import 'dart:async';

/// Mock implementation of ChunkedAudioDecoder for testing
class MockChunkedAudioDecoder extends ChunkedAudioDecoder {
  bool _isInitialized = false;
  Duration _currentPosition = Duration.zero;
  final Duration _totalDuration = const Duration(seconds: 10);
  final Map<String, dynamic> _metadata = {'sampleRate': 44100, 'channels': 2};

  // Configurable behavior for testing
  Duration processingDelay = const Duration(milliseconds: 10);
  bool shouldThrowError = false;
  String? errorMessage;
  int memoryMultiplier = 2; // Simulate memory usage multiplier

  @override
  Future<void> initializeChunkedDecoding(String filePath, {int chunkSize = 10 * 1024 * 1024, Duration? seekPosition}) async {
    await Future.delayed(const Duration(milliseconds: 5));
    _isInitialized = true;
    if (seekPosition != null) {
      _currentPosition = seekPosition;
    }
  }

  @override
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk) async {
    if (!_isInitialized) {
      throw StateError('Decoder not initialized');
    }

    // Simulate processing delay
    await Future.delayed(processingDelay);

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Mock processing error');
    }

    // Generate mock audio chunks
    final samplesPerChunk = fileChunk.data.length ~/ 4; // Simulate conversion
    final samples = List.generate(samplesPerChunk, (i) => (i % 100) / 100.0);

    return [AudioChunk(samples: samples, startSample: fileChunk.startPosition ~/ 4, isLast: fileChunk.isLast)];
  }

  @override
  Future<SeekResult> seekToTime(Duration position) async {
    await Future.delayed(const Duration(milliseconds: 2));
    _currentPosition = position;
    return SeekResult(actualPosition: position, bytePosition: (position.inMilliseconds * 1000).round(), isExact: true);
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
    await Future.delayed(const Duration(milliseconds: 1));
    _currentPosition = Duration.zero;
  }

  @override
  Map<String, dynamic> getFormatMetadata() => Map.from(_metadata);

  @override
  Future<Duration?> estimateDuration() async {
    return _totalDuration;
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> cleanupChunkedProcessing() async {
    await Future.delayed(const Duration(milliseconds: 1));
    _isInitialized = false;
  }

  // AudioDecoder base methods (simplified for testing)
  @override
  Future<AudioData> decode(String filePath) async {
    throw UnimplementedError('Use chunked processing');
  }

  @override
  Stream<AudioChunk> decodeStream(String filePath) async* {
    throw UnimplementedError('Use chunked processing');
  }

  @override
  void dispose() {
    _isInitialized = false;
  }
}

void main() {
  group('ChunkManager', () {
    late ChunkManager chunkManager;
    late MockChunkedAudioDecoder mockDecoder;
    late ChunkManagerConfig config;

    setUp(() {
      mockDecoder = MockChunkedAudioDecoder();
      config = const ChunkManagerConfig(
        maxMemoryUsage: 10 * 1024 * 1024, // 10MB for testing
        maxConcurrentChunks: 2,
        memoryCheckInterval: Duration(milliseconds: 10),
      );
      chunkManager = ChunkManager(config);
    });

    tearDown(() async {
      await chunkManager.dispose();
    });

    group('Configuration', () {
      test('should create with default config', () {
        final defaultManager = ChunkManager(const ChunkManagerConfig());
        expect(defaultManager.memoryStats.maxUsage, equals(100 * 1024 * 1024));
        defaultManager.dispose();
      });

      test('should create low memory config', () {
        final lowMemoryConfig = ChunkManagerConfig.lowMemory();
        expect(lowMemoryConfig.maxMemoryUsage, equals(50 * 1024 * 1024));
        expect(lowMemoryConfig.maxConcurrentChunks, equals(2));
        expect(lowMemoryConfig.memoryPressureThreshold, equals(0.7));
      });

      test('should create high performance config', () {
        final highPerfConfig = ChunkManagerConfig.highPerformance();
        expect(highPerfConfig.maxMemoryUsage, equals(200 * 1024 * 1024));
        expect(highPerfConfig.maxConcurrentChunks, equals(6));
        expect(highPerfConfig.memoryPressureThreshold, equals(0.9));
      });
    });

    group('Memory Statistics', () {
      test('should provide accurate memory stats', () {
        final stats = chunkManager.memoryStats;
        expect(stats.currentUsage, equals(0));
        expect(stats.maxUsage, equals(config.maxMemoryUsage));
        expect(stats.activeChunks, equals(0));
        expect(stats.pendingCleanup, equals(0));
        expect(stats.isUnderPressure, isFalse);
        expect(stats.usagePercentage, equals(0.0));
        expect(stats.availableMemory, equals(config.maxMemoryUsage));
      });

      test('should calculate memory usage percentage correctly', () {
        final stats = MemoryStats(currentUsage: 50 * 1024 * 1024, maxUsage: 100 * 1024 * 1024, activeChunks: 2, pendingCleanup: 1, isUnderPressure: false);

        expect(stats.usagePercentage, equals(0.5));
        expect(stats.availableMemory, equals(50 * 1024 * 1024));
      });
    });

    group('Chunk Processing', () {
      test('should process single chunk successfully', () async {
        await mockDecoder.initializeChunkedDecoding('test.mock');

        final fileChunk = FileChunk(data: Uint8List.fromList(List.generate(1000, (i) => i % 256)), startPosition: 0, endPosition: 1000, isLast: true);

        final chunks = Stream.fromIterable([fileChunk]);
        final results = <ProcessedChunk>[];

        await for (final result in chunkManager.processChunks(chunks, mockDecoder)) {
          results.add(result);
        }

        expect(results.length, equals(1));
        expect(results.first.hasError, isFalse);
        expect(results.first.isSuccessful, isTrue);
        expect(results.first.audioChunks.length, equals(1));
        expect(results.first.audioChunks.first.samples.length, equals(250)); // 1000/4
      });

      test('should process multiple chunks in sequence', () async {
        await mockDecoder.initializeChunkedDecoding('test.mock');

        final fileChunks = List.generate(
          3,
          (i) => FileChunk(
            data: Uint8List.fromList(List.generate(500, (j) => (i * 500 + j) % 256)),
            startPosition: i * 500,
            endPosition: (i + 1) * 500,
            isLast: i == 2,
          ),
        );

        final chunks = Stream.fromIterable(fileChunks);
        final results = <ProcessedChunk>[];

        await for (final result in chunkManager.processChunks(chunks, mockDecoder)) {
          results.add(result);
        }

        expect(results.length, equals(3));
        for (int i = 0; i < results.length; i++) {
          expect(results[i].hasError, isFalse);
          expect(results[i].isSuccessful, isTrue);
          expect(results[i].fileChunk.startPosition, equals(i * 500));
        }
      });

      test('should handle concurrent processing with limits', () async {
        await mockDecoder.initializeChunkedDecoding('test.mock');
        mockDecoder.processingDelay = const Duration(milliseconds: 100);

        final fileChunks = List.generate(
          5,
          (i) => FileChunk(
            data: Uint8List.fromList(List.generate(500, (j) => (i * 500 + j) % 256)),
            startPosition: i * 500,
            endPosition: (i + 1) * 500,
            isLast: i == 4,
          ),
        );

        final chunks = Stream.fromIterable(fileChunks);
        final results = <ProcessedChunk>[];
        final startTime = DateTime.now();

        await for (final result in chunkManager.processChunks(chunks, mockDecoder)) {
          results.add(result);
        }

        final duration = DateTime.now().difference(startTime);

        expect(results.length, equals(5));
        // With maxConcurrentChunks=2 and 100ms delay, should take at least 300ms
        // (first 2 parallel, then 2 more parallel, then 1 final)
        expect(duration.inMilliseconds, greaterThan(250));
      });
    });

    group('Error Handling', () {
      test('should handle chunk processing errors gracefully', () async {
        await mockDecoder.initializeChunkedDecoding('test.mock');
        mockDecoder.shouldThrowError = true;
        mockDecoder.errorMessage = 'Test processing error';

        final fileChunk = FileChunk(data: Uint8List.fromList(List.generate(1000, (i) => i % 256)), startPosition: 0, endPosition: 1000, isLast: true);

        final chunks = Stream.fromIterable([fileChunk]);
        final results = <ProcessedChunk>[];

        await for (final result in chunkManager.processChunks(chunks, mockDecoder)) {
          results.add(result);
        }

        expect(results.length, equals(1));
        expect(results.first.hasError, isTrue);
        expect(results.first.isSuccessful, isFalse);
        expect(results.first.error.toString(), contains('Test processing error'));
        expect(results.first.audioChunks.isEmpty, isTrue);
      });

      test('should continue processing after individual chunk errors', () async {
        // Create a decoder that always fails
        final errorDecoder = MockChunkedAudioDecoder();
        await errorDecoder.initializeChunkedDecoding('test.mock');
        errorDecoder.shouldThrowError = true;
        errorDecoder.errorMessage = 'Simulated chunk error';

        final fileChunk = FileChunk(data: Uint8List.fromList(List.generate(500, (j) => j % 256)), startPosition: 0, endPosition: 500, isLast: true);

        final chunks = Stream.fromIterable([fileChunk]);
        final results = <ProcessedChunk>[];

        await for (final result in chunkManager.processChunks(chunks, errorDecoder)) {
          results.add(result);
        }

        expect(results.length, equals(1));
        expect(results[0].hasError, isTrue);
        expect(results[0].error.toString(), contains('Simulated chunk error'));
      });
    });

    group('Memory Management', () {
      test('should track memory usage during processing', () async {
        await mockDecoder.initializeChunkedDecoding('test.mock');

        final largeChunk = FileChunk(
          data: Uint8List.fromList(List.generate(1024 * 1024, (i) => i % 256)), // 1MB
          startPosition: 0,
          endPosition: 1024 * 1024,
          isLast: true,
        );

        final chunks = Stream.fromIterable([largeChunk]);

        // Start processing but don't await completion
        final processingStream = chunkManager.processChunks(chunks, mockDecoder);
        final iterator = processingStream.listen(null);

        // Check memory usage during processing
        await Future.delayed(const Duration(milliseconds: 5));
        final stats = chunkManager.memoryStats;
        expect(stats.currentUsage, greaterThan(0));

        // Complete processing
        await iterator.asFuture();
        iterator.cancel();
      });

      test('should respect memory limits', () async {
        // Create config with very low memory limit
        final lowMemoryConfig = const ChunkManagerConfig(
          maxMemoryUsage: 1024, // 1KB limit
          maxConcurrentChunks: 1,
        );
        final lowMemoryManager = ChunkManager(lowMemoryConfig);

        try {
          await mockDecoder.initializeChunkedDecoding('test.mock');

          final largeChunk = FileChunk(
            data: Uint8List.fromList(List.generate(2048, (i) => i % 256)), // 2KB chunk
            startPosition: 0,
            endPosition: 2048,
            isLast: true,
          );

          final chunks = Stream.fromIterable([largeChunk]);
          final results = <ProcessedChunk>[];

          // This should handle memory pressure gracefully
          await for (final result in lowMemoryManager.processChunks(chunks, mockDecoder)) {
            results.add(result);
          }

          expect(results.length, equals(1));
        } finally {
          await lowMemoryManager.dispose();
        }
      });

      test('should trigger memory pressure callbacks', () async {
        int pressureCallCount = 0;
        int lastCurrentUsage = 0;
        int lastMaxUsage = 0;

        final configWithCallback = ChunkManagerConfig(
          maxMemoryUsage: 100, // Very small limit - 100 bytes
          maxConcurrentChunks: 1,
          memoryPressureThreshold: 0.1, // Very low threshold
          memoryCheckInterval: const Duration(milliseconds: 1), // Fast checking
          onMemoryPressure: (current, max) {
            pressureCallCount++;
            lastCurrentUsage = current;
            lastMaxUsage = max;
          },
        );

        final managerWithCallback = ChunkManager(configWithCallback);

        try {
          await mockDecoder.initializeChunkedDecoding('test.mock');

          final largeChunk = FileChunk(
            data: Uint8List.fromList(List.generate(1000, (i) => i % 256)), // 1KB chunk (will be 2KB with 2x overhead, way exceeding 100 byte limit)
            startPosition: 0,
            endPosition: 1000,
            isLast: true,
          );

          final chunks = Stream.fromIterable([largeChunk]);
          final results = <ProcessedChunk>[];

          // Wait a bit to let memory monitoring kick in
          await Future.delayed(const Duration(milliseconds: 10));

          await for (final result in managerWithCallback.processChunks(chunks, mockDecoder)) {
            results.add(result);
          }

          // Wait a bit more for memory monitoring
          await Future.delayed(const Duration(milliseconds: 10));

          expect(pressureCallCount, greaterThan(0));
          expect(lastMaxUsage, equals(100));
        } finally {
          await managerWithCallback.dispose();
        }
      });

      test('should force cleanup when requested', () async {
        await mockDecoder.initializeChunkedDecoding('test.mock');

        final fileChunk = FileChunk(data: Uint8List.fromList(List.generate(1000, (i) => i % 256)), startPosition: 0, endPosition: 1000, isLast: true);

        final chunks = Stream.fromIterable([fileChunk]);
        final results = <ProcessedChunk>[];

        await for (final result in chunkManager.processChunks(chunks, mockDecoder)) {
          results.add(result);
        }

        // Force cleanup
        await chunkManager.forceCleanup();

        final stats = chunkManager.memoryStats;
        expect(stats.pendingCleanup, equals(0));
      });

      test('should reduce chunk size under memory pressure', () async {
        final configWithPressure = ChunkManagerConfig(
          maxMemoryUsage: 500, // Very small limit
          maxConcurrentChunks: 1,
          memoryPressureThreshold: 0.3,
          memoryCheckInterval: const Duration(seconds: 10), // Long interval to prevent interference
        );

        final managerWithPressure = ChunkManager(configWithPressure);

        try {
          // Set initial chunk size
          final originalSize = 2048; // 2KB
          final recommendedSize = managerWithPressure.getRecommendedChunkSize(originalSize);
          expect(recommendedSize, equals(originalSize));

          // Verify initial state
          final initialStats = managerWithPressure.memoryPressureStats;
          expect(initialStats.originalChunkSize, equals(originalSize));
          expect(initialStats.currentChunkSize, equals(originalSize));

          // Simulate memory pressure
          await managerWithPressure.handleMemoryPressure();

          // Check that chunk size was reduced
          final pressureStats = managerWithPressure.memoryPressureStats;
          expect(pressureStats.isUnderPressure, isTrue);
          expect(pressureStats.currentChunkSize, lessThan(originalSize));
          expect(pressureStats.reductionPercentage, greaterThan(0));

          // Get new recommended size
          final reducedSize = managerWithPressure.getRecommendedChunkSize(originalSize);
          expect(reducedSize, lessThan(originalSize));
        } finally {
          await managerWithPressure.dispose();
        }
      });

      test('should restore chunk size when memory pressure is relieved', () async {
        final configWithPressure = ChunkManagerConfig(maxMemoryUsage: 500, maxConcurrentChunks: 1, memoryPressureThreshold: 0.3);

        final managerWithPressure = ChunkManager(configWithPressure);

        try {
          // Set initial chunk size
          final originalSize = 2048;
          managerWithPressure.getRecommendedChunkSize(originalSize);

          // Simulate memory pressure
          await managerWithPressure.handleMemoryPressure();
          final pressureStats1 = managerWithPressure.memoryPressureStats;
          expect(pressureStats1.isUnderPressure, isTrue);

          // Reset memory pressure
          managerWithPressure.resetMemoryPressure();
          final pressureStats2 = managerWithPressure.memoryPressureStats;
          expect(pressureStats2.isUnderPressure, isFalse);
          expect(pressureStats2.pressureCount, equals(0));
        } finally {
          await managerWithPressure.dispose();
        }
      });

      test('should provide accurate memory pressure statistics', () async {
        final configWithPressure = ChunkManagerConfig(maxMemoryUsage: 500, maxConcurrentChunks: 1);

        final managerWithPressure = ChunkManager(configWithPressure);

        try {
          // Initial state
          final initialStats = managerWithPressure.memoryPressureStats;
          expect(initialStats.isUnderPressure, isFalse);
          expect(initialStats.pressureCount, equals(0));
          expect(initialStats.currentChunkSize, equals(0));
          expect(initialStats.originalChunkSize, equals(0));
          expect(initialStats.reductionPercentage, equals(0.0));

          // Set chunk size
          final originalSize = 2048;
          managerWithPressure.getRecommendedChunkSize(originalSize);

          // Trigger pressure multiple times
          await managerWithPressure.handleMemoryPressure();
          await managerWithPressure.handleMemoryPressure();

          final pressureStats = managerWithPressure.memoryPressureStats;
          expect(pressureStats.isUnderPressure, isTrue);
          expect(pressureStats.pressureCount, equals(2));
          expect(pressureStats.originalChunkSize, equals(originalSize));
          expect(pressureStats.currentChunkSize, lessThan(originalSize));
          expect(pressureStats.reductionPercentage, greaterThan(0));
        } finally {
          await managerWithPressure.dispose();
        }
      });

      test('should enforce minimum chunk size during pressure', () async {
        final configWithPressure = ChunkManagerConfig(maxMemoryUsage: 100, maxConcurrentChunks: 1);

        final managerWithPressure = ChunkManager(configWithPressure);

        try {
          // Set small initial chunk size
          final originalSize = 2048;
          managerWithPressure.getRecommendedChunkSize(originalSize);

          // Trigger pressure many times to force minimum
          for (int i = 0; i < 10; i++) {
            await managerWithPressure.handleMemoryPressure();
          }

          final pressureStats = managerWithPressure.memoryPressureStats;
          expect(pressureStats.currentChunkSize, greaterThanOrEqualTo(1024)); // Min 1KB
        } finally {
          await managerWithPressure.dispose();
        }
      });

      test('should trigger aggressive garbage collection under pressure', () async {
        final configWithGC = ChunkManagerConfig(maxMemoryUsage: 500, maxConcurrentChunks: 1, enableGarbageCollection: true);

        final managerWithGC = ChunkManager(configWithGC);

        try {
          // Set chunk size
          managerWithGC.getRecommendedChunkSize(2048);

          // Measure time for memory pressure handling (should include GC delays)
          final startTime = DateTime.now();
          await managerWithGC.handleMemoryPressure();
          final duration = DateTime.now().difference(startTime);

          // Should take at least a few milliseconds due to GC hints
          expect(duration.inMilliseconds, greaterThanOrEqualTo(1));

          final pressureStats = managerWithGC.memoryPressureStats;
          expect(pressureStats.isUnderPressure, isTrue);
        } finally {
          await managerWithGC.dispose();
        }
      });
    });

    group('Progress Tracking', () {
      test('should report progress during processing', () async {
        final progressUpdates = <Map<String, int>>[];

        final configWithProgress = ChunkManagerConfig(
          maxMemoryUsage: config.maxMemoryUsage,
          maxConcurrentChunks: config.maxConcurrentChunks,
          onProgress: (processed, total) {
            progressUpdates.add({'processed': processed, 'total': total});
          },
        );

        final managerWithProgress = ChunkManager(configWithProgress);

        try {
          await mockDecoder.initializeChunkedDecoding('test.mock');

          final fileChunks = List.generate(
            3,
            (i) => FileChunk(
              data: Uint8List.fromList(List.generate(500, (j) => (i * 500 + j) % 256)),
              startPosition: i * 500,
              endPosition: (i + 1) * 500,
              isLast: i == 2,
            ),
          );

          final chunks = Stream.fromIterable(fileChunks);
          final results = <ProcessedChunk>[];

          await for (final result in managerWithProgress.processChunks(chunks, mockDecoder)) {
            results.add(result);
          }

          expect(progressUpdates.length, greaterThan(0));
          expect(progressUpdates.last['processed'], equals(3));
          expect(progressUpdates.last['total'], equals(3));
        } finally {
          await managerWithProgress.dispose();
        }
      });
    });

    group('Disposal and Cleanup', () {
      test('should dispose cleanly', () async {
        await mockDecoder.initializeChunkedDecoding('test.mock');

        final fileChunk = FileChunk(data: Uint8List.fromList(List.generate(1000, (i) => i % 256)), startPosition: 0, endPosition: 1000, isLast: true);

        final chunks = Stream.fromIterable([fileChunk]);

        // Process chunks normally
        final results = <ProcessedChunk>[];
        await for (final result in chunkManager.processChunks(chunks, mockDecoder)) {
          results.add(result);
        }

        // Then dispose
        await chunkManager.dispose();

        // Should not throw error
        expect(() => chunkManager.memoryStats, returnsNormally);
        expect(results.length, equals(1));
      });

      test('should throw error when used after disposal', () async {
        await chunkManager.dispose();

        final fileChunk = FileChunk(data: Uint8List.fromList(List.generate(1000, (i) => i % 256)), startPosition: 0, endPosition: 1000, isLast: true);

        final chunks = Stream.fromIterable([fileChunk]);

        expect(() async {
          await for (final _ in chunkManager.processChunks(chunks, mockDecoder)) {
            // This should throw before yielding any results
          }
        }, throwsStateError);
      });
    });

    group('Data Models', () {
      test('ProcessingChunk should track processing state', () {
        final fileChunk = FileChunk(data: Uint8List.fromList([1, 2, 3, 4]), startPosition: 0, endPosition: 4, isLast: true);

        final completer = Completer<List<AudioChunk>>();
        final processingChunk = ProcessingChunk(fileChunk: fileChunk, future: completer.future);

        expect(processingChunk.estimatedMemoryUsage, equals(4));
        expect(processingChunk.processingDuration.inMilliseconds, greaterThanOrEqualTo(0));

        completer.complete([]);
        // Future completion doesn't change the ProcessingChunk state directly
        // We can't easily test future completion in synchronous tests
      });

      test('ProcessedChunk should handle success and error states', () {
        final fileChunk = FileChunk(data: Uint8List.fromList([1, 2, 3, 4]), startPosition: 0, endPosition: 4, isLast: true);

        // Successful chunk
        final successChunk = ProcessedChunk(
          fileChunk: fileChunk,
          audioChunks: [
            const AudioChunk(samples: [0.1, 0.2], startSample: 0, isLast: true),
          ],
        );

        expect(successChunk.hasError, isFalse);
        expect(successChunk.isSuccessful, isTrue);

        // Error chunk
        final errorChunk = ProcessedChunk(fileChunk: fileChunk, audioChunks: [], error: Exception('Test error'));

        expect(errorChunk.hasError, isTrue);
        expect(errorChunk.isSuccessful, isFalse);
      });
    });
  });
}
