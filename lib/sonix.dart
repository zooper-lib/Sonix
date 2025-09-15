/// Sonix - Flutter Audio Waveform Package
///
/// A comprehensive solution for generating and displaying audio waveforms
/// with isolate-based processing to prevent UI thread blocking. Supports multiple
/// audio formats (MP3, OGG, WAV, FLAC, Opus) using native C libraries through Dart FFI.
///
/// ## Quick Start (New Instance-Based API)
///
/// ```dart
/// import 'package:sonix/sonix.dart';
///
/// // Create a Sonix instance with configuration
/// final sonix = SonixInstance(SonixConfig.mobile());
///
/// // Generate waveform from audio file (processed in background isolate)
/// final waveformData = await sonix.generateWaveform('audio.mp3');
/// print('Generated ${waveformData.amplitudes.length} waveform points');
///
/// // Stream waveform generation with progress
/// await for (final progress in sonix.generateWaveformStream('large_audio.flac')) {
///   print('Progress: ${(progress.progress * 100).toStringAsFixed(1)}%');
///   if (progress.isComplete && progress.partialData != null) {
///     print('Waveform generation complete!');
///     final waveformData = progress.partialData!;
///   }
/// }
///
/// // Clean up when done
/// await sonix.dispose();
/// ```
///
/// ## Backward Compatibility (Deprecated)
///
/// ```dart
/// // Legacy static API (deprecated, but still supported)
/// await Sonix.initialize();
/// final waveformData = await Sonix.generateWaveform('audio.mp3');
/// ```
///
/// ## Key Features
///
/// - **Isolate-Based Processing**: All audio processing happens in background isolates
/// - **Instance-Based API**: Create multiple instances with different configurations
/// - **Multi-format Support**: MP3, OGG, WAV, FLAC, Opus
/// - **High Performance**: Native C libraries via Dart FFI
/// - **Memory Efficient**: Automatic resource management and cleanup
/// - **Streaming API**: Real-time progress updates
/// - **Error Recovery**: Comprehensive error handling across isolate boundaries
/// - **Backward Compatible**: Existing code continues to work

library;

// Main API - the primary entry point
export 'src/sonix_api.dart' show Sonix, SonixInstance, SonixConfig, WaveformProgress;

// Core data models
export 'src/models/waveform_data.dart';
export 'src/models/audio_data.dart';

// Processing and generation
export 'src/processing/waveform_generator.dart' show WaveformConfig, WaveformUseCase;
export 'src/processing/waveform_algorithms.dart' show DownsamplingAlgorithm, NormalizationMethod, ScalingCurve;

// Exceptions
export 'src/exceptions/sonix_exceptions.dart';

// UI widgets
export 'src/widgets/waveform_painter.dart';
export 'src/widgets/waveform_style.dart';
export 'src/widgets/waveform_style_presets.dart';
export 'src/widgets/waveform_widget.dart';

// Display resolution and sampling
export 'src/processing/display_sampler.dart';

// Isolate infrastructure (for advanced usage)
export 'src/isolate/isolate_messages.dart';
export 'src/isolate/processing_isolate.dart' show processingIsolateEntryPoint;
export 'src/isolate/error_serializer.dart';
export 'src/isolate/isolate_health_monitor.dart' show IsolateHealthStatus, IsolateHealth;

// Utilities (selective exports)
export 'src/utils/memory_manager.dart' show MemoryManager;
export 'src/utils/resource_manager.dart' show ResourceManager, ResourceStatistics;
export 'src/utils/lru_cache.dart' show CacheStatistics;
export 'src/utils/performance_profiler.dart' show PerformanceProfiler, PerformanceReport;
export 'src/utils/platform_validator.dart' show PlatformValidator;
