import 'dart:async';
import 'dart:math' as math;

import '../models/waveform_data.dart';
import '../models/audio_data.dart';
import '../processing/waveform_generator.dart';
import 'memory_manager.dart';
import 'resource_manager.dart';
import 'performance_profiler.dart';
import 'platform_validator.dart';

/// Advanced performance optimizer for Sonix operations
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  final MemoryManager _memoryManager = MemoryManager();
  final ResourceManager _resourceManager = ResourceManager();
  final PerformanceProfiler _profiler = PerformanceProfiler();
  final PlatformValidator _platformValidator = PlatformValidator();

  bool _isInitialized = false;
  OptimizationSettings _settings = const OptimizationSettings();

  /// Initialize the performance optimizer
  Future<void> initialize({OptimizationSettings? settings}) async {
    if (_isInitialized) return;

    _settings = settings ?? const OptimizationSettings();

    // Initialize dependencies
    _memoryManager.initialize(memoryLimit: _settings.memoryLimit);
    _resourceManager.initialize(maxWaveformCacheSize: _settings.maxCacheSize, memoryLimit: _settings.memoryLimit);

    if (_settings.enableProfiling) {
      _profiler.enable();
    }

    // Validate platform and apply optimizations
    final validation = await _platformValidator.validatePlatform();
    if (validation.isSupported) {
      await _applyPlatformOptimizations(validation);
    }

    _isInitialized = true;
  }

  /// Optimize waveform generation based on current conditions
  Future<WaveformData> optimizeWaveformGeneration(AudioData audioData, {WaveformConfig? config, bool forceOptimization = false}) async {
    _ensureInitialized();

    return await _profiler.profile(
      'optimized_waveform_generation',
      () async {
        final optimizedConfig = await _optimizeWaveformConfig(audioData, config, forceOptimization);

        // Choose the best generation strategy
        if (_shouldUseStreaming(audioData, optimizedConfig)) {
          return await _generateWaveformStreaming(audioData, optimizedConfig);
        } else if (_shouldUseBatching(audioData, optimizedConfig)) {
          return await _generateWaveformBatched(audioData, optimizedConfig);
        } else {
          return await WaveformGenerator.generate(audioData, config: optimizedConfig);
        }
      },
      metadata: {'audio_duration': audioData.duration.inSeconds, 'sample_count': audioData.samples.length, 'resolution': config?.resolution ?? 1000},
    );
  }

  /// Optimize widget rendering performance
  RenderingOptimization optimizeWidgetRendering(WaveformData waveformData, double widgetWidth) {
    _ensureInitialized();

    final amplitudeCount = waveformData.amplitudes.length;
    final pixelsPerAmplitude = widgetWidth / amplitudeCount;

    // Determine optimal rendering strategy
    if (pixelsPerAmplitude < 0.5) {
      // Too many amplitudes for the widget width - downsample
      final targetCount = (widgetWidth * 2).round(); // 2 amplitudes per pixel
      return RenderingOptimization(
        strategy: RenderingStrategy.downsample,
        targetAmplitudeCount: targetCount,
        reason: 'Too many amplitudes for widget width (${pixelsPerAmplitude.toStringAsFixed(2)} pixels per amplitude)',
      );
    } else if (pixelsPerAmplitude > 10) {
      // Too few amplitudes - could interpolate for smoother rendering
      return RenderingOptimization(
        strategy: RenderingStrategy.interpolate,
        targetAmplitudeCount: (widgetWidth / 2).round(),
        reason: 'Could interpolate for smoother rendering (${pixelsPerAmplitude.toStringAsFixed(2)} pixels per amplitude)',
      );
    } else {
      // Optimal rendering
      return RenderingOptimization(
        strategy: RenderingStrategy.direct,
        targetAmplitudeCount: amplitudeCount,
        reason: 'Optimal amplitude count for widget width',
      );
    }
  }

  /// Get current performance metrics
  PerformanceMetrics getCurrentMetrics() {
    _ensureInitialized();

    final resourceStats = _resourceManager.getResourceStatistics();
    final memoryUsage = _memoryManager.currentMemoryUsage;
    final memoryLimit = _memoryManager.memoryLimit;

    return PerformanceMetrics(
      memoryUsage: memoryUsage,
      memoryLimit: memoryLimit,
      memoryUsagePercentage: memoryUsage / memoryLimit,
      cacheHitRate: _calculateCacheHitRate(resourceStats),
      activeResourceCount: resourceStats.managedResourceCount,
      averageOperationTime: _calculateAverageOperationTime(),
      isMemoryPressureHigh: _memoryManager.isMemoryPressureHigh,
      isMemoryPressureCritical: _memoryManager.isMemoryPressureCritical,
    );
  }

  /// Get optimization suggestions based on current performance
  List<OptimizationSuggestion> getOptimizationSuggestions() {
    _ensureInitialized();

    final suggestions = <OptimizationSuggestion>[];
    final metrics = getCurrentMetrics();

    // Memory-based suggestions
    if (metrics.isMemoryPressureCritical) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.memory,
          priority: SuggestionPriority.critical,
          title: 'Critical Memory Pressure',
          description:
              'Memory usage is at ${(metrics.memoryUsagePercentage * 100).toStringAsFixed(1)}%. '
              'Consider reducing waveform resolution or enabling streaming processing.',
          action: 'Reduce resolution by 50% or enable streaming for large files',
        ),
      );
    } else if (metrics.isMemoryPressureHigh) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.memory,
          priority: SuggestionPriority.high,
          title: 'High Memory Pressure',
          description:
              'Memory usage is at ${(metrics.memoryUsagePercentage * 100).toStringAsFixed(1)}%. '
              'Consider optimizing memory usage.',
          action: 'Clear unused cache entries or reduce waveform resolution',
        ),
      );
    }

    // Cache-based suggestions
    if (metrics.cacheHitRate < 0.5) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.caching,
          priority: SuggestionPriority.medium,
          title: 'Low Cache Hit Rate',
          description:
              'Cache hit rate is ${(metrics.cacheHitRate * 100).toStringAsFixed(1)}%. '
              'Consider increasing cache size or reviewing access patterns.',
          action: 'Increase cache size or implement better caching strategy',
        ),
      );
    }

    // Performance-based suggestions
    if (metrics.averageOperationTime > 1000) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.performance,
          priority: SuggestionPriority.high,
          title: 'Slow Operations',
          description:
              'Average operation time is ${metrics.averageOperationTime.toStringAsFixed(1)}ms. '
              'Consider using streaming processing or reducing resolution.',
          action: 'Enable streaming processing for large files',
        ),
      );
    }

    // Platform-specific suggestions
    final platformRecommendations = _platformValidator.getOptimizationRecommendations();
    for (final rec in platformRecommendations) {
      suggestions.add(
        OptimizationSuggestion(
          type: OptimizationType.platform,
          priority: _convertRecommendationPriority(rec.priority),
          title: rec.title,
          description: rec.description,
          action: 'Apply ${rec.category.toLowerCase()} optimization',
        ),
      );
    }

    return suggestions;
  }

  /// Force optimization of all resources
  Future<OptimizationResult> forceOptimization() async {
    _ensureInitialized();

    final startTime = DateTime.now();
    final startMetrics = getCurrentMetrics();

    // Clear caches if memory pressure is high
    if (startMetrics.isMemoryPressureHigh) {
      await _resourceManager.forceCleanup();
    }

    // Force garbage collection
    await _memoryManager.forceMemoryCleanup();

    // Wait for cleanup to take effect
    await Future.delayed(const Duration(milliseconds: 500));

    final endTime = DateTime.now();
    final endMetrics = getCurrentMetrics();

    return OptimizationResult(
      startMetrics: startMetrics,
      endMetrics: endMetrics,
      duration: endTime.difference(startTime),
      memoryFreed: startMetrics.memoryUsage - endMetrics.memoryUsage,
      optimizationsApplied: [if (startMetrics.isMemoryPressureHigh) 'Cache cleanup', 'Memory cleanup'],
    );
  }

  /// Optimize waveform configuration based on current conditions
  Future<WaveformConfig> _optimizeWaveformConfig(AudioData audioData, WaveformConfig? config, bool forceOptimization) async {
    final baseConfig = config ?? WaveformConfig();

    if (!forceOptimization && !_memoryManager.isMemoryPressureHigh) {
      return baseConfig;
    }

    final suggestion = _memoryManager.getSuggestedQualityReduction();
    if (!suggestion.shouldReduce) {
      return baseConfig;
    }

    // Apply quality reduction
    final optimizedResolution = (baseConfig.resolution * suggestion.resolutionReduction).round();

    return baseConfig.copyWith(resolution: optimizedResolution);
  }

  /// Check if streaming should be used
  bool _shouldUseStreaming(AudioData audioData, WaveformConfig config) {
    final estimatedMemory = MemoryManager.estimateAudioMemoryUsage(audioData.samples.length);
    return estimatedMemory > (_settings.streamingThreshold ?? 50 * 1024 * 1024); // 50MB default
  }

  /// Check if batching should be used
  bool _shouldUseBatching(AudioData audioData, WaveformConfig config) {
    final estimatedMemory = MemoryManager.estimateAudioMemoryUsage(audioData.samples.length);
    return estimatedMemory > (_settings.batchingThreshold ?? 20 * 1024 * 1024); // 20MB default
  }

  /// Generate waveform using streaming approach
  Future<WaveformData> _generateWaveformStreaming(AudioData audioData, WaveformConfig config) async {
    // This would implement streaming waveform generation
    // For now, we'll use the regular generator with optimized settings
    return await WaveformGenerator.generate(audioData, config: config);
  }

  /// Generate waveform using batched approach
  Future<WaveformData> _generateWaveformBatched(AudioData audioData, WaveformConfig config) async {
    // This would implement batched waveform generation
    // For now, we'll use the regular generator
    return await WaveformGenerator.generate(audioData, config: config);
  }

  /// Apply platform-specific optimizations
  Future<void> _applyPlatformOptimizations(PlatformValidationResult validation) async {
    final info = validation.platformInfo;

    if (info.isMobile) {
      // Mobile optimizations
      _settings = _settings.copyWith(
        memoryLimit: math.min(_settings.memoryLimit, 100 * 1024 * 1024), // 100MB max on mobile
        maxCacheSize: math.min(_settings.maxCacheSize, 20), // Smaller cache on mobile
        streamingThreshold: 20 * 1024 * 1024, // Lower streaming threshold
      );
    }

    if (info.isAndroid) {
      // Android-specific optimizations
      _memoryManager.registerMemoryPressureCallback(() {
        // Aggressive cleanup on Android
        _resourceManager.forceCleanup();
      });
    }
  }

  /// Calculate cache hit rate
  double _calculateCacheHitRate(ResourceStatistics stats) {
    final waveformStats = stats.waveformCacheStats;
    // For now, return a mock hit rate since we don't track hits/requests yet
    return waveformStats.size > 0 ? 0.8 : 0.0; // 80% hit rate if cache has items
  }

  /// Calculate average operation time
  double _calculateAverageOperationTime() {
    final allStats = _profiler.getAllStatistics();
    if (allStats.isEmpty) return 0.0;

    final totalTime = allStats.values.fold<double>(0.0, (sum, stats) => sum + stats.averageDuration);
    return totalTime / allStats.length;
  }

  /// Convert recommendation priority to suggestion priority
  SuggestionPriority _convertRecommendationPriority(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.low:
        return SuggestionPriority.low;
      case RecommendationPriority.medium:
        return SuggestionPriority.medium;
      case RecommendationPriority.high:
        return SuggestionPriority.high;
      case RecommendationPriority.critical:
        return SuggestionPriority.critical;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('PerformanceOptimizer must be initialized before use');
    }
  }

  /// Dispose of the performance optimizer
  Future<void> dispose() async {
    await _resourceManager.dispose();
    _memoryManager.dispose();
    _profiler.clear();
    _isInitialized = false;
  }
}

