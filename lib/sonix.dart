/// Sonix - Flutter Audio Waveform Package
///
/// A comprehensive solution for generating and displaying audio waveforms
/// without relying on FFMPEG. Supports multiple audio formats (MP3, OGG, WAV, FLAC, Opus)
/// using native C libraries through Dart FFI.

library;

// Main API - everything users need to generate waveforms
export 'src/sonix_api.dart';

// Data models that users will work with
export 'src/models/waveform_data.dart';

// Configuration classes and enums that users need for customization
export 'src/processing/waveform_generator.dart' show WaveformConfig, WaveformUseCase;
export 'src/processing/waveform_algorithms.dart' show DownsamplingAlgorithm, NormalizationMethod, ScalingCurve;

// Exceptions that users should be able to catch
export 'src/exceptions/sonix_exceptions.dart';

// UI widgets for displaying waveforms
export 'src/widgets/widgets.dart';
