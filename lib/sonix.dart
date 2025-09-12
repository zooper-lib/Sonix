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

// Chunked file reading infrastructure
export 'src/utils/chunked_file_reader.dart' show ChunkedFileReader, ChunkedFileReaderInfo, ChunkedFileReaderFactory;
export 'src/models/file_chunk.dart' show FileChunk, ChunkValidationResult, FileChunkUtils;

// Chunked audio decoding interfaces and models
export 'src/decoders/chunked_audio_decoder.dart' show ChunkedAudioDecoder;
export 'src/models/chunked_processing_models.dart' show SeekResult, ChunkSizeRecommendation;

// Progressive waveform generation for streaming processing
export 'src/processing/progressive_waveform_generator.dart'
    show ProgressiveWaveformGenerator, ProgressInfo, ProgressCallback, WaveformChunkEnhanced, ChunkProcessingStats, ProcessedChunk;
export 'src/processing/waveform_aggregator.dart' show WaveformAggregator, WaveformAggregatorStats, ChunkSequenceValidation;

// Performance optimization utilities
export 'src/utils/performance_profiler.dart' show PerformanceProfiler, PerformanceReport, BenchmarkResult;
export 'src/utils/performance_optimizer.dart'
    show PerformanceOptimizer, OptimizationSettings, PerformanceMetrics, OptimizationSuggestion, SuggestionPriority, RenderingOptimization, RenderingStrategy;
export 'src/utils/platform_validator.dart' show PlatformValidator, PlatformValidationResult, PlatformInfo, OptimizationRecommendation, RecommendationPriority;

// Chunked processing configuration system
export 'src/models/chunked_processing_config.dart' show ChunkedProcessingConfig, ChunkedProcessingConfigValidation;
export 'src/utils/chunked_processing_config_manager.dart'
    show ChunkedProcessingConfigManager, ChunkedProcessingConfigCacheStats, ChunkedProcessingConfigException;
