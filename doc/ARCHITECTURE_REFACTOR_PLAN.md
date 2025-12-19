# Sonix Audio Decoder Architecture Refactor Plan

## Executive Summary

This document describes a planned refactoring of the Sonix audio decoding architecture to improve separation of concerns, simplify the codebase, and fix memory issues with large files.

---

## The Problem

### Current Architecture Issues

1. **Mixed Responsibilities in Decoder Classes**
   
   The current `MP3Decoder`, `MP4Decoder`, etc. implement `ChunkedAudioDecoder` which forces them to handle:
   - Pure audio decoding (bytes → samples)
   - File I/O operations
   - Chunked streaming logic
   - Seeking within files
   - Memory management decisions
   
   This violates the Single Responsibility Principle.

2. **Confusing Inheritance Hierarchy**
   
   ```
   AudioDecoder (abstract)
     └── decode(filePath) → AudioData
   
   ChunkedAudioDecoder extends AudioDecoder
     └── decode(filePath) → AudioData  (inherited)
     └── initializeChunkedDecoding()
     └── processFileChunk()
     └── seekToTime()
     └── cleanupChunkedProcessing()
     └── ... 10+ more methods
   
   MP3Decoder implements ChunkedAudioDecoder
     └── Must implement BOTH full decode AND all chunked methods
   ```

3. **Memory Exception for Large Files**
   
   The `decode()` method throws `MemoryException` for large files, forcing callers to:
   - Catch the exception
   - Fall back to chunked processing
   - Or use a wrapper like `MemorySafeDecoder`
   
   This is a leaky abstraction - the caller shouldn't need to know about memory limits.

4. **Duplicate Logic**
   
   The `MemorySafeDecoder` wrapper was created to handle large files, but it:
   - Bypasses the inner decoder's chunked interface
   - Calls native FFI functions directly
   - Duplicates logic that already exists in decoders

5. **File Path vs Bytes Confusion**
   
   - `decode(String filePath)` takes a file path but reads the file internally
   - This mixes file I/O with decoding logic
   - Makes unit testing harder (need real files)

---

## The Solution

### New Architecture: Separation of Concerns

```
┌─────────────────────────────────────────────────────────────┐
│  Sonix API                                                  │
│  - generateWaveform(path) → WaveformData                    │
│  - Just wants the result, doesn't care about details        │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│  AudioFileProcessor (NEW - orchestrates everything)         │
│  - process(path) → AudioData                                │
│  - Checks file size                                         │
│  - Picks strategy: full load vs chunked streaming           │
│  - Uses AudioDecoderFactory to get the right decoder        │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
         ┌──────────────────┐        ┌──────────────────────┐
         │ Full File Load   │        │ Chunked Streaming    │
         │ (small files)    │        │ (large files)        │
         └────────┬─────────┘        └──────────┬───────────┘
                  │                             │
                  └─────────────┬───────────────┘
                                │
                                ▼
                     ┌──────────────────────┐
                     │  AudioDecoder        │
                     │  (pure decoding)     │
                     │                      │
                     │  decode(bytes)       │
                     │  → AudioData         │
                     └──────────────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
   ┌────────────┐       ┌────────────┐       ┌────────────┐
   │ MP3Decoder │       │ MP4Decoder │       │ WAVDecoder │
   │            │       │            │       │            │
   │ Pure:      │       │ Pure:      │       │ Pure:      │
   │ bytes in,  │       │ bytes in,  │       │ bytes in,  │
   │ samples out│       │ samples out│       │ samples out│
   └────────────┘       └────────────┘       └────────────┘
```

---

## Proposed Interfaces

### 1. AudioDecoder (Pure - No File I/O)

```dart
/// Pure audio decoder - converts audio bytes to PCM samples.
/// 
/// Decoders are stateless and handle NO file I/O.
/// They simply transform encoded audio bytes into decoded samples.
abstract class AudioDecoder {
  /// Decode audio bytes into PCM samples.
  /// 
  /// [data] - The encoded audio bytes (e.g., MP3 frame data)
  /// Returns [AudioData] containing PCM samples and metadata.
  /// 
  /// Throws [DecodingException] if the data cannot be decoded.
  AudioData decode(Uint8List data);
  
  /// The audio format this decoder handles.
  AudioFormat get format;
  
  /// Release any native resources held by this decoder.
  void dispose();
}
```

### 2. StreamingAudioDecoder (For Formats Requiring State)

```dart
/// Extended decoder interface for formats that benefit from 
/// stateful/streaming decoding (e.g., MP3 with frame boundaries).
abstract class StreamingAudioDecoder extends AudioDecoder {
  /// Initialize the decoder with format-specific metadata.
  /// 
  /// Some formats (like MP3) need header info before decoding chunks.
  void initialize(AudioMetadata metadata);
  
  /// Decode a chunk of audio data in a streaming context.
  /// 
  /// Unlike [decode], this maintains state between calls for
  /// formats with frame boundaries or inter-frame dependencies.
  /// 
  /// [chunk] - A portion of the audio file
  /// [isLast] - Whether this is the final chunk
  /// Returns decoded samples from this chunk.
  AudioData decodeChunk(Uint8List chunk, {bool isLast = false});
  
  /// Reset decoder state (e.g., after seeking).
  void reset();
}
```

### 3. AudioFileProcessor (Orchestrates File I/O + Decoding)

