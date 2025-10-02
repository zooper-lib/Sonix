# Real Audio Files for Testing

This directory contains real audio files for comprehensive integration and functionality testing.

## Purpose

- Test against actual audio files from real-world scenarios
- Verify Sonix functionality works with diverse audio content and formats
- Integration testing with user-provided audio files across different use cases
- Performance testing with various file sizes, sample rates, and encoding qualities
- Compatibility testing with files from different sources and encoders

## Usage

1. Place your audio files (MP3, WAV, FLAC, etc.) in this directory
2. Run integration tests: `flutter test test/integration/real_audio_integration_test.dart`
3. Run all integration tests: `flutter test test/integration/`
4. Tests will automatically discover and process all audio files in this folder

## Supported Formats

- **MP3** - Including files with various bitrates, VBR/CBR, and different encoder quirks
- **WAV** - Uncompressed PCM audio for reference testing
- **FLAC** - Lossless compression testing
- **OGG Vorbis** - Alternative compressed format
- **Opus** - Modern low-latency codec
- **MP4**

## Integration Test Coverage

- **Waveform generation** across all formats and configurations
- **Metadata extraction** from various file types
- **Performance benchmarking** with different file sizes
- **Memory usage** with large files
- **Error handling** with corrupted or unusual files
- **Log level configuration** with files that produce warnings
- **Cross-platform compatibility** testing

## Note

- **Files in this directory are gitignored** - they will not be committed to version control
- This allows testing with copyrighted material without legal issues
- Each developer can use their own collection of test files
- Recommended to include a variety of sources: music, podcasts, sound effects, etc.
- Consider including files that have caused issues in the past
