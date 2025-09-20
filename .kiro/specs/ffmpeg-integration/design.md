# Design Document

## Overview

This design outlines the migration from current native audio libraries (minimp3, dr_wav, dr_flac, stb_vorbis, libopus) to FFMPEG while maintaining MIT licensing compatibility. The solution involves building FFMPEG with LGPL licensing for all supported platforms and providing automated build scripts for end users to generate the necessary binaries.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Application Layer                     │
├─────────────────────────────────────────────────────────────────┤
│                      Sonix Dart API                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   SonixInstance │  │  Legacy Static  │  │   Isolate       │ │
│  │      API        │  │      API        │  │  Processing     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    FFI Bindings Layer                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              FFMPEG Native Bindings                        │ │
│  │  - Format Detection    - Decoding Functions               │ │
│  │  - Chunked Processing  - Error Handling                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                   Native C Wrapper Layer                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 sonix_native.c                             │ │
│  │  - FFMPEG Integration  - Memory Management                 │ │
│  │  - Format Abstraction - Error Translation                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    FFMPEG Libraries                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  libavformat  │  libavcodec  │  libavutil  │  libswresample │ │
│  │  (Container)  │  (Codecs)    │  (Utils)    │  (Resampling) │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Build System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Build Automation                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  setup_ffmpeg   │  │ build_ffmpeg    │  │ install_ffmpeg  │ │
│  │     .dart       │  │     .dart       │  │     .dart       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                Platform-Specific Builders                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │    Windows      │  │     macOS       │  │     Linux       │ │
│  │   Builder       │  │    Builder      │  │    Builder      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐                     │
│  │    Android      │  │      iOS        │                     │
│  │   Builder       │  │    Builder      │                     │
│  └─────────────────┘  └─────────────────┘                     │
├─────────────────────────────────────────────────────────────────┤
│                   FFMPEG Source Management                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  - Download from official Git repository                   │ │
│  │  - Version pinning for stability                           │ │
│  │  - Checksum verification                                   │ │
│  │  - Patch application (if needed)                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. FFMPEG Native Wrapper (`native/src/ffmpeg_wrapper.c`)

**Purpose**: Provides a C interface that wraps FFMPEG functionality and maintains compatibility with existing Sonix API.

**Key Functions**:
```c
// Format detection using FFMPEG's probing
int ffmpeg_detect_format(const uint8_t *data, size_t size);

// Audio decoding using FFMPEG
SonixAudioData* ffmpeg_decode_audio(const uint8_t *data, size_t size, int format);

// Chunked processing for large files
SonixChunkedDecoder* ffmpeg_init_chunked_decoder(int format, const char *file_path);
SonixChunkResult* ffmpeg_process_file_chunk(SonixChunkedDecoder *decoder, SonixFileChunk *file_chunk);

// Resource cleanup
void ffmpeg_cleanup_decoder(SonixChunkedDecoder *decoder);
void ffmpeg_free_audio_data(SonixAudioData *audio_data);
```

**FFMPEG Integration Points**:
- `avformat_open_input()` for container parsing
- `avcodec_find_decoder()` for codec selection
- `avcodec_decode_audio4()` for audio decoding
- `swr_convert()` for format conversion to float samples

### 2. Build Automation Scripts

#### A. Main Setup Script (`tools/setup_ffmpeg.dart`)

**Purpose**: Entry point for FFMPEG setup process.

**Functionality**:
- Platform detection
- Dependency verification
- Orchestrates download, build, and installation
- Progress reporting and error handling

#### B. FFMPEG Builder (`tools/ffmpeg_builder.dart`)

**Purpose**: Handles FFMPEG source management and compilation.

**Key Methods**:
```dart
class FFMPEGBuilder {
  Future<void> downloadSource(String version, String targetDir);
  Future<void> configureForPlatform(Platform platform, BuildConfig config);
  Future<void> compile(String sourceDir, String outputDir);
  Future<void> verifyBuild(String outputDir);
}
```

**Configuration Options**:
- LGPL-only components (no GPL code)
- Minimal feature set (audio decoding only)
- Optimized for size and performance
- Platform-specific optimizations

#### C. Platform-Specific Builders

**Windows Builder** (`tools/builders/windows_builder.dart`):
- Uses MSYS2/MinGW-w64 for compilation
- Generates `.dll` files
- Handles Windows-specific linking

