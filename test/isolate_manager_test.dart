import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/isolate/isolate_messages.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';

// Test configuration class
class TestSonixConfig implements IsolateConfig {
  @override
  final int maxConcurrentOperations;
  @override
  final int isolatePoolSize;
  @override
  final Duration isolateIdleTimeout;
  @override
  final int maxMemoryUsage;

  const TestSonixConfig({
    this.maxConcurrentOperations = 3,
    this.isolatePoolSize = 2,
    this.isolateIdleTimeout = const Duration(minutes: 5),
    this.maxMemoryUsage = 100 * 1024 * 1024,
  });
}

void main() {
  group('IsolateManager', () {
    late IsolateManager manager;
    late TestSonixConfig config;

    setUp(() {
      config = const TestSonixConfig(
        maxConcurrentOperations: 2,
        isolatePoolSize: 2,
        isolateIdleTimeout: Duration(seconds: 5),
        maxMemoryUsage: 50 * 1024 * 1024,
      );
      manager = IsolateManager(config);
    });

    tearDown(() async {
      await manager.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await manager.initialize();

        final stats = manager.getStatistics();
        expect(stats.activeIsolates, greaterThanOrEqualTo(0));
        expect(stats.queuedTasks, equals(0));
        expect(stats.completedTasks, equals(0));
        expect(stats.failedTasks, equals(0));
      });

      test('should not allow initialization after disposal', () async {
        await manager.dispose();

        expect(() => manager.initialize(), throwsA(isA<StateError>()));
      });
    });

    group('Task Execution', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should execute a simple task', () async {
        final task = ProcessingTask(id: 'test_task_1', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        // Execute the task
        final result = await manager.executeTask(task);

        expect(result, isA<WaveformData>());
        expect(result.amplitudes.length, equals(100));

        final stats = manager.getStatistics();
        expect(stats.completedTasks, equals(1));
        expect(stats.failedTasks, equals(0));
      });

      test('should handle multiple concurrent tasks', () async {
        final tasks = List.generate(3, (i) => ProcessingTask(id: 'test_task_$i', filePath: 'test_audio_$i.mp3', config: const WaveformConfig(resolution: 50)));

        // Execute all tasks concurrently
        final futures = tasks.map((task) => manager.executeTask(task)).toList();
        final results = await Future.wait(futures);

        expect(results.length, equals(3));
        for (final result in results) {
          expect(result, isA<WaveformData>());
          expect(result.amplitudes.length, equals(50));
        }

        final stats = manager.getStatistics();
        expect(stats.completedTasks, equals(3));
        expect(stats.failedTasks, equals(0));
      });

      test('should not allow task execution after disposal', () async {
        await manager.dispose();

        final task = ProcessingTask(id: 'test_task_disposed', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        expect(() => manager.executeTask(task), throwsA(isA<StateError>()));
      });
    });

    group('Task Management', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should track task statistics correctly', () async {
        final task1 = ProcessingTask(id: 'stats_task_1', filePath: 'test_audio1.mp3', config: const WaveformConfig(resolution: 100));

        final task2 = ProcessingTask(id: 'stats_task_2', filePath: 'test_audio2.mp3', config: const WaveformConfig(resolution: 100));

        // Execute tasks sequentially
        await manager.executeTask(task1);
        await manager.executeTask(task2);

        final stats = manager.getStatistics();
        expect(stats.completedTasks, equals(2));
        expect(stats.failedTasks, equals(0));
        expect(stats.averageProcessingTime.inMilliseconds, greaterThan(0));
      });

      test('should provide isolate information', () async {
        // Execute a task to ensure at least one isolate is created
        final task = ProcessingTask(id: 'info_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        await manager.executeTask(task);

        final stats = manager.getStatistics();
        expect(stats.isolateInfo, isNotEmpty);

        for (final info in stats.isolateInfo.values) {
          expect(info.id, isNotEmpty);
          expect(info.createdAt, isA<DateTime>());
          expect(info.lastUsed, isA<DateTime>());
          expect(info.tasksProcessed, greaterThanOrEqualTo(0));
        }
      });
    });

    group('Resource Management', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should respect isolate pool size limits', () async {
        // Create more tasks than the pool size
        final tasks = List.generate(5, (i) => ProcessingTask(id: 'pool_task_$i', filePath: 'test_audio_$i.mp3', config: const WaveformConfig(resolution: 50)));

        // Execute all tasks concurrently
        final futures = tasks.map((task) => manager.executeTask(task)).toList();
        await Future.wait(futures);

        final stats = manager.getStatistics();
        // Should not exceed the configured pool size
        expect(stats.activeIsolates, lessThanOrEqualTo(config.isolatePoolSize));
      });

      test('should optimize resources when requested', () async {
        // Execute a task to create isolates
        final task = ProcessingTask(id: 'optimize_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        await manager.executeTask(task);

        final statsBefore = manager.getStatistics();

        // Optimize resources
        manager.optimizeResources();

        final statsAfter = manager.getStatistics();

        // Should still have valid statistics
        expect(statsAfter.activeIsolates, greaterThanOrEqualTo(0));
        expect(statsAfter.completedTasks, equals(statsBefore.completedTasks));
      });

      test('should estimate memory usage', () async {
        final stats = manager.getStatistics();
        expect(stats.memoryUsage, greaterThanOrEqualTo(0.0));
      });
    });

    group('Error Handling', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should handle task cancellation', () async {
        final task = ProcessingTask(id: 'cancel_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        // Cancel the task immediately
        task.cancel();

        expect(task.cancelToken.isCancelled, isTrue);
        expect(() => task.future, throwsA(isA<TaskCancelledException>()));
      });

      test('should handle task completion with error', () async {
        final task = ProcessingTask(id: 'error_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        final error = Exception('Test error');
        task.completeError(error);

        expect(() => task.future, throwsA(equals(error)));
      });

      test('should handle task completion with result', () async {
        final task = ProcessingTask(id: 'success_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        final result = WaveformData(
          amplitudes: [0.1, 0.2, 0.3],
          sampleRate: 44100,
          duration: const Duration(seconds: 1),
          metadata: WaveformMetadata(resolution: 3, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
        );

        task.complete(result);

        final actualResult = await task.future;
        expect(actualResult, equals(result));
      });
    });

    group('Streaming Tasks', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should support streaming tasks', () async {
        final task = ProcessingTask(id: 'stream_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100), streamResults: true);

        expect(task.streamResults, isTrue);
        expect(task.progressStream, isNotNull);

        // The stream should be available even before execution
        expect(task.progressStream, isA<Stream<ProgressUpdate>>());
      });

      test('should handle progress updates for streaming tasks', () async {
        final task = ProcessingTask(id: 'progress_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100), streamResults: true);

        final progressUpdates = <ProgressUpdate>[];
        final subscription = task.progressStream!.listen(progressUpdates.add);

        // Simulate progress updates
        final update1 = ProgressUpdate(id: 'update1', timestamp: DateTime.now(), requestId: task.id, progress: 0.5, statusMessage: 'Processing...');

        final update2 = ProgressUpdate(id: 'update2', timestamp: DateTime.now(), requestId: task.id, progress: 1.0, statusMessage: 'Complete');

        task.sendProgress(update1);
        task.sendProgress(update2);

        // Wait a bit for stream processing
        await Future.delayed(const Duration(milliseconds: 10));

        expect(progressUpdates.length, equals(2));
        expect(progressUpdates[0].progress, equals(0.5));
        expect(progressUpdates[1].progress, equals(1.0));

        await subscription.cancel();
      });
    });

    group('Disposal', () {
      test('should dispose cleanly', () async {
        await manager.initialize();

        // Execute a task to create some state
        final task = ProcessingTask(id: 'disposal_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        await manager.executeTask(task);

        // Dispose should not throw
        await manager.dispose();

        // Should not be able to execute tasks after disposal
        final newTask = ProcessingTask(id: 'post_disposal_task', filePath: 'test_audio.mp3', config: const WaveformConfig(resolution: 100));

        expect(() => manager.executeTask(newTask), throwsA(isA<StateError>()));
      });

      test('should handle multiple disposal calls gracefully', () async {
        await manager.initialize();

        // First disposal
        await manager.dispose();

        // Second disposal should not throw
        await manager.dispose();
      });
    });
  });

  group('ProcessingTask', () {
    test('should create task with correct properties', () {
      final task = ProcessingTask(id: 'test_task', filePath: 'test.mp3', config: const WaveformConfig(resolution: 500), streamResults: true);

      expect(task.id, equals('test_task'));
      expect(task.filePath, equals('test.mp3'));
      expect(task.config.resolution, equals(500));
      expect(task.streamResults, isTrue);
      expect(task.createdAt, isA<DateTime>());
      expect(task.future, isA<Future<WaveformData>>());
      expect(task.progressStream, isNotNull);
      expect(task.cancelToken.isCancelled, isFalse);
    });

    test('should create non-streaming task correctly', () {
      final task = ProcessingTask(id: 'non_stream_task', filePath: 'test.mp3', config: const WaveformConfig(resolution: 500), streamResults: false);

      expect(task.streamResults, isFalse);
      expect(task.progressStream, isNull);
    });
  });

  group('CancelToken', () {
    test('should start as not cancelled', () {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);
    });

    test('should be cancellable', () {
      final token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('TaskCancelledException', () {
    test('should create with message', () {
      const message = 'Task was cancelled';
      final exception = TaskCancelledException(message);

      expect(exception.message, equals(message));
      expect(exception.toString(), contains(message));
    });
  });
}
