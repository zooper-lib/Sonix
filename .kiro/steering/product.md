# Product Overview

Sonix is a comprehensive Flutter package for generating and displaying audio waveforms using FFMPEG. It provides high-performance audio processing through native C libraries via Dart FFI.

## Core Features

- **Isolate-Based Processing**: All audio processing runs in background isolates to keep UI thread responsive
- **Multi-format Support**: MP3, OGG, WAV, FLAC, and Opus audio formats
- **Memory Efficient**: Chunked processing for large files with intelligent caching
- **Interactive Widgets**: Real-time playback visualization and seeking capabilities
- **Cross-Platform**: Android, iOS, Windows, macOS, and Linux support

## Key Value Propositions

- **Non-blocking Architecture**: Complete isolate-based processing ensures UI remains responsive during heavy audio operations
- No FFMPEG dependency - uses lightweight native decoders
- Instance-based API with backward compatibility for legacy static API
- Comprehensive performance optimization and profiling tools
- Streaming processing for files larger than available RAM
- Extensive customization options with preset styles

## Target Use Cases

- Music visualization applications
- Audio editing and production tools
- Podcast and audiobook players
- Voice recording applications
- Audio analysis and processing tools
