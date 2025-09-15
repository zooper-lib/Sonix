/// Methods for normalizing waveform amplitude values to a consistent range.
///
/// Normalization ensures that waveforms from different audio sources display
/// with consistent visual scale, regardless of the original recording level
/// or dynamic range. This is essential for creating uniform user experiences
/// across different audio files.
///
/// ## When to Use Each Method
///
/// - **Peak**: Most common, ensures maximum visual utilization
/// - **RMS**: Better for perceptually consistent loudness representation
///
/// ## Example Usage
///
/// ```dart
/// // Standard peak normalization (most common)
/// WaveformConfig(
///   normalize: true,
///   normalizationMethod: NormalizationMethod.peak,
/// )
///
/// // Perceptually consistent normalization
/// WaveformConfig(
///   normalize: true,
///   normalizationMethod: NormalizationMethod.rms,
/// )
/// ```
enum NormalizationMethod {
  /// Normalize amplitude values based on the peak (maximum) value.
  ///
  /// Scales all amplitude values so that the highest peak reaches 1.0.
  /// This maximizes the visual dynamic range and ensures full utilization
  /// of the display area. Most common choice for waveform visualization.
  ///
  /// **Formula:** normalized_value = value / max_peak
  ///
  /// **Best for:** General waveform display, maximizing visual detail
  /// **Result:** Full utilization of vertical display space
  peak,

  /// Normalize amplitude values based on RMS (Root Mean Square) level.
  ///
  /// Scales values based on the perceived loudness level rather than peak
  /// values. This can provide more consistent visual representation across
  /// audio files with different dynamic ranges, especially useful when
  /// comparing multiple audio files.
  ///
  /// **Formula:** normalized_value = value / (rms_level * scale_factor)
  ///
  /// **Best for:** Comparing multiple audio files, perceptual consistency
  /// **Result:** More uniform apparent loudness across different files
  rms,
}
