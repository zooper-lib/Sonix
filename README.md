# Sonix - Flutter Audio Waveform Package

A comprehensive Flutter package for generating and displaying audio waveforms with isolate-based processing to prevent UI thread blocking. Sonix supports multiple audio formats (MP3, OGG, WAV, FLAC, Opus) using native C libraries through Dart FFI for optimal performance.

[![pub package](https://img.shields.io/pub/v/sonix.svg)](https://pub.dev/packages/sonix)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

🔄 **Isolate-Based Processing**: All audio processing runs in background isolates to keep UI responsive  
✨ **Multi-format Support**: MP3, OGG, WAV, FLAC, and Opus audio formats  
🚀 **High Performance**: Native C libraries via Dart FFI with FFmpeg-based decoding  
🎨 **Extensive Customization**: Colors, gradients, styles, and animations  
🎚️ **Interactive Playback**: Real-time position visualization and seeking  
📦 **Instance-Based API**: Modern API with proper resource management  
✅ **Easy Integration**: Simple API with comprehensive error handling  
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

Note: Sonix includes the plugin glue code and native wrapper sources. Desktop platforms require FFmpeg installed on the system. The Flutter toolchain builds and bundles the plugin artifacts automatically; you should not need to compile C code manually for typical usage.

### FFmpeg setup

Sonix uses FFmpeg for audio decoding. For desktop platforms, you must install FFmpeg on the system. Mobile platforms do not require a separate FFmpeg install.

Recommended installation methods:

- macOS: Homebrew
  - Install: `brew install ffmpeg`
  - Verify: `ffmpeg -version`
- Linux: Your distro’s package manager
  - Debian/Ubuntu: `sudo apt install ffmpeg`
  - Fedora: `sudo dnf install ffmpeg`
  - Arch: `sudo pacman -S ffmpeg`
- Windows: Install FFmpeg and ensure the DLLs are on PATH or co-located next to your app’s executable
  - Options: winget, chocolatey, or manual install from ffmpeg.org (DLLs must be discoverable at runtime)
  - Verify: `ffmpeg -version`

#### Supported platforms

- ✅ Android (API 21+)
- ✅ iOS (11.0+)
- ✅ Windows (Windows 10+) - requires FFmpeg DLLs
- ✅ macOS (10.15+) - requires FFmpeg dylibs
- ✅ Linux (Ubuntu 18.04+) - requires FFmpeg shared objects

#### Advanced (manual placement)

Desktop apps can also load FFmpeg when the libraries are placed alongside the app at runtime:

- Windows: place FFmpeg DLLs next to the app’s exe (or ensure they are on PATH)
- Linux: place `.so` files under the app’s `lib` directory
- macOS: prefer system-installed FFmpeg; bundling FFmpeg into an app may have licensing implications

Required FFmpeg libraries: `avformat`, `avcodec`, `avutil`, `swresample`

## Quick Start

### Basic Waveform Generation

```dart
import 'package:sonix/sonix.dart';

// Create a Sonix instance
final sonix = Sonix();

// Generate waveform in background isolate (recommended for UI apps)
final waveformData = await sonix.generateWaveformInIsolate('path/to/audio.mp3');

// Or generate on main thread (simpler, but blocks the thread)
// final waveformData = await sonix.generateWaveform('path/to/audio.mp3');

// Display the waveform
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.soundCloud,
)

// Clean up when done
sonix.dispose();
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
// Mobile-optimized configuration (lower memory limit)
final mobileSonix = Sonix(SonixConfig.mobile());

// Desktop-optimized configuration (higher memory limit)
final desktopSonix = Sonix(SonixConfig.desktop());

// Custom configuration
final customSonix = Sonix(SonixConfig(
  maxMemoryUsage: 50 * 1024 * 1024, // 50MB
  logLevel: 2, // ERROR level
));
```

### 3. WaveformConfig presets

```dart
// Create a config tuned for your UI
const musicConfig = WaveformConfig(
  resolution: 2000,
  algorithm: DownsamplingAlgorithm.rms,
  normalize: true,
  scalingCurve: ScalingCurve.logarithmic,
  enableSmoothing: true,
  smoothingWindowSize: 5,
);

const podcastConfig = WaveformConfig(
  resolution: 1500,
  algorithm: DownsamplingAlgorithm.rms,
  normalize: true,
  scalingCurve: ScalingCurve.linear,
  enableSmoothing: false,
);

const editorConfig = WaveformConfig(
  resolution: 5000, // High detail for editing
  algorithm: DownsamplingAlgorithm.peak,
  normalize: true,
  scalingCurve: ScalingCurve.linear,
  enableSmoothing: false,
);

// Use with instance
final sonix = Sonix();
final waveformData = await sonix.generateWaveform(
  'music.mp3',
  config: musicConfig,
);
```

If you prefer a quick preset helper:

```dart
final musicConfig = Sonix.getOptimalConfig(
  useCase: WaveformUseCase.musicVisualization,
  customResolution: 2000,
);
```

### Checking FFmpeg availability

```dart
final ffmpegOk = Sonix.isFFmpegAvailable();
if (!ffmpegOk) {
  // Show instructions to install/ship FFmpeg for the current platform.
}
```

### 4. Pre-generated Waveform Data

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

### 5. Error Handling

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
  sonix.dispose();
}
```

## API Reference

### Main API Class

#### `Sonix`

The main entry point for generating waveforms. This is an instance-based class that manages background isolates for processing.

**Constructor:**

- `Sonix([SonixConfig? config])` - Create a new instance with optional configuration

**Instance Methods:**

- `generateWaveform(String filePath, {...})` → `Future<WaveformData>` - Process on main thread
- `generateWaveformInIsolate(String filePath, {...})` → `Future<WaveformData>` - Process in background isolate (recommended for UI apps)
- `dispose()` → `void` - Clean up resources

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

- `maxMemoryUsage`: Maximum memory usage in bytes
- `logLevel`: FFmpeg log level (0-6, default 2 for ERROR)

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

Sonix includes performance monitoring tools for production applications.

### Performance Profiling

Profile operations to identify bottlenecks:

```dart
final profiler = PerformanceProfiler();

// Profile waveform generation
final result = await profiler.profile('waveform_generation', () async {
  final sonix = Sonix();
  final waveformData = await sonix.generateWaveform('audio.mp3');
  sonix.dispose();
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
2. **Dispose instances**: Always call `dispose()` on Sonix instances when done
3. **Handle errors**: Wrap operations in try-catch blocks for proper error handling
4. **Use a config**: Pass a `WaveformConfig` tuned for your UI
5. **Profile performance**: Use `PerformanceProfiler` to identify bottlenecks in production
6. **Validate formats**: Check `Sonix.isFormatSupported()` before processing files
7. **Use isolate for UI apps**: Prefer `generateWaveformInIsolate()` in Flutter apps to keep UI responsive

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

- macOS/Linux: Use system FFmpeg installed via your package manager (no bundling)
- Windows: Provide FFmpeg DLLs via PATH or next to the app executable
- Background isolate processing for UI responsiveness
- Runtime loading of FFmpeg libraries

#### Troubleshooting FFmpeg setup

If you encounter issues with FFmpeg:

```bash
# Check installation
ffmpeg -version

# On macOS (Homebrew): reinstall
brew reinstall ffmpeg

# On Linux: use your distro package manager to reinstall
# e.g., Ubuntu/Debian
sudo apt --reinstall install ffmpeg
```

Common issues:

- "FFmpeg libraries not found": Install FFmpeg using your system package manager
- "Unsupported platform": Check supported platforms list above

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

**Note**: All audio decoding is handled by FFmpeg libraries. Ensure FFmpeg is installed on the system for desktop platforms.

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Run `flutter pub get`
3. Install system FFmpeg (desktop dev machines)
  - macOS: `brew install ffmpeg`
  - Linux: `sudo apt install ffmpeg` (or your distro equivalent)
  - Windows: install FFmpeg and ensure DLLs are available on PATH
4. Build native library for testing: `dart run tool/build_native_for_development.dart`
5. Run tests: `flutter test`
6. Run example: `cd example && flutter run`

**Note for Contributors**:
- Use `dart run tool/build_native_for_development.dart` for quick development builds
- Use `dart run tool/build_native_for_distribution.dart` for release builds
- Desktop users must install FFmpeg via their system package manager

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://pub.dev/documentation/sonix/latest/)
- 🐛 [Issue Tracker](https://github.com/your-repo/sonix/issues)
- 💬 [Discussions](https://github.com/your-repo/sonix/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes.
