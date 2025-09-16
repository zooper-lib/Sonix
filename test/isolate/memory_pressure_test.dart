import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/utils/memory_manager.dart';

void main() {
  group('Memory Pressure Tests', () {
    late MemoryManager memoryManager;

    setUp(() {
      memoryManager = MemoryManager();
    });

    tearDown(() {
      memoryManager.dispose();
    });

    group('Memory Pressure Detection', () {
      test('should detect high memory pressure', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        expect(memoryManager.isMemoryPressureHigh, isFalse);
        expect(memoryManager.isMemoryPressureCritical, isFalse);

        // Allocate 85% of memory (should trigger high pressure)
        memoryManager.allocateMemory((1024 * 1024 * 0.85).round());

        expect(memoryManager.isMemoryPressureHigh, isTrue);
        expect(memoryManager.isMemoryPressureCritical, isFalse);
      });

      test('should detect critical memory pressure', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        // Allocate 95% of memory (should trigger critical pressure)
        memoryManager.allocateMemory((1024 * 1024 * 0.95).round());

        expect(memoryManager.isMemoryPressureHigh, isTrue);
        expect(memoryManager.isMemoryPressureCritical, isTrue);
      });

      test('should provide accurate memory usage percentage', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        expect(memoryManager.memoryUsagePercentage, equals(0.0));

        memoryManager.allocateMemory(512 * 1024); // 512KB
        expect(memoryManager.memoryUsagePercentage, closeTo(0.5, 0.01));

        memoryManager.allocateMemory(256 * 1024); // Additional 256KB
        expect(memoryManager.memoryUsagePercentage, closeTo(0.75, 0.01));
      });

      test('should handle memory deallocation correctly', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        memoryManager.allocateMemory(900 * 1024); // 900KB (87.5% - above 80% threshold)
        expect(memoryManager.isMemoryPressureHigh, isTrue);

        memoryManager.deallocateMemory(200 * 1024); // Deallocate 200KB, leaving 700KB (68.4% - below 80% threshold)
        expect(memoryManager.isMemoryPressureHigh, isFalse);
      });
    });

    group('Memory Pressure Callbacks', () {
      test('should trigger memory pressure callbacks', () async {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        var highPressureCallCount = 0;
        var criticalPressureCallCount = 0;

        memoryManager.registerMemoryPressureCallback(() {
          highPressureCallCount++;
        });

        memoryManager.registerCriticalMemoryCallback(() {
          criticalPressureCallCount++;
        });

        // Trigger high pressure
        memoryManager.allocateMemory(850 * 1024);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(highPressureCallCount, greaterThan(0));
        expect(criticalPressureCallCount, equals(0));

        // Trigger critical pressure
        memoryManager.allocateMemory(100 * 1024);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(criticalPressureCallCount, greaterThan(0));
      });

      test('should handle callback errors gracefully', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        // Register a callback that throws an error
        memoryManager.registerMemoryPressureCallback(() {
          throw Exception('Test callback error');
        });

        // Should not throw when triggering pressure
        expect(() {
          memoryManager.allocateMemory(850 * 1024);
        }, returnsNormally);
      });

      test('should allow callback removal', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        var callCount = 0;
        void callback() {
          callCount++;
        }

        memoryManager.registerMemoryPressureCallback(callback);

        // Trigger pressure
        memoryManager.allocateMemory(850 * 1024);
        expect(callCount, greaterThan(0));

        // Remove callback and reset
        memoryManager.removeMemoryPressureCallback(callback);
        memoryManager.deallocateMemory(850 * 1024);
        callCount = 0;

        // Trigger pressure again
        memoryManager.allocateMemory(850 * 1024);
        expect(callCount, equals(0)); // Callback should not be called
      });
    });

    group('Quality Reduction Suggestions', () {
      test('should suggest quality reduction under high memory pressure', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        // Trigger high memory pressure
        memoryManager.allocateMemory(850 * 1024);

        final suggestion = memoryManager.getSuggestedQualityReduction();

        expect(suggestion.shouldReduce, isTrue);
        expect(suggestion.resolutionReduction, lessThan(1.0));
        expect(suggestion.reason, contains('memory pressure'));
      });

      test('should suggest aggressive reduction under critical pressure', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        // Trigger critical memory pressure
        memoryManager.allocateMemory(950 * 1024);

        final suggestion = memoryManager.getSuggestedQualityReduction();

        expect(suggestion.shouldReduce, isTrue);
        expect(suggestion.resolutionReduction, lessThan(0.5));
        expect(suggestion.enableStreaming, isTrue);
        expect(suggestion.reason, contains('Critical memory pressure'));
      });

      test('should not suggest reduction under normal conditions', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        // Use only 50% of memory
        memoryManager.allocateMemory(512 * 1024);

        final suggestion = memoryManager.getSuggestedQualityReduction();

        expect(suggestion.shouldReduce, isFalse);
      });
    });

    group('Memory Estimation', () {
      test('should estimate waveform memory usage correctly', () {
        final amplitudeCount = 1000;
        final estimatedMemory = MemoryManager.estimateWaveformMemoryUsage(amplitudeCount);

        // Should be approximately 8 bytes per amplitude plus overhead
        expect(estimatedMemory, greaterThan(amplitudeCount * 8));
        expect(estimatedMemory, lessThan(amplitudeCount * 8 + 2048)); // Reasonable overhead
      });

      test('should estimate audio memory usage correctly', () {
        final sampleCount = 44100; // 1 second at 44.1kHz
        final estimatedMemory = MemoryManager.estimateAudioMemoryUsage(sampleCount);

        // Should be approximately 8 bytes per sample plus overhead
        expect(estimatedMemory, greaterThan(sampleCount * 8));
        expect(estimatedMemory, lessThan(sampleCount * 8 + 4096)); // Reasonable overhead
      });

      test('should check memory limit before allocation', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        // Should allow allocation within limit
        expect(memoryManager.wouldExceedMemoryLimit(512 * 1024), isFalse);

        // Should detect allocation that would exceed limit
        expect(memoryManager.wouldExceedMemoryLimit(2 * 1024 * 1024), isTrue);

        // After allocating some memory
        memoryManager.allocateMemory(800 * 1024);

        // Should detect that additional allocation would exceed limit
        expect(memoryManager.wouldExceedMemoryLimit(300 * 1024), isTrue);
        expect(memoryManager.wouldExceedMemoryLimit(200 * 1024), isFalse);
      });
    });

    group('Memory Monitoring', () {
      test('should handle force memory cleanup', () async {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        var cleanupCallCount = 0;
        memoryManager.registerMemoryPressureCallback(() {
          cleanupCallCount++;
        });

        // Force cleanup should trigger callbacks
        await memoryManager.forceMemoryCleanup();

        expect(cleanupCallCount, greaterThan(0));
      });

      test('should handle disposal correctly', () {
        memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB

        // Should dispose without errors
        expect(() => memoryManager.dispose(), returnsNormally);

        // Should reset state after disposal
        expect(memoryManager.currentMemoryUsage, equals(0));
      });
    });
  });
}
