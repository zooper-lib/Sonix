# Test Audio Assets

This directory contains test audio files and data for comprehensive testing of the Sonix audio waveform package.

## Test Audio Files

### Valid Audio Files
- `test_mono_44100.wav` - Mono WAV file, 44.1kHz, 1 second duration
- `test_stereo_44100.wav` - Stereo WAV file, 44.1kHz, 1 second duration
- `test_mono_48000.wav` - Mono WAV file, 48kHz, 1 second duration
- `test_short.mp3` - Short MP3 file for quick testing
- `test_medium.mp3` - Medium length MP3 file for performance testing
- `test_large.mp3` - Large MP3 file for memory testing
- `test_sample.flac` - FLAC file for lossless format testing
- `test_sample.ogg` - OGG Vorbis file for open format testing
- `test_sample.opus` - Opus file for modern codec testing

### Corrupted Files (for error testing)
- `corrupted_header.mp3` - MP3 file with corrupted header
- `corrupted_data.wav` - WAV file with corrupted audio data
- `truncated.flac` - Truncated FLAC file
- `invalid_format.xyz` - File with unsupported extension
- `empty_file.mp3` - Empty file with MP3 extension

### Reference Waveform Data
- `reference_waveforms.json` - Pre-calculated waveform data for validation
- `test_configurations.json` - Various test configurations and expected results

## File Generation

Test audio files are generated programmatically using synthetic audio data to ensure consistent and predictable test results.