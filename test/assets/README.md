# Test Assets Directory Structure

This directory contains test audio files and related assets for the Sonix package testing suite.

## Directory Structure

```
test/assets/
├── generated/              # Auto-generated test files (primary location)
│   ├── large_files/       # Large test files (>50MB)
│   └── [various formats]  # Generated test files in multiple formats and sizes
├── reference_waveforms.json    # Reference waveform data for validation
├── test_configurations.json   # Test configuration settings
├── test_file_inventory.json   # Inventory of generated test files
└── [legacy files]             # Legacy test files for backward compatibility
```

## File Categories

### Generated Files (`generated/`)
- **Synthetic audio files**: WAV, MP3, FLAC, OGG, MP4 in various sizes (tiny, small, medium, large, xlarge)
- **Corrupted files**: Files with intentional corruption for error testing
- **Edge case files**: Empty files, invalid formats, truncated files, etc.

### Large Files (`generated/large_files/`)
- Files larger than 50MB for performance and memory testing
- Includes xlarge (500MB) files for stress testing

### Configuration Files (root level)
- `reference_waveforms.json`: Expected waveform data for validation
- `test_configurations.json`: Test configuration parameters
- `test_file_inventory.json`: Complete inventory of generated files

### Legacy Files (root level)
- Manually created test files for backward compatibility
- Real audio samples (e.g., "Double-F the King - Your Blessing" series)

## File Generation

Test files are automatically generated using the test data generator:

```bash
# Generate all test files (comprehensive suite)
dart run tools/test_data_generator.dart

# Generate only essential files (faster)
dart run tools/test_data_generator.dart --essential
```

## File Access

Use the `TestDataLoader` class to access test files:

```dart
import 'package:sonix/test/test_helpers/test_data_loader.dart';

// Get path to a test file (checks all directories)
final path = TestDataLoader.getAssetPath('mono_44100.wav');

// Check if a test file exists
final exists = await TestDataLoader.assetExists('sample_audio.flac');

// Get list of all available audio files
final files = await TestDataLoader.getAvailableAudioFiles();
```

The `TestDataLoader` automatically searches in this priority order:
1. `test/assets/generated/large_files/` (for large files)
2. `test/assets/generated/` (for regular generated files)
3. `test/assets/` (for legacy/configuration files)

## File Naming Convention

Generated files follow this pattern:
- `{format}_{size}_{sampleRate}_{channels}ch.{ext}`
- Examples: `wav_small_44100_2ch.wav`, `mp3_tiny_22050_1ch.mp3`

Special files:
- `corrupted_*`: Files with intentional corruption
- `empty_*`: Empty files for error testing
- `invalid_*`: Files with invalid formats/headers

## Size Categories

- **tiny**: ~100KB
- **small**: ~1MB  
- **medium**: ~10MB
- **large**: ~100MB (stored in `large_files/`)
- **xlarge**: ~500MB (stored in `large_files/`)

## Maintenance

- Files are automatically regenerated when running the test data generator
- Use `force: true` parameter to regenerate existing files
- Large files are skipped in CI environments to prevent memory issues
- The inventory file tracks all generated files for validation