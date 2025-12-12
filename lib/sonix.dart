/// Sonix - Flutter Audio Waveform Package
///
/// A comprehensive solution for generating and displaying audio waveforms
/// with isolate-based processing to prevent UI thread blocking. Supports multiple
/// audio formats (MP3, OGG, WAV, FLAC) using native C libraries through Dart FFI.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:sonix/sonix.dart';
///
/// // Create a Sonix instance with configuration
/// final sonix = Sonix(SonixConfig.mobile());
///
/// // Generate waveform from audio file (processed in background isolate)
/// final waveformData = await sonix.generateWaveform('audio.mp3');
/// print('Generated ${waveformData.amplitudes.length} waveform points');
///
/// // Clean up when done
/// await sonix.dispose();
/// ```
///
/// ## Key Features
///
/// - **Isolate-Based Processing**: All audio processing happens in background isolates
/// - **Instance-Based API**: Create multiple instances with different configurations
/// - **Multi-format Support**: MP3, OGG, WAV, FLAC
/// - **High Performance**: Native C libraries via Dart FFI
/// - **Memory Efficient**: Automatic resource management and cleanup
/// - **Streaming API**: Real-time progress updates
/// - **Error Recovery**: Comprehensive error handling across isolate boundaries

library;

// Main API - the primary entry point
export 'src/sonix_api.dart' show Sonix;

// Configuration
export 'src/config/sonix_config.dart';

// Core data models
export 'src/models/waveform_data.dart';
export 'src/models/waveform_type.dart';
export 'src/models/waveform_metadata.dart';
export 'src/models/audio_data.dart';
export 'src/models/mp4_models.dart';

// Audio format enum (from decoders)
export 'src/decoders/audio_decoder.dart' show AudioFormat;

// Processing and generation
export 'src/processing/waveform_generator.dart' show WaveformGenerator;
export 'src/processing/waveform_config.dart';
export 'src/processing/waveform_use_case.dart';
export 'src/processing/waveform_algorithms.dart';
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

// Display resolution and sampling
export 'src/processing/display_sampler.dart';

// Isolate infrastructure (for advanced usage)
export 'src/isolate/isolate_messages.dart';
export 'src/isolate/processing_isolate.dart' show processingIsolateEntryPoint;
export 'src/isolate/error_serializer.dart';
export 'src/isolate/isolate_health_monitor.dart' show IsolateHealthStatus, IsolateHealth;
export 'src/isolate/isolate_config.dart';

// Utilities (selective exports)
export 'src/utils/memory_manager.dart' show MemoryManager;
export 'src/utils/performance_profiler.dart' show PerformanceProfiler;
export 'src/utils/profiled_operation.dart';
export 'src/utils/operation_statistics.dart';
export 'src/utils/performance_report.dart';
export 'src/utils/benchmark_result.dart';
export 'src/utils/platform_validator.dart' show PlatformValidator;

// Logging utilities (for advanced usage and debugging)
export 'src/utils/sonix_logger.dart' show SonixLogger;

// Native bindings (for checking FFMPEG availability)
export 'src/native/native_audio_bindings.dart' show NativeAudioBindings;
