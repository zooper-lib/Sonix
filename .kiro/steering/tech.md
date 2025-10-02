# Technology Stack

## Framework & Language
- **Flutter**: Cross-platform UI framework (>=1.17.0)
- **Dart**: Programming language (^3.9.0)
- **Dart FFI**: Foreign Function Interface for native library integration

## Core Dependencies
- `ffi: ^2.1.0` - Native library bindings
- `path: ^1.8.3` - File path utilities
- `meta: ^1.15.0` - Annotations and metadata
- `crypto: ^3.0.3` - Cryptographic functions
- `archive: ^3.4.10` - Archive file handling
- `http: ^1.1.0` - HTTP client for downloads

## Development Dependencies
- `flutter_lints: ^5.0.0` - Dart/Flutter linting rules
- `ffigen: ^13.0.0` - FFI bindings generator
- `test: ^1.24.0` - Testing framework

## Native Libraries
- **sonix_native**: Custom C wrapper (MIT licensed, bundled with package)
- **FFMPEG**: Audio decoding libraries (GPL licensed, user-provided)
  - `avformat` - Container format handling
  - `avcodec` - Audio/video codecs
  - `avutil` - Utility functions
  - `swresample` - Audio resampling

## Build System
- **CMake**: Native library compilation
- **Flutter Plugin System**: Cross-platform native library distribution
- **Dart Tools**: Custom build and setup scripts

## Common Commands

### For End Users (Flutter App Integration)
```bash
# Add Sonix dependency
flutter pub add sonix

# Setup FFMPEG binaries (required)
dart run sonix:setup_ffmpeg_for_app

# Verify FFMPEG installation
dart run sonix:setup_ffmpeg_for_app --verify

# Force reinstall FFMPEG
dart run sonix:setup_ffmpeg_for_app --force
```

### For Package Development
```bash
# Install dependencies
flutter pub get

# Download FFMPEG for development
dart run tools/download_ffmpeg_binaries.dart

# Quick development build
dart run tools/build_native_for_development.dart

# Distribution build (all platforms)
dart run tools/build_native_for_distribution.dart --platforms all

# Run tests
flutter test

# Run example app
cd example && flutter run
```

### Platform-Specific Build Commands
```bash
# Windows (requires Visual Studio Build Tools)
dart run tools/build_native_for_distribution.dart --platforms windows

# Linux (requires GCC/Clang)
dart run tools/build_native_for_distribution.dart --platforms linux

# macOS (requires Xcode Command Line Tools)
dart run tools/build_native_for_distribution.dart --platforms macos
```

## Supported Platforms
- **Android**: API 21+ (ARM64, ARMv7, x86_64)
- **iOS**: 11.0+ (ARM64, x86_64 simulator)
- **Windows**: Windows 10+ (x64)
- **macOS**: 10.14+ (x64, Apple Silicon via Rosetta)
- **Linux**: Ubuntu 18.04+ (x64)

## Code Generation
- **FFI Bindings**: Generated via `ffigen` from C headers
- **Configuration**: `ffigen.yaml` defines binding generation rules
- **Native Headers**: Located in `native/src/` directory