**macOS Builder** (`tools/builders/macos_builder.dart`):
- Uses Xcode command line tools
- Generates `.dylib` files
- Supports both x86_64 and arm64 architectures

**Linux Builder** (`tools/builders/linux_builder.dart`):
- Uses system GCC/Clang
- Generates `.so` files
- Handles various Linux distributions

**Android Builder** (`tools/builders/android_builder.dart`):
- Uses Android NDK
- Generates `.so` files for multiple architectures
- Integrates with Flutter's Android build system

**iOS Builder** (`tools/builders/ios_builder.dart`):
- Uses Xcode toolchain
- Generates `.framework` or static libraries
- Supports both device and simulator architectures

### 3. Updated Native Interface

#### Modified `sonix_native.c`

**Changes**:
- Replace individual decoder includes with FFMPEG headers
- Implement FFMPEG-based decoding functions
- Maintain existing function signatures for compatibility
- Add FFMPEG-specific error handling

**FFMPEG Configuration**:
```c
// Initialize FFMPEG (called once)
void init_ffmpeg() {
    av_register_all();
    avcodec_register_all();
    av_log_set_level(AV_LOG_ERROR);
}

// Format detection using FFMPEG probing
int sonix_detect_format(const uint8_t *data, size_t size) {
    AVProbeData probe_data = {0};
    probe_data.buf = (unsigned char*)data;
    probe_data.buf_size = size;
    
    AVInputFormat *fmt = av_probe_input_format(&probe_data, 1);
    if (!fmt) return SONIX_FORMAT_UNKNOWN;
    
    // Map FFMPEG format to Sonix format constants
    return map_ffmpeg_format_to_sonix(fmt);
}
```

### 4. Updated FFI Bindings

#### Modified `sonix_bindings.dart`

**Changes**:
- Maintain existing function signatures
- Add FFMPEG-specific error codes
- Update documentation to reflect FFMPEG backend

**New Error Codes**:
```dart
// FFMPEG-specific error codes
const int SONIX_ERROR_FFMPEG_INIT_FAILED = -20;
const int SONIX_ERROR_FFMPEG_PROBE_FAILED = -21;
const int SONIX_ERROR_FFMPEG_CODEC_NOT_FOUND = -22;
const int SONIX_ERROR_FFMPEG_DECODE_FAILED = -23;
```

### 5. Build System Integration

#### Updated `CMakeLists.txt`

**Changes**:
- Remove current decoder library includes
- Add FFMPEG library linking
- Platform-specific FFMPEG library paths
- Conditional compilation based on FFMPEG availability

**FFMPEG Integration**:
```cmake
# Find FFMPEG libraries
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED 
    libavformat 
    libavcodec 
    libavutil 
    libswresample
)

# Link FFMPEG libraries
target_link_libraries(sonix_native ${FFMPEG_LIBRARIES})
target_include_directories(sonix_native PRIVATE ${FFMPEG_INCLUDE_DIRS})
target_compile_options(sonix_native PRIVATE ${FFMPEG_CFLAGS_OTHER})
```

## Data Models

### FFMPEG Configuration

```dart
class FFMPEGConfig {
  final String version;
  final List<String> enabledDecoders;
  final List<String> enabledDemuxers;
  final Map<String, String> configureOptions;
  final bool optimizeForSize;
  
  const FFMPEGConfig({
    this.version = '6.1',
    this.enabledDecoders = const ['mp3', 'aac', 'flac', 'vorbis', 'opus'],
    this.enabledDemuxers = const ['mp3', 'mp4', 'flac', 'ogg', 'wav'],
    this.configureOptions = const {},
    this.optimizeForSize = true,
  });
}
```

### Build Configuration

```dart
class BuildConfig {
  final Platform targetPlatform;
  final Architecture architecture;
  final BuildType buildType;
  final String outputDirectory;
  final FFMPEGConfig ffmpegConfig;
  
  const BuildConfig({
    required this.targetPlatform,
    required this.architecture,
    this.buildType = BuildType.release,
    required this.outputDirectory,
    required this.ffmpegConfig,
  });
}

enum Platform { windows, macos, linux, android, ios }
enum Architecture { x86_64, arm64, armv7, i386 }
enum BuildType { debug, release }
```

### Platform Detection