```dart
/// Processes audio files and returns decoded audio data.
/// 
/// This class orchestrates:
/// - File format detection
/// - File size checking
/// - Strategy selection (full load vs chunked)
/// - Decoder instantiation and lifecycle
/// 
/// Callers don't need to know about memory limits or chunking.
class AudioFileProcessor {
  /// Size threshold for switching to chunked processing.
  /// Files larger than this use streaming to avoid memory issues.
  static const int chunkThreshold = 5 * 1024 * 1024; // 5MB
  
  /// Process an audio file and return decoded audio data.
  /// 
  /// Automatically selects the appropriate strategy based on file size.
  /// The caller never needs to worry about memory limits.
  Future<AudioData> process(String filePath);
  
  /// Process an audio file using streaming (for very large files).
  /// 
  /// Returns a stream of [AudioData] chunks for progressive processing.
  Stream<AudioData> processStreaming(String filePath);
}
```

### 4. AudioDecoderFactory (Unchanged Role)

```dart
/// Factory for creating audio decoders based on file format.
class AudioDecoderFactory {
  /// Create a decoder for the detected audio format.
  static AudioDecoder createDecoder(AudioFormat format);
  
  /// Detect audio format from file extension or content.
  static AudioFormat detectFormat(String filePath);
}
```

---

## Responsibility Matrix

| Responsibility | Current Owner | New Owner |
|---------------|---------------|-----------|
| Detect format from file | `AudioDecoderFactory` | `AudioDecoderFactory` (unchanged) |
| Read file from disk | `MP3Decoder.decode()` | `AudioFileProcessor` |
| Decide chunked vs full load | `MemorySafeDecoder` / caller | `AudioFileProcessor` |
| Decode bytes → samples | `MP3Decoder` | `MP3Decoder` (simplified) |
| Handle frame boundaries | `MP3Decoder.processFileChunk()` | `StreamingAudioDecoder` |
| Manage memory limits | `NativeAudioBindings` + decoder | `AudioFileProcessor` |
| Seek within file | `ChunkedAudioDecoder.seekToTime()` | `AudioFileProcessor` (if needed) |

---

## Migration Strategy

### Phase 1: Create New Interfaces
1. Create new `AudioDecoder` interface (bytes-based, no file I/O)
2. Create `StreamingAudioDecoder` for stateful decoding
3. Create `AudioFileProcessor` class

### Phase 2: Refactor Decoders
1. Simplify `MP3Decoder` to implement new `AudioDecoder`
2. Extract file I/O logic to `AudioFileProcessor`
3. Move chunking logic to `AudioFileProcessor`
4. Repeat for all decoder types

### Phase 3: Update Consumers
1. Update `Sonix API` to use `AudioFileProcessor`
2. Update isolate processing to use `AudioFileProcessor`
3. Remove `MemorySafeDecoder` (no longer needed)
4. Remove old `ChunkedAudioDecoder` interface

### Phase 4: Cleanup
1. Delete deprecated classes
2. Update tests
3. Update documentation

---

## Benefits of New Architecture

1. **Single Responsibility**
   - Decoders only decode
   - `AudioFileProcessor` handles file I/O and strategy
   
2. **Simpler Decoder Interface**
   - From 15+ methods to 3 methods
   - Easy to implement new format support
   
3. **No Memory Exceptions to Caller**
   - `AudioFileProcessor.process()` always works
   - Large files automatically use streaming
   
4. **Testable**
   - Decoders can be unit tested with raw bytes
   - No file system dependencies in decoder tests
   
5. **Flexible**
   - Easy to add new reading strategies
   - Easy to add new formats

---

## Files to Modify

### Core Files
- `lib/src/decoders/audio_decoder.dart` - New simplified interface
- `lib/src/decoders/streaming_audio_decoder.dart` - New streaming interface
- `lib/src/decoders/mp3_decoder.dart` - Simplify to pure decoder
- `lib/src/decoders/mp4_decoder.dart` - Simplify to pure decoder
- `lib/src/decoders/wav_decoder.dart` - Simplify to pure decoder
- `lib/src/decoders/flac_decoder.dart` - Simplify to pure decoder
- `lib/src/decoders/opus_decoder.dart` - Simplify to pure decoder
- `lib/src/decoders/vorbis_decoder.dart` - Simplify to pure decoder

### New Files
- `lib/src/processing/audio_file_processor.dart` - Main orchestrator
- `lib/src/processing/chunked_file_reader.dart` - File chunking logic

### Files to Delete
- `lib/src/decoders/chunked_audio_decoder.dart` - No longer needed
- `lib/src/decoders/memory_safe_decoder.dart` - No longer needed

### Files to Update
- `lib/src/sonix_api.dart` - Use `AudioFileProcessor`
- `lib/src/isolate/processing_isolate.dart` - Use `AudioFileProcessor`
- `lib/src/decoders/audio_decoder_factory.dart` - Simplify

---

## Open Questions

1. **Seeking Support**: Should `AudioFileProcessor` support seeking for large files, or is that a separate use case?

2. **Progress Reporting**: How should progress be reported for large file streaming?

3. **Cancellation**: How should chunked processing support cancellation?

4. **Format-Specific Metadata**: Some formats need header parsing before decoding. Should this be part of the decoder or the processor?

---

## Next Steps

1. Review and approve this plan
2. Create the new interfaces in a feature branch
3. Implement `AudioFileProcessor` with basic strategy selection
4. Refactor one decoder (e.g., `WAVDecoder` - simplest) as a proof of concept
5. Migrate remaining decoders
6. Update consumers and tests
7. Delete deprecated code
