# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-10-02

### 🐛 Bug Fixes

#### Native Library Distribution

- **Fixed Linux RUNPATH Issue**: Resolved hardcoded CI build path in Linux native library
  - The distributed `libsonix_native.so` had a hardcoded RUNPATH pointing to an invalid path
  - Updated CMake configuration to use `$ORIGIN` (relative path) instead of absolute CI paths
  - Native library now correctly looks for FFmpeg dependencies in the same directory
  - Fixes library loading issues when using the package in Flutter applications

#### Build System

- **CMake RPATH Configuration**: Added `CMAKE_BUILD_WITH_INSTALL_RPATH TRUE` to ensure proper RUNPATH handling
  - Prevents CMake from embedding absolute build-time library paths
  - Ensures distributed libraries use relative paths for dependency resolution
  - Improves portability of the native library across different systems

### 🔧 Technical Details

This patch release addresses a critical issue where the Linux native library contained hardcoded paths from the CI build environment, preventing proper library loading in end-user applications. The fix ensures that the library uses relative paths (`$ORIGIN`) to locate its FFmpeg dependencies, making the package truly portable.

## [1.0.0] - 2025-09-26

### 🎉 Initial Release

This is the first stable release of Sonix, a comprehensive Flutter package for generating and displaying audio waveforms with multi-format support and isolate-based processing.

### ✨ Core Features

#### Audio Processing

- **Multi-format Support**: MP3, WAV, FLAC, OGG, Opus, MP4, and M4A audio formats
- **Isolate-based Processing**: All audio processing runs in background isolates to prevent UI thread blocking
- **High Performance**: Native C libraries via Dart FFI for optimal performance
- **Instance-based API**: Modern API with proper resource management and cleanup
- **Memory Efficient**: Automatic memory management with explicit disposal methods

#### Waveform Generation

- **Multiple Algorithms**: RMS, Peak, Average, and Median downsampling algorithms
- **Flexible Resolution**: Configurable waveform resolution from 100 to 10,000 points
- **Normalization Options**: Multiple normalization methods for consistent visualization
- **Scaling Curves**: Linear, logarithmic, and exponential scaling options
- **Optimized Presets**: Ready-to-use configurations for different use cases

#### UI Components

- **WaveformWidget**: Interactive waveform display with playback position and seeking
- **Style Presets**: 10+ pre-configured styles (SoundCloud, Spotify, Professional, etc.)
- **Custom Styling**: Extensive customization options for colors, gradients, and animations
- **Touch Interaction**: Tap-to-seek functionality with smooth animations
- **Responsive Design**: Adapts to different screen sizes and orientations

### 🏗️ Architecture

#### Native Library Distribution

- **Two-layer Architecture**: MIT-licensed `sonix_native` wrapper + user-provided FFMPEG libraries
- **Plugin-based Distribution**: Pre-compiled native libraries bundled via Flutter plugin system
- **Cross-platform Support**: Windows, macOS, Linux, iOS, and Android
- **No Compilation Required**: End users get pre-built binaries automatically

#### Isolate Management

- **Health Monitoring**: Automatic isolate health tracking and recovery
- **Resource Optimization**: Configurable isolate pool size and memory limits
- **Error Serialization**: Comprehensive error handling across isolate boundaries
- **Progress Reporting**: Real-time progress updates for long-running operations

### 🛠️ Developer Tools

#### FFMPEG Setup Tool

- **Automated Installation**: `dart run sonix:setup_ffmpeg_for_app` command
- **Platform Detection**: Automatic platform detection and binary selection
- **Validation**: Built-in verification of FFMPEG installation
- **Force Reinstall**: Option to force reinstall corrupted binaries

#### Development Tools

- **Binary Downloader**: Development tool for downloading FFMPEG binaries
- **Native Builder**: Tools for compiling native libraries for all platforms
- **Performance Profiler**: Built-in performance monitoring and optimization tools
- **Platform Validator**: Validation tools for platform compatibility

### 📊 Data Models

#### WaveformData

- **Comprehensive Metadata**: Duration, sample rate, generation parameters
- **Serialization Support**: Full JSON serialization for caching
- **Memory Management**: Explicit disposal methods for large datasets
- **Factory Constructors**: Multiple creation methods for different use cases

#### Configuration System

- **SonixConfig**: Instance-level configuration with mobile/desktop presets
- **WaveformConfig**: Processing configuration with use-case optimization
- **Style System**: Comprehensive styling system with preset and custom options

### 🎨 Style Presets

#### Built-in Presets

- **SoundCloud**: Orange and grey bars with rounded corners
- **Spotify**: Green and grey bars with modern styling
- **Professional**: Clean style for professional audio applications
- **Minimal Line**: Simple line-style waveform
- **Retro**: Vintage style with warm colors
- **Compact**: Mobile-optimized compact display
- **Podcast**: Optimized for speech content
- **Filled Gradient**: Customizable gradient-filled waveform
- **Glass Effect**: Modern glass-like effect with transparency
- **Neon Glow**: Glowing effect with customizable colors

### 🔧 Configuration Options

#### Instance Configuration

- **Mobile Preset**: Optimized for mobile devices with limited resources
- **Desktop Preset**: Optimized for desktop with full performance
- **Custom Configuration**: Fine-grained control over all parameters
- **Resource Limits**: Configurable memory usage and concurrent operation limits

