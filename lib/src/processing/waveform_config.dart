import 'package:sonix/src/models/waveform_type.dart';
import 'downsampling_algorithm.dart';
import 'normalization_method.dart';
import 'scaling_curve.dart';

/// Comprehensive configuration for waveform generation and processing.
///
/// This class provides fine-grained control over how audio files are processed
/// into waveform data. It includes settings for resolution, visualization type,
/// processing algorithms, and optimization parameters.
///
/// ## Key Configuration Areas
///
/// - **Resolution & Type**: Basic waveform characteristics
/// - **Processing Algorithms**: Advanced signal processing options
/// - **Normalization**: Amplitude scaling and normalization methods
/// - **Optimization**: Performance and quality trade-offs
///
/// ## Basic Usage
///
/// ```dart
/// // Simple configuration
/// final config = WaveformConfig(
///   resolution: 1000,
///   type: WaveformType.bars,
///   normalize: true,
/// );
///
/// final waveform = await sonix.generateWaveform('audio.mp3', config: config);
/// ```
///
/// ## Advanced Configuration
///
/// ```dart
/// // Fine-tuned for high-quality visualization
/// final config = WaveformConfig(
///   resolution: 2000,
///   type: WaveformType.line,
///   algorithm: DownsamplingAlgorithm.peak,
///   normalizationMethod: NormalizationMethod.rms,
///   scalingCurve: ScalingCurve.logarithmic,
///   enableSmoothing: true,
///   smoothingWindowSize: 5,
/// );
/// ```
///
/// ## Performance Optimization
///
/// ```dart
/// // Optimized for mobile devices
/// final mobileConfig = WaveformConfig(
///   resolution: 500,           // Lower resolution for performance
///   algorithm: DownsamplingAlgorithm.rms,  // Good quality/speed balance
///   enableSmoothing: false,    // Disable for faster processing
/// );
///
/// // High-quality for desktop
/// final desktopConfig = WaveformConfig(
///   resolution: 3000,
///   algorithm: DownsamplingAlgorithm.peak,
///   enableSmoothing: true,
///   smoothingWindowSize: 7,
/// );
/// ```
class WaveformConfig {
  /// Number of discrete amplitude points to generate in the final waveform.
  ///
  /// This determines the visual detail and memory usage of the waveform:
  /// - **Low (100-500)**: Suitable for thumbnails and mobile apps
  /// - **Medium (500-2000)**: Good balance for most applications
  /// - **High (2000-5000)**: Professional audio tools and desktop apps
  /// - **Ultra (5000+)**: Detailed analysis and zooming interfaces
  ///
  /// **Performance Impact:** Higher values require more processing time
  /// and memory but provide smoother, more detailed visualizations.
  final int resolution;

  /// Visual style for waveform rendering.
  ///
  /// Affects how amplitude data is interpreted for display:
  /// - [WaveformType.bars]: Traditional vertical bars (most common)
  /// - [WaveformType.line]: Connected line graph (detailed analysis)
  /// - [WaveformType.filled]: Solid filled area (aesthetic appeal)
  final WaveformType type;

  /// Whether to normalize amplitude values to the 0.0-1.0 range.
  ///
  /// **Recommended: true** for consistent visualization across different
  /// audio files with varying volume levels. When false, actual amplitude
  /// values are preserved, which may be useful for technical analysis.
  final bool normalize;

  /// Algorithm used for reducing audio data to the target resolution.
  ///
  /// Each algorithm provides different characteristics:
  /// - [DownsamplingAlgorithm.rms]: Root mean square (balanced quality/performance)
  /// - [DownsamplingAlgorithm.peak]: Maximum values (emphasizes transients)
  /// - [DownsamplingAlgorithm.average]: Simple averaging (smooth results)
  ///
  /// **Default: rms** provides the best overall results for most use cases.
  final DownsamplingAlgorithm algorithm;

  /// Method for normalizing amplitude values when [normalize] is true.
  ///
  /// Controls how the maximum amplitude is determined:
  /// - [NormalizationMethod.peak]: Uses absolute maximum value
  /// - [NormalizationMethod.rms]: Uses RMS (perceptually better)
  /// - [NormalizationMethod.lufs]: Loudness Units (broadcast standard)
  final NormalizationMethod normalizationMethod;

