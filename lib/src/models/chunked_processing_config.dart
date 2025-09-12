import 'dart:io';

/// Configuration for chunked audio processing with adaptive settings
///
/// This class provides intelligent defaults and automatic optimization
/// based on file size, platform capabilities, and memory constraints.
class ChunkedProcessingConfig {
  /// Size of each file chunk in bytes (default: 10MB)
  final int fileChunkSize;

  /// Maximum memory usage for chunked processing (default: 100MB)
  final int maxMemoryUsage;

  /// Maximum number of concurrent chunks being processed (default: 3)
  final int maxConcurrentChunks;

  /// Whether seeking is enabled (default: true)
  final bool enableSeeking;

  /// Whether progress reporting is enabled (default: true)
  final bool enableProgressReporting;

  /// Interval for progress updates (default: 100ms)
  final Duration progressUpdateInterval;

  /// Whether to enable memory pressure detection (default: true)
  final bool enableMemoryPressureDetection;

  /// Memory pressure threshold as percentage of max memory (default: 0.8)
  final double memoryPressureThreshold;

  /// Whether to enable automatic chunk size adjustment (default: true)
  final bool enableAdaptiveChunkSize;

  /// Minimum allowed chunk size in bytes (default: 1MB)
  final int minChunkSize;

  /// Maximum allowed chunk size in bytes (default: 50MB)
  final int maxChunkSize;

  /// Platform-specific optimizations enabled (default: true)
  final bool enablePlatformOptimizations;

  const ChunkedProcessingConfig({
    this.fileChunkSize = 10 * 1024 * 1024, // 10MB
    this.maxMemoryUsage = 100 * 1024 * 1024, // 100MB
    this.maxConcurrentChunks = 3,
    this.enableSeeking = true,
    this.enableProgressReporting = true,
    this.progressUpdateInterval = const Duration(milliseconds: 100),
    this.enableMemoryPressureDetection = true,
    this.memoryPressureThreshold = 0.8,
    this.enableAdaptiveChunkSize = true,
    this.minChunkSize = 1 * 1024 * 1024, // 1MB
    this.maxChunkSize = 50 * 1024 * 1024, // 50MB
    this.enablePlatformOptimizations = true,
  });

