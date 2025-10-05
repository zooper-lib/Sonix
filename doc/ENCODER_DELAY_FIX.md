# Encoder Delay / Priming Samples Issue

## Problem Description

**Date Identified:** October 5, 2025

### Observed Behavior
Waveform displays show invalid/garbage audio data at the very beginning of audio files, following a consistent pattern:
1. **Burst of noise/data** (10-50ms)
2. **Silence or very low amplitude** (transition period)
3. **Actual audio content** begins

### Root Cause
Lossy audio codecs (MP3, AAC, Opus, Vorbis) add **encoder delay** or **priming samples** during encoding. These are padding samples required for the codec's algorithm to work properly, but they are NOT actual audio content.

Our FFmpeg decoder is correctly decoding these samples, but we're **not applying the metadata that tells us to skip them**.

### Confirmation
- ✅ **Does NOT occur with WAV files** (uncompressed, no encoder delay)
- ✅ **Does NOT occur with FLAC files** (lossless, no/minimal padding)
- ❌ **DOES occur with MP3, AAC, Opus, OGG files** (lossy codecs)
- ❌ **Not a fade-in effect** - it's actual garbage data from encoder padding

## Technical Details

### Encoder Delay by Codec

| Codec | Typical Delay (samples) | Duration @ 44.1kHz | Duration @ 48kHz |
|-------|-------------------------|-------------------|------------------|
| MP3 (LAME) | 1152-2880 | 26-65ms | 24-60ms |
| AAC | 1024-2112 | 23-48ms | 21-44ms |
| Opus | 312 | 7.1ms | 6.5ms |
| Vorbis | Variable | ~10-30ms | ~10-30ms |
| WAV | 0 | None | None |
| FLAC | 0-minimal | None | None |

### FFmpeg Metadata We're Currently Ignoring

FFmpeg provides several metadata fields that indicate how many samples to skip:

1. **`AVCodecParameters->initial_padding`**
   - Number of samples to discard from the beginning
   - Available in codec parameters

2. **`AVStream->skip_samples`**
   - Additional skip information
   - Side data on the stream

3. **`AVStream->start_time`**
   - Actual audio start time (may not be 0)
   - Container-level timing information

4. **Opus-specific: OpusHead pre-skip**
   - Stored in codec private data
   - Must be read from OpusHead header

5. **MP4 Edit Lists**
   - Container-level trimming information
   - Indicates media timeline vs presentation timeline

## Current Code Issues

### Location: `native/src/sonix_ffmpeg.c`

**Lines 727-850:** The main decoding loop processes ALL decoded samples without checking metadata:

```c
while (av_read_frame(fmt_ctx, packet) >= 0) {
    if (packet->stream_index == audio_stream_index) {
        ret = avcodec_send_packet(codec_ctx, packet);
        // ...
        while (ret >= 0) {
            ret = avcodec_receive_frame(codec_ctx, frame);
            // ...
            // ⚠️ ISSUE: We store ALL samples without checking skip metadata
            sample_index += converted_samples * channels;
        }
    }
}
```

**Problem:** We never check:
- `codec_ctx->codecpar->initial_padding`
- Stream skip_samples metadata
- Edit lists or container timing

## Solution Approach

### Skip During Decode (Only Option)
- Read encoder delay metadata before decoding loop
- Track samples to skip
- **Don't store priming samples in buffer** - skip them entirely during decode
- **Pros:** Most memory efficient, cleanest, correct approach
- **Cons:** Requires careful sample counting

**This is the only correct approach** - we decode audio only once for waveform generation, so there's no reason to store garbage data. Skip it at the source.

## Task List

### Phase 1: Research & Investigation
- [ ] Read FFmpeg documentation on encoder delay handling
- [ ] Check `initial_padding` values for test audio files
- [ ] Verify skip_samples side data availability
- [ ] Document which codecs need which metadata fields

### Phase 2: Native Code Changes (`native/src/sonix_ffmpeg.c`)

