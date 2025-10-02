# Product Overview

Sonix is a comprehensive Flutter package for generating and displaying audio waveforms with multi-format support. It provides isolate-based processing to prevent UI thread blocking and uses native C libraries through Dart FFI for optimal performance.

## Core Features

- **Multi-format Audio Support**: MP3, WAV, FLAC, OGG, Opus, MP4, M4A using FFMPEG
- **Isolate-based Processing**: All audio processing runs in background isolates to keep UI responsive
- **High Performance**: Native C libraries via Dart FFI (no direct FFMPEG dependency for users)
- **Interactive Waveform Widgets**: Real-time position visualization and seeking capabilities
- **Instance-based API**: Modern API with proper resource management and cleanup
- **Extensive Customization**: Colors, gradients, styles, animations, and preset configurations

## Target Use Cases

- Music visualization and players
- Podcast players with waveform scrubbing
- Audio editing applications
- Voice recording apps
- Audio analysis tools

## Architecture Philosophy

- **Two-layer native architecture**: Custom MIT-licensed wrapper (`sonix_native`) + user-provided FFMPEG libraries
- **Licensing separation**: MIT-licensed Sonix code with GPL FFMPEG handled separately by users
- **Plugin-based distribution**: Pre-compiled native libraries bundled via Flutter plugin system
- **Resource efficiency**: Automatic memory management and isolate optimization