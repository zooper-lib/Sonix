# Chunked Processing Troubleshooting Guide

Comprehensive troubleshooting guide for resolving common issues with Sonix's chunked audio processing.

## Table of Contents

1. [Common Issues](#common-issues)
2. [Error Messages](#error-messages)
3. [Performance Problems](#performance-problems)
4. [Memory Issues](#memory-issues)
5. [Platform-Specific Issues](#platform-specific-issues)
6. [Debugging Tools](#debugging-tools)
7. [FAQ](#faq)

## Common Issues

### Issue: Out of Memory Errors

**Symptoms:**
- Application crashes with `OutOfMemoryError`
- System becomes unresponsive during processing
- Memory usage continuously increases

**Causes:**
- Chunk size too large for available memory
- Too many concurrent chunks
- Memory leaks in processing pipeline
- Insufficient device memory

**Solutions:**

```dart
// 1. Reduce chunk size and concurrency
final conservativeConfig = ChunkedProcessingConfig(
  fileChunkSize: 2 * 1024 * 1024,       // 2MB chunks
  maxMemoryUsage: 25 * 1024 * 1024,     // 25MB limit
  maxConcurrentChunks: 1,                // Sequential processing
);

// 2. Enable memory pressure handling
final adaptiveConfig = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,
  maxMemoryUsage: 50 * 1024 * 1024,
  
  onMemoryPressure: (currentUsage, maxUsage) {
    final pressureLevel = currentUsage / maxUsage;
    
    if (pressureLevel > 0.8) {
      // Reduce chunk size when memory pressure is high
      return ChunkedProcessingConfig(
        fileChunkSize: 1 * 1024 * 1024,
        maxConcurrentChunks: 1,
      );
    }
    return null;
  },
);

// 3. Force garbage collection
await Sonix.forceGarbageCollection();

// 4. Check for memory leaks
final stats = Sonix.getChunkedProcessingStats();
if (stats.activeChunks > 0) {
  print('Warning: ${stats.activeChunks} chunks still active - possible memory leak');
}
```

**Prevention:**
- Always test with target device memory constraints
- Monitor memory usage during development
- Use appropriate chunk sizes for your platform
- Enable memory pressure callbacks

### Issue: Slow Processing Performance

**Symptoms:**
- Processing takes much longer than expected
- Low throughput (< 5 MB/s)
- High CPU usage but slow progress

**Causes:**
- Chunk size too small (excessive overhead)
- Insufficient concurrency
- I/O bottlenecks
- Suboptimal configuration for file format

**Solutions:**

```dart
// 1. Optimize chunk size and concurrency
final performanceConfig = ChunkedProcessingConfig(
  fileChunkSize: 15 * 1024 * 1024,      // Increase chunk size
  maxConcurrentChunks: Platform.numberOfProcessors, // Use all cores
  enableCPUOptimization: true,
);

// 2. Enable I/O optimization
final ioOptimizedConfig = performanceConfig.copyWith(
  enableReadAhead: true,
  readAheadSize: 32 * 1024 * 1024,      // 32MB read-ahead
  ioBufferSize: 64 * 1024,              // 64KB I/O buffer
);

// 3. Use format-specific optimization
final formatConfig = ChunkedProcessingConfig.forFormat(AudioFormat.mp3);

// 4. Benchmark different configurations
final benchmarkResult = await ChunkedProcessingBenchmark.runBenchmark(
  filePath: 'test_file.mp3',
  config: performanceConfig,
);
print('Throughput: ${benchmarkResult.averageThroughput} MB/s');
```

### Issue: Inaccurate Progress Reporting

**Symptoms:**
- Progress jumps or goes backwards
- Progress stuck at certain percentages
- Inconsistent progress updates

**Causes:**
- Incorrect total chunk calculation
- Variable chunk processing times
- Progress update interval too high
- Errors in chunk processing not handled

**Solutions:**

```dart
// 1. Enable accurate progress tracking
final progressConfig = ChunkedProcessingConfig(
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 50), // More frequent updates
  enableAccurateProgressCalculation: true,
);

// 2. Handle progress errors properly
final waveform = await Sonix.generateWaveformChunked(
  'audio_file.mp3',
  config: progressConfig,
  onProgress: (progress) {
    if (progress.hasErrors) {
      print('Progress with errors: ${progress.progressPercentage}');
      print('Last error: ${progress.lastError}');
    } else {
      print('Progress: ${(progress.progressPercentage * 100).toStringAsFixed(1)}%');
    }
    
    // Validate progress is monotonic
    if (progress.progressPercentage < _lastProgress) {
      print('Warning: Progress went backwards');
    }
    _lastProgress = progress.progressPercentage;
  },
);

// 3. Use estimated time remaining
final progressWithETA = ChunkedProcessingConfig(
  enableProgressReporting: true,
  enableTimeEstimation: true,
  
  onProgress: (progress) {
    if (progress.estimatedTimeRemaining != null) {
      print('ETA: ${progress.estimatedTimeRemaining!.inSeconds} seconds');
    }
  },
);
```

### Issue: Seeking Problems

**Symptoms:**
- Seeking to specific positions is slow
- Inaccurate seek positions
- Seeking fails with errors

**Causes:**
- Format doesn't support efficient seeking
- Chunk boundaries don't align with format structures
- Seek tables not available or corrupted
- Insufficient seeking configuration

**Solutions:**

```dart
// 1. Enable format-specific seeking
final seekConfig = ChunkedProcessingConfig(
  enableSeeking: true,
  respectFormatBoundaries: true,
  seekingStrategy: SeekingStrategy.auto, // Auto-detect best strategy
);

// 2. Use format-specific configurations
final mp3SeekConfig = ChunkedProcessingConfig(
  enableSeeking: true,
  respectFormatBoundaries: true,
  enableFrameBoundaryDetection: true,
  seekingStrategy: SeekingStrategy.frameBoundary,
);

final flacSeekConfig = ChunkedProcessingConfig(
  enableSeeking: true,
  enableSeekTableUsage: true,
  seekingStrategy: SeekingStrategy.seekTable,
);

// 3. Handle seeking errors gracefully
try {
  final waveform = await Sonix.seekAndGenerateWaveform(
    'audio_file.mp3',
    Duration(minutes: 2),
    Duration(seconds: 30),
    config: seekConfig,
  );
} on SeekingNotSupportedException catch (e) {
  print('Seeking not supported for this format: ${e.format}');
  // Fallback to full file processing
  final waveform = await Sonix.generateWaveformChunked('audio_file.mp3');
} on InaccurateSeekException catch (e) {
  print('Seek position inaccurate: requested ${e.requestedPosition}, got ${e.actualPosition}');
  // Use actual position
}
```

### Issue: File Format Compatibility

**Symptoms:**
- Certain audio files fail to process
- Inconsistent results across different files
- Format-specific errors

**Causes:**
- Unsupported audio format variations
- Corrupted file headers
- Non-standard format implementations
- Missing format-specific optimizations

**Solutions:**

```dart
// 1. Check format support
final formatInfo = await Sonix.getFormatInfo('audio_file.mp3');
if (!formatInfo.isSupported) {
  print('Format not supported: ${formatInfo.format}');
  print('Reason: ${formatInfo.unsupportedReason}');
  return;
}

// 2. Use format detection
final detectedFormat = await Sonix.detectAudioFormat('unknown_file.audio');
print('Detected format: ${detectedFormat.format}');
print('Confidence: ${detectedFormat.confidence}');

// 3. Handle format-specific errors
try {
  final waveform = await Sonix.generateWaveformChunked('audio_file.mp3');
} on UnsupportedFormatException catch (e) {
  print('Unsupported format: ${e.format}');
  print('Supported formats: ${e.supportedFormats}');
} on CorruptedFileException catch (e) {
  print('File corrupted at position: ${e.position}');
  
  // Try with error recovery
  final recoveryConfig = ChunkedProcessingConfig(
    errorRecoveryStrategy: ErrorRecoveryStrategy.skipAndContinue,
    maxConsecutiveErrors: 5,
  );
  
  final waveform = await Sonix.generateWaveformChunked(
    'audio_file.mp3',
    config: recoveryConfig,
  );
}
```

## Error Messages

### `ChunkedProcessingException`

**Error Message:** `"Chunked processing failed at chunk X"`

**Meaning:** Processing failed for a specific chunk during waveform generation.

**Solutions:**

```dart
try {
  final waveform = await Sonix.generateWaveformChunked('audio_file.mp3');
} on ChunkedProcessingException catch (e) {
  print('Processing failed at chunk: ${e.chunkIndex}');
  print('Error: ${e.message}');
  
  if (e.hasPartialResult) {
    // Use partial waveform data
    final partialWaveform = e.partialResult;
    print('Partial waveform has ${partialWaveform.amplitudes.length} points');
  }
  
  // Retry with different configuration
  final retryConfig = ChunkedProcessingConfig(
    fileChunkSize: 5 * 1024 * 1024,      // Smaller chunks
    errorRecoveryStrategy: ErrorRecoveryStrategy.retryWithSmallerChunk,
  );
  
  final waveform = await Sonix.generateWaveformChunked(
    'audio_file.mp3',
    config: retryConfig,
  );
}
```

### `InsufficientMemoryException`

**Error Message:** `"Insufficient memory for chunked processing"`

**Meaning:** Not enough memory available for the requested chunk size and concurrency.

**Solutions:**

```dart
try {
  final waveform = await Sonix.generateWaveformChunked('large_file.mp3');
} on InsufficientMemoryException catch (e) {
  print('Required memory: ${e.requiredMemory} bytes');
  print('Available memory: ${e.availableMemory} bytes');
  
  // Calculate appropriate chunk size
  final maxChunkSize = (e.availableMemory * 0.8).round(); // Use 80% of available
  final appropriateChunkSize = min(maxChunkSize, 5 * 1024 * 1024); // Max 5MB
  
  final memoryConstrainedConfig = ChunkedProcessingConfig(
    fileChunkSize: appropriateChunkSize,
    maxMemoryUsage: e.availableMemory,
    maxConcurrentChunks: 1,
  );
  
  final waveform = await Sonix.generateWaveformChunked(
    'large_file.mp3',
    config: memoryConstrainedConfig,
  );
}
```

### `SeekingNotSupportedException`

**Error Message:** `"Seeking not supported for format X"`

**Meaning:** The audio format doesn't support efficient seeking operations.

**Solutions:**

```dart
try {
  final waveform = await Sonix.seekAndGenerateWaveform(
    'audio_file.ogg',
    Duration(minutes: 5),
    Duration(seconds: 30),
  );
} on SeekingNotSupportedException catch (e) {
  print('Seeking not supported for ${e.format}');
  
  // Fallback options:
  
  // 1. Process entire file
  final fullWaveform = await Sonix.generateWaveformChunked('audio_file.ogg');
  
  // 2. Use approximate seeking (less accurate but works)
  final approximateConfig = ChunkedProcessingConfig(
    enableSeeking: true,
    seekingStrategy: SeekingStrategy.approximate,
  );
  
  final waveform = await Sonix.seekAndGenerateWaveform(
    'audio_file.ogg',
    Duration(minutes: 5),
    Duration(seconds: 30),
    config: approximateConfig,
  );
}
```

### `CorruptedChunkException`

**Error Message:** `"Chunk X is corrupted or invalid"`

**Meaning:** A specific chunk contains corrupted or invalid audio data.

**Solutions:**

```dart
final robustConfig = ChunkedProcessingConfig(
  errorRecoveryStrategy: ErrorRecoveryStrategy.skipAndContinue,
  maxConsecutiveErrors: 3,
  
  onChunkCorruption: (chunkIndex, position, error) {
    print('Chunk $chunkIndex corrupted at position $position: $error');
    
    // Log corruption for analysis
    CorruptionLogger.log(chunkIndex, position, error);
  },
);

try {
  final waveform = await Sonix.generateWaveformChunked(
    'potentially_corrupted_file.mp3',
    config: robustConfig,
  );
} on CorruptedChunkException catch (e) {
  if (e.corruptedChunks.length > e.totalChunks * 0.5) {
    // More than 50% corrupted - file is likely unusable
    throw FileUnusableException('File too corrupted to process');
  }
  
  // Continue with partial result
  final partialWaveform = e.partialResult;
}
```

## Performance Problems

### Problem: High CPU Usage

**Symptoms:**
- CPU usage at 100% during processing
- System becomes unresponsive
- Processing slower than expected despite high CPU usage

**Diagnosis:**

```dart
// Enable CPU profiling
final profilingConfig = ChunkedProcessingConfig(
  enableCpuProfiling: true,
  
  onCpuUtilization: (utilization) {
    if (utilization > 0.95) {
      print('High CPU usage detected: ${(utilization * 100).toStringAsFixed(1)}%');
    }
  },
);

// Check CPU bottlenecks
final profile = await Sonix.profileChunkedProcessing('audio_file.mp3', profilingConfig);
print('CPU bottlenecks: ${profile.cpuBottlenecks}');
print('Thread utilization: ${profile.threadUtilization}');
```

**Solutions:**

```dart
// 1. Reduce concurrency
final cpuOptimizedConfig = ChunkedProcessingConfig(
  maxConcurrentChunks: max(1, Platform.numberOfProcessors ~/ 2),
  enableCPUThrottling: true,
  cpuThrottlingThreshold: 0.8, // Throttle at 80% CPU usage
);

// 2. Add processing intervals
final intervalConfig = ChunkedProcessingConfig(
  processingInterval: Duration(milliseconds: 10), // 10ms pause between chunks
  yieldToUI: true,
  uiYieldInterval: Duration(milliseconds: 16), // 60 FPS
);

// 3. Lower thread priority
final lowPriorityConfig = ChunkedProcessingConfig(
  threadPriority: ThreadPriority.low,
  enableBackgroundProcessing: true,
);
```

### Problem: Memory Leaks

**Symptoms:**
- Memory usage continuously increases
- Application eventually crashes
- Memory not released after processing

**Diagnosis:**

```dart
// Enable memory leak detection
final leakDetectionConfig = ChunkedProcessingConfig(
  enableMemoryLeakDetection: true,
  memoryLeakThreshold: 5 * 1024 * 1024, // 5MB threshold
  
  onMemoryLeak: (leakSize, chunkIndex) {
    print('Memory leak detected: ${leakSize} bytes after chunk $chunkIndex');
    
    // Force garbage collection
    Sonix.forceGarbageCollection();
    
    // Check if leak persists
    final postGCMemory = Sonix.getCurrentMemoryUsage();
    if (postGCMemory > leakSize * 0.9) {
      print('Memory leak confirmed after GC');
    }
  },
);
```

**Solutions:**

```dart
// 1. Enable aggressive cleanup
final cleanupConfig = ChunkedProcessingConfig(
  enableAggressiveCleanup: true,
  forceGCInterval: 5, // Force GC every 5 chunks
  enableMemoryPool: true, // Reuse memory
);

// 2. Manual cleanup
await for (final waveformChunk in Sonix.generateWaveformStream('audio_file.mp3')) {
  // Process chunk
  processWaveformChunk(waveformChunk);
  
  // Manual cleanup every 10 chunks
  if (chunkCount % 10 == 0) {
    await Sonix.forceCleanupChunkedProcessing();
  }
}

// 3. Monitor memory usage
final monitoringConfig = ChunkedProcessingConfig(
  enableMemoryMonitoring: true,
  memoryMonitoringInterval: Duration(seconds: 1),
  
  onMemoryUsageUpdate: (usage) {
    if (usage.growthRate > 1024 * 1024) { // 1MB/s growth
      print('Warning: High memory growth rate: ${usage.growthRate} bytes/s');
    }
  },
);
```

## Memory Issues

### Issue: Memory Pressure on Mobile Devices

**Symptoms:**
- App receives memory warnings
- System kills the app
- Performance degrades significantly

**Solutions:**

```dart
// Mobile-optimized configuration
final mobileConfig = ChunkedProcessingConfig(
  fileChunkSize: 2 * 1024 * 1024,       // 2MB chunks
  maxMemoryUsage: 30 * 1024 * 1024,     // 30MB limit
  maxConcurrentChunks: 1,                // Sequential processing
  
  // Mobile-specific settings
  respectPlatformMemoryLimits: true,
  enableMemoryWarningHandling: true,
  
  onMemoryWarning: (warningLevel) {
    switch (warningLevel) {
      case MemoryWarningLevel.low:
        // Reduce chunk size
        return ChunkedProcessingConfig(
          fileChunkSize: 1 * 1024 * 1024,
          maxMemoryUsage: 20 * 1024 * 1024,
        );
      case MemoryWarningLevel.critical:
        // Pause processing
        return ChunkedProcessingConfig(
          pauseProcessing: true,
          resumeAfterMemoryRecovery: true,
        );
    }
  },
);

// iOS-specific memory handling
if (Platform.isIOS) {
  final iosConfig = mobileConfig.copyWith(
    respectIOSMemoryWarnings: true,
    enableIOSBackgroundProcessing: false, // Disable in background
  );
}

// Android-specific memory handling
if (Platform.isAndroid) {
  final androidConfig = mobileConfig.copyWith(
    respectAndroidMemoryLimits: true,
    enableAndroidLowMemoryKiller: true,
  );
}
```

### Issue: Large File Processing

**Symptoms:**
- Cannot process files larger than available RAM
- Processing extremely slow for large files
- Memory usage grows with file size

**Solutions:**

```dart
// Large file configuration
final largeFileConfig = ChunkedProcessingConfig.forLargeFiles();

// Or custom configuration for very large files
final customLargeFileConfig = ChunkedProcessingConfig(
  fileChunkSize: 50 * 1024 * 1024,      // 50MB chunks for large files
  maxMemoryUsage: 200 * 1024 * 1024,    // 200MB memory limit
  maxConcurrentChunks: 2,                // Conservative concurrency
  
  // Large file optimizations
  enableLargeFileOptimization: true,
  enableMemoryMappedIO: true,            // Use memory mapping
  memoryMapThreshold: 100 * 1024 * 1024, // Files > 100MB
  
  // Progress reporting for long operations
  enableProgressReporting: true,
  progressUpdateInterval: Duration(seconds: 1),
);

// Process very large file (10GB+)
final hugeFileConfig = ChunkedProcessingConfig(
  fileChunkSize: 100 * 1024 * 1024,     // 100MB chunks
  maxMemoryUsage: 500 * 1024 * 1024,    // 500MB memory limit
  maxConcurrentChunks: 1,                // Sequential for huge files
  
  enableStreamingMode: true,             // Stream processing
  enableDiskCaching: true,               // Cache to disk
  diskCacheSize: 1024 * 1024 * 1024,    // 1GB disk cache
);
```

## Platform-Specific Issues

### Android Issues

#### Issue: Background Processing Limitations

**Problem:** Processing stops when app goes to background

**Solution:**

```dart
// Configure background processing
final backgroundConfig = ChunkedProcessingConfig(
  enableBackgroundProcessing: true,
  backgroundProcessingPriority: BackgroundPriority.high,
  
  // Use foreground service for long operations
  enableForegroundService: true,
  foregroundServiceNotification: ProcessingNotification(
    title: 'Processing Audio',
    description: 'Generating waveform...',
  ),
);

// Handle background limitations
if (Platform.isAndroid) {
  final androidVersion = await DeviceInfoPlugin().androidInfo;
  
  if (androidVersion.version.sdkInt >= 26) { // Android 8.0+
    // Use WorkManager for background processing
    final workManagerConfig = backgroundConfig.copyWith(
      useWorkManager: true,
      workManagerConstraints: WorkConstraints(
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
    );
  }
}
```

#### Issue: Memory Pressure on Low-End Devices

**Problem:** App crashes on devices with limited RAM

**Solution:**

```dart
// Detect device capabilities
final androidInfo = await DeviceInfoPlugin().androidInfo;
final totalMemory = androidInfo.totalMemory;

ChunkedProcessingConfig getAndroidConfig(int totalMemory) {
  if (totalMemory < 2 * 1024 * 1024 * 1024) { // < 2GB RAM
    return ChunkedProcessingConfig(
      fileChunkSize: 1 * 1024 * 1024,    // 1MB chunks
      maxMemoryUsage: 20 * 1024 * 1024,  // 20MB limit
      maxConcurrentChunks: 1,
      enableLowMemoryMode: true,
    );
  } else if (totalMemory < 4 * 1024 * 1024 * 1024) { // < 4GB RAM
    return ChunkedProcessingConfig(
      fileChunkSize: 4 * 1024 * 1024,    // 4MB chunks
      maxMemoryUsage: 50 * 1024 * 1024,  // 50MB limit
      maxConcurrentChunks: 2,
    );
  } else {
    return ChunkedProcessingConfig(
      fileChunkSize: 8 * 1024 * 1024,    // 8MB chunks
      maxMemoryUsage: 100 * 1024 * 1024, // 100MB limit
      maxConcurrentChunks: 3,
    );
  }
}
```

### iOS Issues

#### Issue: Memory Warnings

**Problem:** iOS sends memory warnings during processing

**Solution:**

```dart
// iOS memory warning handling
final iosConfig = ChunkedProcessingConfig(
  respectIOSMemoryWarnings: true,
  
  onIOSMemoryWarning: (warningLevel) {
    switch (warningLevel) {
      case IOSMemoryWarningLevel.low:
        // Reduce memory usage
        return ChunkedProcessingConfig(
          fileChunkSize: 3 * 1024 * 1024,
          maxMemoryUsage: 40 * 1024 * 1024,
          maxConcurrentChunks: 1,
        );
        
      case IOSMemoryWarningLevel.critical:
        // Pause processing and clear caches
        Sonix.clearAllCaches();
        return ChunkedProcessingConfig(
          pauseProcessing: true,
          resumeAfterMemoryRecovery: true,
        );
    }
  },
);
```

### Web Platform Issues

#### Issue: Browser Memory Limitations

**Problem:** Browser limits memory usage, causing failures

**Solution:**

```dart
// Web-optimized configuration
final webConfig = ChunkedProcessingConfig(
  fileChunkSize: 3 * 1024 * 1024,       // 3MB chunks for web
  maxMemoryUsage: 40 * 1024 * 1024,     // 40MB limit
  maxConcurrentChunks: 1,                // Sequential for web
  
  // Web-specific optimizations
  enableWebWorkers: true,                // Use web workers
  webWorkerCount: 2,
  enableServiceWorkerCaching: true,      // Cache in service worker
  
  // Handle browser limitations
  respectBrowserMemoryLimits: true,
  enableWebAssemblyOptimization: true,
);

// Handle web-specific errors
try {
  final waveform = await Sonix.generateWaveformChunked('audio_file.mp3', config: webConfig);
} on WebMemoryLimitException catch (e) {
  print('Browser memory limit exceeded: ${e.limit} bytes');
  
  // Retry with smaller chunks
  final reducedConfig = webConfig.copyWith(
    fileChunkSize: 1 * 1024 * 1024,     // 1MB chunks
    maxMemoryUsage: 20 * 1024 * 1024,   // 20MB limit
  );
  
  final waveform = await Sonix.generateWaveformChunked('audio_file.mp3', config: reducedConfig);
}
```

## Debugging Tools

### Enable Debug Logging

```dart
// Enable comprehensive debug logging
Sonix.setLogLevel(LogLevel.debug);

final debugConfig = ChunkedProcessingConfig(
  enableDebugLogging: true,
  debugLogLevel: LogLevel.verbose,
  
  // Log all operations
  logChunkProcessing: true,
  logMemoryOperations: true,
  logIOOperations: true,
  logErrorRecovery: true,
);

// Custom debug callbacks
final customDebugConfig = debugConfig.copyWith(
  onDebugMessage: (level, message, context) {
    print('[$level] $message');
    if (context != null) {
      print('Context: $context');
    }
  },
);
```

### Performance Profiling

```dart
// Enable detailed profiling
final profilingConfig = ChunkedProcessingConfig(
  enableProfiling: true,
  enableMemoryProfiling: true,
  enableCpuProfiling: true,
  enableIOProfiling: true,
  
  profilingOutputFile: 'chunked_processing_profile.json',
);

// Generate performance report
final waveform = await Sonix.generateWaveformChunked(
  'audio_file.mp3',
  config: profilingConfig,
);

final profile = Sonix.getLastProfilingResult();
print('Performance Report:');
print('Total time: ${profile.totalTime}');
print('Average chunk time: ${profile.averageChunkTime}');
print('Peak memory: ${profile.peakMemoryUsage}');
print('Bottlenecks: ${profile.bottlenecks}');

// Export detailed profile
await profile.exportToFile('detailed_profile.json');
```

### Memory Analysis

```dart
// Memory analysis tools
class MemoryAnalyzer {
  static void analyzeMemoryUsage(ChunkedProcessingConfig config) {
    config.copyWith(
      enableMemoryAnalysis: true,
      memoryAnalysisInterval: Duration(seconds: 1),
      
      onMemorySnapshot: (snapshot) {
        print('Memory Snapshot:');
        print('  Total: ${snapshot.totalMemory} bytes');
        print('  Used: ${snapshot.usedMemory} bytes');
        print('  Free: ${snapshot.freeMemory} bytes');
        print('  Active chunks: ${snapshot.activeChunks}');
        print('  Cached data: ${snapshot.cachedData} bytes');
        
        // Detect memory patterns
        if (snapshot.memoryGrowthRate > 1024 * 1024) { // 1MB/s
          print('Warning: High memory growth rate');
        }
        
        if (snapshot.fragmentationLevel > 0.3) { // 30% fragmentation
          print('Warning: High memory fragmentation');
        }
      },
    );
  }
}
```

## FAQ

### Q: Why is chunked processing slower than traditional processing for small files?

**A:** Chunked processing has overhead for chunk management and coordination. For small files (< 10MB), the overhead may outweigh the benefits. You can:

```dart
// Use smaller chunks for small files
final smallFileConfig = ChunkedProcessingConfig.forFileSize(fileSize);

// Or disable chunked processing for very small files
if (fileSize < 5 * 1024 * 1024) { // < 5MB
  final waveform = await Sonix.generateWaveform(filePath); // Traditional processing
} else {
  final waveform = await Sonix.generateWaveformChunked(filePath); // Chunked processing
}
```

### Q: How do I choose the optimal chunk size?

**A:** Chunk size depends on several factors:

```dart
// General guidelines:
// - Available memory: chunk size should be 10-20% of available memory
// - File size: larger files can use larger chunks
// - Platform: mobile devices need smaller chunks
// - Format: some formats work better with specific chunk sizes

final optimalConfig = ChunkedProcessingConfig.forFileSize(fileSize);

// Or calculate based on available memory
final availableMemory = await Sonix.getAvailableMemory();
final optimalChunkSize = (availableMemory * 0.15).round(); // 15% of available memory

final customConfig = ChunkedProcessingConfig(
  fileChunkSize: optimalChunkSize.clamp(1 * 1024 * 1024, 50 * 1024 * 1024),
);
```

### Q: Can I process multiple files simultaneously?

**A:** Yes, but be careful with memory usage:

```dart
// Process multiple files with shared memory limit
final sharedConfig = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,
  maxMemoryUsage: 100 * 1024 * 1024,    // Shared across all files
  enableSharedMemoryPool: true,
);

// Process files sequentially (safer)
final results = <WaveformData>[];
for (final filePath in filePaths) {
  final waveform = await Sonix.generateWaveformChunked(filePath, config: sharedConfig);
  results.add(waveform);
}

// Process files in parallel (higher memory usage)
final futures = filePaths.map((filePath) => 
  Sonix.generateWaveformChunked(filePath, config: sharedConfig)
).toList();

final results = await Future.wait(futures);
```

### Q: How do I handle very large files (> 10GB)?

**A:** Use specialized configuration for very large files:

```dart
final hugeFileConfig = ChunkedProcessingConfig(
  fileChunkSize: 100 * 1024 * 1024,     // 100MB chunks
  maxMemoryUsage: 500 * 1024 * 1024,    // 500MB memory limit
  maxConcurrentChunks: 1,                // Sequential processing
  
  // Large file optimizations
  enableMemoryMappedIO: true,            // Use memory mapping
  enableDiskCaching: true,               // Cache intermediate results
  enableStreamingMode: true,             // Stream processing
  
  // Progress reporting for long operations
  enableProgressReporting: true,
  progressUpdateInterval: Duration(seconds: 5),
);

// Use streaming for very large files
await for (final waveformChunk in Sonix.generateWaveformStream(
  'huge_file.mp3',
  config: hugeFileConfig,
)) {
  // Process chunk immediately to avoid memory buildup
  processWaveformChunk(waveformChunk);
}
```

### Q: What should I do if processing fails partway through?

**A:** Enable error recovery and use partial results:

```dart
final robustConfig = ChunkedProcessingConfig(
  errorRecoveryStrategy: ErrorRecoveryStrategy.skipAndContinue,
  maxConsecutiveErrors: 5,
  enablePartialResults: true,
);

try {
  final waveform = await Sonix.generateWaveformChunked(filePath, config: robustConfig);
} on ChunkedProcessingException catch (e) {
  if (e.hasPartialResult) {
    // Use partial waveform
    final partialWaveform = e.partialResult;
    print('Got partial result: ${partialWaveform.amplitudes.length} points');
    
    // Optionally, try to process remaining chunks
    final remainingConfig = robustConfig.copyWith(
      startFromChunk: e.lastSuccessfulChunk + 1,
    );
    
    try {
      final remainingWaveform = await Sonix.generateWaveformChunked(
        filePath,
        config: remainingConfig,
      );
      
      // Combine partial and remaining results
      final completeWaveform = combineWaveforms(partialWaveform, remainingWaveform);
    } catch (e2) {
      // Use partial result only
      return partialWaveform;
    }
  }
}
```

This troubleshooting guide covers the most common issues you may encounter with chunked processing. For additional help, check the debug logs and consider filing an issue with detailed reproduction steps.