  /// Create optimal configuration for a specific file size
  ///
  /// This factory method analyzes the file size and creates an optimized
  /// configuration with appropriate chunk sizes and memory limits.
  ///
  /// Requirements: 2.1, 2.2, 2.3, 2.4
  factory ChunkedProcessingConfig.forFileSize(int fileSize) {
    // Validate file size
    if (fileSize <= 0) {
      throw ArgumentError('File size must be positive, got: $fileSize');
    }

    // Get platform-specific memory constraints
    final platformInfo = _getPlatformInfo();
    final availableMemory = platformInfo.availableMemory;
    final isLowMemoryDevice = platformInfo.isLowMemoryDevice;

    // Calculate optimal chunk size based on file size and available memory
    int optimalChunkSize;
    int maxMemory;
    int maxConcurrent;

    if (fileSize < 5 * 1024 * 1024) {
      // < 5MB - Small files
      optimalChunkSize = (fileSize / 2).clamp(512 * 1024, 2 * 1024 * 1024).round(); // 512KB - 2MB
      maxMemory = isLowMemoryDevice ? 20 * 1024 * 1024 : 50 * 1024 * 1024; // 20MB or 50MB
      maxConcurrent = isLowMemoryDevice ? 1 : 2;
    } else if (fileSize < 50 * 1024 * 1024) {
      // 5MB - 50MB - Medium files
      optimalChunkSize = (fileSize / 10).clamp(2 * 1024 * 1024, 8 * 1024 * 1024).round(); // 2MB - 8MB
      maxMemory = isLowMemoryDevice ? 50 * 1024 * 1024 : 100 * 1024 * 1024; // 50MB or 100MB
      maxConcurrent = isLowMemoryDevice ? 2 : 3;
    } else if (fileSize < 500 * 1024 * 1024) {
      // 50MB - 500MB - Large files
      optimalChunkSize = (fileSize / 50).clamp(5 * 1024 * 1024, 15 * 1024 * 1024).round(); // 5MB - 15MB
      maxMemory = isLowMemoryDevice ? 75 * 1024 * 1024 : 150 * 1024 * 1024; // 75MB or 150MB
      maxConcurrent = isLowMemoryDevice ? 2 : 4;
    } else {
      // > 500MB - Very large files
      optimalChunkSize = (fileSize / 100).clamp(10 * 1024 * 1024, 25 * 1024 * 1024).round(); // 10MB - 25MB
      maxMemory = isLowMemoryDevice ? 100 * 1024 * 1024 : 200 * 1024 * 1024; // 100MB or 200MB
      maxConcurrent = isLowMemoryDevice ? 2 : 4;
    }

    // Adjust for available memory constraints
    if (availableMemory > 0) {
      final memoryBudget = (availableMemory * 0.3).round(); // Use 30% of available memory
      maxMemory = maxMemory.clamp(20 * 1024 * 1024, memoryBudget);

      // Ensure chunk size doesn't exceed memory budget
      final maxChunkForMemory = (maxMemory / (maxConcurrent + 1)).round();
      optimalChunkSize = optimalChunkSize.clamp(512 * 1024, maxChunkForMemory);
    }

    return ChunkedProcessingConfig(
      fileChunkSize: optimalChunkSize,
      maxMemoryUsage: maxMemory,
      maxConcurrentChunks: maxConcurrent,
      enableSeeking: fileSize > 10 * 1024 * 1024, // Enable seeking for files > 10MB
      enableProgressReporting: fileSize > 5 * 1024 * 1024, // Enable progress for files > 5MB
      progressUpdateInterval: fileSize > 100 * 1024 * 1024
          ? const Duration(milliseconds: 50) // More frequent updates for large files
          : const Duration(milliseconds: 100),
      enableMemoryPressureDetection: isLowMemoryDevice || fileSize > 50 * 1024 * 1024,
      memoryPressureThreshold: isLowMemoryDevice ? 0.7 : 0.8, // Lower threshold for low-memory devices
      enableAdaptiveChunkSize: fileSize > 20 * 1024 * 1024, // Enable adaptation for larger files
      enablePlatformOptimizations: true,
    );
  }

  /// Create configuration optimized for low-memory devices
  factory ChunkedProcessingConfig.forLowMemoryDevice({int? fileSize}) {
    final baseChunkSize = fileSize != null ? (fileSize / 20).clamp(512 * 1024, 2 * 1024 * 1024).round() : 2 * 1024 * 1024; // 2MB default

    return ChunkedProcessingConfig(
      fileChunkSize: baseChunkSize,
      maxMemoryUsage: 30 * 1024 * 1024, // 30MB
      maxConcurrentChunks: 1,
      enableSeeking: true,
      enableProgressReporting: true,
      progressUpdateInterval: const Duration(milliseconds: 200),
      enableMemoryPressureDetection: true,
      memoryPressureThreshold: 0.6, // Very conservative
      enableAdaptiveChunkSize: true,
      minChunkSize: 512 * 1024, // 512KB
      maxChunkSize: 5 * 1024 * 1024, // 5MB
      enablePlatformOptimizations: true,
    );
  }

  /// Create configuration optimized for high-performance devices
  factory ChunkedProcessingConfig.forHighPerformanceDevice({int? fileSize}) {
    final baseChunkSize = fileSize != null ? (fileSize / 20).clamp(5 * 1024 * 1024, 25 * 1024 * 1024).round() : 15 * 1024 * 1024; // 15MB default

    return ChunkedProcessingConfig(
      fileChunkSize: baseChunkSize,
      maxMemoryUsage: 300 * 1024 * 1024, // 300MB
      maxConcurrentChunks: 6,
      enableSeeking: true,
      enableProgressReporting: true,
      progressUpdateInterval: const Duration(milliseconds: 50),
      enableMemoryPressureDetection: true,
      memoryPressureThreshold: 0.9, // More aggressive
      enableAdaptiveChunkSize: true,
      minChunkSize: 2 * 1024 * 1024, // 2MB
      maxChunkSize: 100 * 1024 * 1024, // 100MB
      enablePlatformOptimizations: true,
    );
  }

