# Sonix - Flutter Audio Waveform Package

A comprehensive Flutter package for generating and displaying audio waveforms with isolate-based processing to prevent UI thread blocking. Sonix supports multiple audio formats (MP3, OGG, WAV, FLAC, Opus) using native C libraries through Dart FFI for optimal performance.

[![pub package](https://img.shields.io/pub/v/sonix.svg)](https://pub.dev/packages/sonix)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

🔄 **Isolate-Based Processing**: All audio processing runs in background isolates to keep UI responsive  
✨ **Multi-format Support**: MP3, OGG, WAV, FLAC, and Opus audio formats  
🚀 **High Performance**: Native C libraries via Dart FFI (no FFMPEG dependency)  
🎨 **Extensive Customization**: Colors, gradients, styles, and animations  
� **\*Interactive Playback**: Real-time position visualization and seeking  
� **Insstance-Based API**: Modern API with proper resource management  
� **Easyi Integration**: Simple API with comprehensive error handling  
📊 **Multiple Algorithms**: RMS, Peak, Average, and Median downsampling  
🎯 **Optimized Presets**: Ready-to-use configurations for different use cases

## Getting Started

### Installation

Add Sonix to your `pubspec.yaml`:

```yaml
dependencies:
  sonix: <latest>
```

Then run:

```bash
flutter pub get
```

### FFMPEG Setup

Sonix uses FFMPEG for audio decoding. You need to install FFMPEG binaries in your Flutter app to use Sonix.

#### Automated Setup (Recommended)

**Required Step**: Use our automated setup tool to download and install FFMPEG binaries:

```bash
# From your Flutter app's root directory
dart run sonix:setup_ffmpeg_for_app

# Verify installation
dart run sonix:setup_ffmpeg_for_app --verify
```

This tool will:

- ✅ Automatically detect your platform
- ✅ Download compatible FFMPEG binaries from trusted sources  
- ✅ Install them to your app's build directories
- ✅ Validate the installation
- ✅ Enable Sonix to work with FFMPEG in your app

**Requirements:**
- Run from your Flutter app's root directory (where pubspec.yaml is located)
- Sonix must be added as a dependency in your pubspec.yaml

#### Supported Platforms

- ✅ Android (API 21+) - _FFMPEG binaries included in APK_
- ✅ iOS (11.0+) - _FFMPEG binaries statically linked_
- ✅ Windows (Windows 10+) - _Requires FFMPEG DLLs_
- ✅ macOS (10.14+) - _Requires FFMPEG dylibs_
- ✅ Linux (Ubuntu 18.04+) - _Requires FFMPEG shared objects_

#### Manual Installation (Advanced)

If you prefer to install FFMPEG binaries manually, place them in your Flutter build directory:

- **Windows**: `build/windows/x64/runner/Debug/`
- **macOS**: `build/macos/Build/Products/Debug/`
- **Linux**: `build/linux/x64/debug/bundle/lib/`

Required FFMPEG libraries: `avformat`, `avcodec`, `avutil`, `swresample`

## Quick Start

### Basic Waveform Generation

```dart
import 'package:sonix/sonix.dart';

// Create a Sonix instance
final sonix = Sonix();

// Generate waveform from audio file (processed in background isolate)
final waveformData = await sonix.generateWaveform('path/to/audio.mp3');

// Display the waveform
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.soundCloud,
)

// Clean up when done
await sonix.dispose();
```

### With Playback Position

```dart
class AudioPlayer extends StatefulWidget {
  @override
  _AudioPlayerState createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer> {
  late Sonix sonix;
  WaveformData? waveformData;
  double playbackPosition = 0.0;

  @override
  void initState() {
    super.initState();
    sonix = Sonix(SonixConfig.mobile()); // Optimized for mobile
  }

  @override
  void dispose() {
    sonix.dispose();
    super.dispose();
  }

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

// Custom style with gradient
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.filledGradient(
    startColor: Colors.blue,
    endColor: Colors.purple,
    height: 100,
  ),
)

// Professional audio editor style
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.professional,
)
```

### 2. Instance Configuration

```dart
// Mobile-optimized configuration
final mobileSonix = Sonix(SonixConfig.mobile());

// Desktop-optimized configuration
final desktopSonix = Sonix(SonixConfig.desktop());

// Custom configuration
final customSonix = Sonix(SonixConfig(
  maxConcurrentOperations: 2,
  isolatePoolSize: 1,
  maxMemoryUsage: 50 * 1024 * 1024, // 50MB
  enableProgressReporting: true,
));
```

### 3. Optimal Configuration for Use Cases

```dart
// Get optimal config for specific use cases
final musicConfig = Sonix.getOptimalConfig(
  useCase: WaveformUseCase.musicVisualization,
  customResolution: 2000,
);

final podcastConfig = Sonix.getOptimalConfig(
  useCase: WaveformUseCase.podcastPlayer,
);

final editorConfig = Sonix.getOptimalConfig(
  useCase: WaveformUseCase.audioEditor,
  customResolution: 5000, // High detail for editing
);

// Use with instance
final sonix = Sonix();
final waveformData = await sonix.generateWaveform(
  'music.mp3',
  config: musicConfig,
);
```

### 4. Resource Management

```dart
// Check resource usage
final sonix = Sonix();
final stats = sonix.getResourceStatistics();
print('Active isolates: ${stats.activeIsolates}');
print('Completed tasks: ${stats.completedTasks}');

// Optimize resources when needed
sonix.optimizeResources();

// Cancel operations if needed
final activeOps = sonix.getActiveOperations();
for (final opId in activeOps) {
  sonix.cancelOperation(opId);
}

// Always dispose when done
await sonix.dispose();
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
final sonix = Sonix();

try {
  final waveformData = await sonix.generateWaveform('audio.mp3');
  // Use waveformData
} on UnsupportedFormatException catch (e) {
  print('Unsupported format: ${e.format}');
  print('Supported formats: ${Sonix.getSupportedFormats()}');
} on DecodingException catch (e) {
  print('Decoding failed: ${e.message}');
} on FileSystemException catch (e) {
  print('File access error: ${e.message}');
} finally {
  await sonix.dispose();
}
```

## API Reference

### Main API Class

#### `Sonix`

The main entry point for generating waveforms. This is an instance-based class that manages background isolates for processing.

**Constructor:**

- `Sonix([SonixConfig? config])` - Create a new instance with optional configuration

**Instance Methods:**

- `generateWaveform(String filePath, {...})` → `Future<WaveformData>`
- `getResourceStatistics()` → `IsolateStatistics`
- `optimizeResources()` → `void`
- `cancelOperation(String taskId)` → `bool`
- `cancelAllOperations()` → `int`
- `getActiveOperations()` → `List<String>`
- `dispose()` → `Future<void>`

**Static Utility Methods:**

- `isFormatSupported(String filePath)` → `bool`
- `getSupportedFormats()` → `List<String>`
- `getSupportedExtensions()` → `List<String>`
- `isExtensionSupported(String extension)` → `bool`
- `getOptimalConfig({required WaveformUseCase useCase, ...})` → `WaveformConfig`

### Configuration

#### `SonixConfig`

Configuration options for Sonix instances.

**Factory Constructors:**

- `SonixConfig.defaultConfig()` - Default configuration
- `SonixConfig.mobile()` - Optimized for mobile devices
- `SonixConfig.desktop()` - Optimized for desktop devices

**Properties:**

- `maxConcurrentOperations`: Maximum concurrent operations
- `isolatePoolSize`: Size of the isolate pool
- `isolateIdleTimeout`: Timeout for idle isolates
- `maxMemoryUsage`: Maximum memory usage in bytes
- `enableProgressReporting`: Whether to enable progress reporting

### Widgets

#### `WaveformWidget`

Interactive waveform display with playback position and seeking.

**Properties:**

- `waveformData` (required): The waveform data to display
- `playbackPosition`: Current playback position (0.0 to 1.0)
- `style`: Customization options (WaveformStyle)
- `onTap`: Callback when user taps the widget
- `onSeek`: Callback when user seeks to a position
- `enableSeek`: Whether to enable touch interaction
- `animationDuration`: Duration for position animations
- `animationCurve`: Animation curve for transitions

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

- `soundCloud`: SoundCloud-inspired orange and grey bars
- `spotify`: Spotify-inspired green and grey bars
- `minimalLine`: Minimal line-style waveform
- `retro`: Vintage style with rounded bars and warm colors
- `compact`: Compact mobile-friendly style
- `podcast`: Optimized for podcast/speech content
- `professional`: Clean style for professional audio applications
- `filledGradient({Color startColor, Color endColor, double height})`: Filled waveform with customizable gradient
- `glassEffect({Color accentColor, double height})`: Modern glass-like effect
- `neonGlow({Color glowColor, double height})`: Glowing neon effect with shadows

## Performance & Monitoring

Sonix includes performance monitoring and optimization tools for production applications.

### Resource Monitoring

Monitor isolate performance and resource usage:

```dart
final sonix = Sonix();

// Get current resource statistics
final stats = sonix.getResourceStatistics();
print('Active isolates: ${stats.activeIsolates}');
print('Completed tasks: ${stats.completedTasks}');
print('Failed tasks: ${stats.failedTasks}');
print('Average processing time: ${stats.averageProcessingTime}ms');

// Optimize resources when needed
sonix.optimizeResources();
```

### Performance Profiling

Profile operations to identify bottlenecks:

```dart
final profiler = PerformanceProfiler();

// Profile waveform generation
final result = await profiler.profile('waveform_generation', () async {
  final sonix = Sonix();
  final waveformData = await sonix.generateWaveform('audio.mp3');
  await sonix.dispose();
  return waveformData;
});

print('Processing took: ${result.duration.inMilliseconds}ms');
print('Memory used: ${result.memoryUsage}MB');

// Generate performance report
final report = profiler.generateReport();
print(report.toString());
```

### Platform Validation

Validate platform compatibility:

```dart
final validator = PlatformValidator();

// Validate current platform
final validation = await validator.validatePlatform();
print('Platform supported: ${validation.isSupported}');

// Check specific format support
final mp3Support = await validator.validateFormatSupport('mp3');
print('MP3 supported: ${mp3Support.isSupported}');

// Get optimization recommendations
final recommendations = validator.getOptimizationRecommendations();
for (final rec in recommendations) {
  print('${rec.category}: ${rec.title}');
}
```

### Best Practices

1. **Use appropriate configuration**: Choose `SonixConfig.mobile()` or `SonixConfig.desktop()` based on your target platform
2. **Dispose instances**: Always call `dispose()` on Sonix instances when done to clean up isolates
3. **Monitor resources**: Use `getResourceStatistics()` to monitor isolate performance
4. **Handle errors**: Wrap operations in try-catch blocks for proper error handling
5. **Use optimal configs**: Use `Sonix.getOptimalConfig()` for different use cases
6. **Cancel when needed**: Cancel long-running operations with `cancelOperation()` if user navigates away
7. **Profile performance**: Use `PerformanceProfiler` to identify bottlenecks in production
8. **Validate formats**: Check `Sonix.isFormatSupported()` before processing files

### Platform-Specific Considerations

#### Android

- Minimum API level 21 (Android 5.0)
- FFMPEG binaries are automatically included in APK during build
- Isolate processing works seamlessly on all Android versions

#### iOS

- Minimum iOS version 11.0
- FFMPEG binaries are statically linked during build
- Background isolates work within iOS app lifecycle constraints

#### Desktop (Windows/macOS/Linux)

- FFMPEG binaries must be present in build directory (use download tool)
- Full isolate pool support for maximum performance
- Runtime loading of FFMPEG libraries from build directory

#### Troubleshooting FFMPEG Setup

If you encounter issues with FFMPEG binaries:

```bash
# Check if binaries are properly installed
dart run sonix:setup_ffmpeg_for_app --verify

# Force reinstall if needed
dart run sonix:setup_ffmpeg_for_app --force

# Remove FFMPEG binaries
dart run sonix:setup_ffmpeg_for_app --clean

# Get help and see all options
dart run sonix:setup_ffmpeg_for_app --help
```

Common issues:

- **"FFMPEG libraries not found"**: Run the download tool to install binaries
- **"Unsupported platform"**: Check supported platforms list above
- **"Binary validation failed"**: Try force reinstalling with `--force` flag

## Supported Audio Formats

Sonix supports multiple audio formats through FFMPEG integration:

| Format     | Extension  | Decoder Backend | Notes                    |
| ---------- | ---------- | --------------- | ------------------------ |
| MP3        | .mp3       | FFMPEG          | Most common audio format |
| WAV        | .wav       | FFMPEG          | Uncompressed audio       |
| FLAC       | .flac      | FFMPEG          | Lossless compression     |
| OGG Vorbis | .ogg       | FFMPEG          | Open source format       |
| Opus       | .opus      | FFMPEG          | Modern codec             |
| MP4/AAC    | .mp4, .m4a | FFMPEG          | Container with AAC       |

**Note**: All audio decoding is handled by FFMPEG libraries. Ensure FFMPEG binaries are installed using the provided download tool.

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Run `flutter pub get`
3. **Install FFMPEG binaries for development**: `dart run tools/download_ffmpeg_binaries.dart`
4. Run tests: `flutter test`
5. Run example: `cd example && flutter run`

**Note for Contributors**: Use `tools/download_ffmpeg_binaries.dart` for package development. End users should use `dart run sonix:setup_ffmpeg_for_app` in their own apps.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://pub.dev/documentation/sonix/latest/)
- 🐛 [Issue Tracker](https://github.com/your-repo/sonix/issues)
- 💬 [Discussions](https://github.com/your-repo/sonix/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes.
