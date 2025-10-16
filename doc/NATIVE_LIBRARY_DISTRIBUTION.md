# Native Library Distribution Strategy

This document explains how Sonix distributes native libraries (`sonix_native`) to end users without requiring them to compile anything.

## Overview

Sonix uses a **Flutter plugin architecture** to automatically bundle pre-compiled native libraries with the published package. When users add Sonix as a dependency, they get everything they need without any build steps.

## Architecture

### 1. Two-Layer Architecture

Sonix uses a two-layer native library architecture:

**Layer 1: Sonix Native Wrapper (`sonix_native`)**
- Custom C library that wraps FFMPEG APIs
- MIT licensed (same as Sonix package)
- Bundled with Sonix package via Flutter plugin system
- Platform-specific: `.dll` (Windows), `.so` (Linux), `.dylib` (macOS), `.a` (iOS)

**Layer 2: FFmpeg Libraries**
- Core audio decoding libraries (`avformat`, `avcodec`, `avutil`, `swresample`)
- GPL licensed (provided separately by user)
- Installed via system package manager (for example, macOS Homebrew: `brew install ffmpeg`)
- Loaded dynamically by `sonix_native` at runtime

### 2. Plugin Structure

Sonix is configured as a Flutter plugin to bundle `sonix_native`:

```yaml
flutter:
  plugin:
    platforms:
      android:
        package: dev.zooper.sonix
        pluginClass: SonixPlugin
      ios:
        pluginClass: SonixPlugin
      linux:
        pluginClass: SonixPlugin
      macos:
        pluginClass: SonixPlugin
      windows:
        pluginClass: SonixPlugin
```

### 2. Platform-Specific Directories

Each platform has its own directory with the necessary configuration:

```
sonix/
├── android/          # Android plugin configuration + JNI libraries
├── ios/              # iOS plugin configuration + static library
├── linux/            # Linux plugin configuration + shared library
├── macos/            # macOS plugin configuration + dynamic library
└── windows/          # Windows plugin configuration + DLL
```

### 3. Native Library Locations

Pre-compiled `sonix_native` libraries are placed in platform-specific locations:

- **Windows**: `windows/sonix_native.dll`
- **Linux**: `linux/libsonix_native.so`
- **macOS**: `macos/libsonix_native.dylib`
- **iOS**: `ios/libsonix_native.a` (static library)
- **Android**: `android/src/main/jniLibs/{arch}/libsonix_native.so`
  - `arm64-v8a/` - 64-bit ARM (modern devices)
  - `armeabi-v7a/` - 32-bit ARM (older devices)
  - `x86_64/` - 64-bit x86 (emulators)

## Build Process

### For Package Developers

1. Install FFmpeg on your development machine (for example, `brew install ffmpeg` on macOS)
2. Build native libraries: `dart run tool/build_native_for_distribution.dart --platforms all`
3. Publish the package: libraries are automatically included

### For End Users

1. Add dependency: `flutter pub add sonix`
2. On desktop, install FFmpeg on the machine where the app runs
3. Use Sonix: `sonix_native` is bundled; FFmpeg is resolved at runtime from the system

## How It Works

### During Package Installation

When a user runs `flutter pub get`:

1. Flutter downloads the Sonix package from pub.dev
2. The package includes all pre-compiled `sonix_native` libraries
3. Flutter's build system automatically includes the appropriate library for the target platform

### During App Build

When a user runs `flutter build`:

1. Flutter detects Sonix as a plugin
2. Copies the appropriate `sonix_native` library to the app's build directory
3. Links the library with the final app bundle
4. The library is available at runtime via FFI

### At Runtime

When Sonix code runs:

1. Dart FFI loads the `sonix_native` library from the app bundle
2. Sonix calls native functions for audio processing
3. Native code uses FFMPEG libraries (provided separately by user)

## Separation of Concerns

### Sonix Native Library (MIT Licensed)
- **What**: Custom C wrapper around FFMPEG APIs
- **License**: MIT (same as Sonix package)
- **Distribution**: Bundled with Sonix package
- **Compilation**: Done by Sonix developers

### FFmpeg Libraries (GPL Licensed)
- **What**: Audio decoding libraries (avformat, avcodec, etc.)
- **License**: GPL (incompatible with MIT for distribution)
- **Distribution**: User must provide via system package manager
- **Compilation**: Provided by OS/package manager (not bundled by Sonix)

## Benefits

### For End Users
- ✅ No compilation required
- ✅ No build tools needed (CMake, compilers, etc.)
- ✅ Works out of the box after FFMPEG setup
- ✅ Consistent behavior across platforms
- ✅ Automatic updates with package updates

### For Package Developers
- ✅ Control over native library compilation
- ✅ Consistent build environment
- ✅ Easier testing and validation
- ✅ Simplified user onboarding
- ✅ Reduced support burden

### For Licensing
- ✅ MIT-licensed Sonix code can be distributed
- ✅ GPL-licensed FFMPEG handled separately
- ✅ Users make their own FFMPEG licensing decisions
- ✅ Clear separation of responsibilities

## Development Workflow

### Initial Setup
```bash
# Clone repository
git clone https://github.com/zooper-dev/sonix.git
cd sonix

# Install dependencies
flutter pub get

# Ensure system FFmpeg is installed (macOS example)
brew install ffmpeg

# Quick development build (for testing)
dart run tool/build_native_for_development.dart

# OR build for distribution (for releases)
dart run tool/build_native_for_distribution.dart --platforms all
```

### Testing
```bash
# Test with example app
cd example
flutter run

# Run unit tests
cd ..
flutter test
```

### Publishing
```bash
# Verify all platforms have native libraries
ls -la windows/ linux/ macos/ ios/ android/src/main/jniLibs/*/

# Publish to pub.dev
flutter pub publish
```

## Troubleshooting

### Missing Native Library
If users get "library not found" errors:
- Verify the appropriate platform directory contains the library
- Check that the library was built for the correct architecture
- Ensure the plugin configuration is correct

### FFmpeg Issues
If users get FFmpeg-related errors:
- Install FFmpeg using the system package manager and ensure shared libraries are available
- On macOS, `brew install ffmpeg` provides dylibs in `/opt/homebrew/opt/ffmpeg/lib`
- This is separate from the Sonix native library

### Build Issues
If native library compilation fails:
- Check that all required toolchains are installed
- Ensure system FFmpeg is available for linking and runtime resolution

## Future Enhancements

### Potential Improvements
- **Automated CI/CD**: Build libraries automatically on releases
- **Multiple Architectures**: Support more CPU architectures
- **Size Optimization**: Strip debug symbols, optimize for size
- **Fallback Mechanisms**: Runtime detection and graceful degradation
- **Alternative Backends**: Support for other audio libraries

### Considerations
- **Binary Size**: Native libraries increase package size
- **Platform Coverage**: Ensure all target platforms are supported
- **Update Frequency**: Balance between features and stability
- **Compatibility**: Maintain backward compatibility across versions