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
/// // Generate waveform from audio file
/// final waveformData = await Sonix.generateWaveform('audio.mp3');
///
/// // Display with playback position
/// WaveformWidget(
///   waveformData: waveformData,
///   playbackPosition: 0.3, // 30% played
///   style: WaveformStylePresets.soundCloud,
///   onSeek: (position) {
///     // Handle seek to position
///   },
/// )
/// ```
///
/// ## Key Features
///
/// - **Multi-format Support**: MP3, OGG, WAV, FLAC, Opus
/// - **High Performance**: Native C libraries via Dart FFI
/// - **Memory Efficient**: Streaming processing and caching
/// - **Interactive UI**: Real-time playback position and seeking
/// - **Extensive Customization**: Colors, gradients, styles
/// - **Error Recovery**: Comprehensive error handling
///
/// ## Memory Management
///
/// Initialize Sonix with memory limits for optimal performance:
///
/// ```dart
/// Sonix.initialize(
///   memoryLimit: 50 * 1024 * 1024, // 50MB
///   maxWaveformCacheSize: 50,
/// );
/// ```
///
/// ## Performance Tips
///
/// 1. Use `generateWaveformCached()` for frequently accessed files
/// 2. Use `generateWaveformStream()` for large files (>50MB)
/// 3. Use `generateWaveformAdaptive()` for automatic optimization
/// 4. Call `dispose()` on WaveformData when no longer needed
/// 5. Monitor memory usage with `getResourceStatistics()`

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
