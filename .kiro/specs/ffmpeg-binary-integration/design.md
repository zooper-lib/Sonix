# Design Document

## Overview

This design outlines the complete overhaul of FFMPEG integration in the Sonix Flutter package by eliminating all stub implementations and requiring users to provide proper FFMPEG binaries. The solution focuses on creating a robust native wrapper that works exclusively with real FFMPEG libraries, comprehensive testing with actual audio processing, and a simple binary download mechanism for users who need pre-built FFMPEG libraries.

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
│  │  - NO STUBS OR MOCKS   - Real FFMPEG Only                 │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                   Native C Wrapper Layer                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 sonix_ffmpeg.c                             │ │
│  │  - Real FFMPEG Integration  - Memory Management           │ │
│  │  - Format Abstraction      - Error Translation            │ │
│  │  - NO FALLBACK STUBS       - Fail Fast on Missing Libs   │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    User-Provided FFMPEG Libraries              │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  libavformat  │  libavcodec  │  libavutil  │  libswresample │ │
│  │  (Container)  │  (Codecs)    │  (Utils)    │  (Resampling) │ │
│  │  USER MUST PROVIDE - NO AUTO-BUILDING                     │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Binary Management Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Binary Management                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Binary         │  │ Binary          │  │ Binary          │ │
│  │  Downloader     │  │ Validator       │  │ Installer       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                Flutter Build Directory Integration              │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  CRITICAL: Flutter loads binaries from build directories   │ │
│  │  - Windows: build/windows/x64/runner/Debug/               │ │
│  │  - macOS: build/macos/Build/Products/Debug/               │ │
│  │  - Linux: build/linux/x64/debug/bundle/lib/               │ │
│  │  - Must copy FFMPEG binaries to these locations           │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                Platform-Specific Binary Sources                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │    Windows      │  │     macOS       │  │     Linux       │ │
│  │   DLL Source    │  │   dylib Source  │  │   .so Source    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                   Binary Verification                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  - Symbol verification (nm, objdump, readelf)              │ │
│  │  - Version compatibility checking                          │ │
│  │  - Architecture validation                                 │ │
│  │  - Dependency resolution                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. FFMPEG Native Wrapper (`native/src/sonix_ffmpeg.c`)

**Purpose**: Provides a C interface that wraps FFMPEG functionality with NO fallback stubs. Fails immediately if FFMPEG libraries are not available.

**Key Functions**:
```c
// Initialization - MUST succeed or fail completely
int sonix_ffmpeg_init(void);
void sonix_ffmpeg_cleanup(void);

// Format detection using FFMPEG's probing - NO STUBS
int sonix_detect_format(const uint8_t *data, size_t size);

// Audio decoding using FFMPEG - NO FALLBACKS
SonixAudioData* sonix_decode_audio(const uint8_t *data, size_t size, int format);

// Chunked processing for large files - REAL FFMPEG ONLY
SonixChunkedDecoder* sonix_init_chunked_decoder(int format, const char *file_path);
SonixChunkResult* sonix_process_file_chunk(SonixChunkedDecoder *decoder, SonixFileChunk *file_chunk);

// Resource cleanup - PROPER FFMPEG CLEANUP
void sonix_cleanup_chunked_decoder(SonixChunkedDecoder *decoder);
void sonix_free_audio_data(SonixAudioData *audio_data);
```

**FFMPEG Integration Points**:
- `avformat_open_input()` for container parsing
- `avcodec_find_decoder()` for codec selection  
- `avcodec_receive_frame()` for audio decoding
- `swr_convert()` for format conversion to float samples
- **NO STUB IMPLEMENTATIONS** - All functions must use real FFMPEG

### 2. Binary Download and Management

#### A. Binary Downloader (`tools/download_ffmpeg_binaries.dart`)

**Purpose**: Downloads pre-built FFMPEG binaries from reliable sources.

**Functionality**:
```dart
class FFMPEGBinaryDownloader {
  Future<void> downloadForPlatform(Platform platform, Architecture arch);
  Future<bool> verifyBinaryIntegrity(String binaryPath);
  Future<void> installBinaries(String downloadPath, String targetPath);
  
  // CRITICAL: Install to Flutter build directories
  Future<void> installToFlutterBuildDirs(String downloadPath) {
    // Windows: build/windows/x64/runner/Debug/
    // macOS: build/macos/Build/Products/Debug/
    // Linux: build/linux/x64/debug/bundle/lib/
    // Also copy to test directory for unit tests
  }
}
```

