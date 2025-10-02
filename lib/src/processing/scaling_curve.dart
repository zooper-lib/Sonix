/// Amplitude scaling curves for perceptual optimization of waveform display.
///
/// These curves modify how amplitude values are mapped to visual height,
/// allowing for perceptual optimization based on human auditory characteristics
/// and the intended use case. Different curves can emphasize different aspects
/// of the audio content.
///
/// ## Curve Characteristics
///
/// - **Linear**: True to original data, no perceptual optimization
/// - **Logarithmic**: Emphasizes quiet details, compresses loud sections
/// - **Exponential**: Emphasizes loud sections, compresses quiet details
/// - **Square Root**: Balanced compromise between linear and logarithmic
///
/// ## Use Case Examples
///
/// ```dart
/// // Natural, unmodified representation
/// WaveformConfig(scalingCurve: ScalingCurve.linear)
///
/// // Better for wide dynamic range content (classical music)
/// WaveformConfig(scalingCurve: ScalingCurve.logarithmic)
///
/// // Emphasize strong beats and impacts
/// WaveformConfig(scalingCurve: ScalingCurve.exponential)
///
/// // Balanced approach for general music
/// WaveformConfig(scalingCurve: ScalingCurve.sqrt)
/// ```
enum ScalingCurve {
  /// Linear scaling preserves the original amplitude relationships.
  ///
  /// No mathematical transformation is applied to the amplitude values.
  /// This provides the most accurate representation of the source audio's
  /// amplitude characteristics without any perceptual optimization.
  ///
  /// **Formula:** output = input
  /// **Best for:** Technical analysis, accurate amplitude representation
  /// **Visual effect:** Natural amplitude mapping
  linear,

  /// Logarithmic scaling emphasizes quiet sections and compresses loud ones.
  ///
  /// Applies a logarithmic curve that makes quiet details more visible
  /// while preventing loud sections from dominating the display. This
  /// mimics human auditory perception and is excellent for content with
  /// wide dynamic range.
  ///
  /// **Formula:** output = log(1 + input * scale) / log(1 + scale)
  /// **Best for:** Classical music, wide dynamic range content, detailed analysis
  /// **Visual effect:** More visible quiet details, compressed loud sections
  logarithmic,

  /// Exponential scaling emphasizes loud sections and compresses quiet ones.
  ///
  /// Applies an exponential curve that makes loud sections more prominent
  /// while de-emphasizing quiet details. Useful for content where the
  /// strong beats and impacts are the most important visual elements.
  ///
  /// **Formula:** output = (exp(input * scale) - 1) / (exp(scale) - 1)
  /// **Best for:** Electronic music, percussion-heavy content, rhythm emphasis
  /// **Visual effect:** Pronounced loud sections, subtle quiet details
  exponential,

  /// Square root scaling provides a balanced perceptual optimization.
  ///
  /// Applies a square root transformation that provides a compromise between
  /// linear and logarithmic scaling. Enhances quiet details moderately while
  /// maintaining good representation of loud sections.
  ///
  /// **Formula:** output = sqrt(input)
  /// **Best for:** General music, balanced representation, most content types
  /// **Visual effect:** Moderately enhanced quiet details, preserved dynamics
  sqrt,
}
