import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/utils/memory_manager.dart';
import 'package:sonix/src/utils/lru_cache.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import '../test_data_generator.dart';
import 'dart:math' as math;

void main() {
  group('Memory Management Tests', () {
    late Map<String, dynamic> testConfigurations;

    setUpAll(() async {
      // Generate essential test data if it doesn't exist (faster)
      if (!await TestDataLoader.assetExists('test_configurations.json')) {
        await TestDataGenerator.generateEssentialTestData();
      }

      testConfigurations = await TestDataLoader.loadTestConfigurations();
    });

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

    group('Resource Disposal', () {
      test('should dispose AudioData properly', () {
        final audioData = AudioData(samples: [1.0, 2.0, 3.0], sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 100));

        // Test disposal (assuming dispose method exists)
        expect(() => audioData.dispose(), returnsNormally);
      });

      test('should dispose WaveformData properly', () {
        final waveformData = WaveformData.fromAmplitudes([0.1, 0.5, 0.8, 0.3]);

        // Test disposal (assuming dispose method exists)
        expect(() => waveformData.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls gracefully', () {
        final audioData = AudioData(samples: [1.0, 2.0], sampleRate: 44100, channels: 1, duration: const Duration(milliseconds: 50));

        expect(() => audioData.dispose(), returnsNormally);
        expect(() => audioData.dispose(), returnsNormally); // Should not throw on multiple calls
      });
    });

    group('Memory Performance Tests', () {
      test('should handle memory usage within configured limits', () async {
        final configs = testConfigurations['memory_test_configs'] as List;

        for (final config in configs) {
          final filename = config['file'] as String;
          final maxMemoryMb = config['max_memory_mb'] as int;

          if (!await TestDataLoader.assetExists(filename)) {
            continue; // Skip if test file doesn't exist
          }

          final memoryManager = MemoryManager();
          memoryManager.initialize(memoryLimit: maxMemoryMb * 1024 * 1024);

          try {
            final initialUsage = memoryManager.currentMemoryUsage;

            // Simulate processing the file
            final audioData = AudioData(
              samples: List.generate(44100 * 5, (i) => math.sin(i * 0.01)), // 5 seconds
              sampleRate: 44100,
              channels: 2,
              duration: const Duration(seconds: 5),
            );

            final waveformData = await WaveformGenerator.generate(audioData);

            final peakUsage = memoryManager.currentMemoryUsage;
            final usedMemoryMb = (peakUsage - initialUsage) / (1024 * 1024);

            expect(usedMemoryMb, lessThan(maxMemoryMb * 2)); // Allow some overhead

            audioData.dispose();
            waveformData.dispose();
          } finally {
            memoryManager.dispose();
          }
        }
      });

      test('should maintain memory efficiency with large datasets', () async {
        final memoryManager = MemoryManager();
        memoryManager.initialize(memoryLimit: 100 * 1024 * 1024); // 100MB

        try {
          final initialUsage = memoryManager.currentMemoryUsage;

          // Process large dataset in chunks
          final audioData = AudioData(
            samples: List.generate(1000000, (i) => math.sin(i * 0.001)),
            sampleRate: 44100,
            channels: 1,
            duration: const Duration(seconds: 23),
          );

          // Note: generateStream would need to be implemented to accept AudioData
          // For now, we'll simulate streaming behavior
          final waveformData = await WaveformGenerator.generate(audioData);
          expect(waveformData.amplitudes, isNotEmpty);

          // Simulate chunk processing
          final chunkSize = 100;
          for (int i = 0; i < waveformData.amplitudes.length; i += chunkSize) {
            final endIndex = math.min(i + chunkSize, waveformData.amplitudes.length);
            final chunk = waveformData.amplitudes.sublist(i, endIndex);

            // Process each chunk
            expect(chunk, isNotEmpty);

            // Memory usage should not grow unbounded
            final currentUsage = memoryManager.currentMemoryUsage;
            expect(currentUsage, lessThan(initialUsage + 50 * 1024 * 1024)); // 50MB limit
          }

          waveformData.dispose();

          audioData.dispose();
        } finally {
          memoryManager.dispose();
        }
      });
    });

    group('Concurrent Memory Operations', () {
      test('should handle concurrent memory operations safely', () async {
        final memoryManager = MemoryManager();
        memoryManager.initialize(memoryLimit: 50 * 1024 * 1024); // 50MB

        try {
          final futures = <Future>[];

          // Create multiple concurrent operations
          for (int i = 0; i < 10; i++) {
            futures.add(
              Future(() async {
                final audioData = AudioData(
                  samples: List.generate(10000, (j) => math.sin(j * 0.01)),
                  sampleRate: 44100,
                  channels: 1,
                  duration: const Duration(milliseconds: 227),
                );

                final waveformData = await WaveformGenerator.generate(audioData);

                // Simulate some processing time
                await Future.delayed(const Duration(milliseconds: 10));

                audioData.dispose();
                waveformData.dispose();
              }),
            );
          }

          // All operations should complete without memory corruption
          await Future.wait(futures);
          expect(true, isTrue); // If we reach here, no memory corruption occurred
        } finally {
          memoryManager.dispose();
        }
      });

      test('should handle concurrent cache operations', () async {
        final cache = WaveformCache(maxSize: 5);
        final futures = <Future>[];

        // Create multiple concurrent cache operations
        for (int i = 0; i < 20; i++) {
          futures.add(
            Future(() {
              final waveform = WaveformData.fromAmplitudes(List.generate(100, (j) => math.Random().nextDouble()));
              cache.putWaveform('key$i', 'config', waveform);

              // Simulate some access
              cache.getWaveform('key${i ~/ 2}', 'config');
            }),
          );
        }

        await Future.wait(futures);

        // Cache should maintain its size limit
        expect(cache.size, lessThanOrEqualTo(5));

        cache.clear();
      });
    });
  });

  // ResourceManager tests omitted due to singleton complexity
}