**Binary Sources and Installation**:
- **Windows**: Download DLLs and install to `build/windows/x64/runner/Debug/`
- **macOS**: Download dylibs and install to `build/macos/Build/Products/Debug/`
- **Linux**: Download .so files and install to `build/linux/x64/debug/bundle/lib/`
- **Testing**: Also copy binaries to `test/` directory for unit test execution

#### B. Binary Validator (`tools/ffmpeg_binary_validator.dart`)

**Purpose**: Validates that downloaded binaries are compatible and contain required symbols.

**Key Methods**:
```dart
class FFMPEGBinaryValidator {
  Future<ValidationResult> validateBinary(String binaryPath);
  Future<List<String>> getRequiredSymbols();
  Future<bool> checkSymbolsPresent(String binaryPath, List<String> symbols);
  Future<String> getBinaryVersion(String binaryPath);
}
```

### 3. Updated Native Build System

#### Modified `CMakeLists.txt`

**Changes**:
- Remove all stub compilation paths
- Require FFMPEG libraries to be present
- Fail build if FFMPEG libraries are missing
- No conditional compilation for stubs

**FFMPEG Integration**:
```cmake
# CRITICAL: Look for FFMPEG libraries in platform-specific directories
set(FFMPEG_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}")

# REQUIRE FFMPEG libraries - NO FALLBACKS
find_library(AVFORMAT_LIBRARY NAMES avformat avformat-60 
    PATHS ${FFMPEG_ROOT_DIR} NO_DEFAULT_PATH REQUIRED)
find_library(AVCODEC_LIBRARY NAMES avcodec avcodec-60
    PATHS ${FFMPEG_ROOT_DIR} NO_DEFAULT_PATH REQUIRED) 
find_library(AVUTIL_LIBRARY NAMES avutil avutil-58
    PATHS ${FFMPEG_ROOT_DIR} NO_DEFAULT_PATH REQUIRED)
find_library(SWRESAMPLE_LIBRARY NAMES swresample swresample-4
    PATHS ${FFMPEG_ROOT_DIR} NO_DEFAULT_PATH REQUIRED)

# Fail if any library is missing
if(NOT AVFORMAT_LIBRARY OR NOT AVCODEC_LIBRARY OR NOT AVUTIL_LIBRARY OR NOT SWRESAMPLE_LIBRARY)
    message(FATAL_ERROR "FFMPEG libraries are required in native/${PLATFORM_NAME}/. Please run: dart run tools/download_ffmpeg_binaries.dart")
endif()

# Link FFMPEG libraries
target_link_libraries(sonix_native 
    ${AVFORMAT_LIBRARY}
    ${AVCODEC_LIBRARY} 
    ${AVUTIL_LIBRARY}
    ${SWRESAMPLE_LIBRARY}
)

# CRITICAL: Copy FFMPEG binaries to Flutter build directories
if(WIN32)
    add_custom_command(TARGET sonix_native POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/avformat-60.dll"
            "${CMAKE_BINARY_DIR}/../../../build/windows/x64/runner/Debug/"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/avcodec-60.dll"
            "${CMAKE_BINARY_DIR}/../../../build/windows/x64/runner/Debug/"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/avutil-58.dll"
            "${CMAKE_BINARY_DIR}/../../../build/windows/x64/runner/Debug/"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FFMPEG_ROOT_DIR}/swresample-4.dll"
            "${CMAKE_BINARY_DIR}/../../../build/windows/x64/runner/Debug/"
        COMMENT "Copying FFMPEG DLLs to Flutter build directory"
    )
endif()
```

### 4. Comprehensive Testing Framework

#### Real Audio File Testing

**Test Data Management**:
```dart
class AudioTestDataManager {
  static const Map<String, String> testFiles = {
    'mp3_sample': 'test/assets/sample.mp3',
    'wav_sample': 'test/assets/sample.wav', 
    'flac_sample': 'test/assets/sample.flac',
    'ogg_sample': 'test/assets/sample.ogg',
    'mp4_sample': 'test/assets/sample.mp4',
  };
  
  Future<Uint8List> loadTestFile(String key);
  Future<Map<String, dynamic>> getExpectedResults(String key);
}
```

#### FFMPEG Wrapper Tests

