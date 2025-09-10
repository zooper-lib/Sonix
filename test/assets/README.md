# Test Audio Assets

This directory contains test audio files and data for comprehensive testing of the Sonix audio waveform package.

## Test Audio Files

### Valid Audio Files

The following real audio files are used for comprehensive testing across all supported formats:

- `Double-F the King - Your Blessing.mp3` - MP3 format test file
- `Double-F the King - Your Blessing.wav` - WAV format test file
- `Double-F the King - Your Blessing.flac` - FLAC lossless format test file
- `Double-F the King - Your Blessing.ogg` - OGG Vorbis format test file
- `Double-F the King - Your Blessing.opus` - Opus format test file

**Audio Credit:**  
"Your Blessing" by Double F The King  
Source: https://freemusicarchive.org/music/double-f-the-king/heartstrings/your-blessing/  
Licensed under CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)  
No changes were made to the original audio content.

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