/// Settings for performance optimization
class OptimizationSettings {
  final int memoryLimit;
  final int maxCacheSize;
  final int? streamingThreshold;
  final int? batchingThreshold;
  final bool enableProfiling;
  final bool enableAutoOptimization;

  const OptimizationSettings({
    this.memoryLimit = 200 * 1024 * 1024, // 200MB default
    this.maxCacheSize = 50,
    this.streamingThreshold,
    this.batchingThreshold,
    this.enableProfiling = false,
    this.enableAutoOptimization = true,
  });

  OptimizationSettings copyWith({
    int? memoryLimit,
    int? maxCacheSize,
    int? streamingThreshold,
    int? batchingThreshold,
    bool? enableProfiling,
    bool? enableAutoOptimization,
  }) {
    return OptimizationSettings(
      memoryLimit: memoryLimit ?? this.memoryLimit,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      streamingThreshold: streamingThreshold ?? this.streamingThreshold,
      batchingThreshold: batchingThreshold ?? this.batchingThreshold,
      enableProfiling: enableProfiling ?? this.enableProfiling,
      enableAutoOptimization: enableAutoOptimization ?? this.enableAutoOptimization,
    );
  }
}

/// Current performance metrics
class PerformanceMetrics {
  final int memoryUsage;
  final int memoryLimit;
  final double memoryUsagePercentage;
  final double cacheHitRate;
  final int activeResourceCount;
  final double averageOperationTime;
  final bool isMemoryPressureHigh;
  final bool isMemoryPressureCritical;

