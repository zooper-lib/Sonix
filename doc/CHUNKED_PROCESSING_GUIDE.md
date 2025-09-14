# Chunked Processing Guide

Complete guide for using Sonix's chunked audio processing capabilities for efficient handling of large audio files.

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Configuration](#configuration)
4. [API Reference](#api-reference)
5. [Performance Optimization](#performance-optimization)
6. [Memory Management](#memory-management)
7. [Error Handling](#error-handling)
8. [Platform Considerations](#platform-considerations)
9. [Migration Guide](#migration-guide)
10. [Troubleshooting](#troubleshooting)

## Overview

Chunked processing is Sonix's approach to handling audio files of any size by processing them in configurable chunks rather than loading entire files into memory. This provides:

- **Consistent Memory Usage**: Process 10GB+ files with the same memory footprint as 10MB files
- **Better Performance**: Reduced memory pressure and improved responsiveness
- **Scalability**: Handle files of any size on any device
- **Progress Tracking**: Real-time progress updates for long-running operations
- **Seeking Support**: Efficient navigation within large files

### When to Use Chunked Processing

Chunked processing is automatically enabled for all files in Sonix v2.0+, but you can explicitly control it:

- **Large Files (>100MB)**: Essential for memory efficiency
- **Memory-Constrained Devices**: Prevents out-of-memory errors
- **Background Processing**: Allows UI responsiveness during processing
- **Streaming Applications**: Process files as they download
- **Batch Processing**: Handle multiple large files efficiently

## Getting Started

### Basic Usage

Chunked processing is enabled by default. No code changes are required:

```dart
// This automatically uses chunked processing for large files
final waveform = await Sonix.generateWaveform('large_audio_file.mp3');
```

### Explicit Chunked Processing

For explicit control over chunked processing:

```dart
// Generate waveform with explicit chunked processing
final waveform = await Sonix.generateWaveformChunked(
  'audio_file.mp3',
  config: ChunkedProcessingConfig(
    fileChunkSize: 10 * 1024 * 1024, // 10MB chunks
    maxMemoryUsage: 50 * 1024 * 1024, // 50MB total memory limit
    enableProgressReporting: true,
  ),
  onProgress: (progress) {
    print('Progress: ${(progress.progressPercentage * 100).toStringAsFixed(1)}%');
  },
);
```

### Streaming Waveform Generation

Generate waveforms progressively as chunks are processed:

```dart
await for (final waveformChunk in Sonix.generateWaveformStream('large_file.mp3')) {
  // Update UI with partial waveform data
  updateWaveformDisplay(waveformChunk);
}
```

## Configuration

### ChunkedProcessingConfig

Configure chunked processing behavior:

```dart
final config = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,        // 10MB file chunks
  maxMemoryUsage: 100 * 1024 * 1024,      // 100MB memory limit
  maxConcurrentChunks: 3,                  // Process 3 chunks concurrently
  enableSeeking: true,                     // Enable efficient seeking
  enableProgressReporting: true,           // Enable progress callbacks
  progressUpdateInterval: Duration(milliseconds: 100), // Progress update frequency
);
```

### Automatic Configuration

Let Sonix choose optimal settings based on file size:

```dart
// Get file size
final file = File('audio_file.mp3');
final fileSize = await file.length();

// Create optimal configuration
final config = ChunkedProcessingConfig.forFileSize(fileSize);

final waveform = await Sonix.generateWaveformChunked(
  'audio_file.mp3',
  config: config,
);
```

### Configuration Guidelines

| File Size | Recommended Chunk Size | Memory Limit | Concurrent Chunks |
|-----------|----------------------|--------------|-------------------|
| < 10MB    | 1MB                  | 25MB         | 2                 |
| 10-100MB  | 5MB                  | 50MB         | 3                 |
| 100MB-1GB | 10MB                 | 100MB        | 3                 |
| > 1GB     | 20MB                 | 150MB        | 4                 |

## API Reference

### Core Methods

#### `generateWaveformChunked()`

```dart
Future<WaveformData> generateWaveformChunked(
  String filePath, {
  ChunkedProcessingConfig? config,
  WaveformConfig? waveformConfig,
  ProgressCallback? onProgress,
  Duration? seekPosition,
})
```

Generate complete waveform using chunked processing.

**Parameters:**
- `filePath`: Path to audio file
- `config`: Chunked processing configuration (optional)
- `waveformConfig`: Waveform generation settings (optional)
- `onProgress`: Progress callback function (optional)
- `seekPosition`: Start processing from specific time (optional)

#### `generateWaveformStream()`

```dart
Stream<WaveformChunk> generateWaveformStream(
  String filePath, {
  ChunkedProcessingConfig? config,
  WaveformConfig? waveformConfig,
})
```

Generate waveform as a stream of chunks.

**Returns:** Stream of `WaveformChunk` objects containing partial waveform data.

#### `seekAndGenerateWaveform()`

```dart
Future<WaveformData> seekAndGenerateWaveform(
  String filePath,
  Duration startTime,
  Duration duration, {
  ChunkedProcessingConfig? config,
  WaveformConfig? waveformConfig,
})
```

Generate waveform for a specific time range without processing the entire file.

### Data Models

#### `ChunkedProcessingConfig`

Configuration for chunked processing behavior:

```dart
class ChunkedProcessingConfig {
  final int fileChunkSize;              // Size of file chunks in bytes
  final int maxMemoryUsage;             // Maximum memory usage in bytes
  final int maxConcurrentChunks;        // Maximum concurrent chunk processing
  final bool enableSeeking;             // Enable seeking capabilities
  final bool enableProgressReporting;   // Enable progress callbacks
  final Duration progressUpdateInterval; // Progress update frequency
}
```

#### `ProgressInfo`

Progress information provided to callbacks:

```dart
class ProgressInfo {
  final int processedChunks;            // Number of chunks processed
  final int totalChunks;                // Total number of chunks
  final bool hasErrors;                 // Whether errors occurred
  final Object? lastError;              // Last error encountered
  final Duration? estimatedTimeRemaining; // Estimated time to completion
  
  double get progressPercentage;        // Progress as 0.0 to 1.0
}
```

#### `WaveformChunk`

Partial waveform data from streaming generation:

```dart
class WaveformChunk {
  final List<double> amplitudes;        // Amplitude values for this chunk
  final int startSample;                // Starting sample position
  final bool isLast;                    // Whether this is the final chunk
  final Duration? timeOffset;           // Time offset of this chunk
}
```

## Performance Optimization

### Chunk Size Optimization

Choose chunk sizes based on your use case:

```dart
// For real-time processing (lower latency)
final realtimeConfig = ChunkedProcessingConfig(
  fileChunkSize: 1 * 1024 * 1024,  // 1MB chunks
  maxConcurrentChunks: 2,           // Lower concurrency
);

// For batch processing (higher throughput)
final batchConfig = ChunkedProcessingConfig(
  fileChunkSize: 20 * 1024 * 1024, // 20MB chunks
  maxConcurrentChunks: 4,           // Higher concurrency
);

// For memory-constrained devices
final constrainedConfig = ChunkedProcessingConfig(
  fileChunkSize: 512 * 1024,       // 512KB chunks
  maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
  maxConcurrentChunks: 1,           // Sequential processing
);
```

### Memory Management

Monitor and control memory usage:

```dart
// Check current memory usage
final stats = Sonix.getChunkedProcessingStats();
print('Memory usage: ${stats.currentMemoryUsage} bytes');
print('Active chunks: ${stats.activeChunks}');

// Configure memory pressure handling
final config = ChunkedProcessingConfig(
  maxMemoryUsage: 50 * 1024 * 1024,
  onMemoryPressure: (currentUsage, maxUsage) {
    print('Memory pressure: $currentUsage / $maxUsage bytes');
    // Optionally pause other operations
  },
);
```

### Concurrent Processing

Optimize concurrent chunk processing:

```dart
// Get optimal concurrency for current device
final optimalConcurrency = Sonix.getOptimalConcurrency();

final config = ChunkedProcessingConfig(
  maxConcurrentChunks: optimalConcurrency,
  fileChunkSize: 10 * 1024 * 1024,
);
```

## Memory Management

### Memory Limits

Set appropriate memory limits based on your application:

```dart
// Conservative (mobile apps)
final mobileConfig = ChunkedProcessingConfig(
  maxMemoryUsage: 50 * 1024 * 1024,  // 50MB
  fileChunkSize: 5 * 1024 * 1024,    // 5MB chunks
);

// Aggressive (desktop apps)
final desktopConfig = ChunkedProcessingConfig(
  maxMemoryUsage: 200 * 1024 * 1024, // 200MB
  fileChunkSize: 20 * 1024 * 1024,   // 20MB chunks
);
```

### Memory Pressure Handling

Handle memory pressure gracefully:

```dart
final config = ChunkedProcessingConfig(
  maxMemoryUsage: 100 * 1024 * 1024,
  onMemoryPressure: (currentUsage, maxUsage) {
    final pressureLevel = currentUsage / maxUsage;
    
    if (pressureLevel > 0.9) {
      // Critical pressure - pause processing
      print('Critical memory pressure - pausing');
    } else if (pressureLevel > 0.7) {
      // High pressure - reduce chunk size
      print('High memory pressure - reducing chunk size');
    }
  },
);
```

### Cleanup and Resource Management

Ensure proper cleanup:

```dart
// Manual cleanup when needed
await Sonix.forceCleanupChunkedProcessing();

// Check for memory leaks
final stats = Sonix.getChunkedProcessingStats();
if (stats.activeChunks > 0) {
  print('Warning: ${stats.activeChunks} chunks still active');
}
```

## Error Handling

### Error Recovery Strategies

Configure how errors are handled during chunked processing:

```dart
final config = ChunkedProcessingConfig(
  errorRecoveryStrategy: ErrorRecoveryStrategy.skipAndContinue,
  maxRetries: 3,
  retryDelay: Duration(milliseconds: 100),
);
```

Available strategies:

- `ErrorRecoveryStrategy.skipAndContinue`: Skip failed chunks and continue
- `ErrorRecoveryStrategy.retryWithSmallerChunk`: Retry with smaller chunk size
- `ErrorRecoveryStrategy.seekToNextBoundary`: Skip to next format boundary
- `ErrorRecoveryStrategy.failFast`: Fail immediately on any error

### Handling Specific Errors

```dart
try {
  final waveform = await Sonix.generateWaveformChunked(
    'audio_file.mp3',
    onProgress: (progress) {
      if (progress.hasErrors) {
        print('Error in chunk processing: ${progress.lastError}');
      }
    },
  );
} on ChunkedProcessingException catch (e) {
  print('Chunked processing failed: ${e.message}');
  print('Failed at chunk: ${e.chunkIndex}');
  print('Partial result available: ${e.hasPartialResult}');
  
  if (e.hasPartialResult) {
    final partialWaveform = e.partialResult;
    // Use partial waveform data
  }
} on InsufficientMemoryException catch (e) {
  print('Not enough memory: ${e.requiredMemory} bytes needed');
  // Retry with smaller chunk size
  final smallerConfig = ChunkedProcessingConfig(
    fileChunkSize: 1 * 1024 * 1024, // 1MB chunks
    maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
  );
  
  final waveform = await Sonix.generateWaveformChunked(
    'audio_file.mp3',
    config: smallerConfig,
  );
}
```

## Platform Considerations

### Android

```dart
// Android-specific optimizations
final androidConfig = ChunkedProcessingConfig(
  fileChunkSize: 8 * 1024 * 1024,    // 8MB chunks (good for Android)
  maxMemoryUsage: 64 * 1024 * 1024,  // 64MB limit
  maxConcurrentChunks: 2,             // Conservative concurrency
);
```

### iOS

```dart
// iOS-specific optimizations
final iosConfig = ChunkedProcessingConfig(
  fileChunkSize: 10 * 1024 * 1024,   // 10MB chunks
  maxMemoryUsage: 100 * 1024 * 1024, // 100MB limit
  maxConcurrentChunks: 3,             // Higher concurrency on iOS
);
```

### Desktop Platforms

```dart
// Desktop-specific optimizations
final desktopConfig = ChunkedProcessingConfig(
  fileChunkSize: 20 * 1024 * 1024,   // 20MB chunks
  maxMemoryUsage: 200 * 1024 * 1024, // 200MB limit
  maxConcurrentChunks: 4,             // Higher concurrency
);
```

### Web Platform

```dart
// Web-specific considerations
final webConfig = ChunkedProcessingConfig(
  fileChunkSize: 5 * 1024 * 1024,    // 5MB chunks (network considerations)
  maxMemoryUsage: 50 * 1024 * 1024,  // 50MB limit (browser memory)
  maxConcurrentChunks: 2,             // Conservative for web
);
```

## Migration Guide

### From Traditional Processing

If you're upgrading from Sonix v1.x, chunked processing is automatically enabled. No code changes are required for basic usage:

```dart
// v1.x code - still works in v2.x
final waveform = await Sonix.generateWaveform('audio_file.mp3');

// v2.x - automatically uses chunked processing for large files
// No changes needed!
```

### Explicit Migration

For explicit control over the migration:

```dart
// Old approach (v1.x)
final waveform = await Sonix.generateWaveform('large_file.mp3');

// New approach (v2.x) - explicit chunked processing
final waveform = await Sonix.generateWaveformChunked(
  'large_file.mp3',
  config: ChunkedProcessingConfig.forFileSize(fileSize),
  onProgress: (progress) {
    // Add progress reporting
    updateProgressBar(progress.progressPercentage);
  },
);
```

### Configuration Migration

Update your initialization code to include chunked processing settings:

```dart
// Old initialization (v1.x)
Sonix.initialize(
  memoryLimit: 100 * 1024 * 1024,
);

// New initialization (v2.x)
Sonix.initialize(
  memoryLimit: 100 * 1024 * 1024,
  defaultChunkedConfig: ChunkedProcessingConfig(
    fileChunkSize: 10 * 1024 * 1024,
    maxMemoryUsage: 100 * 1024 * 1024,
    enableProgressReporting: true,
  ),
);
```

### Performance Comparison

Compare performance between traditional and chunked processing:

```dart
// Benchmark both approaches
final stopwatch = Stopwatch()..start();

// Traditional processing
final traditionalWaveform = await Sonix.generateWaveform(
  'test_file.mp3',
  forceTraditionalProcessing: true, // Force old method
);
final traditionalTime = stopwatch.elapsedMilliseconds;

stopwatch.reset();

// Chunked processing
final chunkedWaveform = await Sonix.generateWaveformChunked('test_file.mp3');
final chunkedTime = stopwatch.elapsedMilliseconds;

print('Traditional: ${traditionalTime}ms');
print('Chunked: ${chunkedTime}ms');
print('Memory saved: ${traditionalMemoryUsage - chunkedMemoryUsage} bytes');
```

## Troubleshooting

### Common Issues

#### 1. Out of Memory Errors

**Problem:** Application crashes with out-of-memory errors.

**Solution:**
```dart
// Reduce chunk size and memory limit
final config = ChunkedProcessingConfig(
  fileChunkSize: 1 * 1024 * 1024,    // 1MB chunks
  maxMemoryUsage: 25 * 1024 * 1024,  // 25MB limit
  maxConcurrentChunks: 1,             // Sequential processing
);
```

#### 2. Slow Processing Performance

**Problem:** Chunked processing is slower than expected.

**Solution:**
```dart
// Increase chunk size and concurrency
final config = ChunkedProcessingConfig(
  fileChunkSize: 20 * 1024 * 1024,   // 20MB chunks
  maxConcurrentChunks: 4,             // More concurrency
);

// Or use automatic optimization
final config = ChunkedProcessingConfig.forFileSize(fileSize);
```

#### 3. Inaccurate Progress Reporting

**Problem:** Progress updates are inconsistent or inaccurate.

**Solution:**
```dart
// Ensure progress reporting is enabled and configure update interval
final config = ChunkedProcessingConfig(
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 50), // More frequent updates
);
```

#### 4. Seeking Issues

**Problem:** Seeking to specific positions is slow or inaccurate.

**Solution:**
```dart
// Enable seeking and use format-specific optimizations
final config = ChunkedProcessingConfig(
  enableSeeking: true,
  fileChunkSize: 5 * 1024 * 1024,    // Smaller chunks for better seeking
);

// For MP3 files, ensure frame boundaries are respected
final mp3Config = ChunkedProcessingConfig(
  enableSeeking: true,
  respectFormatBoundaries: true,      // Align with MP3 frames
);
```

### Debugging

Enable debug logging to troubleshoot issues:

```dart
// Enable debug logging
Sonix.setLogLevel(LogLevel.debug);

// Check processing statistics
final stats = Sonix.getChunkedProcessingStats();
print('Active chunks: ${stats.activeChunks}');
print('Memory usage: ${stats.currentMemoryUsage}');
print('Processing queue size: ${stats.queueSize}');

// Monitor chunk processing
final config = ChunkedProcessingConfig(
  onChunkProcessed: (chunkIndex, processingTime) {
    print('Chunk $chunkIndex processed in ${processingTime}ms');
  },
  onMemoryPressure: (currentUsage, maxUsage) {
    print('Memory pressure: ${(currentUsage / maxUsage * 100).toStringAsFixed(1)}%');
  },
);
```

### Performance Profiling

Profile chunked processing performance:

```dart
// Enable performance profiling
final config = ChunkedProcessingConfig(
  enableProfiling: true,
);

final waveform = await Sonix.generateWaveformChunked(
  'audio_file.mp3',
  config: config,
);

// Get profiling results
final profile = Sonix.getLastProfilingResult();
print('Total processing time: ${profile.totalTime}');
print('Average chunk time: ${profile.averageChunkTime}');
print('Memory peak usage: ${profile.peakMemoryUsage}');
print('Bottlenecks: ${profile.bottlenecks}');
```

### Getting Help

If you encounter issues not covered in this guide:

1. **Check the logs**: Enable debug logging to see detailed processing information
2. **Verify configuration**: Ensure your `ChunkedProcessingConfig` is appropriate for your use case
3. **Test with smaller files**: Verify the issue occurs with large files specifically
4. **Check device resources**: Monitor memory and CPU usage during processing
5. **Report issues**: Include configuration, file details, and error logs when reporting bugs

For additional support, see the [GitHub Issues](https://github.com/your-repo/sonix/issues) page.