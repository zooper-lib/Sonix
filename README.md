# Sonix - Flutter Audio Waveform Package

A comprehensive Flutter package for generating and displaying audio waveforms without relying on FFMPEG. Sonix supports multiple audio formats (MP3, OGG, WAV, FLAC, Opus) using native C libraries through Dart FFI for optimal performance.

[![pub package](https://img.shields.io/pub/v/sonix.svg)](https://pub.dev/packages/sonix)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

✨ **Multi-format Support**: MP3, OGG, WAV, FLAC, and Opus audio formats  
🚀 **High Performance**: Native C libraries via Dart FFI (no FFMPEG dependency)  
🎨 **Extensive Customization**: Colors, gradients, styles, and animations  
📱 **Interactive Playback**: Real-time position visualization and seeking  
💾 **Memory Efficient**: Streaming processing and intelligent caching  
🔧 **Easy Integration**: Simple API with comprehensive error handling  
📊 **Multiple Algorithms**: RMS, Peak, Average, and Median downsampling  
🎯 **Optimized Presets**: Ready-to-use configurations for different use cases  

## Getting Started

### Installation

Add Sonix to your `pubspec.yaml`:

```yaml
dependencies:
  sonix: ^0.0.1
```

Then run:

```bash
flutter pub get
```

### Platform Setup

Sonix uses native libraries that are automatically built for each platform. No additional setup is required for most use cases.

#### Supported Platforms
- ✅ Android (API 21+)
- ✅ iOS (11.0+)
- ✅ Windows (Windows 10+)
- ✅ macOS (10.14+)
- ✅ Linux (Ubuntu 18.04+)

## Quick Start

### Basic Waveform Generation

```dart
import 'package:sonix/sonix.dart';

// Generate waveform from audio file
final waveformData = await Sonix.generateWaveform('path/to/audio.mp3');

// Display the waveform
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.soundCloud,
)
```

### With Playback Position

```dart
class AudioPlayer extends StatefulWidget {
  @override
  _AudioPlayerState createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer> {
  WaveformData? waveformData;
  double playbackPosition = 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (waveformData != null)
          WaveformWidget(
            waveformData: waveformData!,
            playbackPosition: playbackPosition,
            style: WaveformStylePresets.spotify,
            onSeek: (position) {
              setState(() {
                playbackPosition = position;
              });
              // Update your audio player position
            },
          ),
      ],
    );
  }
}
```

## Usage Examples

### 1. Different Waveform Styles

```dart
// SoundCloud-style waveform
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.soundCloud,
)

// Spotify-style waveform
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.spotify,
)

// Custom style
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStyle(
    playedColor: Colors.blue,
    unplayedColor: Colors.grey.shade300,
    height: 80,
    type: WaveformType.filled,
    gradient: LinearGradient(
      colors: [Colors.blue, Colors.purple],
    ),
  ),
)
```

### 2. Memory-Efficient Processing

```dart
// For large audio files
final waveformData = await Sonix.generateWaveformMemoryEfficient(
  'large_audio.wav',
  maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
);

// Adaptive processing (automatically chooses best method)
final waveformData = await Sonix.generateWaveformAdaptive('any_size_audio.mp3');

// With caching for better performance
final waveformData = await Sonix.generateWaveformCached('audio.mp3');
```

### 3. Streaming Processing

```dart
// Process large files in chunks
await for (final chunk in Sonix.generateWaveformStream('large_audio.flac')) {
  print('Received chunk with ${chunk.amplitudes.length} data points');
  // Update UI progressively
}
```

### 4. Custom Configuration

```dart
// Use optimal settings for different scenarios
final config = Sonix.getOptimalConfig(
  useCase: WaveformUseCase.musicVisualization,
  customResolution: 2000,
);

final waveformData = await Sonix.generateWaveform(
  'music.mp3',
  config: config,
);

// Custom algorithm and settings
final customConfig = WaveformConfig(
  resolution: 1500,
  algorithm: DownsamplingAlgorithm.rms,
  normalize: true,
  type: WaveformType.bars,
);
```

### 5. Pre-generated Waveform Data

```dart
// Use pre-computed waveform data
final jsonData = await loadWaveformFromCache();
final waveformData = WaveformData.fromJson(jsonData);

// Or from amplitude array
final amplitudes = [0.1, 0.5, 0.8, 0.3, 0.7, ...];
final waveformData = WaveformData.fromAmplitudes(amplitudes);

WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.professional,
)
```

### 6. Error Handling

```dart
try {
  final waveformData = await Sonix.generateWaveform('audio.mp3');
  // Use waveformData
} on UnsupportedFormatException catch (e) {
  print('Unsupported format: ${e.format}');
  print('Supported formats: ${Sonix.getSupportedFormats()}');
} on DecodingException catch (e) {
  print('Decoding failed: ${e.message}');
} on FileSystemException catch (e) {
  print('File access error: ${e.message}');
}
```

## API Reference

### Main API Class

#### `Sonix`

The main entry point for generating waveforms.

**Static Methods:**

- `generateWaveform(String filePath, {...})` → `Future<WaveformData>`
- `generateWaveformStream(String filePath, {...})` → `Stream<WaveformChunk>`
- `generateWaveformMemoryEfficient(String filePath, {...})` → `Future<WaveformData>`
- `generateWaveformCached(String filePath, {...})` → `Future<WaveformData>`
- `generateWaveformAdaptive(String filePath, {...})` → `Future<WaveformData>`
- `getSupportedFormats()` → `List<String>`
- `isFormatSupported(String filePath)` → `bool`
- `getOptimalConfig({required WaveformUseCase useCase, ...})` → `WaveformConfig`

### Widgets

#### `WaveformWidget`

Interactive waveform display with playback position and seeking.

**Properties:**
- `waveformData` (required): The waveform data to display
- `playbackPosition`: Current playback position (0.0 to 1.0)
- `style`: Customization options
- `onSeek`: Callback when user seeks to a position
- `enableSeek`: Whether to enable touch interaction

#### `StaticWaveformWidget`

Simplified waveform display without playback features.

### Data Models

#### `WaveformData`

Contains processed waveform data and metadata.

**Properties:**
- `amplitudes`: List of amplitude values (0.0 to 1.0)
- `duration`: Duration of the original audio
- `sampleRate`: Sample rate of the original audio
- `metadata`: Generation metadata

**Methods:**
- `toJson()` → `Map<String, dynamic>`
- `fromJson(Map<String, dynamic>)` → `WaveformData`
- `fromAmplitudes(List<double>)` → `WaveformData`

#### `WaveformStyle`

Customization options for waveform appearance.

**Properties:**
- `playedColor`: Color for played portion
- `unplayedColor`: Color for unplayed portion
- `height`: Height of the waveform
- `type`: Visualization type (bars, line, filled)
- `gradient`: Optional gradient overlay
- `borderRadius`: Border radius for rounded corners

### Style Presets

#### `WaveformStylePresets`

Pre-configured styles for common use cases:

- `soundCloud`: SoundCloud-inspired orange and grey
- `spotify`: Spotify-inspired green and grey
- `professional`: Clean black and grey for professional apps
- `minimalLine`: Minimal line-style waveform
- `filledGradient()`: Filled waveform with customizable gradient
- `neonGlow()`: Glowing neon effect with customizable color

## Performance Optimization

Sonix includes comprehensive performance optimization tools for production applications.

### Performance Optimizer

Automatically optimize waveform generation based on system conditions:

```dart
// Initialize performance optimizer
final optimizer = PerformanceOptimizer();
await optimizer.initialize(settings: OptimizationSettings(
  enableProfiling: true,
  memoryLimit: 150 * 1024 * 1024, // 150MB
  enableAutoOptimization: true,
));

// Optimize waveform generation automatically
final waveformData = await optimizer.optimizeWaveformGeneration(audioData);

// Get real-time performance metrics
final metrics = optimizer.getCurrentMetrics();
print('Memory usage: ${(metrics.memoryUsagePercentage * 100).toStringAsFixed(1)}%');
print('Cache hit rate: ${(metrics.cacheHitRate * 100).toStringAsFixed(1)}%');

// Get optimization suggestions
final suggestions = optimizer.getOptimizationSuggestions();
for (final suggestion in suggestions) {
  print('${suggestion.priority.name.toUpperCase()}: ${suggestion.title}');
  print('  ${suggestion.description}');
  print('  Action: ${suggestion.action}');
}

// Optimize widget rendering
final renderingOpt = optimizer.optimizeWidgetRendering(waveformData, widgetWidth);
print('Rendering strategy: ${renderingOpt.strategy.name}');
```

### Performance Profiling

Profile operations to identify bottlenecks and optimize performance:

```dart
final profiler = PerformanceProfiler();
profiler.enable();

// Profile individual operations
final result = await profiler.profile('waveform_generation', () async {
  return await Sonix.generateWaveform('audio.mp3');
}, metadata: {'file_size': fileSize, 'format': 'mp3'});

// Profile synchronous operations
final processedData = profiler.profileSync('data_processing', () {
  return processAudioData(rawData);
});

// Run comprehensive benchmarks
final waveformBenchmark = await profiler.benchmarkWaveformGeneration(
  resolutions: [500, 1000, 2000],
  durations: [10.0, 30.0, 60.0],
  iterations: 3,
);

final renderingBenchmark = await profiler.benchmarkWidgetRendering(
  amplitudeCounts: [1000, 2000, 5000],
  iterations: 5,
);

// Generate detailed performance report
final report = profiler.generateReport();
print(report.toString());

// Export profiling data
final jsonData = profiler.exportToJson();
await File('performance_data.json').writeAsString(jsonEncode(jsonData));
```

### Platform Validation

Validate platform compatibility and get optimization recommendations:

```dart
final validator = PlatformValidator();

// Validate current platform
final validation = await validator.validatePlatform();
print('Platform: ${validation.platformInfo.operatingSystem}');
print('Supported: ${validation.isSupported}');

if (validation.hasIssues) {
  for (final issue in validation.issues) {
    print('${issue.severity.name.toUpperCase()}: ${issue.message}');
  }
}

// Check format support
final mp3Support = await validator.validateFormatSupport('mp3');
print('MP3 supported: ${mp3Support.isSupported}');

// Get platform-specific recommendations
final recommendations = validator.getOptimizationRecommendations();
for (final rec in recommendations) {
  print('${rec.category}: ${rec.title}');
  print('  ${rec.description}');
}
```

### Package Finalization

Comprehensive package validation and optimization for production:

```dart
final finalizer = PackageFinalizer();

// Run complete finalization process
final result = await finalizer.finalizePackage(
  runPerformanceTests: true,
  validatePlatforms: true,
  generateDocumentation: true,
  optimizeForProduction: true,
);

print('Ready for publication: ${result.isReady}');
print('Issues: ${result.issues.length}');
print('Warnings: ${result.warnings.length}');

if (!result.isReady) {
  for (final issue in result.criticalIssues) {
    print('CRITICAL: ${issue.message}');
  }
}
```

### Memory Management

```dart
// Initialize with memory limits
Sonix.initialize(
  memoryLimit: 50 * 1024 * 1024, // 50MB
  maxWaveformCacheSize: 50,
  maxAudioDataCacheSize: 20,
);

// Monitor resource usage
final stats = Sonix.getResourceStatistics();
print('Memory usage: ${stats.memoryUsagePercentage * 100}%');

// Advanced memory management
final memoryManager = MemoryManager();
memoryManager.initialize(memoryLimit: 100 * 1024 * 1024);

// Get quality reduction suggestions under memory pressure
final suggestion = memoryManager.getSuggestedQualityReduction();
if (suggestion.shouldReduce) {
  print('Reduce resolution to: ${(suggestion.resolutionReduction * 100).toStringAsFixed(0)}%');
  print('Enable streaming: ${suggestion.enableStreaming}');
}

// Clean up when needed
await Sonix.forceCleanup();
```

### Best Practices

1. **Use appropriate resolution**: Higher resolution = more memory usage
2. **Enable caching**: Use `generateWaveformCached()` for frequently accessed files
3. **Stream large files**: Use `generateWaveformStream()` for files > 50MB
4. **Dispose resources**: Call `dispose()` on WaveformData when no longer needed
5. **Monitor memory**: Check `getResourceStatistics()` in memory-constrained environments
6. **Profile in production**: Use `PerformanceProfiler` to identify bottlenecks
7. **Validate platforms**: Use `PlatformValidator` for cross-platform compatibility
8. **Optimize automatically**: Use `PerformanceOptimizer` for adaptive performance tuning

### Platform-Specific Considerations

#### Android
- Minimum API level 21 (Android 5.0)
- Native libraries are automatically included in APK
- ProGuard/R8 rules are included automatically

#### iOS
- Minimum iOS version 11.0
- Native libraries are statically linked
- No additional configuration required

#### Desktop (Windows/macOS/Linux)
- Native libraries are bundled with the application
- No runtime dependencies required
- Automatic platform detection and library loading

## Supported Audio Formats

| Format | Extension | Decoder Library | License |
|--------|-----------|----------------|---------|
| MP3 | .mp3 | minimp3 | CC0/Public Domain |
| WAV | .wav | dr_wav | MIT/Public Domain |
| FLAC | .flac | dr_flac | MIT/Public Domain |
| OGG Vorbis | .ogg | stb_vorbis | MIT/Public Domain |
| Opus | .opus | libopus | BSD 3-Clause |

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Run `flutter pub get`
3. Run tests: `flutter test`
4. Run example: `cd example && flutter run`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://pub.dev/documentation/sonix/latest/)
- 🐛 [Issue Tracker](https://github.com/your-repo/sonix/issues)
- 💬 [Discussions](https://github.com/your-repo/sonix/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes.