**Core Functionality Tests**:
```dart
group('FFMPEG Format Detection', () {
  test('should detect MP3 format correctly', () async {
    final mp3Data = await AudioTestDataManager().loadTestFile('mp3_sample');
    final format = sonixDetectFormat(mp3Data);
    expect(format, equals(SonixFormat.mp3));
  });
  
  // Similar tests for WAV, FLAC, OGG, MP4
});

group('FFMPEG Audio Decoding', () {
  test('should decode MP3 audio correctly', () async {
    final mp3Data = await AudioTestDataManager().loadTestFile('mp3_sample');
    final audioData = await sonixDecodeAudio(mp3Data, SonixFormat.mp3);
    
    expect(audioData, isNotNull);
    expect(audioData.samples, isNotEmpty);
    expect(audioData.sampleRate, greaterThan(0));
    expect(audioData.channels, greaterThan(0));
    
    // Verify against expected results
    final expected = await AudioTestDataManager().getExpectedResults('mp3_sample');
    expect(audioData.sampleRate, equals(expected['sampleRate']));
    expect(audioData.channels, equals(expected['channels']));
  });
});
```

#### Memory Management Tests

**Resource Cleanup Validation**:
```dart
group('FFMPEG Memory Management', () {
  test('should properly cleanup chunked decoder resources', () async {
    final decoder = await sonixInitChunkedDecoder(SonixFormat.mp3, 'test/assets/sample.mp3');
    expect(decoder, isNotNull);
    
    // Process some chunks
    final chunk = FileChunk(startByte: 0, endByte: 4096, chunkIndex: 0);
    final result = await sonixProcessFileChunk(decoder, chunk);
    expect(result.success, isTrue);
    
    // Cleanup and verify no memory leaks
    sonixCleanupChunkedDecoder(decoder);
    
    // Verify decoder is properly cleaned up (implementation-specific checks)
  });
});
```

## Data Models

### Binary Configuration

```dart
class FFMPEGBinaryConfig {
  final Platform platform;
  final Architecture architecture;
  final String version;
  final Map<String, String> libraryPaths;
  final List<String> requiredSymbols;
  
  const FFMPEGBinaryConfig({
    required this.platform,
    required this.architecture,
    required this.version,
    required this.libraryPaths,
    required this.requiredSymbols,
  });
}
```

### Binary Validation Result

```dart
class BinaryValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> missingSymbols;
  final String? detectedVersion;
  final Map<String, dynamic> metadata;
  
  const BinaryValidationResult({
    required this.isValid,
    this.errorMessage,
    this.missingSymbols = const [],
    this.detectedVersion,
    this.metadata = const {},
  });
}
```

### Platform Detection

```dart
class PlatformInfo {
  final Platform platform;
  final Architecture architecture;
  final String osVersion;
  final List<String> expectedLibraryExtensions;
  final List<String> librarySearchPaths;
  
  static PlatformInfo detect() {
    // Implementation for detecting current platform
  }
  
  List<String> getExpectedLibraryNames() {
    // Return platform-specific library names
    switch (platform) {
      case Platform.windows:
        return ['avformat-60.dll', 'avcodec-60.dll', 'avutil-58.dll', 'swresample-4.dll'];
      case Platform.macos:
        return ['libavformat.dylib', 'libavcodec.dylib', 'libavutil.dylib', 'libswresample.dylib'];
      case Platform.linux:
        return ['libavformat.so', 'libavcodec.so', 'libavutil.so', 'libswresample.so'];
    }
  }
}
```

## Error Handling

### Fail-Fast Error Strategy

**Philosophy**: The system should fail immediately and clearly when FFMPEG libraries are not available, rather than falling back to stubs.

```c
// Example error handling in native wrapper
int sonix_ffmpeg_init(void) {
    // Try to load FFMPEG libraries
    if (!load_ffmpeg_libraries()) {
        set_error_message("FFMPEG libraries not found. Please run: dart run tools/download_ffmpeg_binaries.dart");
        return SONIX_ERROR_FFMPEG_NOT_AVAILABLE;
    }
    
    // Initialize FFMPEG
    if (avformat_network_init() < 0) {
        set_error_message("Failed to initialize FFMPEG network components");
        return SONIX_ERROR_FFMPEG_INIT_FAILED;
    }
    
    return SONIX_OK;
}
```

### FFMPEG Error Translation

**Strategy**: Provide clear, actionable error messages that help users resolve issues.

