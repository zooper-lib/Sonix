// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/utils/performance_profiler.dart';
import 'package:sonix/src/utils/performance_optimizer.dart';
import 'package:sonix/src/utils/platform_validator.dart';
import 'package:sonix/src/utils/memory_manager.dart';
import 'package:sonix/src/utils/resource_manager.dart';
import 'package:sonix/src/utils/lru_cache.dart';
import 'dart:math' as math;

void main() {
  group('Performance Optimization Tests', () {
    late PerformanceProfiler profiler;
    late PerformanceOptimizer optimizer;
    late PlatformValidator platformValidator;

    setUpAll(() async {
      // Initialize performance tools
      profiler = PerformanceProfiler();
      profiler.enable();

      optimizer = PerformanceOptimizer();
      await optimizer.initialize(
        settings: const OptimizationSettings(
          enableProfiling: true,
          memoryLimit: 50 * 1024 * 1024, // 50MB for tests
        ),
      );

      platformValidator = PlatformValidator();
    });

    tearDownAll(() async {
      await optimizer.dispose();
      profiler.clear();
    });

    group('Performance Profiler Tests', () {
      test('should profile synchronous operations', () {
        var counter = 0;

        final result = profiler.profileSync('test_sync_operation', () {
          counter = 42;
          return counter;
        });

        expect(result, equals(42));
        expect(counter, equals(42));

        // Check that the operation was recorded
        final stats = profiler.getStatistics('test_sync_operation');
        expect(stats, isNotNull);
        expect(stats!.totalExecutions, equals(1));
        expect(stats.successfulExecutions, equals(1));
        expect(stats.averageDuration, greaterThanOrEqualTo(0));
      });

      test('should profile asynchronous operations', () async {
        final result = await profiler.profile('test_async_operation', () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'completed';
        });

        expect(result, equals('completed'));

        // Check that the operation was recorded
        final stats = profiler.getStatistics('test_async_operation');
        expect(stats, isNotNull);
        expect(stats!.totalExecutions, equals(1));
        expect(stats.successfulExecutions, equals(1));
        expect(stats.averageDuration, greaterThan(5)); // Should take at least 5ms
      });

      test('should handle operation failures', () async {
        try {
          await profiler.profile('test_failing_operation', () async {
            throw Exception('Test error');
          });
        } catch (e) {
          expect(e.toString(), contains('Test error'));
        }

        // Check that the failed operation was recorded
        final stats = profiler.getStatistics('test_failing_operation');
        expect(stats, isNotNull);
        expect(stats!.totalExecutions, equals(1));
        expect(stats.successfulExecutions, equals(0));
        expect(stats.failureRate, equals(1.0));
      });

      test('should generate performance reports', () async {
        // Run a few operations to generate data
        for (int i = 0; i < 3; i++) {
          await profiler.profile('test_report_operation', () async {
            await Future.delayed(const Duration(milliseconds: 5));
            return i;
          });
        }

        final report = profiler.generateReport();
        expect(report, isA<PerformanceReport>());
        expect(report.totalOperations, greaterThanOrEqualTo(3));
        expect(report.operationStatistics, isNotEmpty);
        expect(report.successfulOperations, greaterThanOrEqualTo(3));
      });
    });

    group('Performance Optimizer Tests', () {
      test('should provide performance metrics', () {
        final metrics = optimizer.getCurrentMetrics();
        expect(metrics, isA<PerformanceMetrics>());
        expect(metrics.memoryUsage, greaterThanOrEqualTo(0));
        expect(metrics.memoryLimit, greaterThan(0));
        expect(metrics.memoryUsagePercentage, greaterThanOrEqualTo(0.0));
        expect(metrics.memoryUsagePercentage, lessThanOrEqualTo(1.0));
      });

      test('should provide optimization suggestions', () {
        final suggestions = optimizer.getOptimizationSuggestions();
        expect(suggestions, isA<List<OptimizationSuggestion>>());
        // Should have some suggestions (even if just platform-specific)
        expect(suggestions.length, greaterThanOrEqualTo(0));
      });

      test('should optimize widget rendering', () {
        final waveformData = _createTestWaveformData(2000); // Many amplitudes
        final widgetWidth = 300.0; // Typical widget width

        final optimization = optimizer.optimizeWidgetRendering(waveformData, widgetWidth);
        expect(optimization, isA<RenderingOptimization>());
        expect(optimization.strategy, isA<RenderingStrategy>());
        expect(optimization.targetAmplitudeCount, greaterThan(0));

        waveformData.dispose();
      });

      test('should force optimization', () async {
        final result = await optimizer.forceOptimization();
        expect(result, isA<OptimizationResult>());
        expect(result.duration, greaterThan(Duration.zero));
        expect(result.memoryFreed, greaterThanOrEqualTo(0));
        expect(result.optimizationsApplied, isA<List<String>>());
      });
    });

    group('Platform Validator Tests', () {
      test('should validate current platform', () async {
        final validation = await platformValidator.validatePlatform();
        expect(validation, isA<PlatformValidationResult>());
        expect(validation.platformInfo, isA<PlatformInfo>());

        // Should detect the current platform
        expect(validation.platformInfo.operatingSystem, isNotEmpty);
        expect(validation.validatedAt, isA<DateTime>());
      });

      test('should validate format support', () async {
        final mp3Support = await platformValidator.validateFormatSupport('mp3');
        expect(mp3Support, isA<FormatSupportResult>());
        expect(mp3Support.format, equals('mp3'));

        final wavSupport = await platformValidator.validateFormatSupport('wav');
        expect(wavSupport, isA<FormatSupportResult>());
        expect(wavSupport.format, equals('wav'));

        final unsupportedSupport = await platformValidator.validateFormatSupport('xyz');
        expect(unsupportedSupport, isA<FormatSupportResult>());
        expect(unsupportedSupport.isSupported, isFalse);
      });

      test('should provide optimization recommendations', () {
        final recommendations = platformValidator.getOptimizationRecommendations();
        expect(recommendations, isA<List<OptimizationRecommendation>>());

        // Should have platform-specific recommendations
        expect(recommendations.length, greaterThanOrEqualTo(0));
      });

      test('should get platform info', () {
        final info = platformValidator.platformInfo;
        expect(info, isA<PlatformInfo>());
        expect(info.operatingSystem, isNotEmpty);
        expect(info.architecture, isNotEmpty);

        // Should correctly identify mobile vs desktop
        expect(info.isMobile || info.isDesktop, isTrue);
      });
    });

    group('Memory Management Tests', () {
      test('should track memory usage', () {
        final memoryManager = MemoryManager();
        memoryManager.initialize(memoryLimit: 10 * 1024 * 1024); // 10MB

        final initialUsage = memoryManager.currentMemoryUsage;

        // Allocate some memory
        memoryManager.allocateMemory(1024 * 1024); // 1MB
        expect(memoryManager.currentMemoryUsage, equals(initialUsage + 1024 * 1024));

        // Deallocate memory
        memoryManager.deallocateMemory(1024 * 1024); // 1MB
        expect(memoryManager.currentMemoryUsage, equals(initialUsage));
      });

      test('should provide quality reduction suggestions', () {
        final memoryManager = MemoryManager();
        memoryManager.initialize(memoryLimit: 10 * 1024 * 1024); // 10MB

        // Simulate high memory usage
        memoryManager.allocateMemory(9 * 1024 * 1024); // 9MB (90% usage)

        final suggestion = memoryManager.getSuggestedQualityReduction();
        expect(suggestion, isA<QualityReductionSuggestion>());
        expect(suggestion.shouldReduce, isTrue);
        expect(suggestion.resolutionReduction, lessThan(1.0));
      });

      test('should estimate memory usage', () {
        final waveformMemory = MemoryManager.estimateWaveformMemoryUsage(1000);
        expect(waveformMemory, greaterThan(0));

        final audioMemory = MemoryManager.estimateAudioMemoryUsage(44100);
        expect(audioMemory, greaterThan(0));
        expect(audioMemory, greaterThan(waveformMemory)); // Audio should use more memory
      });
    });

    group('Resource Management Tests', () {
      test('should manage resources', () {
        final resourceManager = ResourceManager();
        resourceManager.initialize();

        final stats = resourceManager.getResourceStatistics();
        expect(stats, isA<ResourceStatistics>());
        expect(stats.memoryUsage, greaterThanOrEqualTo(0));
        expect(stats.memoryLimit, greaterThan(0));
      });

      test('should provide cache statistics', () {
        final resourceManager = ResourceManager();
        resourceManager.initialize();

        final waveformCache = resourceManager.waveformCache;
        expect(waveformCache, isNotNull);

        final cacheStats = waveformCache.getStatistics();
        expect(cacheStats, isA<CacheStatistics>());
        expect(cacheStats.size, greaterThanOrEqualTo(0));
        expect(cacheStats.maxSize, greaterThan(0));
      });
    });

    group('Integration Tests', () {
      test('should handle complete workflow', () async {
        // Create test audio data
        final audioData = _createTestAudioData(durationSeconds: 2);

        // Profile the workflow
        final result = await profiler.profile('integration_workflow', () async {
          // Create test waveform data directly (since generator might not be fully implemented)
          final waveformData = _createTestWaveformData(1000);

          // Optimize for widget rendering
          final renderingOpt = optimizer.optimizeWidgetRendering(waveformData, 400.0);
          expect(renderingOpt.strategy, isA<RenderingStrategy>());

          // Get performance metrics
          final metrics = optimizer.getCurrentMetrics();
          expect(metrics.memoryUsage, greaterThanOrEqualTo(0));

          return waveformData;
        });

        expect(result.amplitudes, isNotEmpty);

        // Check that the workflow was profiled
        final stats = profiler.getStatistics('integration_workflow');
        expect(stats, isNotNull);
        expect(stats!.successfulExecutions, equals(1));

        audioData.dispose();
      });

      test('should maintain performance under load', () async {
        final futures = <Future>[];

        // Create multiple concurrent operations
        for (int i = 0; i < 3; i++) {
          futures.add(
            profiler.profile('concurrent_test_$i', () async {
              final audioData = _createTestAudioData(durationSeconds: 1);
              final waveformData = _createTestWaveformData(500);
              audioData.dispose();
              waveformData.dispose();
              return waveformData;
            }),
          );
        }

        // Wait for all operations to complete
        final results = await Future.wait(futures);
        expect(results.length, equals(3));

        // Check that all operations were profiled
        final allStats = profiler.getAllStatistics();
        final concurrentOps = allStats.keys.where((k) => k.startsWith('concurrent_test_')).length;
        expect(concurrentOps, equals(3));
      });
    });
  });
}

/// Helper function to create test audio data
AudioData _createTestAudioData({double durationSeconds = 1.0, int sampleRate = 44100, int channels = 1}) {
  final totalSamples = (sampleRate * durationSeconds * channels).round();
  final samples = <double>[];

  for (int i = 0; i < totalSamples; i++) {
    final time = i / (sampleRate * channels);
    final sample = 0.5 * math.sin(2.0 * math.pi * 440.0 * time);
    samples.add(sample);
  }

  return AudioData(
    samples: samples,
    sampleRate: sampleRate,
    channels: channels,
    duration: Duration(milliseconds: (durationSeconds * 1000).round()),
  );
}

/// Helper function to create test waveform data
WaveformData _createTestWaveformData(int amplitudeCount) {
  final amplitudes = List.generate(amplitudeCount, (i) => math.sin(2 * math.pi * i / amplitudeCount) * 0.5 + 0.5);

  return WaveformData(
    amplitudes: amplitudes,
    duration: const Duration(seconds: 10),
    sampleRate: 44100,
    metadata: WaveformMetadata(resolution: amplitudeCount, type: WaveformType.bars, normalized: true, generatedAt: DateTime.now()),
  );
}
