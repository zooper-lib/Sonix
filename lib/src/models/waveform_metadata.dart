import 'waveform_type.dart';

/// Metadata containing information about how the waveform was generated.
///
/// This class stores essential configuration and timing information that
/// accompanies [WaveformData]. It helps track generation parameters and
/// provides context for caching and optimization decisions.
///
/// ## Example Usage
///
/// ```dart
/// final metadata = WaveformMetadata(
///   resolution: 1000,
///   type: WaveformType.bars,
///   normalized: true,
///   generatedAt: DateTime.now(),
/// );
///
/// // Check when waveform was generated
/// print('Generated ${DateTime.now().difference(metadata.generatedAt)} ago');
/// ```
class WaveformMetadata {
  /// Target resolution (number of amplitude data points) in the waveform.
  ///
  /// This determines how many discrete amplitude values are generated from
  /// the source audio. Higher values provide more detail but use more memory.
  /// Typical values: 100-2000 for mobile apps, 1000-5000 for desktop apps.
  final int resolution;

  /// Type of waveform visualization this metadata describes.
  ///
  /// Indicates the visual style the waveform was optimized for.
  /// See [WaveformType] for available options.
  final WaveformType type;

  /// Whether amplitude values have been normalized to the 0.0-1.0 range.
  ///
  /// When true, all amplitude values are scaled so the maximum value
  /// equals 1.0. This ensures consistent visualization across different
  /// audio files with varying volume levels.
  final bool normalized;

  /// Timestamp when this waveform was generated.
  ///
  /// Useful for cache invalidation, debugging, and performance tracking.
  /// Generated waveforms can be cached and reused if source hasn't changed.
  final DateTime generatedAt;

  const WaveformMetadata({required this.resolution, required this.type, required this.normalized, required this.generatedAt});

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {'resolution': resolution, 'type': type.name, 'normalized': normalized, 'generatedAt': generatedAt.toIso8601String()};
  }

  /// Create from JSON
  factory WaveformMetadata.fromJson(Map<String, dynamic> json) {
    return WaveformMetadata(
      resolution: json['resolution'] as int,
      type: WaveformType.values.firstWhere((e) => e.name == json['type'], orElse: () => WaveformType.bars),
      normalized: json['normalized'] as bool,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'WaveformMetadata(resolution: $resolution, type: $type, '
        'normalized: $normalized, generatedAt: $generatedAt)';
  }
}
