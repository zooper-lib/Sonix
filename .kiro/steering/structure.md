# Project Structure

## Root Directory Layout

```
sonix/
├── lib/                    # Main Dart library code
├── example/                # Example Flutter app demonstrating usage
├── test/                   # Comprehensive test suite
├── tool/                   # Development and build tools
├── native/                 # Native C library source code
├── docs/                   # Additional documentation
├── android/                # Android plugin configuration
├── ios/                    # iOS plugin configuration  
├── linux/                  # Linux plugin configuration
├── macos/                  # macOS plugin configuration
├── windows/                # Windows plugin configuration
└── .kiro/                  # Kiro AI assistant configuration
```

## Library Structure (`lib/`)

```
lib/
├── sonix.dart              # Main library export file
└── src/
    ├── sonix_api.dart      # Primary API class (Sonix)
    ├── config/             # Configuration classes
    ├── decoders/           # Audio format decoders
    ├── exceptions/         # Custom exception classes
    ├── isolate/            # Isolate management and communication
    ├── models/             # Data models (WaveformData, etc.)
    ├── native/             # FFI bindings and native interface
    ├── processing/         # Waveform generation and processing
    ├── utils/              # Utility classes and helpers
    └── widgets/            # Flutter UI widgets
```

## Key Directories

### `/lib/src/` - Core Implementation
- **`sonix_api.dart`**: Main entry point class with instance-based API
- **`config/`**: Configuration classes for Sonix instances and processing
- **`models/`**: Data structures (WaveformData, AudioData, metadata)
- **`processing/`**: Waveform generation algorithms and processing logic
- **`isolate/`**: Background processing infrastructure and communication
- **`widgets/`**: Flutter widgets for waveform display and interaction
- **`native/`**: FFI bindings and native library interface
- **`decoders/`**: Audio format detection and decoding logic
- **`exceptions/`**: Custom exception hierarchy
- **`utils/`**: Performance profiling, memory management, validation

### `/test/` - Comprehensive Testing
- **`assets/`**: Test audio files and fixtures
- **`core/`**: Core functionality tests
- **`integration/`**: End-to-end integration tests
- **`performance/`**: Performance benchmarking tests
- **`mocks/`**: Mock objects and test doubles
- **`fixtures/`**: Test data (optionally, local FFmpeg libs for tests)

### `/tool/` - Development Tools
// System FFmpeg is required; no download/setup tools are provided.
- **`build_native_for_development.dart`**: Quick development builds
- **`build_native_for_distribution.dart`**: Production builds for all platforms

### `/native/` - Native Library Source
- **`src/`**: C source code for sonix_native wrapper
- **`CMakeLists.txt`**: CMake build configuration
- **Platform subdirectories**: Platform-specific build artifacts

### Platform Plugin Directories
- **`android/`**: Android plugin configuration and JNI libraries
- **`ios/`**: iOS plugin configuration and static libraries
- **`linux/`**: Linux plugin configuration and shared libraries
- **`macos/`**: macOS plugin configuration and dynamic libraries
- **`windows/`**: Windows plugin configuration and DLLs

## File Naming Conventions

### Dart Files
- **Snake case**: `waveform_data.dart`, `sonix_api.dart`
- **Descriptive names**: Clearly indicate purpose and scope
- **Suffix patterns**: 
  - `_config.dart` for configuration classes
  - `_exception.dart` for exception classes
  - `_widget.dart` for Flutter widgets
  - `_test.dart` for test files

### Native Files
- **C source**: `.c` and `.h` extensions
- **CMake**: `CMakeLists.txt` for build configuration
- **Platform libraries**: Follow platform conventions (`.dll`, `.so`, `.dylib`, `.a`)

### Tool Scripts
- **Descriptive names**: Clearly indicate tool purpose
- **Dart executable**: All tools are Dart scripts for consistency
- **Prefix patterns**: `build_`, `download_`, `setup_` for different tool categories

## Import Organization

### Library Exports (`lib/sonix.dart`)
- **Selective exports**: Only expose public API, not internal implementation
- **Grouped by category**: API, configuration, models, widgets, etc.
- **Documentation**: Each export group has explanatory comments

### Internal Imports
- **Relative imports**: Use relative paths within the package
- **Grouped imports**: Dart SDK, Flutter, external packages, internal
- **Alphabetical order**: Within each group, maintain alphabetical order

## Architecture Patterns

### Instance-Based API
- **Main class**: `Sonix` class manages isolates and resources
- **Configuration**: `SonixConfig` for instance customization
- **Resource management**: Explicit `dispose()` for cleanup

### Isolate Communication
- **Message passing**: Structured messages for isolate communication
- **Error serialization**: Custom error handling across isolate boundaries
- **Health monitoring**: Isolate health tracking and recovery

### Plugin Architecture
- **Platform abstraction**: Common interface with platform-specific implementations
- **Native library loading**: Dynamic loading with fallback mechanisms
- **Resource bundling**: Automatic inclusion of native libraries in builds