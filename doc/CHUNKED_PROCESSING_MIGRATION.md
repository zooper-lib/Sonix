# Chunked Processing Migration Guide

Complete guide for migrating from traditional audio processing to Sonix's chunked processing system.

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [Backward Compatibility](#backward-compatibility)
3. [Step-by-Step Migration](#step-by-step-migration)
4. [API Changes](#api-changes)
5. [Configuration Migration](#configuration-migration)
6. [Performance Comparison](#performance-comparison)
7. [Common Migration Issues](#common-migration-issues)
8. [Testing Your Migration](#testing-your-migration)

## Migration Overview

Sonix v2.0 introduces chunked processing as the default method for handling audio files. This migration guide helps you transition from the traditional full-file processing approach to the new chunked system.

### What's Changed

**Before (v1.x):**
- Entire audio files loaded into memory
- Memory usage scaled with file size
- Limited to files smaller than available RAM
- Simple but not scalable

**After (v2.x):**
- Files processed in configurable chunks
- Consistent memory usage regardless of file size
- Can handle files larger than available RAM
- More complex but highly scalable

### Migration Benefits

- **Consistent Memory Usage**: Process 10GB files with the same memory footprint as 10MB files
- **Better Performance**: Reduced memory pressure and improved responsiveness
- **Scalability**: Handle files of any size on any device
- **Progress Tracking**: Real-time progress updates for long operations
- **Error Recovery**: Continue processing even if individual chunks fail

## Backward Compatibility

### Automatic Migration

Sonix v2.0 maintains full backward compatibility. Your existing code will continue to work without changes:

```dart
// v1.x code - still works in v2.x
final waveform = await Sonix.generateWaveform('audio_file.mp3');

// Automatically uses chunked processing for large files (>50MB)
// Uses traditional processing for smaller files for optimal performance
```

### Explicit Control

You can explicitly control which processing method to use:

```dart
// Force traditional processing (v1.x behavior)
final traditionalWaveform = await Sonix.generateWaveform(
  'audio_file.mp3',
  forceTraditionalProcessing: true,
);

// Force chunked processing (v2.x behavior)
final chunkedWaveform = await Sonix.generateWaveformChunked('audio_file.mp3');
```

### Gradual Migration

Enable chunked processing gradually:

```dart
class MigrationController {
  static bool _enableChunkedProcessing = false;
  
  static void enableChunkedProcessing() {
    _enableChunkedProcessing = true;
  }
  
  static Future<WaveformData> generateWaveform(String filePath) async {
    if (_enableChunkedProcessing) {
      return await Sonix.generateWaveformChunked(filePath);
    } else {
      return await Sonix.generateWaveform(filePath);
    }
  }
}

// Enable chunked processing when ready
MigrationController.enableChunkedProcessing();
```

## Step-by-Step Migration

### Step 1: Update Dependencies

Update your `pubspec.yaml`:

```yaml
dependencies:
  sonix: ^2.0.0  # Update from v1.x to v2.x
```

Run:
```bash
flutter pub get
```

### Step 2: Test Existing Code

Verify your existing code still works:

```dart
// Test existing functionality
void testExistingCode() async {
  try {
    // This should work without changes
    final waveform = await Sonix.generateWaveform('test_audio.mp3');
    print('Existing code works: ${waveform.amplitudes.length} points');
  } catch (e) {
    print('Migration issue detected: $e');
  }
}
```

### Step 3: Add Chunked Processing Gradually

Start using chunked processing for new features:

```dart
// New feature using chunked processing
Future<WaveformData> processLargeFile(String filePath) async {
  final fileSize = await File(filePath).length();
  
  if (fileSize > 50 * 1024 * 1024) { // Files > 50MB
    // Use chunked processing for large files
    return await Sonix.generateWaveformChunked(
      filePath,
      onProgress: (progress) {
        print('Progress: ${(progress.progressPercentage * 100).toStringAsFixed(1)}%');
      },
    );
  } else {
    // Keep using traditional processing for small files
    return await Sonix.generateWaveform(filePath);
  }
}
```

### Step 4: Migrate Configuration

Update your initialization code:

```dart
// Old initialization (v1.x)
void initializeOld() {
  Sonix.initialize(
    memoryLimit: 100 * 1024 * 1024,
    maxWaveformCacheSize: 50,
  );
}

// New initialization (v2.x)
void initializeNew() {
  Sonix.initialize(
    memoryLimit: 100 * 1024 * 1024,
    maxWaveformCacheSize: 50,
    
    // Add chunked processing configuration
    defaultChunkedConfig: ChunkedProcessingConfig(
      fileChunkSize: 10 * 1024 * 1024,
      maxMemoryUsage: 100 * 1024 * 1024,
      enableProgressReporting: true,
    ),
  );
}
```

### Step 5: Update Error Handling

Enhance error handling for chunked processing:

```dart
// Old error handling (v1.x)
Future<WaveformData> processAudioOld(String filePath) async {
  try {
    return await Sonix.generateWaveform(filePath);
  } catch (e) {
    print('Processing failed: $e');
    rethrow;
  }
}

// New error handling (v2.x)
Future<WaveformData> processAudioNew(String filePath) async {
  try {
    return await Sonix.generateWaveformChunked(filePath);
  } on ChunkedProcessingException catch (e) {
    print('Chunked processing failed at chunk ${e.chunkIndex}: ${e.message}');
    
    if (e.hasPartialResult) {
      print('Using partial result with ${e.partialResult.amplitudes.length} points');
      return e.partialResult;
    }
    
    // Fallback to traditional processing
    print('Falling back to traditional processing');
    return await Sonix.generateWaveform(filePath, forceTraditionalProcessing: true);
  } on InsufficientMemoryException catch (e) {
    print('Insufficient memory: ${e.requiredMemory} bytes needed');
    
    // Retry with smaller chunks
    final smallerConfig = ChunkedProcessingConfig(
      fileChunkSize: 2 * 1024 * 1024, // 2MB chunks
      maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
    );
    
    return await Sonix.generateWaveformChunked(filePath, config: smallerConfig);
  } catch (e) {
    print('Processing failed: $e');
    rethrow;
  }
}
```

### Step 6: Add Progress Reporting

Enhance user experience with progress reporting:

```dart
// Old approach (v1.x) - no progress reporting
Future<WaveformData> processWithoutProgress(String filePath) async {
  showLoadingDialog(); // Simple loading indicator
  
  try {
    final waveform = await Sonix.generateWaveform(filePath);
    hideLoadingDialog();
    return waveform;
  } catch (e) {
    hideLoadingDialog();
    rethrow;
  }
}

// New approach (v2.x) - with progress reporting
Future<WaveformData> processWithProgress(String filePath) async {
  showProgressDialog(); // Progress dialog with percentage
  
  try {
    final waveform = await Sonix.generateWaveformChunked(
      filePath,
      onProgress: (progress) {
        updateProgressDialog(progress.progressPercentage);
        
        if (progress.estimatedTimeRemaining != null) {
          updateTimeRemaining(progress.estimatedTimeRemaining!);
        }
        
        if (progress.hasErrors) {
          showWarning('Some chunks failed to process');
        }
      },
    );
    
    hideProgressDialog();
    return waveform;
  } catch (e) {
    hideProgressDialog();
    rethrow;
  }
}
```

### Step 7: Full Migration

Replace all traditional processing calls:

```dart
class AudioProcessor {
  // Migration flag for gradual rollout
  static bool useChunkedProcessing = true;
  
  static Future<WaveformData> generateWaveform(
    String filePath, {
    WaveformConfig? config,
    ProgressCallback? onProgress,
  }) async {
    if (useChunkedProcessing) {
      return await _generateWaveformChunked(filePath, config, onProgress);
    } else {
      return await _generateWaveformTraditional(filePath, config);
    }
  }
  
  static Future<WaveformData> _generateWaveformChunked(
    String filePath,
    WaveformConfig? config,
    ProgressCallback? onProgress,
  ) async {
    final fileSize = await File(filePath).length();
    final chunkedConfig = ChunkedProcessingConfig.forFileSize(fileSize);
    
    return await Sonix.generateWaveformChunked(
      filePath,
      config: chunkedConfig,
      waveformConfig: config,
      onProgress: onProgress,
    );
  }
  
  static Future<WaveformData> _generateWaveformTraditional(
    String filePath,
    WaveformConfig? config,
  ) async {
    return await Sonix.generateWaveform(
      filePath,
      config: config,
      forceTraditionalProcessing: true,
    );
  }
}
```

## API Changes

### New Methods

```dart
// New chunked processing methods in v2.x
Future<WaveformData> generateWaveformChunked(
  String filePath, {
  ChunkedProcessingConfig? config,
  WaveformConfig? waveformConfig,
  ProgressCallback? onProgress,
  Duration? seekPosition,
});

Stream<WaveformChunk> generateWaveformStream(
  String filePath, {
  ChunkedProcessingConfig? config,
  WaveformConfig? waveformConfig,
});

Future<WaveformData> seekAndGenerateWaveform(
  String filePath,
  Duration startTime,
  Duration duration, {
  ChunkedProcessingConfig? config,
  WaveformConfig? waveformConfig,
});
```

### Enhanced Existing Methods

```dart
// Enhanced existing methods with chunked processing support
Future<WaveformData> generateWaveform(
  String filePath, {
  int resolution = 1000,
  WaveformType type = WaveformType.bars,
  bool normalize = true,
  WaveformConfig? config,
  
  // New parameters in v2.x
  bool forceTraditionalProcessing = false,  // Force v1.x behavior
  bool enableAutoChunking = true,           // Auto-enable chunking for large files
  ChunkedProcessingConfig? chunkedConfig,   // Chunked processing configuration
});
```

### New Configuration Classes

```dart
// New configuration classes in v2.x
class ChunkedProcessingConfig {
  final int fileChunkSize;
  final int maxMemoryUsage;
  final int maxConcurrentChunks;
  final bool enableSeeking;
  final bool enableProgressReporting;
  // ... other properties
}

class ProgressInfo {
  final int processedChunks;
  final int totalChunks;
  final double progressPercentage;
  final Duration? estimatedTimeRemaining;
  final bool hasErrors;
  // ... other properties
}
```

## Configuration Migration

### Basic Configuration

```dart
// v1.x configuration
class OldConfig {
  static void initialize() {
    Sonix.initialize(
      memoryLimit: 100 * 1024 * 1024,
      maxWaveformCacheSize: 50,
      maxAudioDataCacheSize: 20,
    );
  }
}

// v2.x configuration
class NewConfig {
  static void initialize() {
    Sonix.initialize(
      memoryLimit: 100 * 1024 * 1024,
      maxWaveformCacheSize: 50,
      maxAudioDataCacheSize: 20,
      
      // New chunked processing configuration
      defaultChunkedConfig: ChunkedProcessingConfig(
        fileChunkSize: 10 * 1024 * 1024,
        maxMemoryUsage: 100 * 1024 * 1024,
        maxConcurrentChunks: 3,
        enableProgressReporting: true,
        enableSeeking: true,
      ),
      
      // Auto-chunking thresholds
      autoChunkingThreshold: 50 * 1024 * 1024, // Enable chunking for files > 50MB
      enableAutoChunking: true,
    );
  }
}
```

### Platform-Specific Configuration

```dart
// v1.x platform configuration
class OldPlatformConfig {
  static void configurePlatform() {
    if (Platform.isAndroid) {
      Sonix.initialize(memoryLimit: 50 * 1024 * 1024);
    } else if (Platform.isIOS) {
      Sonix.initialize(memoryLimit: 100 * 1024 * 1024);
    }
  }
}

// v2.x platform configuration
class NewPlatformConfig {
  static void configurePlatform() {
    if (Platform.isAndroid) {
      Sonix.initialize(
        memoryLimit: 50 * 1024 * 1024,
        defaultChunkedConfig: ChunkedProcessingConfig(
          fileChunkSize: 5 * 1024 * 1024,
          maxMemoryUsage: 50 * 1024 * 1024,
          maxConcurrentChunks: 2,
          respectAndroidMemoryLimits: true,
        ),
      );
    } else if (Platform.isIOS) {
      Sonix.initialize(
        memoryLimit: 100 * 1024 * 1024,
        defaultChunkedConfig: ChunkedProcessingConfig(
          fileChunkSize: 10 * 1024 * 1024,
          maxMemoryUsage: 100 * 1024 * 1024,
          maxConcurrentChunks: 3,
          respectIOSMemoryWarnings: true,
        ),
      );
    }
  }
}
```

## Performance Comparison

### Benchmarking Migration

Compare performance between old and new approaches:

```dart
class MigrationBenchmark {
  static Future<void> comparePerformance(List<String> testFiles) async {
    for (final filePath in testFiles) {
      print('\nTesting: $filePath');
      
      // Benchmark traditional processing
      final traditionalResult = await _benchmarkTraditional(filePath);
      print('Traditional: ${traditionalResult.processingTime}ms, '
            '${traditionalResult.peakMemoryUsage} bytes peak memory');
      
      // Benchmark chunked processing
      final chunkedResult = await _benchmarkChunked(filePath);
      print('Chunked: ${chunkedResult.processingTime}ms, '
            '${chunkedResult.peakMemoryUsage} bytes peak memory');
      
      // Compare results
      final speedDiff = (chunkedResult.processingTime.inMilliseconds - 
                        traditionalResult.processingTime.inMilliseconds) / 
                       traditionalResult.processingTime.inMilliseconds;
      
      final memoryDiff = (chunkedResult.peakMemoryUsage - traditionalResult.peakMemoryUsage) / 
                         traditionalResult.peakMemoryUsage;
      
      print('Performance difference: ${(speedDiff * 100).toStringAsFixed(1)}% time, '
            '${(memoryDiff * 100).toStringAsFixed(1)}% memory');
    }
  }
  
  static Future<BenchmarkResult> _benchmarkTraditional(String filePath) async {
    final stopwatch = Stopwatch()..start();
    final memoryBefore = await Sonix.getCurrentMemoryUsage();
    
    final waveform = await Sonix.generateWaveform(
      filePath,
      forceTraditionalProcessing: true,
    );
    
    stopwatch.stop();
    final memoryAfter = await Sonix.getCurrentMemoryUsage();
    
    return BenchmarkResult(
      processingTime: stopwatch.elapsed,
      peakMemoryUsage: memoryAfter - memoryBefore,
      waveformPoints: waveform.amplitudes.length,
    );
  }
  
  static Future<BenchmarkResult> _benchmarkChunked(String filePath) async {
    final stopwatch = Stopwatch()..start();
    final memoryBefore = await Sonix.getCurrentMemoryUsage();
    int peakMemory = memoryBefore;
    
    final waveform = await Sonix.generateWaveformChunked(
      filePath,
      config: ChunkedProcessingConfig(enableProfiling: true),
      onProgress: (progress) async {
        final currentMemory = await Sonix.getCurrentMemoryUsage();
        peakMemory = max(peakMemory, currentMemory);
      },
    );
    
    stopwatch.stop();
    
    return BenchmarkResult(
      processingTime: stopwatch.elapsed,
      peakMemoryUsage: peakMemory - memoryBefore,
      waveformPoints: waveform.amplitudes.length,
    );
  }
}

class BenchmarkResult {
  final Duration processingTime;
  final int peakMemoryUsage;
  final int waveformPoints;
  
  BenchmarkResult({
    required this.processingTime,
    required this.peakMemoryUsage,
    required this.waveformPoints,
  });
}
```

### Performance Expectations

| File Size | Traditional Memory | Chunked Memory | Performance Impact |
|-----------|-------------------|----------------|-------------------|
| 10MB      | ~15MB            | ~25MB          | 10-20% slower     |
| 50MB      | ~75MB            | ~50MB          | Similar speed     |
| 200MB     | ~300MB           | ~50MB          | 20-30% faster     |
| 1GB       | Out of memory    | ~50MB          | Only option       |

## Common Migration Issues

### Issue 1: Performance Regression for Small Files

**Problem:** Chunked processing is slower for small files due to overhead.

**Solution:**

```dart
// Use hybrid approach
Future<WaveformData> smartGenerateWaveform(String filePath) async {
  final fileSize = await File(filePath).length();
  
  if (fileSize < 20 * 1024 * 1024) { // < 20MB
    // Use traditional processing for small files
    return await Sonix.generateWaveform(filePath, forceTraditionalProcessing: true);
  } else {
    // Use chunked processing for large files
    return await Sonix.generateWaveformChunked(filePath);
  }
}
```

### Issue 2: Memory Usage Higher Than Expected

**Problem:** Chunked processing uses more memory than traditional for small files.

**Solution:**

```dart
// Optimize configuration for small files
ChunkedProcessingConfig getOptimalConfig(int fileSize) {
  if (fileSize < 10 * 1024 * 1024) { // < 10MB
    return ChunkedProcessingConfig(
      fileChunkSize: 2 * 1024 * 1024,    // 2MB chunks
      maxMemoryUsage: 15 * 1024 * 1024,  // 15MB limit
      maxConcurrentChunks: 1,             // Sequential processing
    );
  } else {
    return ChunkedProcessingConfig.forFileSize(fileSize);
  }
}
```

### Issue 3: Progress Reporting Not Working

**Problem:** Progress callbacks not being called.

**Solution:**

```dart
// Ensure progress reporting is enabled
final config = ChunkedProcessingConfig(
  enableProgressReporting: true,
  progressUpdateInterval: Duration(milliseconds: 100),
);

final waveform = await Sonix.generateWaveformChunked(
  filePath,
  config: config,
  onProgress: (progress) {
    print('Progress: ${(progress.progressPercentage * 100).toStringAsFixed(1)}%');
  },
);
```

### Issue 4: Compatibility Issues with Existing Code

**Problem:** Existing code expects synchronous behavior or specific error types.

**Solution:**

```dart
// Create compatibility wrapper
class CompatibilityWrapper {
  static Future<WaveformData> generateWaveform(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
  }) async {
    try {
      // Try chunked processing first
      return await Sonix.generateWaveformChunked(
        filePath,
        waveformConfig: WaveformConfig(
          resolution: resolution,
          type: type,
          normalize: normalize,
        ),
      );
    } on ChunkedProcessingException catch (e) {
      // Convert to traditional exception for compatibility
      throw AudioProcessingException(e.message);
    } catch (e) {
      // Fallback to traditional processing
      return await Sonix.generateWaveform(
        filePath,
        resolution: resolution,
        type: type,
        normalize: normalize,
        forceTraditionalProcessing: true,
      );
    }
  }
}
```

## Testing Your Migration

### Unit Tests

```dart
// Test migration compatibility
void main() {
  group('Migration Tests', () {
    test('backward compatibility', () async {
      // Test that old API still works
      final waveform = await Sonix.generateWaveform('test_audio.mp3');
      expect(waveform.amplitudes.isNotEmpty, true);
    });
    
    test('chunked processing equivalence', () async {
      // Test that results are equivalent
      final traditional = await Sonix.generateWaveform(
        'test_audio.mp3',
        forceTraditionalProcessing: true,
      );
      
      final chunked = await Sonix.generateWaveformChunked('test_audio.mp3');
      
      // Results should be very similar (allowing for minor differences)
      expect(traditional.amplitudes.length, chunked.amplitudes.length);
      
      final maxDifference = _calculateMaxDifference(traditional.amplitudes, chunked.amplitudes);
      expect(maxDifference, lessThan(0.01)); // Less than 1% difference
    });
    
    test('memory usage improvement', () async {
      final largeFile = 'large_test_audio.mp3'; // > 100MB file
      
      // Chunked processing should use less memory
      final chunkedMemory = await _measureMemoryUsage(() => 
        Sonix.generateWaveformChunked(largeFile)
      );
      
      expect(chunkedMemory, lessThan(100 * 1024 * 1024)); // < 100MB
    });
  });
}

double _calculateMaxDifference(List<double> a, List<double> b) {
  double maxDiff = 0.0;
  for (int i = 0; i < min(a.length, b.length); i++) {
    final diff = (a[i] - b[i]).abs();
    maxDiff = max(maxDiff, diff);
  }
  return maxDiff;
}

Future<int> _measureMemoryUsage(Future<void> Function() operation) async {
  final memoryBefore = await Sonix.getCurrentMemoryUsage();
  await operation();
  final memoryAfter = await Sonix.getCurrentMemoryUsage();
  return memoryAfter - memoryBefore;
}
```

### Integration Tests

```dart
// Test real-world scenarios
void main() {
  group('Integration Tests', () {
    test('large file processing', () async {
      final largeFile = await _createLargeTestFile(); // Create 500MB test file
      
      final stopwatch = Stopwatch()..start();
      final waveform = await Sonix.generateWaveformChunked(largeFile);
      stopwatch.stop();
      
      expect(waveform.amplitudes.isNotEmpty, true);
      expect(stopwatch.elapsed.inMinutes, lessThan(5)); // Should complete in < 5 minutes
      
      await File(largeFile).delete(); // Cleanup
    });
    
    test('progress reporting accuracy', () async {
      final progressUpdates = <double>[];
      
      await Sonix.generateWaveformChunked(
        'test_audio.mp3',
        onProgress: (progress) {
          progressUpdates.add(progress.progressPercentage);
        },
      );
      
      // Progress should be monotonic and reach 100%
      expect(progressUpdates.isNotEmpty, true);
      expect(progressUpdates.last, closeTo(1.0, 0.01));
      
      for (int i = 1; i < progressUpdates.length; i++) {
        expect(progressUpdates[i], greaterThanOrEqualTo(progressUpdates[i - 1]));
      }
    });
  });
}
```

### Performance Tests

```dart
// Benchmark migration performance
void main() {
  group('Performance Tests', () {
    test('performance comparison', () async {
      final testFiles = [
        'small_file.mp3',   // 5MB
        'medium_file.mp3',  // 50MB
        'large_file.mp3',   // 200MB
      ];
      
      for (final file in testFiles) {
        final traditionalTime = await _benchmarkTraditional(file);
        final chunkedTime = await _benchmarkChunked(file);
        
        print('$file: Traditional ${traditionalTime}ms, Chunked ${chunkedTime}ms');
        
        // For large files, chunked should be faster or similar
        if (await File(file).length() > 100 * 1024 * 1024) {
          expect(chunkedTime, lessThanOrEqualTo(traditionalTime * 1.2)); // Within 20%
        }
      }
    });
  });
}
```

## Migration Checklist

Use this checklist to ensure a successful migration:

### Pre-Migration
- [ ] Update to Sonix v2.0+
- [ ] Test existing code for backward compatibility
- [ ] Identify large files that would benefit from chunked processing
- [ ] Plan gradual migration strategy

### During Migration
- [ ] Update initialization code with chunked processing configuration
- [ ] Add progress reporting to long-running operations
- [ ] Enhance error handling for chunked processing exceptions
- [ ] Implement hybrid approach for optimal performance
- [ ] Add memory pressure handling for mobile devices

### Post-Migration
- [ ] Benchmark performance improvements
- [ ] Monitor memory usage in production
- [ ] Test with various file sizes and formats
- [ ] Verify progress reporting accuracy
- [ ] Test error recovery scenarios

### Testing
- [ ] Unit tests for API compatibility
- [ ] Integration tests for real-world scenarios
- [ ] Performance tests comparing old vs new approaches
- [ ] Memory usage tests for large files
- [ ] Error handling tests for edge cases

This migration guide provides a comprehensive path from traditional to chunked processing while maintaining compatibility and optimizing performance.