# MP4/AAC Decoding with FAAD2 Integration

This document describes the FAAD2 library integration for MP4/AAC audio decoding in the Sonix native library.

## Overview

The MP4 decoder uses the FAAD2 (Freeware Advanced Audio Decoder) library to decode AAC audio streams contained within MP4 containers. FAAD2 is a mature, well-tested AAC decoder that supports various AAC profiles including AAC-LC, AAC-HE, and AAC-HEv2.

## Files

- `mp4_decoder.h` - Header file with MP4 decoder API
- `mp4_decoder.c` - Implementation of MP4/AAC decoding using FAAD2
- `mp4_faad2_test.c` - Test program for FAAD2 integration
- `CMakeLists.txt` - Updated build configuration with FAAD2 detection

## FAAD2 Library Detection

The build system automatically detects FAAD2 availability:

```cmake
# Find FAAD2 library
find_library(FAAD2_LIBRARY NAMES faad2 faad libfaad2 libfaad)
find_path(FAAD2_INCLUDE_DIR NAMES neaacdec.h PATHS /usr/include /usr/local/include /opt/homebrew/include)
```

When FAAD2 is found:
- `HAVE_FAAD2=1` is defined
- FAAD2 library is linked
- Full MP4/AAC decoding is enabled

When FAAD2 is not found:
- `HAVE_FAAD2=0` is defined
- MP4 decoder gracefully reports unavailability
- Build continues without errors

## API Functions

### Core Functions

- `mp4_decoder_init()` - Initialize MP4 decoder context
- `mp4_decoder_init_with_config()` - Configure decoder with AAC parameters
- `mp4_decoder_decode_frame()` - Decode individual AAC frames
- `mp4_decoder_cleanup()` - Clean up decoder resources
- `mp4_decode_file()` - Decode complete MP4 file

### Integration Functions

- `mp4_get_error_message()` - Get detailed error messages
- `mp4_decoder_get_properties()` - Get decoder sample rate and channels

## Error Handling

The MP4 decoder provides comprehensive error handling:

- **FAAD2 unavailable**: Graceful degradation with clear error messages
- **Invalid configuration**: Detailed FAAD2 error reporting
- **Decode failures**: Frame-level error detection and reporting
- **Memory errors**: Proper cleanup on allocation failures

## Usage Example

```c
// Initialize decoder
Mp4DecoderContext* decoder = mp4_decoder_init();
if (!decoder) {
    printf("Error: %s\n", mp4_get_error_message());
    return;
}

// Configure with AAC parameters
uint8_t aac_config[] = {0x12, 0x10}; // AAC-LC, 44.1kHz, stereo
int result = mp4_decoder_init_with_config(decoder, aac_config, sizeof(aac_config));
if (result != SONIX_OK) {
    printf("Config error: %s\n", mp4_get_error_message());
    mp4_decoder_cleanup(decoder);
    return;
}

// Decode AAC frame
float* samples;
uint32_t sample_count;
result = mp4_decoder_decode_frame(decoder, frame_data, frame_size, &samples, &sample_count);
if (result == SONIX_OK) {
    // Process decoded samples
    free(samples);
}

// Cleanup
mp4_decoder_cleanup(decoder);
```

## Testing

Run the FAAD2 integration tests:

```bash
# Build with tests enabled
cmake .. -DBUILD_TESTS=ON
cmake --build . --config Debug

# Run FAAD2-specific test (synthetic data)
./mp4_faad2_test

# Run integration test (synthetic data)
./mp4_integration_test

# Run real MP4 file test (requires actual MP4 file)
./mp4_real_file_test "../../../test/assets/Double-F the King - Your Blessing.mp4"
```

### Test Coverage

1. **mp4_faad2_test**: Tests FAAD2 library integration with synthetic AAC data
   - Decoder initialization and cleanup
   - AAC configuration parsing
   - Frame decoding (when FAAD2 available)
   - Error handling and graceful degradation

2. **mp4_integration_test**: Tests integration with main Sonix API
   - Format detection
   - Decode API integration
   - Error propagation

3. **mp4_real_file_test**: Tests with actual MP4 files
   - Real-world format detection (4.1MB test file)
   - Container validation with actual MP4 structure
   - Full decode pipeline testing
   - Audio sample validation and analysis

### Convenience Scripts

Use the provided scripts for easy testing:

**Windows:**
```cmd
test_real_mp4.bat
```

**Unix/Linux/macOS:**
```bash
./test_real_mp4.sh
```

## Installation Notes

### Ubuntu/Debian
```bash
sudo apt-get install libfaad-dev
```

### macOS (Homebrew)
```bash
brew install faad2
```

### Windows
- Download FAAD2 development libraries
- Set FAAD2_LIBRARY and FAAD2_INCLUDE_DIR environment variables
- Or place libraries in standard system paths

## License Compatibility

FAAD2 is available under a dual GPL/commercial license. For open source projects like Sonix (MIT license), FAAD2 can be used under its permissive license terms that allow integration into MIT-licensed software.

## Performance Notes

- FAAD2 provides optimized AAC decoding for various platforms
- Float output format is used for consistency with other Sonix decoders
- Memory management is handled automatically by the MP4 decoder wrapper
- Frame-by-frame decoding allows for efficient chunked processing

## Future Enhancements

- Support for additional AAC profiles (AAC-HE, AAC-HEv2)
- Optimized sample table parsing for large MP4 files
- Integration with MP4 container sample table for accurate seeking
- Platform-specific optimizations (SIMD, hardware acceleration)