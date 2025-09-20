# Implementation Plan

- [x] 1. Extend core enums and constants for MP4 support

  - Add MP4 format to AudioFormat enum with extensions and name
  - Update native constants to include SONIX_FORMAT_MP4 and MP4-specific error codes
  - Extend NativeAudioBindings format conversion methods for MP4
  - _Requirements: 1.1, 3.1, 4.1_

- [x] 2. Update AudioDecoderFactory for MP4 format detection

  - Add MP4 file extension detection (.mp4, .m4a) to detectFormat method
  - Implement MP4 magic byte detection (\_checkMP4Signature method)
  - Update createDecoder method to return MP4Decoder for MP4 format
  - Update supported formats and extensions lists to include MP4
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 3. Create MP4-specific data models and exceptions

  - Create MP4ContainerInfo class with duration, bitrate, codec info, and sample table
  - Create MP4SampleInfo class for sample offset, size, timestamp, and keyframe data
  - Implement MP4ContainerException, MP4CodecException, and MP4TrackException classes
  - Write unit tests for MP4 data models and exception classes
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 7.5_

- [x] 4. Implement basic MP4Decoder class structure

  - Create MP4Decoder class implementing AudioDecoder and ChunkedAudioDecoder interfaces
  - Implement constructor, dispose method, and basic state management
  - Add MP4-specific instance variables for metadata and chunked processing state
  - Implement \_checkDisposed helper method and basic error handling

  - Write unit tests for MP4Decoder class instantiation and disposal
  - _Requirements: 1.1, 7.1, 7.2_

- [x] 5. Implement MP4 container parsing functionality

  - Create \_parseMP4Container method to extract metadata from MP4 header
  - Implement \_buildSampleIndex method for creating sample-to-byte offset mapping
  - Add \_estimateDurationFromContainer method for duration calculation
  - Create helper methods for MP4 box parsing and validation
  - Write unit tests for container parsing with synthetic MP4 data
  - _Requirements: 1.2, 1.3, 6.1, 6.4_

- [x] 6. Implement basic MP4 audio decoding

  - Implement decode method for full file MP4 decoding using native bindings
  - Add proper error handling for corrupted files, missing audio tracks, and unsupported codecs
  - Implement resource cleanup and memory management
  - Create integration with NativeAudioBindings.decodeAudio for MP4 format
  - Write unit tests for basic MP4 decoding with various file types
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 6.1, 6.2, 6.3, 6.4_

- [x] 7. Implement chunked processing initialization


  - Implement initializeChunkedDecoding method with file path and optional seek position
  - Add file validation, metadata extraction, and sample index building
  - Implement seekToTime method with MP4-specific seeking logic
  - Add proper state management for chunked processing mode
  - Write unit tests for chunked processing initialization and seeking
  - _Requirements: 2.1, 2.3, 2.5_

- [ ] 8. Implement chunked file processing

  - Implement processFileChunk method for processing MP4 file chunks
  - Add buffer management for AAC frame boundaries and incomplete chunks
  - Implement proper AudioChunk creation with correct sample positioning
  - Add handling for last chunk processing and cleanup
  - Write unit tests for chunk processing with various chunk sizes
  - _Requirements: 2.1, 2.2, 2.5_

- [ ] 9. Implement chunk size optimization and metadata methods

  - Implement getOptimalChunkSize method with MP4-specific recommendations
  - Add getFormatMetadata method returning MP4 format information
  - Implement estimateDuration method for duration estimation
  - Add cleanupChunkedProcessing method for proper resource cleanup
  - Write unit tests for optimization methods and metadata retrieval
  - _Requirements: 2.4, 2.5, 2.6_

