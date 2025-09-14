# Project Structure

## Root Directory Layout

```
sonix/
├── lib/                    # Main Dart library code
├── native/                 # Native C libraries and build system
├── example/                # Example Flutter application
├── test/                   # Comprehensive test suite
├── doc/                    # Documentation files
├── scripts/                # Build and utility scripts
├── templates/              # Project templates for specs/plans
├── memory/                 # Project constitution and guidelines
└── .kiro/                  # Kiro IDE configuration and steering
```

## Library Structure (`lib/`)

```
lib/
├── sonix.dart              # Main library export file
└── src/                    # Internal implementation
    ├── sonix_api.dart      # Primary API (SonixInstance, SonixConfig)
    ├── models/             # Data models (WaveformData, AudioData, etc.)
    ├── processing/         # Audio processing and waveform generation
    ├── decoders/           # Format-specific audio decoders
    ├── isolate/            # Isolate management and messaging
    ├── widgets/            # Flutter UI widgets
    ├── utils/              # Utilities (caching, memory management, etc.)
    └── exceptions/         # Custom exception classes
```

## Native Code Structure (`native/`)

```
native/
├── src/                    # C source files
│   ├── sonix_native.c      # Main native interface
│   ├── minimp3/            # MP3 decoder library
│   ├── dr_wav/             # WAV decoder library
│   ├── dr_flac/            # FLAC decoder library
│   ├── stb_vorbis/         # OGG Vorbis decoder library
│   └── opus/               # Opus decoder library
├── CMakeLists.txt          # CMake build configuration
├── build.sh                # Unix build script
├── build.bat               # Windows build script
└── [platform]/            # Platform-specific configurations
```

## Test Structure (`test/`)

```
test/
├── *_test.dart             # Individual test files
├── assets/                 # Test audio files
├── decoders/               # Decoder-specific tests
├── exceptions/             # Exception handling tests
├── integration/            # Integration tests
├── isolate/                # Isolate functionality tests
├── mocks/                  # Mock objects for testing
├── models/                 # Data model tests
├── processing/             # Processing algorithm tests
├── test_helpers/           # Test utilities and helpers
├── utils/                  # Utility function tests
└── widgets/                # Widget tests
```

## Documentation Structure (`doc/`)

- `API_REFERENCE.md` - Complete API documentation
- `CHUNKED_PROCESSING_*.md` - Chunked processing guides and configuration
- `PERFORMANCE_GUIDE.md` - Performance optimization guidance
- `PLATFORM_GUIDE.md` - Platform-specific implementation details

## Key Architectural Principles

### API Design
- **Instance-based**: Primary API uses `SonixInstance` with configuration
- **Backward compatibility**: Legacy static `Sonix` API still supported
- **Isolate-first**: All heavy processing happens in background isolates

### Code Organization
- **Feature-based modules**: Each major feature has its own directory
- **Clear separation**: Models, processing, UI, and utilities are separated
- **Export control**: Main library file (`sonix.dart`) controls public API

### Testing Strategy
- **Comprehensive coverage**: Unit, integration, and performance tests
- **Real data testing**: Uses actual audio files for validation
- **Isolate testing**: Dedicated tests for isolate functionality
- **Platform testing**: Cross-platform compatibility validation

### File Naming Conventions
- **Snake_case**: All Dart files use snake_case naming
- **Descriptive names**: File names clearly indicate their purpose
- **Test suffix**: Test files end with `_test.dart`
- **Integration prefix**: Integration tests clearly marked

### Import Organization
- **Relative imports**: Use relative imports within the package
- **Barrel exports**: Main library file re-exports public APIs
- **Selective exports**: Only expose necessary classes and functions