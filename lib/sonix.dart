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

// Error recovery utilities for advanced users
export 'src/exceptions/error_recovery.dart' show RecoverableOperation, RecoverableStreamOperation;

// UI widgets for displaying waveforms
export 'src/widgets/widgets.dart';

// Memory management utilities
export 'src/utils/memory_manager.dart' show MemoryManager, QualityReductionSuggestion;
export 'src/utils/resource_manager.dart' show ResourceManager, ResourceStatistics, ResourceInfo;
export 'src/utils/lazy_waveform_data.dart' show LazyWaveformData;
export 'src/utils/lru_cache.dart' show CacheStatistics;
