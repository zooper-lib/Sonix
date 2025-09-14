# Technology Stack

## Framework & Language
- **Flutter**: Cross-platform UI framework
- **Dart**: Primary programming language (SDK ^3.9.0)
- **Native C**: Audio processing libraries via Dart FFI

## Core Dependencies
- `ffi: ^2.1.0` - Foreign Function Interface for native library integration
- `path: ^1.8.3` - Cross-platform path manipulation
- `meta: ^1.15.0` - Annotations for static analysis

## Development Dependencies
- `flutter_test` - Testing framework
- `flutter_lints: ^5.0.0` - Dart/Flutter linting rules
- `ffigen: ^13.0.0` - FFI bindings generator

## Native Audio Libraries
- **minimp3**: MP3 decoding (CC0/Public Domain)
- **dr_wav**: WAV decoding (MIT/Public Domain)
- **dr_flac**: FLAC decoding (MIT/Public Domain)
- **stb_vorbis**: OGG Vorbis decoding (MIT/Public Domain)
- **libopus**: Opus decoding (BSD 3-Clause)

## Build System
- **CMake**: Native library compilation (minimum version 3.10)
- **C99 Standard**: Native code compilation standard
- **Platform-specific outputs**: .dll (Windows), .dylib (macOS), .so (Linux/Android)

## Common Commands

### Development
```bash
# Get dependencies
flutter pub get

# Run tests
flutter test

# Run example app
cd example && flutter run

# Generate FFI bindings (if needed)
dart run ffigen --config ffigen.yaml
```

### Native Build
```bash
# Windows
native/build.bat

# Unix-like systems
chmod +x native/build.sh
./native/build.sh
```

### Testing & Validation
```bash
# Run comprehensive test suite
dart test/run_comprehensive_tests.dart

# Run isolate-specific tests
dart test/run_isolate_tests.dart

# Performance testing
dart scripts/test-cache.dart
```

## Architecture Patterns
- **Isolate-based processing**: Background audio processing to prevent UI blocking
- **Instance-based API**: Modern API with SonixInstance and SonixConfig
- **Factory pattern**: AudioDecoderFactory for format-specific decoders
- **Resource management**: Automatic cleanup and memory management
- **Streaming processing**: Chunked processing for large files