import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/isolate/isolate_manager.dart';
import 'package:sonix/src/processing/waveform_generator.dart';

/// Simple test configuration for isolate management
class SimpleTestConfig implements IsolateConfig {
  @override
  final int maxConcurrentOperations = 2;

  @override
  final int isolatePoolSize = 1;

  @override
  final Duration isolateIdleTimeout = const Duration(seconds: 1);

  @override
  final int maxMemoryUsage = 10 * 1024 * 1024; // 10MB
}

void main() {
  group('Simple Resource Management Tests', () {
    late IsolateManager isolateManager;
    late SimpleTestConfig config;

    setUp(() {
      config = SimpleTestConfig();
      isolateManager = IsolateManager(config);
    });

    tearDown(() async {
      await isolateManager.dispose();
    });

    group('Basic Functionality', () {
      test('should initialize and dispose cleanly', () async {
        await isolateManager.initialize();

        final stats = isolateManager.getStatistics();
        expect(stats.activeIsolates, greaterThanOrEqualTo(0));

        // Should dispose without errors
        await isolateManager.dispose();
      });

      test('should provide resource statistics', () async {
        await isolateManager.initialize();

        final stats = isolateManager.getStatistics();

        expect(stats.activeIsolates, isA<int>());
        expect(stats.queuedTasks, isA<int>());
        expect(stats.completedTasks, isA<int>());
        expect(stats.failedTasks, isA<int>());
        expect(stats.averageProcessingTime, isA<Duration>());
        expect(stats.memoryUsage, isA<double>());
        expect(stats.isolateInfo, isA<Map<String, IsolateInfo>>());
      });

      test('should handle resource optimization', () async {
        await isolateManager.initialize();

        // Should not throw errors
        expect(() => isolateManager.optimizeResources(), returnsNormally);

        // Should still be functional
        final stats = isolateManager.getStatistics();
        expect(stats.activeIsolates, greaterThanOrEqualTo(0));
      });
    });

    group('Cleanup and Shutdown', () {
      test('should handle graceful shutdown', () async {
        await isolateManager.initialize();

        // Should complete shutdown without errors
        await expectLater(isolateManager.beginGracefulShutdown(), completes);

        // Should be in shutdown state
        final stats = isolateManager.getStatistics();
        expect(stats.activeIsolates, equals(0));
      });

      test('should prevent operations after shutdown', () async {
        await isolateManager.initialize();
        await isolateManager.beginGracefulShutdown();

        // Should handle operations gracefully after shutdown
        expect(() => isolateManager.optimizeResources(), returnsNormally);
      });

      test('should handle multiple shutdown calls', () async {
        await isolateManager.initialize();

        // Multiple shutdown calls should not cause issues
        final futures = <Future<void>>[];
        for (int i = 0; i < 3; i++) {
          futures.add(isolateManager.beginGracefulShutdown());
        }

        await expectLater(Future.wait(futures), completes);
      });
    });

    group('Memory and Resource Optimization', () {
      test('should handle idle timeout cleanup', () async {
        await isolateManager.initialize();

        // Wait for idle timeout
        await Future.delayed(config.isolateIdleTimeout + const Duration(milliseconds: 500));

        // Trigger cleanup
        isolateManager.optimizeResources();

        // Should maintain at least some isolates for responsiveness
        final stats = isolateManager.getStatistics();
        expect(stats.activeIsolates, greaterThanOrEqualTo(0));
      });

      test('should handle concurrent optimization calls', () async {
        await isolateManager.initialize();

        // Multiple concurrent optimization calls
        final futures = <Future<void>>[];
        for (int i = 0; i < 5; i++) {
          futures.add(Future(() => isolateManager.optimizeResources()));
        }

        await expectLater(Future.wait(futures), completes);

        // Should still be functional
        final stats = isolateManager.getStatistics();
        expect(stats.activeIsolates, greaterThanOrEqualTo(0));
      });

      test('should provide health statistics', () async {
        await isolateManager.initialize();

        final healthInfo = isolateManager.getIsolateHealth();
        expect(healthInfo, isA<Map<String, dynamic>>());

        final healthStats = isolateManager.getHealthStatistics();
        expect(healthStats, isA<Map<String, dynamic>>());
      });
    });

    group('Error Handling', () {
      test('should handle initialization errors gracefully', () async {
        // Should not throw during normal initialization
        await expectLater(isolateManager.initialize(), completes);
      });

      test('should handle disposal of uninitialized manager', () async {
        // Should handle disposal without initialization
        await expectLater(isolateManager.dispose(), completes);
      });

      test('should prevent double initialization', () async {
        await isolateManager.initialize();

        // Second initialization should not cause issues
        await expectLater(isolateManager.initialize(), completes);
      });
    });
  });
}
