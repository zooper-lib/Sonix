import 'dart:async';
import 'dart:math' as math;

import 'sonix_logger.dart';

/// Callback function type for memory pressure events
typedef MemoryPressureCallback = void Function();

/// Comprehensive memory management system for Sonix
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  // Memory thresholds and limits
  // Default memory limit - set very high to not artificially restrict large audio files
  // Most systems can handle multi-GB audio files; let OS memory management handle limits
  static const int _defaultMemoryLimit = 16 * 1024 * 1024 * 1024; // 16GB - practically unlimited
  static const double _warningThresholdRatio = 0.8; // 80% of memory limit
  static const double _criticalThresholdRatio = 0.9; // 90% of memory limit

  // Current memory usage tracking
  int _currentMemoryUsage = 0;
  int _memoryLimit = _defaultMemoryLimit;

  // Memory pressure callbacks
  final List<MemoryPressureCallback> _memoryPressureCallbacks = [];
  final List<MemoryPressureCallback> _criticalMemoryCallbacks = [];

  // Timer for periodic memory monitoring
  Timer? _memoryMonitorTimer;

  /// Initialize memory manager with optional custom limit
  void initialize({int? memoryLimit}) {
    _memoryLimit = memoryLimit ?? _defaultMemoryLimit;
    _startMemoryMonitoring();
  }

  /// Get current memory usage in bytes
  int get currentMemoryUsage => _currentMemoryUsage;

  /// Get memory limit in bytes
  int get memoryLimit => _memoryLimit;

  /// Get memory usage as percentage (0.0 to 1.0)
  double get memoryUsagePercentage => _currentMemoryUsage / _memoryLimit;

  /// Check if memory usage is above warning threshold
  bool get isMemoryPressureHigh => _currentMemoryUsage > (_memoryLimit * _warningThresholdRatio);

  /// Check if memory usage is above critical threshold
  bool get isMemoryPressureCritical => _currentMemoryUsage > (_memoryLimit * _criticalThresholdRatio);

  /// Register callback for memory pressure events
  void registerMemoryPressureCallback(MemoryPressureCallback callback) {
    _memoryPressureCallbacks.add(callback);
  }

  /// Register callback for critical memory events
  void registerCriticalMemoryCallback(MemoryPressureCallback callback) {
    _criticalMemoryCallbacks.add(callback);
  }

  /// Remove memory pressure callback
  void removeMemoryPressureCallback(MemoryPressureCallback callback) {
    _memoryPressureCallbacks.remove(callback);
  }

  /// Remove critical memory callback
  void removeCriticalMemoryCallback(MemoryPressureCallback callback) {
    _criticalMemoryCallbacks.remove(callback);
  }

  /// Allocate memory and track usage
  void allocateMemory(int bytes) {
    _currentMemoryUsage += bytes;
    _checkMemoryPressure();
  }

  /// Deallocate memory and update tracking
  void deallocateMemory(int bytes) {
    _currentMemoryUsage = math.max(0, _currentMemoryUsage - bytes);
  }

  /// Estimate memory usage for waveform data
  static int estimateWaveformMemoryUsage(int amplitudeCount) {
    // Each amplitude is a double (8 bytes) plus object overhead
    return (amplitudeCount * 8) + 1024; // 1KB overhead estimate
  }

  /// Estimate memory usage for audio data
  static int estimateAudioMemoryUsage(int sampleCount) {
    // Each sample is a double (8 bytes) plus object overhead
    return (sampleCount * 8) + 2048; // 2KB overhead estimate
  }

  /// Check if allocation would exceed memory limits
  bool wouldExceedMemoryLimit(int additionalBytes) {
    return (_currentMemoryUsage + additionalBytes) > _memoryLimit;
  }

  /// Get suggested quality reduction based on memory pressure
  QualityReductionSuggestion getSuggestedQualityReduction() {
    final usagePercentage = memoryUsagePercentage;

    if (usagePercentage > 0.9) {
      return QualityReductionSuggestion(
        shouldReduce: true,
        resolutionReduction: 0.25, // Reduce to 25% of original
        enableStreaming: true,
        reason: 'Critical memory pressure (${(usagePercentage * 100).toStringAsFixed(1)}%)',
      );
    } else if (usagePercentage > 0.8) {
      return QualityReductionSuggestion(
        shouldReduce: true,
        resolutionReduction: 0.5, // Reduce to 50% of original
        enableStreaming: true,
        reason: 'High memory pressure (${(usagePercentage * 100).toStringAsFixed(1)}%)',
      );
    } else if (usagePercentage > 0.7) {
      return QualityReductionSuggestion(
        shouldReduce: true,
        resolutionReduction: 0.75, // Reduce to 75% of original
        enableStreaming: false,
        reason: 'Moderate memory pressure (${(usagePercentage * 100).toStringAsFixed(1)}%)',
      );
    }

    return QualityReductionSuggestion(shouldReduce: false);
  }

  /// Force garbage collection and memory cleanup
  Future<void> forceMemoryCleanup() async {
    // Trigger garbage collection
    // Note: Dart doesn't provide direct GC control, but we can help

    // Clear any temporary data structures
    _triggerMemoryPressureCallbacks();

    // Wait a bit for cleanup to occur
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Start periodic memory monitoring
  void _startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkMemoryPressure());
  }

  /// Check memory pressure and trigger callbacks if needed
  void _checkMemoryPressure() {
    if (isMemoryPressureCritical) {
      _triggerCriticalMemoryCallbacks();
    } else if (isMemoryPressureHigh) {
      _triggerMemoryPressureCallbacks();
    }
  }

  /// Trigger memory pressure callbacks
  void _triggerMemoryPressureCallbacks() {
    for (final callback in _memoryPressureCallbacks) {
      try {
        callback();
      } catch (e) {
        SonixLogger.debug('Memory pressure callback failed: ${e.toString()}');
      }
    }
  }

  /// Trigger critical memory callbacks
  void _triggerCriticalMemoryCallbacks() {
    for (final callback in _criticalMemoryCallbacks) {
      try {
        callback();
      } catch (e) {
        SonixLogger.debug('Critical memory callback failed: ${e.toString()}');
      }
    }
  }

  /// Dispose of memory manager resources
  void dispose() {
    _memoryMonitorTimer?.cancel();
    _memoryPressureCallbacks.clear();
    _criticalMemoryCallbacks.clear();
    _currentMemoryUsage = 0;
  }
}

/// Suggestion for quality reduction based on memory pressure
class QualityReductionSuggestion {
  /// Whether quality should be reduced
  final bool shouldReduce;

  /// Factor to reduce resolution by (0.0 to 1.0)
  final double resolutionReduction;

  /// Whether to enable streaming processing
  final bool enableStreaming;

  /// Reason for the suggestion
  final String reason;

  const QualityReductionSuggestion({required this.shouldReduce, this.resolutionReduction = 1.0, this.enableStreaming = false, this.reason = ''});

  @override
  String toString() {
    return 'QualityReductionSuggestion(shouldReduce: $shouldReduce, '
        'resolutionReduction: $resolutionReduction, '
        'enableStreaming: $enableStreaming, reason: $reason)';
  }
}