  /// Validate configuration constraints and return validation result
  ///
  /// Requirements: 2.1, 2.2, 2.3, 2.4
  ChunkedProcessingConfigValidation validate() {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate chunk size constraints
    if (fileChunkSize < 1024) {
      errors.add('File chunk size too small: ${fileChunkSize}B (minimum: 1KB)');
    }
    if (fileChunkSize > 1024 * 1024 * 1024) {
      // 1GB
      errors.add('File chunk size too large: ${fileChunkSize}B (maximum: 1GB)');
    }
    if (fileChunkSize < minChunkSize) {
      errors.add('File chunk size (${fileChunkSize}B) is smaller than minimum (${minChunkSize}B)');
    }
    if (fileChunkSize > maxChunkSize) {
      errors.add('File chunk size (${fileChunkSize}B) is larger than maximum (${maxChunkSize}B)');
    }

    // Validate memory constraints
    if (maxMemoryUsage < fileChunkSize * maxConcurrentChunks) {
      errors.add('Max memory usage (${maxMemoryUsage}B) is insufficient for concurrent chunks');
    }
    if (maxMemoryUsage < 10 * 1024 * 1024) {
      // 10MB minimum
      warnings.add('Max memory usage is very low (${maxMemoryUsage}B), may impact performance');
    }

    // Validate concurrency constraints
    if (maxConcurrentChunks < 1) {
      errors.add('Max concurrent chunks must be at least 1, got: $maxConcurrentChunks');
    }
    if (maxConcurrentChunks > 10) {
      warnings.add('High concurrent chunk count ($maxConcurrentChunks) may cause resource contention');
    }

    // Validate memory pressure threshold
    if (memoryPressureThreshold < 0.1 || memoryPressureThreshold > 1.0) {
      errors.add('Memory pressure threshold must be between 0.1 and 1.0, got: $memoryPressureThreshold');
    }

    // Validate progress update interval
    if (progressUpdateInterval.inMilliseconds < 10) {
      warnings.add('Very frequent progress updates (${progressUpdateInterval.inMilliseconds}ms) may impact performance');
    }

    // Platform-specific validations
    final platformInfo = _getPlatformInfo();
    if (platformInfo.isLowMemoryDevice && maxMemoryUsage > 100 * 1024 * 1024) {
      warnings.add('High memory usage (${maxMemoryUsage}B) detected on low-memory device');
    }

    return ChunkedProcessingConfigValidation(isValid: errors.isEmpty, errors: errors, warnings: warnings);
  }

  /// Create an optimized copy of this configuration
  ///
  /// Requirements: 2.1, 2.2, 8.4
  ChunkedProcessingConfig optimize({int? targetFileSize, int? availableMemory, bool? isLowMemoryDevice}) {
    if (targetFileSize != null) {
      // Create new optimized config for the target file size
      final optimized = ChunkedProcessingConfig.forFileSize(targetFileSize);

      // Merge with current settings where appropriate
      return ChunkedProcessingConfig(
        fileChunkSize: optimized.fileChunkSize,
        maxMemoryUsage: availableMemory != null ? (availableMemory * 0.3).clamp(20 * 1024 * 1024, optimized.maxMemoryUsage).round() : optimized.maxMemoryUsage,
        maxConcurrentChunks: (isLowMemoryDevice == true) ? (optimized.maxConcurrentChunks / 2).ceil() : optimized.maxConcurrentChunks,
        enableSeeking: enableSeeking,
        enableProgressReporting: enableProgressReporting,
        progressUpdateInterval: progressUpdateInterval,
        enableMemoryPressureDetection: enableMemoryPressureDetection || (isLowMemoryDevice == true),
        memoryPressureThreshold: (isLowMemoryDevice == true) ? (memoryPressureThreshold * 0.8).clamp(0.5, 0.8) : memoryPressureThreshold,
        enableAdaptiveChunkSize: enableAdaptiveChunkSize,
        minChunkSize: minChunkSize,
        maxChunkSize: maxChunkSize,
        enablePlatformOptimizations: enablePlatformOptimizations,
      );
    }

    return this; // No optimization needed
  }

