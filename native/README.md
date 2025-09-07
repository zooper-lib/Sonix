# Sonix Native Library

This directory contains the native C library for audio decoding used by the Sonix Flutter package.

## Architecture

The native library provides a unified interface for decoding multiple audio formats:

- **MP3**: Using minimp3 (CC0/Public Domain)
- **FLAC**: Using dr_flac (MIT/Public Domain)
- **WAV**: Using dr_wav (MIT/Public Domain)
- **OGG Vorbis**: Using stb_vorbis (MIT/Public Domain)
- **Opus**: Using libopus (BSD 3-Clause)

## Directory Structure

```
native/
├── src/                    # Source code
│   ├── sonix_native.h     # Main header file
│   ├── sonix_native.c     # Main implementation
│   ├── minimp3/           # MP3 decoder
│   ├── dr_flac/           # FLAC decoder
│   ├── dr_wav/            # WAV decoder
│   ├── stb_vorbis/        # OGG Vorbis decoder
│   └── opus/              # Opus decoder
├── android/               # Android NDK build config
├── ios/                   # iOS CocoaPods config
├── windows/               # Windows build config
├── macos/                 # macOS build config
├── linux/                 # Linux build config
├── build/                 # Build output directory
├── CMakeLists.txt         # Main CMake configuration
├── build.sh               # Unix build script
└── build.bat              # Windows build script
```

## Building

### Prerequisites

- CMake 3.10 or later
- C compiler (GCC, Clang, or MSVC)
- Platform-specific tools:
  - **Android**: Android NDK
  - **iOS**: Xcode
  - **Windows**: Visual Studio 2019 or later
  - **macOS**: Xcode Command Line Tools
  - **Linux**: GCC or Clang

### Build Commands

#### Automatic Build (Recommended)

The native library is automatically built when you run Flutter commands:

```bash
# This will trigger native builds for the target platform
flutter build apk          # Android
flutter build ios          # iOS
flutter build windows      # Windows
flutter build macos        # macOS
flutter build linux        # Linux
```

#### Manual Build

For development and testing:

**Unix/Linux/macOS:**
```bash
cd native
chmod +x build.sh
./build.sh [platform] [build_type]
```

**Windows:**
```cmd
cd native
build.bat [build_type]
```

Parameters:
- `platform`: android, ios, windows, macos, linux, all (default: current platform)
- `build_type`: debug, release (default: release)

### FFI Bindings Generation

Generate Dart FFI bindings from the C headers:

```bash
# From the package root directory
dart run ffigen
```

This will generate `lib/src/native/sonix_bindings.dart` based on the configuration in `ffigen.yaml`.

## Integration with Flutter

The native library is integrated into the Flutter package through:

1. **FFI Bindings**: Generated Dart code that provides type-safe access to C functions
2. **Platform Channels**: For loading the native library on each platform
3. **Build Integration**: CMake configurations that integrate with Flutter's build system

## License Compatibility

All included audio decoding libraries are MIT-compatible:

- **minimp3**: CC0 (Public Domain)
- **dr_flac**: MIT/Public Domain (dual license)
- **dr_wav**: MIT/Public Domain (dual license)
- **stb_vorbis**: MIT/Public Domain (dual license)
- **libopus**: BSD 3-Clause

This ensures the entire package can be distributed under the MIT license.

## Performance Notes

- The library is optimized for performance with `-O3` optimization in release builds
- Memory management is handled carefully to prevent leaks
- Streaming processing is supported for large files
- Platform-specific optimizations are applied where appropriate

## Troubleshooting

### Build Issues

1. **CMake not found**: Install CMake 3.10 or later
2. **Compiler errors**: Ensure you have the appropriate C compiler installed
3. **Android build fails**: Check that Android NDK is properly configured
4. **iOS build fails**: Ensure Xcode and Command Line Tools are installed

### Runtime Issues

1. **Library not found**: Check that the native library was built and is in the correct location
2. **Decoding errors**: Verify the audio file format is supported
3. **Memory issues**: Ensure proper disposal of audio data objects

For more help, check the main package documentation or file an issue on the project repository.