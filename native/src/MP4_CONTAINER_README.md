# MP4 Container Parsing Implementation

This document describes the MP4 container parsing functionality implemented in `mp4_container.c` and `mp4_container.h`.

## Overview

The MP4 container parsing module provides functions to parse and validate MP4 file structure, extract audio track information, and validate container integrity. This is the foundation for MP4 audio decoding support in the Sonix library.

## Key Features

- **MP4 Box Parsing**: Parse MP4 box headers and navigate box hierarchy
- **Container Validation**: Validate MP4 file structure and supported brands
- **Audio Track Detection**: Find and extract audio track information
- **Sample Table Parsing**: Parse sample tables for chunked processing support
- **Error Handling**: Comprehensive error detection and reporting

## Core Functions

### Box Parsing
- `mp4_parse_box_header()` - Parse MP4 box headers (supports both 32-bit and 64-bit sizes)
- `mp4_find_box()` - Find specific box types within MP4 data
- `mp4_validate_ftyp_box()` - Validate file type box and supported brands

### Container Analysis
- `mp4_validate_container()` - Validate complete MP4 container structure
- `mp4_find_audio_track()` - Locate and parse audio track information
- `mp4_parse_sample_table()` - Extract sample table information for seeking

### Metadata Extraction
- `mp4_parse_mdhd_box()` - Parse media header for timing information
- `mp4_parse_hdlr_box()` - Parse handler reference to identify track types
- `mp4_parse_stsd_box()` - Parse sample description for codec information

## Data Structures

### Mp4BoxHeader
Contains parsed box header information including size, type, and header size.

### Mp4AudioTrack
Complete audio track information including:
- Track ID and media header
- Sample description (codec, channels, sample rate)
- Sample table information for chunked processing

### Mp4SampleTable
Sample table information for efficient seeking and chunked processing:
- Sample count and chunk count
- Sample size information
- Chunk offset availability

## Supported MP4 Features

### Container Types
- ISO Base Media File Format (isom)
- MP4 version 1 and 2 (mp41, mp42)
- M4A audio containers (M4A)
- M4B audiobook containers (M4B)

### Audio Codecs
- AAC (mp4a) - Primary supported codec
- Extensible to other codecs in future implementations

### Box Types
- `ftyp` - File type and brand information
- `moov` - Movie metadata container
- `trak` - Track container
- `mdia` - Media information
- `mdhd` - Media header (timing)
- `hdlr` - Handler reference (track type)
- `minf` - Media information
- `stbl` - Sample table
- `stsd` - Sample description (codec info)
- `stsz` - Sample sizes
- `stco`/`co64` - Chunk offsets

## Error Handling

The implementation provides detailed error reporting for:
- Invalid container structure
- Missing required boxes
- Unsupported codecs
- Corrupted data
- Missing audio tracks

Error codes are defined in `sonix_native.h`:
- `SONIX_ERROR_MP4_CONTAINER_INVALID`
- `SONIX_ERROR_MP4_NO_AUDIO_TRACK`
- `SONIX_ERROR_MP4_UNSUPPORTED_CODEC`

## Integration

The MP4 container parsing is integrated into the main Sonix native library:

1. **Format Detection**: `sonix_detect_format()` recognizes MP4 ftyp signature
2. **Container Validation**: `decode_mp4()` validates container before decoding
3. **Metadata Extraction**: Audio track information is extracted for decoding setup
4. **Error Propagation**: Container errors are properly reported through existing error system

## Testing

Comprehensive test suite includes:
- **Unit Tests** (`mp4_container_test.c`): Test individual parsing functions
- **Integration Tests** (`mp4_integration_test.c`): Test integration with main library
- **Error Handling Tests**: Validate proper error detection and reporting

## Future Enhancements

The current implementation provides the foundation for:
- Full AAC audio decoding (Task 18)
- Chunked processing support (Task 19)
- Advanced seeking capabilities
- Additional codec support

## Build Instructions

The MP4 container parsing is automatically included when building the native library:

```bash
mkdir build && cd build
cmake -DBUILD_TESTS=ON ..
cmake --build .

# Run tests
./mp4_container_test
./mp4_integration_test
```

## Performance Considerations

- Efficient box traversal without loading entire file
- Minimal memory allocation during parsing
- Lazy loading of sample table information
- Optimized for streaming and chunked processing scenarios