- [ ] 10. Extend native bindings for MP4 support

  - Update NativeAudioBindings to handle SONIX_FORMAT_MP4 in format conversion methods
  - Add MP4-specific memory usage estimation in estimateDecodedMemoryUsage method
  - Update wouldExceedMemoryLimits method to handle MP4 compression ratios
  - Implement error message handling for MP4-specific error codes
  - Write unit tests for native bindings MP4 integration
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 11. Create comprehensive MP4 decoder unit tests

  - Create mp4_decoder_test.dart with tests for all MP4Decoder public methods
  - Test decode method with various MP4 file types and error conditions
  - Test chunked processing methods with different scenarios
  - Test error handling for corrupted files, missing tracks, and unsupported codecs
  - Test resource cleanup and memory management
  - _Requirements: 5.1, 5.4, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [ ] 12. Create MP4 chunked processing tests

  - Create mp4_chunked_decoder_test.dart for chunked processing functionality
  - Test initializeChunkedDecoding with various file sizes and seek positions
  - Test processFileChunk with different chunk sizes and boundary conditions
  - Test seekToTime accuracy and performance with MP4 files
  - Test memory management during chunked processing
  - _Requirements: 5.3, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 13. Create MP4 format detection and factory tests

  - Add MP4 format detection tests to existing factory test files
  - Test file extension detection for .mp4 and .m4a files
  - Test magic byte detection for MP4 container format
  - Test MP4Decoder creation through AudioDecoderFactory
  - Test supported formats and extensions lists include MP4
  - _Requirements: 5.5, 5.6, 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 14. Generate MP4 test assets and data

  - Create MP4TestDataGenerator tool for generating synthetic test files
  - Generate mp4_tiny_44100_2ch.mp4, mp4_small_44100_2ch.mp4, mp4_medium_44100_2ch.mp4
  - Create corrupted MP4 files for error handling tests
  - Generate MP4 files with no audio tracks and unsupported codecs
  - Add real-world MP4 test files with various characteristics
  - _Requirements: 5.2, 5.4, 6.1, 6.2, 6.3, 6.4_

- [ ] 15. Create MP4 integration and performance tests

  - Create mp4_real_files_test.dart for testing with real MP4 files
  - Test MP4 decoding accuracy and performance compared to other formats
  - Create mp4_performance_test.dart for performance benchmarking
  - Test memory usage validation during MP4 processing
  - Test cross-platform compatibility for MP4 decoding
  - _Requirements: 5.2, 5.7_

- [ ] 16. Update native library with MP4 support foundation

  - Add SONIX_FORMAT_MP4 constant and MP4-specific error codes to sonix_native.h
  - Create SonixMp4Metadata structure for MP4-specific metadata
  - Add MP4 format detection to sonix_detect_format function
  - Update sonix_decode_audio function to handle MP4 format
  - Add placeholder implementations for MP4 decoding functions
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 17. Implement native MP4 container parsing

  - Create mp4_container.c with functions for parsing MP4 box structure
  - Implement functions to extract audio track information and sample tables
  - Add validation for MP4 container structure and audio track presence
  - Implement helper functions for reading MP4 box headers and data
  - Write native code tests for container parsing functionality
  - _Requirements: 1.2, 6.1, 6.4_

- [ ] 18. Integrate FAAD2 library for AAC decoding

  - Add FAAD2 library integration to CMakeLists.txt build system
  - Create mp4_decoder.c with FAAD2 decoder initialization and cleanup
  - Implement AAC decoding functions using FAAD2 API
  - Add proper error handling for FAAD2 decoder errors
  - Test FAAD2 integration with sample AAC data
  - _Requirements: 1.2, 1.3, 4.2, 4.3_

- [ ] 19. Implement native MP4 chunked processing

  - Create SonixMp4Context structure for maintaining decoder state
  - Implement sonix_init_mp4_chunked_decoder function
  - Add sonix_process_mp4_chunk function for processing file chunks
  - Implement sonix_seek_mp4_to_time function for time-based seeking
  - Add sonix_cleanup_mp4_decoder function for resource cleanup
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 4.2, 4.3_

- [ ] 20. Complete native MP4 implementation and testing

  - Implement full MP4 decoding in sonix_decode_audio function
  - Add comprehensive error handling and resource cleanup
  - Create native unit tests for MP4 decoding functionality
  - Test memory management and error conditions in native code
  - Validate cross-platform compatibility of native MP4 implementation
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 21. Run comprehensive test suite and validation

  - Execute all MP4-related unit tests and ensure they pass
  - Run integration tests with real MP4 files of various types
  - Perform performance benchmarking against other supported formats
  - Validate memory usage and resource cleanup
  - Test error handling with corrupted and invalid MP4 files
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [ ] 22. Update documentation and finalize implementation
  - Add MP4 format to API documentation and supported formats lists
  - Update README and examples to include MP4 usage
  - Add code comments and documentation for MP4-specific functionality
  - Create migration guide for developers adding MP4 support
  - Validate that all requirements are met and implementation is complete
  - _Requirements: 7.5, 7.6_
