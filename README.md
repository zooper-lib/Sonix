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

// Clean up when needed
await Sonix.forceCleanup();
```

### Best Practices

1. **Use appropriate resolution**: Higher resolution = more memory usage
2. **Enable caching**: Use `generateWaveformCached()` for frequently accessed files
3. **Stream large files**: Use `generateWaveformStream()` for files > 50MB
4. **Dispose resources**: Call `dispose()` on WaveformData when no longer needed
5. **Monitor memory**: Check `getResourceStatistics()` in memory-constrained environments

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
