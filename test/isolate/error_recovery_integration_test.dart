import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/isolate/isolate_config.dart';
import 'package:sonix/src/isolate/isolate_health_monitor.dart';
import 'package:sonix/src/processing/waveform_config.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import '../ffmpeg/ffmpeg_setup_helper.dart';

/// Mock configuration for testing
class MockIsolateConfig implements IsolateConfig {
  @override
  final int maxConcurrentOperations;

  @override
  final int isolatePoolSize;

  @override
  final Duration isolateIdleTimeout;

  @override
  final int maxMemoryUsage;

  const MockIsolateConfig({
    this.maxConcurrentOperations = 2,
    this.isolatePoolSize = 1,
    this.isolateIdleTimeout = const Duration(seconds: 30),
    this.maxMemoryUsage = 50 * 1024 * 1024, // 50MB
  });
}

void main() {
  setUpAll(() async {
    // Setup FFMPEG binaries for testing
    await FFMPEGSetupHelper.setupFFMPEGForTesting();
  });

  group('Isolate Error Recovery Integration', () {
    late IsolateManager manager;
    late MockIsolateConfig config;

    setUp(() {
      config = const MockIsolateConfig();
      manager = IsolateManager(config, maxRetryAttempts: 2, enableErrorRecovery: true);
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('should initialize isolate manager with error recovery', () async {
      await manager.initialize();

      final stats = manager.getStatistics();
      expect(stats.activeIsolates, equals(1));
      expect(stats.completedTasks, equals(0));
      expect(stats.failedTasks, equals(0));
    });

    test('should track isolate health statistics', () async {
      await manager.initialize();

      final healthStats = manager.getHealthStatistics();
      expect(healthStats['totalIsolates'], equals(1));
      expect(healthStats['healthyIsolates'], equals(1));
      expect(healthStats['crashedIsolates'], equals(0));
    });

    test('should provide isolate health information', () async {
      await manager.initialize();

      final healthMap = manager.getIsolateHealth();
      expect(healthMap.length, equals(1));

      final health = healthMap.values.first;
      expect(health.status, equals(IsolateHealthStatus.healthy));
      expect(health.completedTasks, equals(0));
      expect(health.failedTasks, equals(0));
    });

    test('should handle error recovery configuration', () {
      // Test with error recovery disabled
      final managerNoRecovery = IsolateManager(config, maxRetryAttempts: 0, enableErrorRecovery: false);

      expect(managerNoRecovery.maxRetryAttempts, equals(0));
      expect(managerNoRecovery.enableErrorRecovery, isFalse);

      managerNoRecovery.dispose();
    });

    test('should handle multiple isolate configurations', () async {
      final multiIsolateConfig = MockIsolateConfig(isolatePoolSize: 3, maxConcurrentOperations: 5);

      final multiManager = IsolateManager(multiIsolateConfig);
      await multiManager.initialize();

      final stats = multiManager.getStatistics();
      expect(stats.activeIsolates, equals(1)); // Only initial isolate spawned

      await multiManager.dispose();
    });

    test('should properly dispose and clean up resources', () async {
      await manager.initialize();

      // Verify manager is initialized
      var stats = manager.getStatistics();
      expect(stats.activeIsolates, greaterThan(0));

      // Dispose manager
      await manager.dispose();

      // Verify cleanup
      stats = manager.getStatistics();
      expect(stats.activeIsolates, equals(0));
      expect(stats.queuedTasks, equals(0));
    });

    test('should handle configuration validation', () {
      // Test edge case configurations
      final edgeConfig = MockIsolateConfig(isolatePoolSize: 0, maxConcurrentOperations: 0);

      final edgeManager = IsolateManager(edgeConfig);
      expect(edgeManager, isNotNull);

      edgeManager.dispose();
    });

    test('should track processing statistics correctly', () async {
      await manager.initialize();

      // Initial state
      var stats = manager.getStatistics();
      expect(stats.completedTasks, equals(0));
      expect(stats.failedTasks, equals(0));

      // The actual task execution would require a real isolate setup
      // For this test, we're just verifying the statistics tracking structure
      expect(stats.averageProcessingTime, equals(Duration.zero));
    });

    test('should handle health monitoring integration', () async {
      await manager.initialize();

      final healthStats = manager.getHealthStatistics();
      expect(healthStats, containsPair('totalIsolates', 1));
      expect(healthStats, containsPair('healthyIsolates', 1));
      expect(healthStats, containsPair('unresponsiveIsolates', 0));
      expect(healthStats, containsPair('crashedIsolates', 0));
      expect(healthStats, containsPair('totalCompletedTasks', 0));
      expect(healthStats, containsPair('totalFailedTasks', 0));
    });

    test('should validate error recovery parameters', () {
      // Test various retry configurations
      final configs = [
        (maxRetries: 0, enableRecovery: false),
        (maxRetries: 1, enableRecovery: true),
        (maxRetries: 5, enableRecovery: true),
        (maxRetries: 10, enableRecovery: false),
      ];

      for (final config in configs) {
        final testManager = IsolateManager(const MockIsolateConfig(), maxRetryAttempts: config.maxRetries, enableErrorRecovery: config.enableRecovery);

        expect(testManager.maxRetryAttempts, equals(config.maxRetries));
        expect(testManager.enableErrorRecovery, equals(config.enableRecovery));

        testManager.dispose();
      }
    });

    test('should handle concurrent initialization and disposal', () async {
      // Test rapid initialization and disposal
      final futures = <Future>[];

      for (int i = 0; i < 3; i++) {
        final testManager = IsolateManager(config);
        futures.add(testManager.initialize().then((_) => testManager.dispose()));
      }

      await Future.wait(futures);
      // If we get here without exceptions, the test passes
    });

    test('should maintain isolate pool size constraints', () async {
      final poolConfig = MockIsolateConfig(isolatePoolSize: 2);
      final poolManager = IsolateManager(poolConfig);

      await poolManager.initialize();

      // Should start with 1 isolate (minimum)
      var stats = poolManager.getStatistics();
      expect(stats.activeIsolates, equals(1));

      await poolManager.dispose();
    });
  });

  group('Error Handling Edge Cases', () {
    test('should handle invalid isolate configurations gracefully', () {
      // Test with extreme configurations
      final extremeConfig = MockIsolateConfig(
        isolatePoolSize: -1, // Invalid
        maxConcurrentOperations: -1, // Invalid
        maxMemoryUsage: -1, // Invalid
      );

      // Should not throw during construction
      final manager = IsolateManager(extremeConfig);
      expect(manager, isNotNull);

      manager.dispose();
    });

    test('should handle disposal of uninitialized manager', () async {
      final manager = IsolateManager(const MockIsolateConfig());

      // Should not throw when disposing uninitialized manager
      await manager.dispose();
    });

    test('should handle multiple disposal calls', () async {
      final manager = IsolateManager(const MockIsolateConfig());
      await manager.initialize();

      // Multiple disposal calls should be safe
      await manager.dispose();
      await manager.dispose();
      await manager.dispose();
    });

    test('should validate error recovery with different error types', () {
      final manager = IsolateManager(const MockIsolateConfig(), enableErrorRecovery: true);

      // Test that manager accepts different error recovery settings
      expect(manager.enableErrorRecovery, isTrue);
      expect(manager.maxRetryAttempts, equals(3)); // Default value

      manager.dispose();
    });

    test('should respect maxRetryAttempts limit for failed tasks', () async {
      final tempDir = await Directory.systemTemp.createTemp('sonix_retry_test_');
      try {
        // Create an empty file that will cause decoding to fail
        final emptyFile = File('${tempDir.path}/empty.mp4');
        await emptyFile.writeAsBytes([]);

        final testManager = IsolateManager(
          const MockIsolateConfig(),
          maxRetryAttempts: 2,
          enableErrorRecovery: true,
        );

        try {
          await testManager.executeTask(
            ProcessingTask(
              id: 'test_retry_limit',
              filePath: emptyFile.path,
              config: WaveformConfig(),
            ),
          );
          fail('Should have thrown an exception');
        } catch (e) {
          // Expected to fail after retries
          expect(e, isA<SonixException>());
        }

        await testManager.dispose();
      } finally {
        await tempDir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('should correctly track retry attempts across multiple retries', () {
      // Test the base task ID extraction logic with various retry suffixes
      const originalTaskId = 'task_12345';
      const retryTaskId1 = 'task_12345_retry_1';
      const retryTaskId2 = 'task_12345_retry_1_retry_2';
      const retryTaskId3 = 'task_12345_retry_1_retry_2_retry_3';

      // All these IDs should map to the same base task
      expect(originalTaskId.replaceAll(RegExp(r'_retry_\d+'), ''), equals('task_12345'));
      expect(retryTaskId1.replaceAll(RegExp(r'_retry_\d+'), ''), equals('task_12345'));
      expect(retryTaskId2.replaceAll(RegExp(r'_retry_\d+'), ''), equals('task_12345'));
      expect(retryTaskId3.replaceAll(RegExp(r'_retry_\d+'), ''), equals('task_12345'));
    });
  });

  group('Performance and Resource Management', () {
    test('should handle resource optimization calls', () async {
      final manager = IsolateManager(const MockIsolateConfig());
      await manager.initialize();

      // Should not throw when optimizing resources
      manager.optimizeResources();

      await manager.dispose();
    });

    test('should provide consistent statistics', () async {
      final manager = IsolateManager(const MockIsolateConfig());
      await manager.initialize();

      // Get statistics multiple times
      final stats1 = manager.getStatistics();
      final stats2 = manager.getStatistics();

      // Should be consistent
      expect(stats1.activeIsolates, equals(stats2.activeIsolates));
      expect(stats1.completedTasks, equals(stats2.completedTasks));
      expect(stats1.failedTasks, equals(stats2.failedTasks));

      await manager.dispose();
    });

    test('should handle health statistics consistently', () async {
      final manager = IsolateManager(const MockIsolateConfig());
      await manager.initialize();

      // Get health statistics multiple times
      final health1 = manager.getHealthStatistics();
      final health2 = manager.getHealthStatistics();

      // Should be consistent
      expect(health1['totalIsolates'], equals(health2['totalIsolates']));
      expect(health1['healthyIsolates'], equals(health2['healthyIsolates']));

      await manager.dispose();
    });
  });
}
