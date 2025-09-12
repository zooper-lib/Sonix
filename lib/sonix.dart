/// Sonix - Flutter Audio Waveform Package
///
/// A comprehensive solution for generating and displaying audio waveforms
/// without relying on FFMPEG. Supports multiple audio formats (MP3, OGG, WAV, FLAC, Opus)
/// using native C libraries through Dart FFI.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:sonix/sonix.dart';
///
/// // Initialize Sonix (call once at app startup)
/// Sonix.initialize();
///
/// // Generate waveform from audio file
/// final waveformData = await Sonix.generateWaveform('audio.mp3');
/// print('Generated ${waveformData.points.length} waveform points');
///
/// // Stream waveform generation with progress
/// await for (final event in Sonix.generateWaveformStream('large_audio.flac')) {
///   if (event.isProgress) {
///     print('Progress: ${event.progress}%');
///   } else if (event.isComplete) {
///     print('Waveform generation complete!');
///   }
/// }
/// ```
///
/// ## Key Features
///
/// - **Multi-format Support**: MP3, OGG, WAV, FLAC, Opus
/// - **High Performance**: Native C libraries via Dart FFI
/// - **Memory Efficient**: Automatic chunked processing for large files
/// - **Streaming API**: Real-time progress updates
/// - **Caching**: Built-in LRU cache for better performance
/// - **Error Recovery**: Comprehensive error handling

library;

// Main API - the primary entry point
export 'src/sonix_api.dart';

// Core data models
export 'src/models/waveform_data.dart';
export 'src/models/audio_data.dart';
export 'src/models/chunked_processing_config.dart';

// Processing and generation
export 'src/processing/waveform_generator.dart' show WaveformConfig, WaveformUseCase;
export 'src/processing/waveform_algorithms.dart' show DownsamplingAlgorithm, NormalizationMethod, ScalingCurve;

// Exceptions
export 'src/exceptions/sonix_exceptions.dart';

// UI widgets
export 'src/widgets/widgets.dart';

// Utilities (selective exports)
export 'src/utils/memory_manager.dart' show MemoryManager;
export 'src/utils/resource_manager.dart' show ResourceManager, ResourceStatistics;
export 'src/utils/lazy_waveform_data.dart' show LazyWaveformData;
export 'src/utils/lru_cache.dart' show CacheStatistics;
export 'src/utils/performance_profiler.dart' show PerformanceProfiler, PerformanceReport;
export 'src/utils/performance_optimizer.dart' show PerformanceOptimizer, OptimizationSettings;
export 'src/utils/platform_validator.dart' show PlatformValidator;