```c
int translate_ffmpeg_error(int ffmpeg_error) {
    switch (ffmpeg_error) {
        case AVERROR_INVALIDDATA:
            set_error_message("Invalid audio data format. File may be corrupted.");
            return SONIX_ERROR_INVALID_DATA;
        case AVERROR(ENOMEM):
            set_error_message("Out of memory during audio processing.");
            return SONIX_ERROR_OUT_OF_MEMORY;
        case AVERROR_DECODER_NOT_FOUND:
            set_error_message("Audio codec not supported by FFMPEG installation.");
            return SONIX_ERROR_CODEC_NOT_SUPPORTED;
        default:
            set_error_message("FFMPEG processing failed with unknown error.");
            return SONIX_ERROR_FFMPEG_DECODE_FAILED;
    }
}
```

## Testing Strategy

### 1. Unit Tests with Real Audio Files

**FFMPEG Wrapper Tests**:
- Test format detection with actual audio file headers
- Test decoding accuracy with known audio samples
- Test memory management with real FFMPEG contexts
- Test error handling with invalid/corrupted files

**No Mock/Stub Tests**:
- All tests must use real FFMPEG libraries
- All tests must use real audio files
- No simulated or mocked FFMPEG behavior

### 2. Integration Tests

**End-to-End Processing**:
- Test complete audio processing pipeline with real files
- Test isolate-based processing with actual FFMPEG contexts
- Test chunked processing with large real audio files
- Test cross-platform binary loading

### 3. Binary Validation Tests

**Binary Compatibility**:
- Test binary download and installation
- Test symbol verification on downloaded binaries
- Test version compatibility checking
- Test platform-specific binary loading

### 4. Performance Tests

**Real-World Performance**:
- Benchmark decoding speed with actual audio files
- Memory usage measurement with real FFMPEG contexts
- Comparison with previous implementations using same test data

## Implementation Phases

### Phase 1: Remove All Stubs and Mocks
1. Delete all stub implementations (`sonix_native_stub.c`, etc.)
2. Remove mock FFMPEG implementations from tests
3. Update CMakeLists.txt to require FFMPEG libraries
4. Ensure build fails when FFMPEG is not available

### Phase 2: Create Binary Download System
1. Implement binary downloader for each platform
2. Create binary validator with symbol checking
3. Set up reliable binary sources
4. Test binary download and installation

### Phase 3: Robust Native Wrapper
1. Rewrite native wrapper to use only real FFMPEG
2. Implement proper FFMPEG initialization and cleanup
3. Add comprehensive error handling and translation
4. Test with real FFMPEG libraries

### Phase 4: Comprehensive Testing
1. Create test suite using real audio files
2. Implement memory management validation
3. Add cross-platform binary loading tests
4. Performance benchmarking with real data

### Phase 5: Documentation and User Experience
1. Create clear setup instructions
2. Document binary requirements and sources
3. Provide troubleshooting guides
4. User-friendly error messages

## Security and Reliability Considerations

### Binary Security
- Verify checksums of downloaded binaries
- Use trusted sources for binary downloads
- Validate binary signatures where available
- Scan for malicious code in downloaded binaries

### Reliability
- Graceful handling of missing or corrupted binaries
- Clear error messages with resolution steps
- Robust memory management in native wrapper
- Comprehensive testing with edge cases

## Performance Considerations

### Optimization Strategies
- Efficient FFMPEG context reuse
- Minimal memory allocations
- Platform-specific optimizations
- Lazy loading of FFMPEG libraries

### Memory Management
- Proper cleanup of FFMPEG contexts
- Buffer reuse where possible
- Memory leak detection in tests
- Resource monitoring and reporting

## User Experience

### Setup Process
1. User runs: `dart run tools/download_ffmpeg_binaries.dart`
2. Script downloads appropriate binaries for platform
3. Binaries are installed to `native/[platform]/` directory
4. **CRITICAL**: When building Flutter app, binaries are automatically copied to Flutter build directories:
   - Windows: `build/windows/x64/runner/Debug/`
   - macOS: `build/macos/Build/Products/Debug/`
   - Linux: `build/linux/x64/debug/bundle/lib/`
5. User can immediately use Sonix with FFMPEG

### Flutter Build Integration
- CMake build system automatically copies FFMPEG binaries to Flutter build directories
- No manual copying required by user
- Binaries are available at runtime when Flutter loads the native library
- For testing, binaries are also copied to `test/` directory

### Error Handling
- Clear error messages when binaries are missing from Flutter build directories
- Helpful suggestions for resolving issues (run download script, rebuild native library)
- Links to documentation and troubleshooting guides
- Platform-specific instructions for manual binary placement