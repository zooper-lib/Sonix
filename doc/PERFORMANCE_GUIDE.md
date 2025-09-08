# Performance Optimization Guide

This guide provides comprehensive recommendations for optimizing performance when using the Sonix audio waveform package.

## Table of Contents

1. [Memory Management](#memory-management)
2. [Processing Optimization](#processing-optimization)
3. [UI Performance](#ui-performance)
4. [Platform-Specific Optimizations](#platform-specific-optimizations)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

## Memory Management

### Initialize with Memory Limits

Always initialize Sonix with appropriate memory limits for your application:

```dart
void main() {
  // Initialize before runApp()
  Sonix.initialize(
    memoryLimit: 50 * 1024 * 1024, // 50MB - adjust based on your needs
    maxWaveformCacheSize: 50,       // Number of waveforms to cache
    maxAudioDataCacheSize: 20,      // Number of audio data to cache
  );
  
  runApp(MyApp());
}
```

### Memory Limit Guidelines

| Device Type | Recommended Limit | Use Case |
|-------------|------------------|----------|
| Low-end mobile | 25-50MB | Basic waveform display |
| Mid-range mobile | 50-100MB | Multiple waveforms, caching |
| High-end mobile | 100-200MB | Heavy usage, large files |
| Desktop/Web | 200-500MB | Professional applications |

### Monitor Memory Usage

Regularly check memory usage and adjust accordingly:

```dart
void checkMemoryUsage() {
  final stats = Sonix.getResourceStatistics();
  
  print('Memory usage: ${(stats.memoryUsagePercentage * 100).toStringAsFixed(1)}%');
  print('Cached waveforms: ${stats.cachedWaveforms}');
  print('Cache hit rate: ${stats.cacheHitRate.toStringAsFixed(1)}%');
  
  // Take action if memory usage is high
  if (stats.memoryUsagePercentage > 0.8) {
    await Sonix.forceCleanup();
  }
}
```

### Memory Cleanup Strategies

1. **Automatic Cleanup**: Sonix automatically manages memory, but you can force cleanup:

```dart
// Force cleanup when memory is low
await Sonix.forceCleanup();

// Clear specific files from cache
Sonix.clearFileFromCaches('large_audio.wav');
```

2. **Dispose Resources**: Always dispose of WaveformData when no longer needed:

```dart
class MyWidget extends StatefulWidget {
  WaveformData? waveformData;
  
  @override
  void dispose() {
    waveformData?.dispose(); // Free memory
    super.dispose();
  }
}
```

## Processing Optimization

### Choose the Right Processing Method

Select the appropriate method based on your use case:

#### 1. Standard Processing
- **Best for**: Small to medium files (<50MB)
- **Pros**: Fastest processing
- **Cons**: Uses more memory

```dart
final waveformData = await Sonix.generateWaveform('audio.mp3');
```

#### 2. Memory-Efficient Processing
- **Best for**: Large files (50-200MB)
- **Pros**: Lower memory usage
- **Cons**: Slower processing

```dart
final waveformData = await Sonix.generateWaveformMemoryEfficient(
  'large_audio.wav',
  maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
);
```

#### 3. Streaming Processing
- **Best for**: Very large files (>200MB)
- **Pros**: Minimal memory usage, progressive loading
- **Cons**: More complex to handle

```dart
await for (final chunk in Sonix.generateWaveformStream('huge_audio.flac')) {
  // Process chunks as they arrive
  updateUI(chunk);
}
```

#### 4. Adaptive Processing
- **Best for**: Unknown file sizes
- **Pros**: Automatically chooses best method
- **Cons**: Slight overhead for decision making

```dart
final waveformData = await Sonix.generateWaveformAdaptive('any_audio.mp3');
```

#### 5. Cached Processing
- **Best for**: Frequently accessed files
- **Pros**: Very fast for repeated access
- **Cons**: Uses cache memory

```dart
final waveformData = await Sonix.generateWaveformCached('frequent_audio.mp3');
```

### Resolution Optimization

Choose appropriate resolution based on display requirements:

```dart
// Low resolution for thumbnails
final thumbnailWaveform = await Sonix.generateWaveform(
  'audio.mp3',
  resolution: 50,
);

// Medium resolution for normal display
final normalWaveform = await Sonix.generateWaveform(
  'audio.mp3',
  resolution: 200,
);

// High resolution for detailed analysis
final detailedWaveform = await Sonix.generateWaveform(
  'audio.mp3',
  resolution: 1000,
);
```

### Algorithm Selection

Different algorithms have different performance characteristics:

```dart
final config = WaveformConfig(
  resolution: 200,
  algorithm: DownsamplingAlgorithm.rms,     // Best balance of quality/speed
  // algorithm: DownsamplingAlgorithm.peak,    // Fastest
  // algorithm: DownsamplingAlgorithm.average, // Good quality
  // algorithm: DownsamplingAlgorithm.median,  // Highest quality, slowest
);
```

### Preloading Strategy

Preload audio data for better user experience:

```dart
// Preload in background
Future<void> preloadAudioFiles(List<String> filePaths) async {
  for (final path in filePaths) {
    try {
      await Sonix.preloadAudioData(path);
    } catch (e) {
      print('Failed to preload $path: $e');
    }
  }
}

// Use preloaded data
final waveformData = await Sonix.generateWaveformCached('preloaded_audio.mp3');
```

## UI Performance

### Widget Optimization

1. **Use StaticWaveformWidget for non-interactive displays**:

```dart
// For static display (better performance)
StaticWaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.professional,
)

// Only use WaveformWidget when interaction is needed
WaveformWidget(
  waveformData: waveformData,
  playbackPosition: position,
  onSeek: (pos) => handleSeek(pos),
)
```

2. **Optimize animation settings**:

```dart
WaveformWidget(
  waveformData: waveformData,
  playbackPosition: position,
  animationDuration: const Duration(milliseconds: 100), // Shorter for better performance
  animationCurve: Curves.linear, // Simpler curve
)
```

3. **Use appropriate waveform types**:

```dart
// Fastest rendering
WaveformStyle(type: WaveformType.line)

// Medium performance
WaveformStyle(type: WaveformType.bars)

// Slowest rendering (but most visually appealing)
WaveformStyle(type: WaveformType.filled)
```

### Rendering Optimization

1. **Avoid complex gradients in performance-critical scenarios**:

```dart
// Good for performance
WaveformStyle(
  playedColor: Colors.blue,
  unplayedColor: Colors.grey,
)

// Use gradients sparingly
WaveformStyle(
  gradient: LinearGradient(
    colors: [Colors.blue, Colors.purple],
  ),
)
```

2. **Optimize widget rebuilds**:

```dart
class OptimizedWaveformWidget extends StatefulWidget {
  final WaveformData waveformData;
  final double playbackPosition;
  
  @override
  Widget build(BuildContext context) {
    return WaveformWidget(
      waveformData: waveformData,
      playbackPosition: playbackPosition,
      style: _cachedStyle, // Cache style objects
    );
  }
  
  // Cache style to avoid recreating
  static final _cachedStyle = WaveformStylePresets.soundCloud;
}
```

## Platform-Specific Optimizations

### Android

1. **ProGuard/R8 Optimization**: Sonix includes optimized ProGuard rules automatically.

2. **NDK Optimization**: Native libraries are optimized for different architectures:
   - arm64-v8a (recommended for modern devices)
   - armeabi-v7a (for older devices)

3. **Memory Management**:
```dart
// Android-specific memory limits
Sonix.initialize(
  memoryLimit: 30 * 1024 * 1024, // Conservative for Android
);
```

### iOS

1. **Memory Warnings**: Handle iOS memory warnings:
```dart
// In your app delegate or main widget
void handleMemoryWarning() {
  Sonix.forceCleanup();
}
```

2. **Background Processing**: iOS may limit background processing:
```dart
// Process waveforms when app is active
if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
  await generateWaveform();
}
```

### Desktop (Windows/macOS/Linux)

1. **Higher Memory Limits**: Desktop apps can use more memory:
```dart
Sonix.initialize(
  memoryLimit: 200 * 1024 * 1024, // 200MB for desktop
  maxWaveformCacheSize: 100,
);
```

2. **File System Performance**: Use absolute paths for better performance:
```dart
final absolutePath = path.absolute('audio.mp3');
final waveformData = await Sonix.generateWaveform(absolutePath);
```

### Web

1. **WASM Performance**: Web version uses WebAssembly for optimal performance.

2. **Memory Constraints**: Web has stricter memory limits:
```dart
Sonix.initialize(
  memoryLimit: 50 * 1024 * 1024, // Conservative for web
);
```

## Best Practices

### 1. Initialization

```dart
// Initialize once at app startup
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure based on platform
  final memoryLimit = Platform.isAndroid || Platform.isIOS 
    ? 50 * 1024 * 1024  // 50MB for mobile
    : 200 * 1024 * 1024; // 200MB for desktop
    
  Sonix.initialize(memoryLimit: memoryLimit);
  
  runApp(MyApp());
}
```

### 2. Error Handling

```dart
Future<WaveformData?> safeGenerateWaveform(String filePath) async {
  try {
    return await Sonix.generateWaveformAdaptive(filePath);
  } on UnsupportedFormatException catch (e) {
    print('Unsupported format: ${e.format}');
    return null;
  } on MemoryException catch (e) {
    print('Memory error: ${e.message}');
    await Sonix.forceCleanup();
    return null;
  } catch (e) {
    print('Unexpected error: $e');
    return null;
  }
}
```

### 3. Batch Processing

```dart
Future<List<WaveformData>> processBatch(List<String> filePaths) async {
  final results = <WaveformData>[];
  
  for (final path in filePaths) {
    try {
      // Use cached processing for batch operations
      final waveform = await Sonix.generateWaveformCached(path);
      results.add(waveform);
      
      // Check memory usage periodically
      final stats = Sonix.getResourceStatistics();
      if (stats.memoryUsagePercentage > 0.7) {
        await Sonix.forceCleanup();
      }
    } catch (e) {
      print('Failed to process $path: $e');
    }
  }
  
  return results;
}
```

### 4. Lifecycle Management

```dart
class AudioPlayerScreen extends StatefulWidget {
  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up resources
    waveformData?.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background, clean up memory
      Sonix.forceCleanup();
    }
  }
}
```

## Troubleshooting

### Common Performance Issues

1. **High Memory Usage**
   - **Symptom**: App crashes or becomes slow
   - **Solution**: Reduce memory limit, use streaming processing
   - **Code**:
   ```dart
   // Check memory usage
   final stats = Sonix.getResourceStatistics();
   if (stats.memoryUsagePercentage > 0.8) {
     await Sonix.forceCleanup();
   }
   ```

2. **Slow Waveform Generation**
   - **Symptom**: Long processing times
   - **Solution**: Use appropriate algorithm, reduce resolution
   - **Code**:
   ```dart
   // Use faster algorithm
   final config = WaveformConfig(
     algorithm: DownsamplingAlgorithm.peak, // Fastest
     resolution: 100, // Lower resolution
   );
   ```

3. **UI Lag During Playback**
   - **Symptom**: Choppy animations
   - **Solution**: Optimize animation settings, use StaticWaveformWidget
   - **Code**:
   ```dart
   WaveformWidget(
     animationDuration: const Duration(milliseconds: 50),
     animationCurve: Curves.linear,
   )
   ```

### Performance Monitoring

```dart
class PerformanceMonitor {
  static void logPerformanceStats() {
    final stats = Sonix.getResourceStatistics();
    
    print('=== Sonix Performance Stats ===');
    print('Memory Usage: ${(stats.memoryUsagePercentage * 100).toStringAsFixed(1)}%');
    print('Cached Waveforms: ${stats.cachedWaveforms}');
    print('Cached Audio Data: ${stats.cachedAudioData}');
    print('Cache Hit Rate: ${stats.cacheHitRate.toStringAsFixed(1)}%');
    print('Active Resources: ${stats.activeResources}');
    print('Last Cleanup: ${stats.lastCleanupTime}');
    print('===============================');
  }
  
  static void startPerformanceMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      logPerformanceStats();
      
      final stats = Sonix.getResourceStatistics();
      if (stats.memoryUsagePercentage > 0.9) {
        print('WARNING: High memory usage detected!');
        Sonix.forceCleanup();
      }
    });
  }
}
```

### Debugging Tools

```dart
// Enable debug logging (development only)
void enableDebugLogging() {
  // This would be implemented in the actual package
  // Sonix.setDebugMode(true);
}

// Performance profiling
Future<void> profileWaveformGeneration(String filePath) async {
  final stopwatch = Stopwatch()..start();
  
  try {
    final waveform = await Sonix.generateWaveform(filePath);
    stopwatch.stop();
    
    print('Waveform generation took: ${stopwatch.elapsedMilliseconds}ms');
    print('Data points: ${waveform.amplitudes.length}');
    print('Memory usage: ${(Sonix.getResourceStatistics().memoryUsagePercentage * 100).toStringAsFixed(1)}%');
  } catch (e) {
    stopwatch.stop();
    print('Waveform generation failed after: ${stopwatch.elapsedMilliseconds}ms');
    print('Error: $e');
  }
}
```

## Conclusion

Following these performance optimization guidelines will help you achieve the best possible performance with the Sonix package. Remember to:

1. Initialize with appropriate memory limits
2. Choose the right processing method for your use case
3. Monitor memory usage regularly
4. Optimize UI rendering
5. Handle platform-specific considerations
6. Implement proper error handling and cleanup

For additional help, refer to the [API documentation](https://pub.dev/documentation/sonix/latest/) or [file an issue](https://github.com/your-repo/sonix/issues).