#### Processing Configuration

- **Use Case Optimization**: Presets for music, podcasts, and audio editing
- **Algorithm Selection**: Choice of downsampling and normalization algorithms
- **Quality Settings**: Balance between processing speed and output quality
- **Memory Management**: Configurable memory usage patterns

### 🚀 Performance Features

#### Optimization

- **Lazy Loading**: Waveform data loaded only when needed
- **Caching Support**: Built-in serialization for persistent caching
- **Resource Monitoring**: Real-time monitoring of isolate performance
- **Memory Profiling**: Tools for identifying memory usage patterns

#### Monitoring Tools

- **Performance Profiler**: Detailed timing and memory usage analysis
- **Resource Statistics**: Active isolate and task monitoring
- **Benchmark Results**: Comprehensive performance reporting
- **Platform Validation**: Compatibility and optimization recommendations

### 🛡️ Error Handling

#### Exception Hierarchy

- **SonixException**: Base exception class with detailed error information
- **UnsupportedFormatException**: Format-specific error handling
- **DecodingException**: Audio decoding error details
- **FileAccessException**: File system error handling
- **IsolateProcessingException**: Background processing error management
- **MP4ContainerException**: Specialized MP4/M4A error handling

#### Error Recovery

- **Graceful Degradation**: Fallback mechanisms for unsupported features
- **Retry Logic**: Automatic retry for transient failures
- **Resource Cleanup**: Automatic cleanup on error conditions
- **Detailed Diagnostics**: Comprehensive error information for debugging

### 📱 Platform Support

#### Supported Platforms

- **Android**: API 21+ (ARM64, ARMv7, x86_64)
- **iOS**: 11.0+ (ARM64, x86_64 simulator)
- **Windows**: Windows 10+ (x64)
- **macOS**: 10.14+ (x64, Apple Silicon via Rosetta)
- **Linux**: Ubuntu 18.04+ (x64)

#### Native Library Distribution

- **Automatic Bundling**: Native libraries included in Flutter builds
- **Platform-specific Optimization**: Optimized binaries for each platform
- **Runtime Loading**: Dynamic loading with fallback mechanisms
- **Version Compatibility**: Consistent behavior across platform versions

### 📚 Documentation

#### Comprehensive Documentation

- **API Reference**: Complete documentation for all public APIs
- **Usage Examples**: Extensive examples for common use cases
- **Best Practices**: Performance and resource management guidelines
- **Troubleshooting**: Common issues and solutions
- **Migration Guide**: Guidelines for future version upgrades

#### Developer Resources

- **Contributing Guide**: Instructions for package development
- **Build Instructions**: Native library compilation guidelines
- **Testing Guide**: Comprehensive testing strategies
- **Architecture Overview**: Detailed system architecture documentation

### 🔄 Dependencies

#### Core Dependencies

- `ffi: ^2.1.0` - Native library bindings
- `path: ^1.8.3` - File path utilities
- `meta: ^1.15.0` - Annotations and metadata
- `crypto: ^3.0.3` - Cryptographic functions
- `archive: ^3.4.10` - Archive file handling
- `http: ^1.1.0` - HTTP client for downloads

#### Development Dependencies

- `flutter_lints: ^5.0.0` - Dart/Flutter linting rules
- `ffigen: ^13.0.0` - FFI bindings generator
- `test: ^1.24.0` - Testing framework

### 📋 Requirements

#### System Requirements

- **Flutter**: >=1.17.0
- **Dart**: ^3.9.0
- **FFMPEG**: User-provided (installed via setup tool)

#### Build Requirements (Development Only)

- **CMake**: For native library compilation
- **Platform Toolchains**: Visual Studio (Windows), Xcode (macOS), GCC/Clang (Linux)

### 🎯 Use Cases

#### Target Applications

- Music visualization and players
- Podcast players with waveform scrubbing
- Audio editing applications
- Voice recording apps
- Audio analysis tools
- Educational audio software
- Streaming applications
- Audio content management systems

### 🔐 Licensing

#### License Structure

- **Sonix Package**: MIT License (permissive, commercial-friendly)
- **Native Wrapper**: MIT License (bundled with package)
- **FFMPEG Libraries**: GPL License (user-provided, separate licensing)
- **Clear Separation**: Licensing responsibilities clearly defined

### 🚀 Getting Started

#### Quick Installation

```bash
# Add to pubspec.yaml
flutter pub add sonix

# Setup FFMPEG (required)
dart run sonix:setup_ffmpeg_for_app

# Verify installation
dart run sonix:setup_ffmpeg_for_app --verify
```

#### Basic Usage

```dart
// Create instance and generate waveform
final sonix = Sonix();
final waveformData = await sonix.generateWaveform('audio.mp3');

// Display with built-in widget
WaveformWidget(
  waveformData: waveformData,
  style: WaveformStylePresets.soundCloud,
)

// Clean up resources
await sonix.dispose();
```

### 🎉 What's Next

This stable 1.0.0 release provides a solid foundation for audio waveform visualization in Flutter applications. Future releases will focus on:

- Additional audio format support
- Enhanced performance optimizations
- More visualization styles and effects
- Advanced audio analysis features
- Improved developer tooling
- Extended platform support

---

**Full Changelog**: https://github.com/zooper-lib/Sonix/commits/v1.0.0
