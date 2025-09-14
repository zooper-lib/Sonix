import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/processing/waveform_generator.dart';

// Simple test configuration
class SimpleConfig implements IsolateConfig {
  @override
  final int maxConcurrentOperations = 2;
  @override
  final int isolatePoolSize = 1;
  @override
  final Duration isolateIdleTimeout = const Duration(seconds: 5);
  @override
  final int maxMemoryUsage = 50 * 1024 * 1024;
}

void main() {
  group('IsolateManager Basic Tests', () {
    test('should create IsolateManager instance', () {
      final config = SimpleConfig();
      final manager = IsolateManager(config);

      expect(manager, isNotNull);
      expect(manager.config, equals(config));
    });

    test('should initialize and dispose cleanly', () async {
      final config = SimpleConfig();
      final manager = IsolateManager(config);

      await manager.initialize();

      final stats = manager.getStatistics();
      expect(stats, isNotNull);
      expect(stats.activeIsolates, greaterThanOrEqualTo(0));

      await manager.dispose();
    });

    test('should create ProcessingTask correctly', () {
      final task = ProcessingTask(id: 'test_task', filePath: 'test.mp3', config: const WaveformConfig(resolution: 100));

      expect(task.id, equals('test_task'));
      expect(task.filePath, equals('test.mp3'));
      expect(task.config.resolution, equals(100));
      expect(task.streamResults, isFalse);
      expect(task.cancelToken.isCancelled, isFalse);
    });

    test('should handle task cancellation', () async {
      final task = ProcessingTask(id: 'cancel_task', filePath: 'test.mp3', config: const WaveformConfig(resolution: 100));

      expect(task.cancelToken.isCancelled, isFalse);

      task.cancel();

      expect(task.cancelToken.isCancelled, isTrue);

      // The future should complete with an error
      expect(() => task.future, throwsA(isA<TaskCancelledException>()));
    });
  });
}
