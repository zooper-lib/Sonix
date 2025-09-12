# API Reference

Complete API reference for the Sonix Flutter audio waveform package.

## Table of Contents

1. [Main API Class](#main-api-class)
2. [Data Models](#data-models)
3. [Widgets](#widgets)
4. [Configuration Classes](#configuration-classes)
5. [Style Presets](#style-presets)
6. [Exceptions](#exceptions)
7. [Utility Classes](#utility-classes)

## Main API Class

### `Sonix`

The main entry point for generating waveforms from audio files.

#### Static Methods

##### `initialize({int? memoryLimit, int maxWaveformCacheSize = 50, int maxAudioDataCacheSize = 20})`

Initialize Sonix with memory management settings.

**Parameters:**
- `memoryLimit` (optional): Maximum memory usage in bytes (default: 100MB)
- `maxWaveformCacheSize`: Maximum number of waveforms to cache (default: 50)
- `maxAudioDataCacheSize`: Maximum number of audio data to cache (default: 20)

**Example:**
```dart
Sonix.initialize(
  memoryLimit: 50 * 1024 * 1024, // 50MB
  maxWaveformCacheSize: 30,
  defaultChunkedConfig: ChunkedProcessingConfig(
    fileChunkSize: 10 * 1024 * 1024,
    maxMemoryUsage: 100 * 1024 * 1024,
    enableProgressReporting: true,
  ),
);
```

##### `generateWaveform(String filePath, {int resolution = 1000, WaveformType type = WaveformType.bars, bool normalize = true, WaveformConfig? config, bool forceTraditionalProcessing = false, bool enableAutoChunking = true, ChunkedProcessingConfig? chunkedConfig}) → Future<WaveformData>`

Generate waveform data from an audio file. Automatically uses chunked processing for large files (>50MB) unless disabled.

**Parameters:**
- `filePath`: Path to the audio file
- `resolution`: Number of data points in the waveform (default: 1000)
- `type`: Type of waveform visualization (default: bars)
- `normalize`: Whether to normalize amplitude values (default: true)
- `config`: Advanced configuration options (optional)
- `forceTraditionalProcessing`: Force v1.x processing method (default: false)
- `enableAutoChunking`: Automatically enable chunked processing for large files (default: true)
- `chunkedConfig`: Configuration for chunked processing (optional)

**Example:**
```dart
// Basic usage (automatically uses optimal processing method)
final waveform = await Sonix.generateWaveform('audio_file.mp3');

// Force traditional processing
final traditionalWaveform = await Sonix.generateWaveform(
  'audio_file.mp3',
  forceTraditionalProcessing: true,
);

// Custom chunked processing configuration
final chunkedWaveform = await Sonix.generateWaveform(
  'large_audio_file.mp3',
  chunkedConfig: ChunkedProcessingConfig(
    fileChunkSize: 20 * 1024 * 1024, // 20MB chunks
    enableProgressReporting: true,
  ),
);
```

##### `generateWaveformChunked(String filePath, {ChunkedProcessingConfig? config, WaveformConfig? waveformConfig, ProgressCallback? onProgress, Duration? seekPosition}) → Future<WaveformData>`

Generate waveform data using chunked processing for optimal memory usage and performance with large files.

**Parameters:**
- `filePath`: Path to the audio file
- `config`: Chunked processing configuration (optional)
- `waveformConfig`: Waveform generation settings (optional)
- `onProgress`: Progress callback function (optional)
- `seekPosition`: Start processing from specific time position (optional)

**Example:**
```dart
final waveform = await Sonix.generateWaveformChunked(
  'large_audio_file.mp3',
  config: ChunkedProcessingConfig(
    fileChunkSize: 10 * 1024 * 1024, // 10MB chunks
    maxMemoryUsage: 100 * 1024 * 1024, // 100MB memory limit
    enableProgressReporting: true,
  ),
  onProgress: (progress) {
    print('Progress: ${(progress.progressPercentage * 100).toStringAsFixed(1)}%');
    if (progress.estimatedTimeRemaining != null) {
      print('ETA: ${progress.estimatedTimeRemaining!.inSeconds} seconds');
    }
  },
);
```

##### `generateWaveformStream(String filePath, {ChunkedProcessingConfig? config, WaveformConfig? waveformConfig}) → Stream<WaveformChunk>`

Generate waveform data as a stream of chunks for real-time processing and display.

**Parameters:**
- `filePath`: Path to the audio file
- `config`: Chunked processing configuration (optional)
- `waveformConfig`: Waveform generation settings (optional)

**Returns:** Stream of `WaveformChunk` objects containing partial waveform data.

**Example:**
```dart
await for (final waveformChunk in Sonix.generateWaveformStream('audio_file.mp3')) {
  // Update UI with streaming waveform data
  updateWaveformDisplay(waveformChunk);
  
  if (waveformChunk.isLast) {
    print('Waveform generation complete');
  }
}
```

##### `seekAndGenerateWaveform(String filePath, Duration startTime, Duration duration, {ChunkedProcessingConfig? config, WaveformConfig? waveformConfig}) → Future<WaveformData>`

Generate waveform for a specific time range without processing the entire file.

**Parameters:**
- `filePath`: Path to the audio file
- `startTime`: Start time position
- `duration`: Duration of audio to process
- `config`: Chunked processing configuration (optional)
- `waveformConfig`: Waveform generation settings (optional)

**Example:**
```dart
// Generate waveform for 30 seconds starting at 2 minutes
final waveform = await Sonix.seekAndGenerateWaveform(
  'long_audio_file.mp3',
  Duration(minutes: 2),
  Duration(seconds: 30),
);
```

##### `getChunkedProcessingStats() → ChunkedProcessingStats`

Get current statistics about chunked processing operations.

**Returns:** `ChunkedProcessingStats` object with current processing information.

**Example:**
```dart
final stats = Sonix.getChunkedProcessingStats();
print('Active chunks: ${stats.activeChunks}');
print('Memory usage: ${stats.currentMemoryUsage} bytes');
print('Processing queue size: ${stats.queueSize}');
```

**Returns:** `Future<WaveformData>` containing amplitude values and metadata

**Throws:**
- `UnsupportedFormatException` if the audio format is not supported
- `DecodingException` if audio decoding fails
- `FileSystemException` if the file cannot be accessed

**Example:**
```dart
final waveformData = await Sonix.generateWaveform(
  'audio.mp3',
  resolution: 500,
  normalize: true,
);
```

##### `generateWaveformStream(String filePath, {int resolution = 1000, WaveformType type = WaveformType.bars, bool normalize = true, int chunkSize = 100, WaveformConfig? config}) → Stream<WaveformChunk>`

Generate waveform data using streaming processing for memory efficiency.

**Parameters:**
- `filePath`: Path to the audio file
- `resolution`: Number of data points in the waveform (default: 1000)
- `type`: Type of waveform visualization (default: bars)
- `normalize`: Whether to normalize amplitude values (default: true)
- `chunkSize`: Size of each output chunk in data points (default: 100)
- `config`: Advanced configuration options (optional)

**Returns:** `Stream<WaveformChunk>` that emits waveform data chunks

**Example:**
```dart
await for (final chunk in Sonix.generateWaveformStream('large_audio.mp3')) {
  print('Received chunk with ${chunk.amplitudes.length} data points');
}
```

##### `generateWaveformMemoryEfficient(String filePath, {int resolution = 1000, WaveformType type = WaveformType.bars, bool normalize = true, int maxMemoryUsage = 50 * 1024 * 1024, WaveformConfig? config}) → Future<WaveformData>`

Generate waveform with memory-efficient processing for large files.

**Parameters:**
- `filePath`: Path to the audio file
- `resolution`: Number of data points in the waveform (default: 1000)
- `type`: Type of waveform visualization (default: bars)
- `normalize`: Whether to normalize amplitude values (default: true)
- `maxMemoryUsage`: Maximum memory usage in bytes (default: 50MB)
- `config`: Advanced configuration options (optional)

**Example:**
```dart
final waveformData = await Sonix.generateWaveformMemoryEfficient(
  'large_audio.wav',
  maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
);
```

##### `generateWaveformCached(String filePath, {int resolution = 1000, WaveformType type = WaveformType.bars, bool normalize = true, WaveformConfig? config, bool useCache = true}) → Future<WaveformData>`

Generate waveform with automatic caching and memory management.

**Example:**
```dart
final waveformData = await Sonix.generateWaveformCached('audio.mp3');
```

##### `generateWaveformAdaptive(String filePath, {int resolution = 1000, WaveformType type = WaveformType.bars, bool normalize = true, WaveformConfig? config}) → Future<WaveformData>`

Generate waveform with adaptive quality based on file size.

**Example:**
```dart
final waveformData = await Sonix.generateWaveformAdaptive('any_size_audio.wav');
```

##### `getSupportedFormats() → List<String>`

Get a list of supported audio format names.

**Returns:** List of human-readable format names (e.g., ['MP3', 'WAV', 'FLAC'])

**Example:**
```dart
final formats = Sonix.getSupportedFormats();
print('Supported formats: ${formats.join(', ')}');
```

##### `getSupportedExtensions() → List<String>`

Get a list of supported file extensions.

**Returns:** List of file extensions (e.g., ['mp3', 'wav', 'flac'])

##### `isFormatSupported(String filePath) → bool`

Check if a specific audio format is supported.

**Parameters:**
- `filePath`: Path to the audio file or just the filename with extension

**Returns:** `true` if the format is supported, `false` otherwise

**Example:**
```dart
if (Sonix.isFormatSupported('audio.mp3')) {
  // Process the file
}
```

##### `getOptimalConfig({required WaveformUseCase useCase, int? customResolution}) → WaveformConfig`

Get optimal configuration for different use cases.

**Parameters:**
- `useCase`: The intended use case for the waveform
- `customResolution`: Override the default resolution for the use case

**Returns:** `WaveformConfig` optimized for the specified use case

**Example:**
```dart
final config = Sonix.getOptimalConfig(
  useCase: WaveformUseCase.musicVisualization,
  customResolution: 2000,
);
```

##### `getResourceStatistics() → ResourceStatistics`

Get memory and resource usage statistics.

**Returns:** Detailed information about current memory usage and cache statistics

##### `forceCleanup() → Future<void>`

Force cleanup of all cached resources and memory.

##### `dispose() → Future<void>`

Dispose of all Sonix resources. Call when shutting down your application.

## Data Models

### Chunked Processing Models

#### `ChunkedProcessingConfig`

Configuration class for chunked audio processing.

```dart
class ChunkedProcessingConfig {
  final int fileChunkSize;              // Size of file chunks in bytes (default: 10MB)
  final int maxMemoryUsage;             // Maximum memory usage in bytes (default: 100MB)
  final int maxConcurrentChunks;        // Maximum concurrent chunk processing (default: 3)
  final bool enableSeeking;             // Enable seeking capabilities (default: true)
  final bool enableProgressReporting;   // Enable progress callbacks (default: true)
  final Duration progressUpdateInterval; // Progress update frequency (default: 100ms)
  final ErrorRecoveryStrategy errorRecoveryStrategy; // Error recovery strategy
  final int maxRetries;                 // Maximum retry attempts (default: 3)
  final Duration retryDelay;            // Delay between retries (default: 100ms)
  
  // Factory constructors
  ChunkedProcessingConfig.forFileSize(int fileSize);  // Optimal config for file size
  ChunkedProcessingConfig.forPlatform();              // Platform-optimized config
}
```

#### `ProgressInfo`

Progress information provided to progress callbacks.

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

Partial waveform data from streaming generation.

```dart
class WaveformChunk {
  final List<double> amplitudes;        // Amplitude values for this chunk
  final int startSample;                // Starting sample position
  final bool isLast;                    // Whether this is the final chunk
  final Duration? timeOffset;           // Time offset of this chunk
  final WaveformMetadata? metadata;     // Optional metadata
}
```

#### `ChunkedProcessingStats`

Statistics about current chunked processing operations.

```dart
class ChunkedProcessingStats {
  final int activeChunks;               // Number of active chunks
  final int currentMemoryUsage;         // Current memory usage in bytes
  final int queueSize;                  // Processing queue size
  final double averageChunkTime;        // Average chunk processing time in ms
  final double throughputMBps;          // Processing throughput in MB/s
}
```

### Core Data Models

### `WaveformData`

Contains processed waveform data and metadata.

#### Properties

- `amplitudes`: `List<double>` - Amplitude values for each data point (0.0 to 1.0)
- `duration`: `Duration` - Duration of the original audio
- `sampleRate`: `int` - Sample rate of the original audio
- `metadata`: `WaveformMetadata` - Metadata about the waveform generation

#### Methods

##### `toJson() → Map<String, dynamic>`

Convert to JSON for serialization.

##### `fromJson(Map<String, dynamic> json) → WaveformData`

Create from JSON.

##### `fromAmplitudes(List<double> amplitudes) → WaveformData`

Create from pre-generated amplitude data (simplified for display only).

**Example:**
```dart
final amplitudes = [0.1, 0.5, 0.8, 0.3, 0.7];
final waveformData = WaveformData.fromAmplitudes(amplitudes);
```

##### `fromJsonString(String jsonString) → WaveformData`

Create from JSON string.

##### `toJsonString() → String`

Convert to JSON string.

##### `dispose()`

Dispose of resources for memory management.

### `WaveformChunk`

Represents a chunk of waveform data for streaming processing.

#### Properties

- `amplitudes`: `List<double>` - Amplitude values in this chunk
- `startTime`: `Duration` - Starting time offset for this chunk
- `isLast`: `bool` - Whether this is the last chunk in the stream

### `WaveformMetadata`

Metadata about waveform generation.

#### Properties

- `resolution`: `int` - Resolution (number of data points)
- `type`: `WaveformType` - Type of waveform visualization
- `normalized`: `bool` - Whether the data has been normalized
- `generatedAt`: `DateTime` - When the waveform was generated

## Widgets

### `WaveformWidget`

Interactive waveform display with playback position and seeking.

#### Properties

- `waveformData`: `WaveformData` (required) - The waveform data to display
- `playbackPosition`: `double?` - Current playback position (0.0 to 1.0)
- `style`: `WaveformStyle` - Customization options (default: `WaveformStyle()`)
- `onTap`: `VoidCallback?` - Callback when the waveform is tapped
- `onSeek`: `Function(double)?` - Callback when user seeks to a position
- `animationDuration`: `Duration` - Duration for smooth position transitions (default: 150ms)
- `animationCurve`: `Curve` - Animation curve for position transitions (default: `Curves.easeInOut`)
- `enableSeek`: `bool` - Whether to enable touch interaction for seeking (default: true)

**Example:**
```dart
WaveformWidget(
  waveformData: waveformData,
  playbackPosition: 0.3, // 30% played
  style: WaveformStylePresets.soundCloud,
  onSeek: (position) {
    // Handle seek to position
  },
)
```

### `StaticWaveformWidget`

Simplified waveform display without playback features.

#### Properties

- `waveformData`: `WaveformData` (required) - The waveform data to display
- `style`: `WaveformStyle` - Customization options (default: `WaveformStyle()`)
- `onTap`: `VoidCallback?` - Callback when the waveform is tapped

**Example:**
```dart
StaticWaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.professional,
)
```

## Configuration Classes

### `WaveformStyle`

Customization options for waveform appearance.

#### Properties

- `playedColor`: `Color` - Color for played portion (default: `Colors.blue`)
- `unplayedColor`: `Color` - Color for unplayed portion (default: `Colors.grey`)
- `backgroundColor`: `Color` - Background color (default: `Colors.transparent`)
- `height`: `double` - Height of the waveform (default: 100.0)
- `barWidth`: `double` - Width of bars for bar-type waveforms (default: 2.0)
- `barSpacing`: `double` - Spacing between bars (default: 1.0)
- `borderRadius`: `BorderRadius?` - Border radius for rounded corners
- `gradient`: `Gradient?` - Optional gradient overlay
- `type`: `WaveformType` - Visualization type (default: `WaveformType.bars`)
- `margin`: `EdgeInsets` - Margin around the waveform (default: `EdgeInsets.zero`)
- `border`: `Border?` - Border around the waveform
- `boxShadow`: `List<BoxShadow>?` - Shadow effects

**Example:**
```dart
WaveformStyle(
  playedColor: Colors.blue,
  unplayedColor: Colors.grey.shade300,
  height: 80,
  type: WaveformType.filled,
  gradient: LinearGradient(
    colors: [Colors.blue, Colors.purple],
  ),
)
```

### `WaveformConfig`

Advanced configuration options for waveform generation.

#### Properties

- `resolution`: `int` - Number of data points in the waveform
- `algorithm`: `DownsamplingAlgorithm` - Algorithm for downsampling
- `normalize`: `bool` - Whether to normalize amplitude values
- `type`: `WaveformType` - Type of waveform visualization
- `useCase`: `WaveformUseCase` - Intended use case for optimization

### Enums

#### `WaveformType`

Types of waveform visualization:
- `bars` - Classic bar-style waveform
- `line` - Continuous line waveform
- `filled` - Filled/solid waveform

#### `DownsamplingAlgorithm`

Algorithms for processing audio data:
- `rms` - Root Mean Square (best balance of quality/speed)
- `peak` - Peak detection (fastest)
- `average` - Average values (good quality)
- `median` - Median values (highest quality, slowest)

#### `WaveformUseCase`

Predefined use cases for optimization:
- `musicVisualization` - Optimized for music playback
- `podcastVisualization` - Optimized for speech content
- `audioEditing` - High precision for editing applications
- `thumbnailGeneration` - Low resolution for thumbnails
- `realtimeVisualization` - Optimized for real-time display

## Style Presets

### `WaveformStylePresets`

Pre-configured styles for common use cases.

#### Static Properties

##### `soundCloud`

SoundCloud-inspired orange and grey style.

##### `spotify`

Spotify-inspired green and grey style.

##### `professional`

Clean black and grey for professional applications.

##### `minimalLine`

Minimal line-style waveform.

#### Static Methods

##### `filledGradient({Color startColor = Colors.blue, Color endColor = Colors.purple}) → WaveformStyle`

Filled waveform with customizable gradient.

##### `neonGlow({Color glowColor = Colors.cyan}) → WaveformStyle`

Glowing neon effect with customizable color.

**Example:**
```dart
// Use preset
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.soundCloud,
)

// Use customizable preset
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.neonGlow(glowColor: Colors.pink),
)
```

## Exceptions

### `SonixException`

Base class for all Sonix-related exceptions.

#### Properties

- `message`: `String` - Error message
- `details`: `String?` - Additional error details

### `UnsupportedFormatException`

Thrown when an unsupported audio format is encountered.

#### Properties

- `format`: `String` - The unsupported format

**Example:**
```dart
try {
  final waveform = await Sonix.generateWaveform('audio.xyz');
} on UnsupportedFormatException catch (e) {
  print('Unsupported format: ${e.format}');
  print('Supported formats: ${Sonix.getSupportedFormats()}');
}
```

### `DecodingException`

Thrown when audio decoding fails.

**Example:**
```dart
try {
  final waveform = await Sonix.generateWaveform('corrupted.mp3');
} on DecodingException catch (e) {
  print('Decoding failed: ${e.message}');
  if (e.details != null) {
    print('Details: ${e.details}');
  }
}
```

### `MemoryException`

Thrown when memory-related errors occur.

**Example:**
```dart
try {
  final waveform = await Sonix.generateWaveform('huge_audio.wav');
} on MemoryException catch (e) {
  print('Memory error: ${e.message}');
  await Sonix.forceCleanup();
}
```

## Utility Classes

### `ResourceStatistics`

Information about current resource usage.

#### Properties

- `memoryUsagePercentage`: `double` - Current memory usage as percentage (0.0 to 1.0)
- `cachedWaveforms`: `int` - Number of cached waveforms
- `cachedAudioData`: `int` - Number of cached audio data
- `activeResources`: `int` - Number of active resources
- `cacheHitRate`: `double` - Cache hit rate as percentage (0.0 to 100.0)
- `lastCleanupTime`: `DateTime?` - When the last cleanup occurred

### `MemoryManager`

Utility class for memory management operations.

#### Static Methods

##### `getCurrentUsage() → int`

Get current memory usage in bytes.

##### `getMemoryPressure() → double`

Get current memory pressure (0.0 to 1.0).

##### `suggestQualityReduction() → QualityReductionSuggestion`

Get suggestions for reducing quality to save memory.

### `LazyWaveformData`

Lazy-loaded waveform data for memory efficiency.

#### Methods

##### `load() → Future<WaveformData>`

Load the actual waveform data.

##### `isLoaded → bool`

Check if data is currently loaded.

##### `unload()`

Unload data to free memory.

**Example:**
```dart
final lazyWaveform = LazyWaveformData('audio.mp3');

// Load when needed
final waveformData = await lazyWaveform.load();

// Use the data
WaveformWidget(waveformData: waveformData);

// Unload to save memory
lazyWaveform.unload();
```

## Error Handling Best Practices

### Comprehensive Error Handling

```dart
Future<WaveformData?> safeGenerateWaveform(String filePath) async {
  try {
    return await Sonix.generateWaveform(filePath);
  } on UnsupportedFormatException catch (e) {
    print('Unsupported format: ${e.format}');
    print('Supported formats: ${Sonix.getSupportedFormats()}');
    return null;
  } on DecodingException catch (e) {
    print('Decoding failed: ${e.message}');
    return null;
  } on MemoryException catch (e) {
    print('Memory error: ${e.message}');
    await Sonix.forceCleanup();
    return null;
  } on FileSystemException catch (e) {
    print('File access error: ${e.message}');
    return null;
  } catch (e) {
    print('Unexpected error: $e');
    return null;
  }
}
```

### Recovery Strategies

```dart
Future<WaveformData?> generateWaveformWithRecovery(String filePath) async {
  try {
    // Try standard generation first
    return await Sonix.generateWaveform(filePath);
  } on MemoryException catch (e) {
    print('Memory error, trying memory-efficient approach: ${e.message}');
    
    try {
      // Fallback to memory-efficient processing
      return await Sonix.generateWaveformMemoryEfficient(filePath);
    } catch (e2) {
      print('Memory-efficient approach also failed: $e2');
      return null;
    }
  } catch (e) {
    print('Generation failed: $e');
    return null;
  }
}
```

This API reference provides comprehensive documentation for all public APIs in the Sonix package. For more examples and usage patterns, see the [examples directory](../example/) and the [Performance Guide](PERFORMANCE_GUIDE.md).