  const PerformanceMetrics({
    required this.memoryUsage,
    required this.memoryLimit,
    required this.memoryUsagePercentage,
    required this.cacheHitRate,
    required this.activeResourceCount,
    required this.averageOperationTime,
    required this.isMemoryPressureHigh,
    required this.isMemoryPressureCritical,
  });

  @override
  String toString() {
    return 'PerformanceMetrics(\n'
        '  memory: ${(memoryUsage / 1024 / 1024).toStringAsFixed(1)}MB / '
        '${(memoryLimit / 1024 / 1024).toStringAsFixed(1)}MB '
        '(${(memoryUsagePercentage * 100).toStringAsFixed(1)}%)\n'
        '  cache hit rate: ${(cacheHitRate * 100).toStringAsFixed(1)}%\n'
        '  active resources: $activeResourceCount\n'
        '  avg operation time: ${averageOperationTime.toStringAsFixed(1)}ms\n'
        '  memory pressure: ${isMemoryPressureCritical
            ? 'CRITICAL'
            : isMemoryPressureHigh
            ? 'HIGH'
            : 'NORMAL'}\n'
        ')';
  }
}

/// Optimization suggestion
class OptimizationSuggestion {
  final OptimizationType type;
  final SuggestionPriority priority;
  final String title;
  final String description;
  final String action;

