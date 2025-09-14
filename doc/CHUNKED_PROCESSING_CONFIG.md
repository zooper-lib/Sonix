# Chunked Processing Configuration Guide

Comprehensive configuration guide for optimizing Sonix chunked processing across different use cases, platforms, and scenarios.

## Table of Contents

1. [Configuration Overview](#configuration-overview)
2. [Use Case Configurations](#use-case-configurations)
3. [Platform-Specific Configurations](#platform-specific-configurations)
4. [Performance Tuning](#performance-tuning)
5. [Memory Optimization](#memory-optimization)
6. [Error Handling Configuration](#error-handling-configuration)
7. [Advanced Configurations](#advanced-configurations)

## Configuration Overview

The `ChunkedProcessingConfig` class provides comprehensive control over how Sonix processes audio files in chunks. Understanding each parameter helps you optimize for your specific needs.

### Core Parameters

```dart
ChunkedProcessingConfig({
  int fileChunkSize = 10 * 1024 * 1024,        // 10MB default
  int maxMemoryUsage = 100 * 1024 * 1024,      // 100MB default
  int maxConcurrentChunks = 3,                  // 3 concurrent chunks
  bool enableSeeking = true,                    // Enable seeking
  bool enableProgressReporting = true,          // Enable progress callbacks
  Duration progressUpdateInterval = const Duration(milliseconds: 100),
  ErrorRecoveryStrategy errorRecoveryStrategy = ErrorRecoveryStrategy.skipAndContinue,
  int maxRetries = 3,
  Duration retryDelay = const Duration(milliseconds: 100),
})
```

### Parameter Guidelines

| Parameter | Small Files (<10MB) | Medium Files (10-100MB) | Large Files (>100MB) |
|-----------|-------------------|------------------------|---------------------|
| `fileChunkSize` | 1-2MB | 5-10MB | 10-20MB |
| `maxMemoryUsage` | 25-50MB | 50-100MB | 100-200MB |
| `maxConcurrentChunks` | 1-2 | 2-3 | 3-4 |

## Use Case Configurations

### 1. Real-Time Audio Processing

For applications requiring low latency and real-time feedback:

```dart
final realtimeConfig = ChunkedProcessingConfig(
  fileChunkSize: 1 * 1024 * 1024,              // 1MB chunks for low latency
  maxMemoryUsage: 50 * 1024 * 1024,            // 50MB memory limit
  maxConcurrentChunks: 2,                       // Lower concurrency for predictability
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 50), // Frequent updates
  errorRecoveryStrategy: ErrorRecoveryStrategy.skipAndContinue,
);

// Usage example
final waveform = await Sonix.generateWaveformChunked(
  'live_audio.mp3',
  config: realtimeConfig,
  onProgress: (progress) {
    // Update real-time UI
    updateRealtimeDisplay(progress.progressPercentage);
  },
);
```

### 2. Batch Processing

For processing multiple large files efficiently:

```dart
final batchConfig = ChunkedProcessingConfig(
  fileChunkSize: 20 * 1024 * 1024,             // 20MB chunks for throughput
  maxMemoryUsage: 200 * 1024 * 1024,           // 200MB memory limit
  maxConcurrentChunks: 4,                       // High concurrency
  enableProgressReporting: false,               // Disable for performance
  errorRecoveryStrategy: ErrorRecoveryStrategy.retryWithSmallerChunk,
  maxRetries: 5,                                // More retries for reliability
);

// Batch processing example
final files = ['file1.mp3', 'file2.mp3', 'file3.mp3'];
final results = <WaveformData>[];

for (final file in files) {
  try {
    final waveform = await Sonix.generateWaveformChunked(file, config: batchConfig);
    results.add(waveform);
  } catch (e) {
    print('Failed to process $file: $e');
  }
}
```

### 3. Memory-Constrained Devices

For devices with limited RAM (e.g., older mobile devices):

```dart
final constrainedConfig = ChunkedProcessingConfig(
  fileChunkSize: 512 * 1024,                   // 512KB chunks
  maxMemoryUsage: 25 * 1024 * 1024,            // 25MB memory limit
  maxConcurrentChunks: 1,                       // Sequential processing only
  enableSeeking: false,                         // Disable seeking to save memory
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 200), // Less frequent updates
  errorRecoveryStrategy: ErrorRecoveryStrategy.skipAndContinue,
);

// Check available memory before processing
final availableMemory = await Sonix.getAvailableMemory();
if (availableMemory < 50 * 1024 * 1024) { // Less than 50MB available
  // Use even more constrained settings
  final ultraConstrainedConfig = ChunkedProcessingConfig(
    fileChunkSize: 256 * 1024,                 // 256KB chunks
    maxMemoryUsage: 15 * 1024 * 1024,          // 15MB memory limit
    maxConcurrentChunks: 1,
    enableProgressReporting: false,             // Disable to save memory
  );
}
```

### 4. Background Processing

For processing files in the background without affecting UI:

```dart
final backgroundConfig = ChunkedProcessingConfig(
  fileChunkSize: 15 * 1024 * 1024,             // 15MB chunks
  maxMemoryUsage: 100 * 1024 * 1024,           // 100MB memory limit
  maxConcurrentChunks: 2,                       // Moderate concurrency
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 500), // Less frequent updates
  yieldToUI: true,                              // Yield to UI thread regularly
  uiYieldInterval: Duration(milliseconds: 16),  // 60 FPS yield rate
);

// Background processing with UI updates
void processInBackground(String filePath) async {
  final waveform = await Sonix.generateWaveformChunked(
    filePath,
    config: backgroundConfig,
    onProgress: (progress) {
      // Update background task progress
      BackgroundTaskManager.updateProgress(progress.progressPercentage);
    },
  );
  
  // Notify completion
  BackgroundTaskManager.notifyCompletion(waveform);
}
```

### 5. Streaming Applications

For applications that process audio as it streams:

```dart
final streamingConfig = ChunkedProcessingConfig(
  fileChunkSize: 2 * 1024 * 1024,              // 2MB chunks for streaming
  maxMemoryUsage: 75 * 1024 * 1024,            // 75MB memory limit
  maxConcurrentChunks: 3,
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 100),
  enableStreamingMode: true,                    // Enable streaming optimizations
  bufferAheadChunks: 2,                         // Buffer 2 chunks ahead
);

// Streaming waveform generation
await for (final waveformChunk in Sonix.generateWaveformStream(
  'streaming_audio.mp3',
  config: streamingConfig,
)) {
  // Update UI with streaming waveform data
  appendWaveformChunk(waveformChunk);
}
```

## Platform-Specific Configurations

### Android Configuration

```dart
class AndroidChunkedConfig {
  static ChunkedProcessingConfig forDevice(AndroidDeviceInfo deviceInfo) {
    final totalMemory = deviceInfo.totalMemory;
    final apiLevel = deviceInfo.version.sdkInt;
    
    if (totalMemory < 2 * 1024 * 1024 * 1024) { // < 2GB RAM
      return ChunkedProcessingConfig(
        fileChunkSize: 2 * 1024 * 1024,          // 2MB chunks
        maxMemoryUsage: 30 * 1024 * 1024,        // 30MB limit
        maxConcurrentChunks: 1,
        enableSeeking: false,
      );
    } else if (totalMemory < 4 * 1024 * 1024 * 1024) { // < 4GB RAM
      return ChunkedProcessingConfig(
        fileChunkSize: 8 * 1024 * 1024,          // 8MB chunks
        maxMemoryUsage: 64 * 1024 * 1024,        // 64MB limit
        maxConcurrentChunks: 2,
      );
    } else { // >= 4GB RAM
      return ChunkedProcessingConfig(
        fileChunkSize: 12 * 1024 * 1024,         // 12MB chunks
        maxMemoryUsage: 128 * 1024 * 1024,       // 128MB limit
        maxConcurrentChunks: 3,
      );
    }
  }
  
  // Configuration for Android background processing
  static final background = ChunkedProcessingConfig(
    fileChunkSize: 5 * 1024 * 1024,
    maxMemoryUsage: 50 * 1024 * 1024,
    maxConcurrentChunks: 1,                       // Conservative for background
    respectAndroidMemoryLimits: true,             // Respect Android memory management
    pauseOnLowMemory: true,                       // Pause when system memory is low
  );
}

// Usage
final deviceInfo = await DeviceInfoPlugin().androidInfo;
final config = AndroidChunkedConfig.forDevice(deviceInfo);
```

### iOS Configuration

```dart
class IOSChunkedConfig {
  static ChunkedProcessingConfig forDevice(IosDeviceInfo deviceInfo) {
    final model = deviceInfo.model;
    
    if (model.contains('iPhone') && 
        (model.contains('6') || model.contains('7') || model.contains('8'))) {
      // Older iPhones
      return ChunkedProcessingConfig(
        fileChunkSize: 5 * 1024 * 1024,          // 5MB chunks
        maxMemoryUsage: 50 * 1024 * 1024,        // 50MB limit
        maxConcurrentChunks: 2,
      );
    } else if (model.contains('iPad')) {
      // iPads generally have more memory
      return ChunkedProcessingConfig(
        fileChunkSize: 15 * 1024 * 1024,         // 15MB chunks
        maxMemoryUsage: 150 * 1024 * 1024,       // 150MB limit
        maxConcurrentChunks: 4,
      );
    } else {
      // Modern iPhones
      return ChunkedProcessingConfig(
        fileChunkSize: 10 * 1024 * 1024,         // 10MB chunks
        maxMemoryUsage: 100 * 1024 * 1024,       // 100MB limit
        maxConcurrentChunks: 3,
      );
    }
  }
  
  // Configuration for iOS background app refresh
  static final backgroundAppRefresh = ChunkedProcessingConfig(
    fileChunkSize: 3 * 1024 * 1024,
    maxMemoryUsage: 30 * 1024 * 1024,
    maxConcurrentChunks: 1,
    respectIOSMemoryWarnings: true,               // Respond to iOS memory warnings
    pauseOnMemoryWarning: true,
  );
}
```

### Desktop Configuration

```dart
class DesktopChunkedConfig {
  // High-performance desktop configuration
  static final highPerformance = ChunkedProcessingConfig(
    fileChunkSize: 50 * 1024 * 1024,             // 50MB chunks
    maxMemoryUsage: 500 * 1024 * 1024,           // 500MB limit
    maxConcurrentChunks: 8,                       // High concurrency
    enableSeeking: true,
    enableProgressReporting: true,
    progressUpdateInterval: Duration(milliseconds: 50),
  );
  
  // Balanced desktop configuration
  static final balanced = ChunkedProcessingConfig(
    fileChunkSize: 20 * 1024 * 1024,             // 20MB chunks
    maxMemoryUsage: 200 * 1024 * 1024,           // 200MB limit
    maxConcurrentChunks: 4,
  );
  
  // Memory-efficient desktop configuration
  static final memoryEfficient = ChunkedProcessingConfig(
    fileChunkSize: 10 * 1024 * 1024,             // 10MB chunks
    maxMemoryUsage: 100 * 1024 * 1024,           // 100MB limit
    maxConcurrentChunks: 2,
  );
}
```

### Web Configuration

```dart
class WebChunkedConfig {
  // Configuration for web browsers
  static final webOptimized = ChunkedProcessingConfig(
    fileChunkSize: 5 * 1024 * 1024,              // 5MB chunks (network considerations)
    maxMemoryUsage: 50 * 1024 * 1024,            // 50MB limit (browser memory)
    maxConcurrentChunks: 2,                       // Conservative for web
    enableProgressReporting: true,
    respectBrowserMemoryLimits: true,             // Respect browser memory limits
    useWebWorkers: true,                          // Use web workers for processing
  );
  
  // Configuration for Progressive Web Apps
  static final pwaOptimized = ChunkedProcessingConfig(
    fileChunkSize: 3 * 1024 * 1024,              // 3MB chunks
    maxMemoryUsage: 40 * 1024 * 1024,            // 40MB limit
    maxConcurrentChunks: 1,                       // Sequential for PWAs
    enableServiceWorkerCaching: true,             // Cache chunks in service worker
  );
}
```

## Performance Tuning

### CPU-Bound vs I/O-Bound Optimization

```dart
// For CPU-intensive processing (complex waveform algorithms)
final cpuOptimized = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,              // Smaller chunks
  maxConcurrentChunks: Platform.numberOfProcessors, // Match CPU cores
  enableCPUAffinity: true,                      // Pin threads to cores
  cpuIntensiveMode: true,
);

// For I/O-intensive processing (large files from slow storage)
final ioOptimized = ChunkedProcessingConfig(
  fileChunkSize: 20 * 1024 * 1024,             // Larger chunks
  maxConcurrentChunks: 2,                       // Lower concurrency
  enableReadAhead: true,                        // Read ahead optimization
  ioBufferSize: 64 * 1024,                      // 64KB I/O buffer
);
```

### Format-Specific Optimization

```dart
class FormatOptimizedConfigs {
  // MP3 files - respect frame boundaries
  static final mp3Optimized = ChunkedProcessingConfig(
    fileChunkSize: 8 * 1024 * 1024,              // 8MB chunks
    respectFormatBoundaries: true,                // Align with MP3 frames
    enableFrameBoundaryDetection: true,
    seekingStrategy: SeekingStrategy.frameBoundary,
  );
  
  // FLAC files - use seek tables
  static final flacOptimized = ChunkedProcessingConfig(
    fileChunkSize: 12 * 1024 * 1024,             // 12MB chunks
    enableSeekTableUsage: true,                   // Use FLAC seek tables
    respectBlockBoundaries: true,                 // Align with FLAC blocks
    seekingStrategy: SeekingStrategy.seekTable,
  );
  
  // WAV files - sample-accurate seeking
  static final wavOptimized = ChunkedProcessingConfig(
    fileChunkSize: 15 * 1024 * 1024,             // 15MB chunks
    enableSampleAccurateSeeking: true,            // Sample-accurate positioning
    respectSampleAlignment: true,                 // Align with sample boundaries
  );
  
  // OGG files - page boundary optimization
  static final oggOptimized = ChunkedProcessingConfig(
    fileChunkSize: 10 * 1024 * 1024,             // 10MB chunks
    respectPageBoundaries: true,                  // Align with OGG pages
    enablePageGranuleUsage: true,                 // Use granule positions
    seekingStrategy: SeekingStrategy.pageBoundary,
  );
}
```

## Memory Optimization

### Dynamic Memory Management

```dart
class DynamicMemoryConfig {
  static ChunkedProcessingConfig createAdaptive() {
    return ChunkedProcessingConfig(
      // Start with conservative settings
      fileChunkSize: 5 * 1024 * 1024,
      maxMemoryUsage: 50 * 1024 * 1024,
      maxConcurrentChunks: 2,
      
      // Enable dynamic adjustment
      enableDynamicAdjustment: true,
      memoryPressureThreshold: 0.8,                // Adjust at 80% memory usage
      
      onMemoryPressure: (currentUsage, maxUsage) {
        final pressureLevel = currentUsage / maxUsage;
        
        if (pressureLevel > 0.9) {
          // Critical pressure - reduce to minimum
          return ChunkedProcessingConfig(
            fileChunkSize: 1 * 1024 * 1024,
            maxMemoryUsage: 25 * 1024 * 1024,
            maxConcurrentChunks: 1,
          );
        } else if (pressureLevel > 0.7) {
          // High pressure - reduce moderately
          return ChunkedProcessingConfig(
            fileChunkSize: 3 * 1024 * 1024,
            maxMemoryUsage: 40 * 1024 * 1024,
            maxConcurrentChunks: 1,
          );
        }
        
        return null; // No adjustment needed
      },
    );
  }
}
```

### Memory Pool Configuration

```dart
final memoryPoolConfig = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,
  maxMemoryUsage: 100 * 1024 * 1024,
  
  // Memory pool settings
  enableMemoryPool: true,
  memoryPoolSize: 5,                              // Pool 5 chunks
  memoryPoolPreallocation: true,                  // Pre-allocate pool memory
  memoryPoolGrowthStrategy: PoolGrowthStrategy.conservative,
  
  // Garbage collection optimization
  enableGCOptimization: true,
  gcTriggerThreshold: 0.8,                        // Trigger GC at 80% usage
  forceGCAfterChunks: 10,                         // Force GC every 10 chunks
);
```

## Error Handling Configuration

### Comprehensive Error Recovery

```dart
final robustErrorConfig = ChunkedProcessingConfig(
  // Error recovery settings
  errorRecoveryStrategy: ErrorRecoveryStrategy.retryWithSmallerChunk,
  maxRetries: 5,
  retryDelay: Duration(milliseconds: 200),
  
  // Fallback strategies
  fallbackStrategies: [
    ErrorRecoveryStrategy.retryWithSmallerChunk,
    ErrorRecoveryStrategy.seekToNextBoundary,
    ErrorRecoveryStrategy.skipAndContinue,
  ],
  
  // Error tolerance
  maxConsecutiveErrors: 3,                        // Fail after 3 consecutive errors
  maxTotalErrors: 10,                             // Fail after 10 total errors
  errorTolerancePercentage: 0.1,                  // Allow 10% error rate
  
  // Error callbacks
  onChunkError: (chunkIndex, error, retryCount) {
    print('Chunk $chunkIndex failed (retry $retryCount): $error');
  },
  
  onRecoveryAttempt: (strategy, chunkIndex) {
    print('Attempting recovery with $strategy for chunk $chunkIndex');
  },
  
  onErrorThresholdReached: (errorCount, totalChunks) {
    print('Error threshold reached: $errorCount errors in $totalChunks chunks');
  },
);
```

### Format-Specific Error Handling

```dart
class FormatErrorConfigs {
  // MP3 error handling - common sync issues
  static final mp3ErrorHandling = ChunkedProcessingConfig(
    errorRecoveryStrategy: ErrorRecoveryStrategy.seekToNextBoundary,
    enableSyncWordRecovery: true,                 // Recover from sync word loss
    maxSyncSearchDistance: 8192,                  // Search 8KB for sync
    
    onSyncLoss: (position) {
      print('MP3 sync lost at position $position, searching for recovery');
    },
  );
  
  // FLAC error handling - block corruption
  static final flacErrorHandling = ChunkedProcessingConfig(
    errorRecoveryStrategy: ErrorRecoveryStrategy.skipAndContinue,
    enableBlockValidation: true,                  // Validate FLAC blocks
    skipCorruptedBlocks: true,                    // Skip corrupted blocks
    
    onBlockCorruption: (blockIndex, position) {
      print('FLAC block $blockIndex corrupted at $position, skipping');
    },
  );
}
```

## Advanced Configurations

### Multi-File Processing

```dart
class MultiFileConfig {
  static ChunkedProcessingConfig forBatchProcessing(List<String> filePaths) {
    final totalSize = filePaths.fold<int>(0, (sum, path) {
      return sum + File(path).lengthSync();
    });
    
    // Adjust configuration based on total workload
    if (totalSize > 10 * 1024 * 1024 * 1024) { // > 10GB total
      return ChunkedProcessingConfig(
        fileChunkSize: 25 * 1024 * 1024,         // 25MB chunks
        maxMemoryUsage: 200 * 1024 * 1024,       // 200MB limit
        maxConcurrentChunks: 2,                   // Conservative for large batch
        enableBatchOptimization: true,
        batchProcessingMode: BatchMode.sequential,
      );
    } else {
      return ChunkedProcessingConfig(
        fileChunkSize: 15 * 1024 * 1024,         // 15MB chunks
        maxMemoryUsage: 150 * 1024 * 1024,       // 150MB limit
        maxConcurrentChunks: 3,
        enableBatchOptimization: true,
        batchProcessingMode: BatchMode.parallel,
      );
    }
  }
}
```

### Network-Aware Configuration

```dart
final networkAwareConfig = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,                // 5MB chunks for network
  maxMemoryUsage: 75 * 1024 * 1024,              // 75MB limit
  
  // Network optimization
  enableNetworkOptimization: true,
  networkBufferSize: 1 * 1024 * 1024,            // 1MB network buffer
  enableProgressiveDownload: true,                // Download while processing
  
  // Adaptive chunk sizing based on network speed
  enableAdaptiveChunkSizing: true,
  minChunkSize: 1 * 1024 * 1024,                  // 1MB minimum
  maxChunkSize: 20 * 1024 * 1024,                 // 20MB maximum
  
  onNetworkSpeedChange: (bytesPerSecond) {
    // Adjust chunk size based on network speed
    final optimalChunkSize = (bytesPerSecond * 2).clamp(
      1 * 1024 * 1024,   // 1MB min
      20 * 1024 * 1024,  // 20MB max
    );
    
    return ChunkedProcessingConfig(
      fileChunkSize: optimalChunkSize,
      // ... other settings
    );
  },
);
```

### Debug and Profiling Configuration

```dart
final debugConfig = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,
  maxMemoryUsage: 100 * 1024 * 1024,
  
  // Debug settings
  enableDebugLogging: true,
  debugLogLevel: LogLevel.verbose,
  enableProfiling: true,
  enableMemoryTracking: true,
  
  // Performance monitoring
  onChunkProcessed: (chunkIndex, processingTime, memoryUsed) {
    print('Chunk $chunkIndex: ${processingTime}ms, ${memoryUsed} bytes');
  },
  
  onPerformanceMetrics: (metrics) {
    print('Avg chunk time: ${metrics.averageChunkTime}ms');
    print('Peak memory: ${metrics.peakMemoryUsage} bytes');
    print('Throughput: ${metrics.throughputMBps} MB/s');
  },
  
  // Memory leak detection
  enableMemoryLeakDetection: true,
  memoryLeakThreshold: 10 * 1024 * 1024,          // 10MB threshold
  
  onMemoryLeak: (leakSize, chunkIndex) {
    print('Memory leak detected: ${leakSize} bytes after chunk $chunkIndex');
  },
);
```

## Configuration Best Practices

### 1. Start Conservative

```dart
// Begin with conservative settings and adjust based on performance
final conservativeConfig = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,                // 5MB chunks
  maxMemoryUsage: 50 * 1024 * 1024,              // 50MB limit
  maxConcurrentChunks: 2,                         // Low concurrency
);

// Monitor performance and gradually increase
final optimizedConfig = await optimizeConfiguration(
  conservativeConfig,
  testFiles: ['test1.mp3', 'test2.mp3'],
  targetMetrics: PerformanceTargets(
    maxProcessingTime: Duration(seconds: 30),
    maxMemoryUsage: 100 * 1024 * 1024,
  ),
);
```

### 2. Test with Real Data

```dart
// Test configuration with actual files from your application
Future<ChunkedProcessingConfig> testConfiguration(
  ChunkedProcessingConfig config,
  List<String> testFiles,
) async {
  final results = <PerformanceResult>[];
  
  for (final file in testFiles) {
    final stopwatch = Stopwatch()..start();
    
    try {
      await Sonix.generateWaveformChunked(file, config: config);
      results.add(PerformanceResult(
        file: file,
        processingTime: stopwatch.elapsed,
        success: true,
      ));
    } catch (e) {
      results.add(PerformanceResult(
        file: file,
        processingTime: stopwatch.elapsed,
        success: false,
        error: e,
      ));
    }
  }
  
  // Analyze results and suggest optimizations
  return analyzeAndOptimize(config, results);
}
```

### 3. Monitor in Production

```dart
// Production monitoring configuration
final productionConfig = ChunkedProcessingConfig(
  // ... your optimized settings ...
  
  enableProductionMonitoring: true,
  
  onProductionMetrics: (metrics) {
    // Send metrics to your analytics service
    Analytics.track('chunked_processing_metrics', {
      'avg_processing_time': metrics.averageProcessingTime.inMilliseconds,
      'peak_memory_usage': metrics.peakMemoryUsage,
      'error_rate': metrics.errorRate,
      'throughput': metrics.throughputMBps,
    });
  },
  
  onPerformanceRegression: (currentMetrics, baselineMetrics) {
    // Alert on performance regressions
    if (currentMetrics.averageProcessingTime > 
        baselineMetrics.averageProcessingTime * 1.5) {
      AlertService.sendAlert('Chunked processing performance regression detected');
    }
  },
);
```

This configuration guide provides comprehensive examples for optimizing Sonix chunked processing across different scenarios. Choose the configuration that best matches your use case and adjust based on your specific requirements and performance testing results.