```dart
class PlatformInfo {
  final Platform platform;
  final Architecture architecture;
  final String osVersion;
  final Map<String, String> buildTools;
  
  static PlatformInfo detect() {
    // Implementation for detecting current platform and available tools
  }
  
  bool get canBuildFFMPEG => buildTools.containsKey('cmake') && 
                            buildTools.containsKey('compiler');
}
```

## Error Handling

### FFMPEG Error Translation

**Strategy**: Map FFMPEG error codes to Sonix error codes while preserving detailed error information.

```c
int translate_ffmpeg_error(int ffmpeg_error) {
    switch (ffmpeg_error) {
        case AVERROR_INVALIDDATA:
            return SONIX_ERROR_INVALID_DATA;
        case AVERROR(ENOMEM):
            return SONIX_ERROR_OUT_OF_MEMORY;
        case AVERROR_DECODER_NOT_FOUND:
            return SONIX_ERROR_FFMPEG_CODEC_NOT_FOUND;
        default:
            return SONIX_ERROR_FFMPEG_DECODE_FAILED;
    }
}
```

### Build Error Handling

**Strategy**: Provide clear error messages and recovery suggestions for build failures.

```dart
class BuildError extends Exception {
  final String message;
  final String? suggestion;
  final String? logPath;
  
  const BuildError(this.message, {this.suggestion, this.logPath});
  
  @override
  String toString() {
    var result = 'Build Error: $message';
    if (suggestion != null) result += '\nSuggestion: $suggestion';
    if (logPath != null) result += '\nSee log: $logPath';
    return result;
  }
}
```

## Testing Strategy

### 1. Unit Tests

**FFMPEG Wrapper Tests**:
- Test format detection with various audio files
- Test decoding accuracy against reference implementations
- Test memory management and cleanup
- Test error handling for invalid inputs

**Build System Tests**:
- Test platform detection
- Test FFMPEG download and verification
- Test build configuration generation
- Test cross-platform compatibility

### 2. Integration Tests

**End-to-End Processing**:
- Test complete audio processing pipeline
- Compare output with current implementation
- Test isolate-based processing
- Test chunked processing for large files

**Performance Tests**:
- Benchmark decoding speed vs current implementation
- Memory usage comparison
- Startup time impact assessment

### 3. Platform Tests

**Cross-Platform Validation**:
- Test on all supported platforms
- Validate binary compatibility
- Test Flutter integration on each platform

### 4. Regression Tests

**API Compatibility**:
- Ensure existing API continues to work
- Test backward compatibility with legacy code
- Validate that all current tests pass

## Implementation Phases

### Phase 1: Build System Setup
1. Create FFMPEG download and build scripts
2. Implement platform-specific builders
3. Test FFMPEG compilation on all platforms
4. Verify LGPL compliance

### Phase 2: Native Integration
1. Create FFMPEG wrapper in C
2. Implement core decoding functions
3. Update CMakeLists.txt for FFMPEG linking
4. Test basic decoding functionality

### Phase 3: Dart Integration
1. Update FFI bindings
2. Modify existing decoders to use FFMPEG backend
3. Ensure API compatibility
4. Update error handling

### Phase 4: Testing and Validation
1. Run comprehensive test suite
2. Performance benchmarking
3. Cross-platform validation
4. Documentation updates

### Phase 5: Migration and Cleanup
1. Remove old decoder libraries
2. Update build scripts
3. Clean up unused code
4. Final testing and validation

## Security and Licensing Considerations

### LGPL Compliance
- FFMPEG built with LGPL-only components
- Dynamic linking to maintain license compatibility
- Clear separation between MIT (Sonix) and LGPL (FFMPEG) code
- Documentation of licensing requirements

### Security
- Checksum verification for downloaded FFMPEG source
- Secure build environment setup
- Input validation for all FFMPEG calls
- Memory safety in native wrapper code

## Performance Considerations

### Optimization Strategies
- Minimal FFMPEG configuration (audio-only)
- Platform-specific optimizations
- Efficient memory management
- Lazy initialization of FFMPEG components

### Memory Management
- Proper cleanup of FFMPEG contexts
- Buffer reuse where possible
- Monitoring for memory leaks
- Graceful handling of large files

## Deployment Strategy

### User Experience
- Simple setup command: `dart run tools/setup_ffmpeg.dart`
- Clear progress indication during build
- Helpful error messages with solutions
- Automatic platform detection

### CI/CD Integration
- Pre-built binaries for common platforms (optional)
- Automated testing on multiple platforms
- Build verification in CI pipeline
- Documentation generation