import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/utils/memory_manager.dart';
import 'package:sonix/src/utils/lru_cache.dart';
import 'package:sonix/src/models/waveform_data.dart';

void main() {
  group('MemoryManager', () {
    test('should track memory allocation and deallocation', () {
      final memoryManager = MemoryManager();
      memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB for testing

      try {
        expect(memoryManager.currentMemoryUsage, equals(0));

        memoryManager.allocateMemory(1024);
        expect(memoryManager.currentMemoryUsage, equals(1024));

        memoryManager.deallocateMemory(512);
        expect(memoryManager.currentMemoryUsage, equals(512));

        memoryManager.deallocateMemory(1024); // Should not go below 0
        expect(memoryManager.currentMemoryUsage, equals(0));
      } finally {
        memoryManager.dispose();
      }
    });

    test('should detect memory pressure', () {
      final memoryManager = MemoryManager();
      memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB for testing

      try {
        expect(memoryManager.isMemoryPressureHigh, isFalse);
        expect(memoryManager.isMemoryPressureCritical, isFalse);

        // Allocate memory to trigger pressure (need to exceed the thresholds)
        memoryManager.allocateMemory(950 * 1024); // 950KB - should exceed both thresholds
        expect(memoryManager.isMemoryPressureHigh, isTrue);
        expect(memoryManager.isMemoryPressureCritical, isTrue);
      } finally {
        memoryManager.dispose();
      }
    });

    test('should suggest quality reduction based on memory pressure', () {
      final memoryManager = MemoryManager();
      memoryManager.initialize(memoryLimit: 1024 * 1024); // 1MB for testing

      try {
        // Low memory usage - no reduction needed
        memoryManager.allocateMemory(500 * 1024); // 500KB
        var suggestion = memoryManager.getSuggestedQualityReduction();
        expect(suggestion.shouldReduce, isFalse);

        // High memory usage - should suggest reduction
        memoryManager.allocateMemory(450 * 1024); // Total 950KB - should trigger reduction
        suggestion = memoryManager.getSuggestedQualityReduction();
        expect(suggestion.shouldReduce, isTrue);
        expect(suggestion.resolutionReduction, lessThan(1.0));
      } finally {
        memoryManager.dispose();
      }
    });

    test('should estimate memory usage correctly', () {
      final waveformMemory = MemoryManager.estimateWaveformMemoryUsage(1000);
      expect(waveformMemory, greaterThan(8000)); // At least 8 bytes per amplitude

      final audioMemory = MemoryManager.estimateAudioMemoryUsage(44100);
      expect(audioMemory, greaterThan(352800)); // At least 8 bytes per sample
    });
  });

  group('LRUCache', () {
    late LRUCache<String, String> cache;

    setUp(() {
      cache = LRUCache<String, String>(3); // Small cache for testing
    });

    test('should store and retrieve values', () {
      cache.put('key1', 'value1');
      expect(cache.get('key1'), equals('value1'));
      expect(cache.size, equals(1));
    });

    test('should evict least recently used items when full', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.size, equals(3));

      // Access key1 to make it recently used
      cache.get('key1');

      // Add key4, should evict key2 (least recently used)
      cache.put('key4', 'value4');
      expect(cache.size, equals(3));
      expect(cache.get('key2'), isNull);
      expect(cache.get('key1'), equals('value1'));
      expect(cache.get('key4'), equals('value4'));
    });

    test('should provide cache statistics', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');

      final stats = cache.getStatistics();
      expect(stats.size, equals(2));
      expect(stats.maxSize, equals(3));
      expect(stats.utilization, closeTo(0.67, 0.01));
    });

    test('should clear all entries', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      expect(cache.size, equals(2));

      cache.clear();
      expect(cache.size, equals(0));
      expect(cache.isEmpty, isTrue);
    });
  });

  group('WaveformCache', () {
    late WaveformCache cache;

    setUp(() {
      cache = WaveformCache(maxSize: 5); // Increase size for testing
    });

    test('should cache waveform data by file path and config', () {
      final waveformData = WaveformData.fromAmplitudes([0.1, 0.2, 0.3]);

      cache.putWaveform('file1.mp3', 'config1', waveformData);

      final retrieved = cache.getWaveform('file1.mp3', 'config1');
      expect(retrieved, isNotNull);
      expect(retrieved!.amplitudes, equals([0.1, 0.2, 0.3]));
    });

    test('should clear waveforms for specific file', () {
      final waveform1 = WaveformData.fromAmplitudes([0.1, 0.2]);
      final waveform2 = WaveformData.fromAmplitudes([0.3, 0.4]);

      cache.putWaveform('file1.mp3', 'config1', waveform1);
      cache.putWaveform('file1.mp3', 'config2', waveform2);
      cache.putWaveform('file2.mp3', 'config1', waveform1);

      expect(cache.size, equals(3));

      cache.clearWaveformsForFile('file1.mp3');
      expect(cache.size, equals(1));
      expect(cache.hasWaveform('file2.mp3', 'config1'), isTrue);
    });
  });

  // ResourceManager tests omitted due to singleton complexity
}