  const OptimizationSuggestion({required this.type, required this.priority, required this.title, required this.description, required this.action});

  @override
  String toString() {
    return 'OptimizationSuggestion(${priority.name.toUpperCase()}: $title - $description)';
  }
}

/// Types of optimizations
enum OptimizationType { memory, performance, caching, platform }

/// Priority levels for suggestions
enum SuggestionPriority { low, medium, high, critical }

/// Result of optimization operation
class OptimizationResult {
  final PerformanceMetrics startMetrics;
  final PerformanceMetrics endMetrics;
  final Duration duration;
  final int memoryFreed;
  final List<String> optimizationsApplied;

  const OptimizationResult({
    required this.startMetrics,
    required this.endMetrics,
    required this.duration,
    required this.memoryFreed,
    required this.optimizationsApplied,
  });

  @override
  String toString() {
    return 'OptimizationResult(\n'
        '  duration: ${duration.inMilliseconds}ms\n'
        '  memory freed: ${(memoryFreed / 1024 / 1024).toStringAsFixed(1)}MB\n'
        '  optimizations: ${optimizationsApplied.join(', ')}\n'
        '  memory usage: ${(startMetrics.memoryUsagePercentage * 100).toStringAsFixed(1)}% → '
        '${(endMetrics.memoryUsagePercentage * 100).toStringAsFixed(1)}%\n'
        ')';
  }
}

/// Widget rendering optimization recommendation
class RenderingOptimization {
  final RenderingStrategy strategy;
  final int targetAmplitudeCount;
  final String reason;

  const RenderingOptimization({required this.strategy, required this.targetAmplitudeCount, required this.reason});

  @override
  String toString() {
    return 'RenderingOptimization(strategy: ${strategy.name}, target: $targetAmplitudeCount, reason: $reason)';
  }
}

/// Rendering strategies
enum RenderingStrategy { direct, downsample, interpolate }