#### 2.1: In-Memory Decoding (`sonix_decode_audio`)
- [ ] Read `codec_ctx->codecpar->initial_padding` before decode loop
- [ ] Read `AVStream->skip_samples` if available
- [ ] Calculate total samples to skip at start
- [ ] Implement skip counter in decode loop
- [ ] Don't store samples until skip count is satisfied
- [ ] Update sample_index calculation to account for skipped samples
- [ ] Handle edge case: skip value larger than first frame

#### 2.2: Chunked Decoding (`sonix_decode_audio_chunk`)
- [ ] Same as 2.1 but track skip state across chunks
- [ ] Store skip offset in `SonixChunkedDecoder` structure
- [ ] Only apply skip on first chunk
- [ ] Add field to track if skip has been applied

#### 2.3: Codec-Specific Handling
- [ ] **Opus:** Extract pre-skip from OpusHead side data
- [ ] **MP4/AAC:** Check for edit list support
- [ ] **OGG/Vorbis:** Handle Vorbis comment pre-skip
- [ ] **MP3:** Verify LAME encoder delay detection

### Phase 3: Data Structure Updates

#### 3.1: `SonixChunkedDecoder` Structure
- [ ] Add `samples_to_skip` field (track remaining samples to skip)
- [ ] Add `skip_applied` boolean flag (track if initial skip is complete)
- [ ] Initialize fields in decoder creation

### Phase 4: Testing

#### 4.1: Create Test Files
- [ ] Generate MP3 files with known LAME encoder delay
- [ ] Generate AAC/M4A files with priming samples
- [ ] Generate Opus files
- [ ] Generate OGG Vorbis files
- [ ] Keep WAV files as control (should have no delay)

#### 4.2: Unit Tests
- [ ] Test skip detection for each codec
- [ ] Test correct sample count after skipping
- [ ] Test waveform generation with/without skip
- [ ] Test edge case: skip > first frame size
- [ ] Test chunked decoder maintains skip state

#### 4.3: Integration Tests
- [ ] Verify waveforms start at actual audio (no garbage)
- [ ] Verify duration calculations are correct
- [ ] Verify sample counts match expected values
- [ ] Compare decoded audio with reference tools (ffplay, sox)

### Phase 5: Documentation
- [ ] Update `WAVEFORM_CONTROLLER.md` with encoder delay info
- [ ] Document codec-specific behaviors
- [ ] Add troubleshooting section for timing issues
- [ ] Update API documentation if structures changed

### Phase 6: Validation
- [ ] Test with real-world audio files from different encoders
- [ ] Verify gapless playback if implementing playback features
- [ ] Check edge cases (very short files, files with no delay metadata)
- [ ] Performance testing (ensure skip logic doesn't slow decode)

## References & Resources

### FFmpeg Documentation
- `AVCodecParameters->initial_padding`: https://ffmpeg.org/doxygen/trunk/structAVCodecParameters.html
- Encoder delay discussion: https://hydrogenaud.io/index.php/topic,106125.0.html
- Edit lists in MP4: https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/

### Codec Specifications
- **MP3 Encoder Delay:** LAME project documentation
- **AAC Priming:** ISO/IEC 14496-3 specification
- **Opus Pre-skip:** RFC 7845, Section 5.1
- **Vorbis:** Xiph.org documentation on comment headers

### Industry Standard Behavior
- **iTunes/Apple Music:** Reads and applies edit lists
- **VLC:** Uses FFmpeg metadata for gapless playback
- **foobar2000:** Advanced ReplayGain and gap handling
- **Audacity:** Shows encoder delay in waveform timing

## Expected Outcome

After implementing this fix:
- ✅ Waveforms will start at the actual audio content
- ✅ No more garbage/noise at the beginning
- ✅ Accurate timing and duration calculations
- ✅ Proper gapless playback support (if implemented)
- ✅ Consistent behavior across all lossy codecs

## Notes

- This is a **well-known issue** in audio processing
- All professional audio tools must handle this
- The fix is straightforward but requires careful implementation
- Most important for MP3 and AAC (longest delays)
- Critical for gapless album playback

---

**Status:** 🔴 Not Started  
**Priority:** High (affects waveform visual accuracy)  
**Complexity:** Medium (native C code + FFmpeg metadata)  
**Estimated Effort:** 1-2 days for full implementation and testing
