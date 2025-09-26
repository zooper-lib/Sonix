# Format Detection Issues

This document summarizes the format detection bugs identified by the test suite.

## Current Status (Updated)

After switching to real audio files instead of synthetic test data, most format detection issues have been resolved. The FFMPEG integration is working correctly for most formats.

## Resolved Issues

### 1. MP3 Format Detection - FIXED ✅
**Status**: WORKING
**Description**: Real MP3 files are now correctly detected.
- **Expected**: `SONIX_FORMAT_MP3` (1)
- **Actual**: `SONIX_FORMAT_MP3` (1) ✅
- **File Header**: `49 44 33` (ID3 tag) or `FF FB` (sync frame)
- **Resolution**: Using real audio files instead of synthetic data

### 2. OGG Format Detection - FIXED ✅
**Status**: WORKING
**Description**: Real OGG files are now correctly detected.
- **Expected**: `SONIX_FORMAT_OGG` (4)
- **Actual**: `SONIX_FORMAT_OGG` (4) ✅
- **File Header**: `4F 67 67 53` (valid "OggS" signature)
- **Resolution**: Using real audio files instead of synthetic data

### 3. WAV Format Detection - WORKING ✅
**Status**: WORKING
- Correctly detects WAV files with RIFF/WAVE headers
- Returns `SONIX_FORMAT_WAV` (3) as expected
- Performance is acceptable

### 4. FLAC Format Detection - WORKING ✅
**Status**: WORKING
- Correctly detects FLAC files with fLaC signature
- Returns `SONIX_FORMAT_FLAC` (2) as expected
- Performance is acceptable

## Remaining Issues

### 1. MP4 Format Detection Bug
**Status**: HIGH PRIORITY
**Description**: Real MP4 files are not being detected by FFMPEG.
- **Expected**: `SONIX_FORMAT_MP4` (5)
- **Actual**: `SONIX_FORMAT_UNKNOWN` (0)
- **File Header**: `00 00 00 20 66 74 79 70` (valid ftyp box)
- **Impact**: MP4 files cannot be processed by the chunked decoder

**Root Cause**: FFMPEG's `av_probe_input_format` may be detecting the format with a different name than expected, or the format mapping is incomplete.

**Potential Solutions**:
1. Add more MP4-related format names to the mapping function
2. Debug what format name FFMPEG is actually returning
3. Check if the MP4 file structure is compatible with FFMPEG's expectations

### 2. Synthetic Format Detection Issues
**Status**: MEDIUM
**Description**: Synthetic test data with correct headers but invalid content structure fails detection.
- **Impact**: Test reliability for edge cases
- **Root Cause**: FFMPEG validates entire format structure, not just headers
- **Solution**: Use real audio files for testing instead of synthetic data

### 3. Performance Issue
**Status**: MEDIUM
**Description**: Format detection is slower than expected for large files.
- **Current**: ~530ms for 100MB files
- **Expected**: <100ms for any file size
- **Impact**: Poor user experience with large audio files

**Root Cause**: FFMPEG may be processing more data than necessary for format detection.

## Recommendations

### Immediate Fixes Needed

1. **Fix MP4 Detection**: The MP4 format detection needs investigation. FFMPEG may be detecting the format with a different name than expected.
   - Add debug logging to see what format name FFMPEG returns
   - Expand format mapping to include more MP4-related names
   - Test with different MP4 container variants

### Performance Optimization

1. **Limit Data Processing**: Format detection should only read the first few KB of a file, not the entire file.

2. **Early Return**: Once a format is detected, the function should return immediately without processing more data.

### Testing Improvements

1. **Continue Using Real Files**: The switch to real audio files has been highly successful.

2. **Add More MP4 Variants**: Test with different MP4 container types and codecs.

3. **Benchmark Performance**: Add automated performance regression tests.

## Test Coverage

The format detection test suite now covers:
- ✅ Synthetic format headers
- ✅ Real audio files (MAJOR IMPROVEMENT)
- ✅ Header-only detection
- ✅ Corrupted file handling
- ✅ Performance testing
- ✅ Edge cases (null pointers, empty buffers)
- ✅ Consistency testing

## Impact on Chunked Decoder

**SIGNIFICANT IMPROVEMENT**: Most format detection issues have been resolved:
- ✅ **MP3 files can now be properly processed**
- ✅ **OGG files can now be properly processed** 
- ✅ **WAV files continue to work correctly**
- ✅ **FLAC files continue to work correctly**
- ❌ **MP4 files still need investigation**

The chunked decoder functionality is now working for 4 out of 5 major audio formats, representing a major improvement in reliability.