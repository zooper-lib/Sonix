# Implementation Plan

- [x] 1. Remove all existing FFMPEG stubs and mock implementations

  - Delete all stub implementation files (sonix_native_stub.c, sonix_native_stub.c.in)
  - Remove mock FFMPEG implementations from performance tests
  - Update CMakeLists.txt to fail when FFMPEG libraries are not found
  - Remove conditional compilation paths that fall back to stubs
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 1.1 Clean up existing FFMPEG build automation

  - Remove or deprecate existing FFMPEG source building tools
  - Clean up tools/ffmpeg directory of source building scripts
  - Remove setup_ffmpeg.dart source building functionality
  - Update documentation to reflect binary-only approach
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 2. Create FFMPEG binary download and management system

  - Implement FFMPEGBinaryDownloader class for downloading pre-built binaries
  - Create platform-specific binary source configurations
  - Implement binary integrity verification using checksums
  - Add support for Windows DLLs, macOS dylibs, and Linux shared objects
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 2.1 Implement binary validation and symbol checking

  - Create FFMPEGBinaryValidator class for verifying downloaded binaries
  - Implement symbol verification using nm, objdump, and readelf tools
  - Add version compatibility checking for FFMPEG binaries
  - Create architecture validation for downloaded binaries
  - _Requirements: 3.4, 3.5, 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 2.2 Implement Flutter build directory integration

  - Create binary installer that copies to Flutter build directories
  - Add support for Windows build/windows/x64/runner/Debug/ path
  - Add support for macOS build/macos/Build/Products/Debug/ path
  - Add support for Linux build/linux/x64/debug/bundle/lib/ path
  - Copy binaries to test/ directory for unit test execution
  - _Requirements: 3.3, 6.1, 6.2, 6.3_

- [x] 3. Rewrite native FFMPEG wrapper without stubs

  - Create new sonix_ffmpeg.c that only works with real FFMPEG libraries
  - Implement proper FFMPEG initialization and fail-fast error handling
  - Add real FFMPEG format detection using av_probe_input_format
  - Implement audio decoding using avformat, avcodec, and swresample
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 4.1, 4.2, 4.3_

- [x] 3.1 Implement robust FFMPEG memory management

  - Add proper FFMPEG context initialization and cleanup
  - Implement chunked processing with real FFMPEG contexts
  - Add comprehensive error handling and FFMPEG error translation
  - Ensure no memory leaks in FFMPEG resource management
  - _Requirements: 4.1, 4.4, 4.5_

- [x] 3.2 Update CMakeLists.txt for binary-only FFMPEG integration

  - Remove all stub compilation paths from CMakeLists.txt
  - Add required FFMPEG library finding with NO_DEFAULT_PATH
  - Implement automatic copying of FFMPEG binaries to Flutter build directories
  - Add platform-specific library path configurations
  - Fail build immediately if FFMPEG libraries are not found
  - _Requirements: 1.2, 1.3, 2.5, 6.1, 6.2, 6.3_

- [x] 4. Create comprehensive unit tests using real FFMPEG and audio files

  - Create AudioTestDataManager for managing real audio test files
  - Add test audio files for MP3, WAV, FLAC, OGG, and MP4 formats
  - Implement format detection tests using real audio file headers
  - Create audio decoding tests that verify sample extraction accuracy
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 4.1 Implement FFMPEG memory management and error handling tests

  - Create tests for proper FFMPEG context cleanup and resource management
  - Add tests for chunked processing with real large audio files
  - Implement error handling tests using invalid/corrupted audio files
  - Create memory leak detection tests for FFMPEG integration
  - _Requirements: 5.4, 5.5, 5.6_

- [x] 4.2 Create cross-platform binary loading tests

  - Test FFMPEG binary loading on Windows with DLL files
  - Test FFMPEG binary loading on macOS with dylib files
  - Test FFMPEG binary loading on Linux with shared object files
  - Verify platform-specific binary path resolution
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 5. Update Dart FFI bindings and API integration

  - Modify existing Dart FFI bindings to work with new native wrapper
  - Ensure SonixInstance API remains unchanged for backward compatibility
  - Update error handling to provide clear messages when FFMPEG is missing
  - Test isolate-based processing with real FFMPEG contexts
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 5.1 Create binary download command-line tool

  - Implement tools/download_ffmpeg_binaries.dart as main user interface
  - Add command-line options for platform selection and binary sources
  - Provide progress reporting during binary download and installation
  - Add validation and verification steps with clear success/failure messages
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 6. Performance testing and benchmarking with real data


  - Create performance tests using actual audio files and real FFMPEG
  - Benchmark decoding speed compared to previous implementations
  - Add memory usage measurement during real FFMPEG processing
  - Test concurrent processing with multiple real FFMPEG contexts
  - _Requirements: 5.1, 5.3, 7.5_

- [x] 6.1 Integration testing with Flutter build system

  - Test complete Flutter app build with FFMPEG binary integration
  - Verify binaries are correctly copied to Flutter build directories
  - Test runtime loading of FFMPEG binaries in Flutter applications
  - Add end-to-end testing from binary download to Flutter app execution
  - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2_

- [ ] 7. Documentation and user experience improvements

  - Create comprehensive setup guide for binary download and installation
  - Document platform-specific requirements and binary sources
  - Add troubleshooting guide for common FFMPEG binary issues
  - Update API documentation to reflect FFMPEG binary requirements
  - _Requirements: 1.2, 3.5, 6.5_

- [ ] 7.1 Create user-friendly error messages and diagnostics
  - Implement clear error messages when FFMPEG binaries are missing
  - Add diagnostic tools to check binary installation and compatibility
  - Provide step-by-step resolution instructions for common issues
  - Create platform-specific troubleshooting documentation
  - _Requirements: 1.2, 3.5, 6.5_
