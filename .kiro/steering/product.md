# Product Overview

Sonix is a comprehensive Flutter package for generating and displaying audio waveforms with multi-format support. It provides isolate-based processing to prevent UI thread blocking and uses native C libraries through Dart FFI for optimal performance.

## Core Features

- **Multi-format Audio Support**: MP3, WAV, FLAC, OGG, Opus, MP4, M4A using FFmpeg
- **Isolate-based Processing**: All audio processing runs in background isolates to keep UI responsive
- **High Performance**: Native C libraries via Dart FFI (FFmpeg required on desktop systems)
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

- **Two-layer native architecture**: Custom MIT-licensed wrapper (`sonix_native`) + system-provided FFmpeg libraries (on desktop)
- **Licensing separation**: MIT-licensed Sonix code; FFmpeg is provided by the system/user as required
- **Plugin-based distribution**: Plugin sources and artifacts are built by Flutter; desktop relies on system FFmpeg
- **Resource efficiency**: Automatic memory management and isolate optimization