  /// Convert configuration to JSON map
  Map<String, dynamic> toJson() {
    return {
      'fileChunkSize': fileChunkSize,
      'maxMemoryUsage': maxMemoryUsage,
      'maxConcurrentChunks': maxConcurrentChunks,
      'enableSeeking': enableSeeking,
      'enableProgressReporting': enableProgressReporting,
      'progressUpdateIntervalMs': progressUpdateInterval.inMilliseconds,
      'enableMemoryPressureDetection': enableMemoryPressureDetection,
      'memoryPressureThreshold': memoryPressureThreshold,
      'enableAdaptiveChunkSize': enableAdaptiveChunkSize,
      'minChunkSize': minChunkSize,
      'maxChunkSize': maxChunkSize,
      'enablePlatformOptimizations': enablePlatformOptimizations,
      'version': 1, // For future migration support
    };
  }

  /// Create configuration from JSON map
  factory ChunkedProcessingConfig.fromJson(Map<String, dynamic> json) {
    return ChunkedProcessingConfig(
      fileChunkSize: json['fileChunkSize'] as int? ?? 10 * 1024 * 1024,
      maxMemoryUsage: json['maxMemoryUsage'] as int? ?? 100 * 1024 * 1024,
      maxConcurrentChunks: json['maxConcurrentChunks'] as int? ?? 3,
      enableSeeking: json['enableSeeking'] as bool? ?? true,
      enableProgressReporting: json['enableProgressReporting'] as bool? ?? true,
      progressUpdateInterval: Duration(milliseconds: json['progressUpdateIntervalMs'] as int? ?? 100),
      enableMemoryPressureDetection: json['enableMemoryPressureDetection'] as bool? ?? true,
      memoryPressureThreshold: (json['memoryPressureThreshold'] as num?)?.toDouble() ?? 0.8,
      enableAdaptiveChunkSize: json['enableAdaptiveChunkSize'] as bool? ?? true,
      minChunkSize: json['minChunkSize'] as int? ?? 1 * 1024 * 1024,
      maxChunkSize: json['maxChunkSize'] as int? ?? 50 * 1024 * 1024,
      enablePlatformOptimizations: json['enablePlatformOptimizations'] as bool? ?? true,
    );
  }

