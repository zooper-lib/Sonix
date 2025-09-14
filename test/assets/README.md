# Test Assets Directory

This directory contains test files for the Sonix audio processing library.

## Directory Structure

```
test/assets/
├── README.md                    # This file
├── generated/                   # Generated test files (excluded from git)
│   ├── *.wav                   # Generated WAV test files
│   ├── *.mp3                   # Generated MP3 test files  
│   ├── *.flac                  # Generated FLAC test files
│   ├── *.ogg                   # Generated OGG test files
│   ├── corrupted_*             # Corrupted files for error testing
│   ├── invalid_*               # Invalid files for error testing
│   └── large_files/            # Large test files (>50MB)
├── reference_waveforms.json    # Reference waveform data
├── test_configurations.json    # Test configuration data
└── [existing test files]       # Pre-existing small test files
```

## Generated Files

The `generated/` directory contains test files that are automatically created by the test suite:

- **Size Categories**: tiny (100KB), small (1MB), medium (10MB), large (100MB), xlarge (500MB)
- **Audio Formats**: WAV, MP3, FLAC, OGG
- **Audio Characteristics**: Various sample rates (8kHz-96kHz), channel counts (1-6), bit depths (16-24)
- **Corrupted Files**: Files with various types of corruption for error handling tests
- **Large Files**: Files >50MB are stored in the `large_files/` subdirectory

## Git Exclusion

Generated test files are excluded from version control via `.gitignore` because:

1. **Size**: Generated files can total several GB
2. **Reproducibility**: Files are generated deterministically by the test suite
3. **CI/CD**: Generated on-demand during testing

## Generating Test Files

Test files are automatically generated when running comprehensive tests:

```bash
# Generate and run comprehensive tests
flutter test test/practical_comprehensive_test_suite.dart

# Or generate files manually
dart test/run_comprehensive_tests.dart --generate-only
```

## File Naming Convention

Generated files follow this naming pattern:
```
{format}_{size}_{sampleRate}_{channels}ch.{extension}
```

Examples:
- `wav_small_44100_2ch.wav` - Small WAV file, 44.1kHz, stereo
- `mp3_medium_48000_1ch.mp3` - Medium MP3 file, 48kHz, mono
- `flac_large_96000_2ch.flac` - Large FLAC file, 96kHz, stereo

## Cleanup

To clean up generated files:

```bash
# Remove all generated files
rm -rf test/assets/generated/

# Or use the test runner
dart test/run_comprehensive_tests.dart --cleanup
```