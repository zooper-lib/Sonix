# Sonix Native Library

This directory contains the native C implementation for Sonix audio processing, now integrated with FFMPEG libraries.

## Overview

The native library provides high-performance audio decoding using FFMPEG libraries while maintaining compatibility with the existing Sonix API. The implementation supports both full FFMPEG integration and a fallback stub implementation when FFMPEG libraries are not available.

## Architecture

### FFMPEG Integration (`src/ffmpeg_wrapper.c`)

The main implementation uses FFMPEG libraries for:
- Audio format detection using `av_probe_input_format()`
- Audio decoding with `avcodec_decode_audio4()`
- Format conversion to float samples using `swr_convert()`
- Chunked processing for large files
- Seeking functionality for time-based navigation

### Stub Implementation (`src/sonix_native_stub.c`)

When FFMPEG libraries are not available, the build system automatically falls back to a stub implementation that:
- Returns appropriate error codes indicating FFMPEG is not available
- Maintains API compatibility
- Provides helpful error messages directing users to run the setup script

## Build System

### CMake Configuration (`CMakeLists.txt`)

The build system automatically:
- Detects the target platform (Windows, macOS, Linux, Android, iOS)
- Searches for FFMPEG libraries in platform-specific directories
- Falls back to stub implementation if FFMPEG is not found
- Handles platform-specific linking and library copying
- Supports conditional compilation based on FFMPEG availability

### Platform-Specific Directories

FFMPEG libraries should be placed in platform-specific subdirectories:
- `windows/` - Windows DLL files
- `macos/` - macOS dylib files  
- `linux/` - Linux shared object files
- `android/` - Android NDK libraries
- `ios/` - iOS framework or static libraries

## Building

### Prerequisites

- CMake 3.10 or later
- Platform-appropriate C compiler:
  - Windows: Visual Studio or MinGW
  - macOS: Xcode command line tools
  - Linux: GCC or Clang
  - Android: Android NDK
  - iOS: Xcode

### Build Scripts

#### Unix-like Systems (Linux, macOS)
```bash
./build.sh
```

#### Windows
```cmd
build.bat
```

### Manual Build
```bash
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make
```

## FFMPEG Setup

To build FFMPEG libraries for your platform:

```bash
dart run tools/setup_ffmpeg.dart
```

This will:
1. Download FFMPEG source code
2. Configure with LGPL-compatible options
3. Build platform-specific libraries
4. Install them in the correct directories

## API Functions

### Core Functions

- `sonix_detect_format()` - Detect audio format from file data
- `sonix_decode_audio()` - Decode audio data to float samples
- `sonix_free_audio_data()` - Free allocated audio data
- `sonix_get_error_message()` - Get last error message

### Chunked Processing

- `sonix_init_chunked_decoder()` - Initialize chunked decoder
- `sonix_process_file_chunk()` - Process file chunk
- `sonix_seek_to_time()` - Seek to time position
- `sonix_get_optimal_chunk_size()` - Get optimal chunk size
- `sonix_cleanup_chunked_decoder()` - Cleanup decoder
- `sonix_free_chunk_result()` - Free chunk result

## Error Handling

The library provides comprehensive error handling with specific error codes:

### Standard Errors
- `SONIX_OK` (0) - Success
- `SONIX_ERROR_INVALID_FORMAT` (-1) - Invalid audio format
- `SONIX_ERROR_DECODE_FAILED` (-2) - Decoding failed
- `SONIX_ERROR_OUT_OF_MEMORY` (-3) - Out of memory
- `SONIX_ERROR_INVALID_DATA` (-4) - Invalid input data

### FFMPEG-Specific Errors
- `SONIX_ERROR_FFMPEG_INIT_FAILED` (-20) - FFMPEG initialization failed
- `SONIX_ERROR_FFMPEG_PROBE_FAILED` (-21) - Format probing failed
- `SONIX_ERROR_FFMPEG_CODEC_NOT_FOUND` (-22) - Codec not found
- `SONIX_ERROR_FFMPEG_DECODE_FAILED` (-23) - FFMPEG decoding failed
- `SONIX_ERROR_FFMPEG_NOT_AVAILABLE` (-100) - FFMPEG not available (stub mode)

## Memory Management

The library handles memory management automatically:
- All allocated structures must be freed using the appropriate `sonix_free_*()` functions
- FFMPEG contexts are properly cleaned up in chunked decoders
- Buffer reallocation is handled automatically during decoding
- Memory pressure thresholds are respected for large files

## Platform-Specific Notes

### Windows
- FFMPEG DLLs are automatically copied to the output directory
- Requires Visual Studio or MinGW compiler
- Uses Windows-specific library loading

### macOS
- Supports both x86_64 and arm64 architectures
- Can build as framework for iOS
- Uses dylib format for libraries

### Linux
- Supports various distributions
- Uses standard shared object format
- Requires development packages for system libraries

### Android
- Uses Android NDK for compilation
- Supports multiple architectures (arm64-v8a, armeabi-v7a, x86_64)
- Integrates with Flutter's Android build system

### iOS
- Can build as static library or framework
- Supports both device and simulator architectures
- Requires Xcode toolchain

## Troubleshooting

### FFMPEG Not Found
If you see "FFMPEG libraries not found" warnings:
1. Run `dart run tools/setup_ffmpeg.dart` to build FFMPEG
2. Ensure libraries are in the correct platform directory
3. Check that library names match expected patterns

### Build Failures
- Ensure CMake and appropriate compiler are installed
- Check that all dependencies are available
- Verify platform-specific build tools are in PATH

### Runtime Errors
- Check that FFMPEG libraries are in the same directory as the native library
- Verify that the audio file format is supported
- Ensure sufficient memory is available for large files

## License Compliance

The native library maintains MIT license compatibility:
- FFMPEG is built with LGPL-only components
- Dynamic linking is used to comply with LGPL requirements
- No FFMPEG source code is included in the package
- Users must build FFMPEG libraries separately