  /// Create a copy with modified parameters
  ChunkedProcessingConfig copyWith({
    int? fileChunkSize,
    int? maxMemoryUsage,
    int? maxConcurrentChunks,
    bool? enableSeeking,
    bool? enableProgressReporting,
    Duration? progressUpdateInterval,
    bool? enableMemoryPressureDetection,
    double? memoryPressureThreshold,
    bool? enableAdaptiveChunkSize,
    int? minChunkSize,
    int? maxChunkSize,
    bool? enablePlatformOptimizations,
  }) {
    return ChunkedProcessingConfig(
      fileChunkSize: fileChunkSize ?? this.fileChunkSize,
      maxMemoryUsage: maxMemoryUsage ?? this.maxMemoryUsage,
      maxConcurrentChunks: maxConcurrentChunks ?? this.maxConcurrentChunks,
      enableSeeking: enableSeeking ?? this.enableSeeking,
      enableProgressReporting: enableProgressReporting ?? this.enableProgressReporting,
      progressUpdateInterval: progressUpdateInterval ?? this.progressUpdateInterval,
      enableMemoryPressureDetection: enableMemoryPressureDetection ?? this.enableMemoryPressureDetection,
      memoryPressureThreshold: memoryPressureThreshold ?? this.memoryPressureThreshold,
      enableAdaptiveChunkSize: enableAdaptiveChunkSize ?? this.enableAdaptiveChunkSize,
      minChunkSize: minChunkSize ?? this.minChunkSize,
      maxChunkSize: maxChunkSize ?? this.maxChunkSize,
      enablePlatformOptimizations: enablePlatformOptimizations ?? this.enablePlatformOptimizations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChunkedProcessingConfig &&
        other.fileChunkSize == fileChunkSize &&
        other.maxMemoryUsage == maxMemoryUsage &&
        other.maxConcurrentChunks == maxConcurrentChunks &&
        other.enableSeeking == enableSeeking &&
        other.enableProgressReporting == enableProgressReporting &&
        other.progressUpdateInterval == progressUpdateInterval &&
        other.enableMemoryPressureDetection == enableMemoryPressureDetection &&
        other.memoryPressureThreshold == memoryPressureThreshold &&
        other.enableAdaptiveChunkSize == enableAdaptiveChunkSize &&
        other.minChunkSize == minChunkSize &&
        other.maxChunkSize == maxChunkSize &&
        other.enablePlatformOptimizations == enablePlatformOptimizations;
  }

  @override
  int get hashCode {
    return Object.hash(
      fileChunkSize,
      maxMemoryUsage,
      maxConcurrentChunks,
      enableSeeking,
      enableProgressReporting,
      progressUpdateInterval,
      enableMemoryPressureDetection,
      memoryPressureThreshold,
      enableAdaptiveChunkSize,
      minChunkSize,
      maxChunkSize,
      enablePlatformOptimizations,
    );
  }

  @override
  String toString() {
    return 'ChunkedProcessingConfig('
        'fileChunkSize: ${fileChunkSize}B, '
        'maxMemoryUsage: ${maxMemoryUsage}B, '
        'maxConcurrentChunks: $maxConcurrentChunks, '
        'enableSeeking: $enableSeeking, '
        'enableProgressReporting: $enableProgressReporting, '
        'progressUpdateInterval: ${progressUpdateInterval.inMilliseconds}ms, '
        'enableMemoryPressureDetection: $enableMemoryPressureDetection, '
        'memoryPressureThreshold: $memoryPressureThreshold, '
        'enableAdaptiveChunkSize: $enableAdaptiveChunkSize, '
        'minChunkSize: ${minChunkSize}B, '
        'maxChunkSize: ${maxChunkSize}B, '
        'enablePlatformOptimizations: $enablePlatformOptimizations'
        ')';
  }
}

/// Result of configuration validation
class ChunkedProcessingConfigValidation {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ChunkedProcessingConfigValidation({required this.isValid, required this.errors, required this.warnings});

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Configuration Validation: ${isValid ? 'VALID' : 'INVALID'}');

    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }

    return buffer.toString();
  }
}

/// Platform information for configuration optimization
class _PlatformInfo {
  final bool isLowMemoryDevice;
  final int availableMemory; // in bytes, 0 if unknown
  final String platform;

  const _PlatformInfo({required this.isLowMemoryDevice, required this.availableMemory, required this.platform});
}

/// Get platform-specific information for configuration optimization
_PlatformInfo _getPlatformInfo() {
  try {
    final platform = Platform.operatingSystem;

    // Simple heuristics for platform detection
    // In a real implementation, this would use platform-specific APIs
    // to get actual memory information

    bool isLowMemory = false;
    int availableMemory = 0;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms - assume more memory constraints
      isLowMemory = true; // Conservative assumption
      availableMemory = 2 * 1024 * 1024 * 1024; // Assume 2GB available
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop platforms - assume more memory available
      isLowMemory = false;
      availableMemory = 8 * 1024 * 1024 * 1024; // Assume 8GB available
    }

    return _PlatformInfo(isLowMemoryDevice: isLowMemory, availableMemory: availableMemory, platform: platform);
  } catch (e) {
    // Fallback to conservative defaults
    return const _PlatformInfo(isLowMemoryDevice: true, availableMemory: 0, platform: 'unknown');
  }
}
