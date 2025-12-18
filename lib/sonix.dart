/// Sonix - Flutter Audio Waveform Package
///
/// A comprehensive solution for generating and displaying audio waveforms
/// with optional isolate-based processing to prevent UI thread blocking.
/// Supports multiple audio formats (MP3, OGG, WAV, FLAC) using native C
/// libraries through Dart FFI.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:sonix/sonix.dart';
///
/// // Create a Sonix instance
/// final sonix = Sonix();
///
/// // Generate waveform on main thread (simple usage)
/// final waveformData = await sonix.generateWaveform('audio.mp3');
///
/// // Or generate in a background isolate (for large files/UI responsiveness)
/// final waveformData = await sonix.generateWaveformInIsolate('audio.mp3');
///
/// print('Generated ${waveformData.amplitudes.length} waveform points');
/// ```
///
/// ## Key Features
///
/// - **Isolate-Based Processing**: Optional background processing via `generateWaveformInIsolate`
/// - **Multi-format Support**: MP3, OGG, WAV, FLAC
/// - **High Performance**: Native C libraries via Dart FFI
/// - **Memory Efficient**: Automatic resource management
/// - **Simple API**: Easy to use without complex setup

library;

// Main API - the primary entry point
export 'src/sonix_api.dart' show Sonix;

// Configuration
export 'src/config/sonix_config.dart';

// Core data models
export 'src/models/waveform_data.dart';
export 'src/models/waveform_type.dart';
export 'src/models/waveform_metadata.dart';

// Audio format enum (from decoders)
export 'src/decoders/audio_decoder.dart' show AudioFormat;

// Processing and generation
export 'src/processing/waveform_config.dart';
export 'src/processing/downsampling_algorithm.dart';
export 'src/processing/normalization_method.dart';
export 'src/processing/scaling_curve.dart';
export 'src/processing/downsample_method.dart';
export 'src/processing/upsample_method.dart';

// Exceptions
export 'src/exceptions/sonix_exceptions.dart';
export 'src/exceptions/mp4_exceptions.dart';

// UI widgets
export 'src/widgets/waveform_painter.dart';
export 'src/widgets/waveform_style.dart';
export 'src/widgets/waveform_style_presets.dart';
export 'src/widgets/waveform_widget.dart';
export 'src/widgets/waveform_controller.dart';