  /// Curve applied to amplitude values for perceptual optimization.
  ///
  /// Affects how amplitude values are scaled for human perception:
  /// - [ScalingCurve.linear]: No modification (raw values)
  /// - [ScalingCurve.logarithmic]: Better for wide dynamic range audio
  /// - [ScalingCurve.exponential]: Emphasizes quiet sections
  final ScalingCurve scalingCurve;

  /// Multiplier applied to final amplitude values (typically 0.5-2.0).
  ///
  /// Use this to adjust the visual "height" of the waveform without
  /// affecting the underlying data. Values > 1.0 make waveforms taller,
  /// values < 1.0 make them shorter.
  final double scalingFactor;

  /// Whether to apply smoothing to reduce visual noise in the waveform.
  ///
  /// Smoothing reduces sharp spikes and creates more aesthetically pleasing
  /// waveforms, especially useful for music visualization. May slightly
  /// reduce accuracy of transient representation.
  final bool enableSmoothing;

  /// Size of the moving average window when [enableSmoothing] is true.
  ///
  /// Larger values create smoother waveforms but may lose detail:
  /// - **3-5**: Light smoothing, preserves most detail
  /// - **5-7**: Moderate smoothing, good for music
  /// - **7-10**: Heavy smoothing, very clean appearance
  final int smoothingWindowSize;

  const WaveformConfig({
    this.resolution = 1000,
    this.type = WaveformType.bars,
    this.normalize = true,
    this.algorithm = DownsamplingAlgorithm.rms,
    this.normalizationMethod = NormalizationMethod.peak,
    this.scalingCurve = ScalingCurve.linear,
    this.scalingFactor = 1.0,
    this.enableSmoothing = false,
    this.smoothingWindowSize = 3,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'resolution': resolution,
      'type': type.name,
      'normalize': normalize,
      'algorithm': algorithm.name,
      'normalizationMethod': normalizationMethod.name,
      'scalingCurve': scalingCurve.name,
      'scalingFactor': scalingFactor,
      'enableSmoothing': enableSmoothing,
      'smoothingWindowSize': smoothingWindowSize,
    };
  }

  /// Create from JSON
  factory WaveformConfig.fromJson(Map<String, dynamic> json) {
    return WaveformConfig(
      resolution: json['resolution'] as int? ?? 1000,
      type: WaveformType.values.firstWhere((e) => e.name == json['type'], orElse: () => WaveformType.bars),
      normalize: json['normalize'] as bool? ?? true,
      algorithm: DownsamplingAlgorithm.values.firstWhere((e) => e.name == json['algorithm'], orElse: () => DownsamplingAlgorithm.rms),
      normalizationMethod: NormalizationMethod.values.firstWhere((e) => e.name == json['normalizationMethod'], orElse: () => NormalizationMethod.peak),
      scalingCurve: ScalingCurve.values.firstWhere((e) => e.name == json['scalingCurve'], orElse: () => ScalingCurve.linear),
      scalingFactor: (json['scalingFactor'] as num?)?.toDouble() ?? 1.0,
      enableSmoothing: json['enableSmoothing'] as bool? ?? false,
      smoothingWindowSize: json['smoothingWindowSize'] as int? ?? 3,
    );
  }

  WaveformConfig copyWith({
    int? resolution,
    WaveformType? type,
    bool? normalize,
    DownsamplingAlgorithm? algorithm,
    NormalizationMethod? normalizationMethod,
    ScalingCurve? scalingCurve,
    double? scalingFactor,
    bool? enableSmoothing,
    int? smoothingWindowSize,
  }) {
    return WaveformConfig(
      resolution: resolution ?? this.resolution,
      type: type ?? this.type,
      normalize: normalize ?? this.normalize,
      algorithm: algorithm ?? this.algorithm,
      normalizationMethod: normalizationMethod ?? this.normalizationMethod,
      scalingCurve: scalingCurve ?? this.scalingCurve,
      scalingFactor: scalingFactor ?? this.scalingFactor,
      enableSmoothing: enableSmoothing ?? this.enableSmoothing,
      smoothingWindowSize: smoothingWindowSize ?? this.smoothingWindowSize,
    );
  }
}
