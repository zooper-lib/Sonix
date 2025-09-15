/// Methods for audio signal downsampling during waveform generation.
///
/// These algorithms determine how large amounts of audio data are reduced
/// to the target waveform resolution while preserving important characteristics.
/// Each algorithm has different computational costs and preserves different
/// aspects of the audio signal.
///
/// ## Algorithm Selection Guide
///
/// - **RMS**: Best general-purpose algorithm for music and mixed content
/// - **Peak**: Ideal for percussive content and speech with clear transients
/// - **Average**: Simple and fast, good for smooth ambient content
/// - **Median**: Excellent noise resistance for problematic recordings
///
/// ## Performance Comparison
///
/// | Algorithm | Speed | Quality | Best Use Case |
/// |-----------|-------|---------|---------------|
/// | Average   | Fast  | Basic   | Ambient, simple content |
/// | Peak      | Fast  | Good    | Drums, speech, transients |
/// | RMS       | Medium| Excellent| Music, general purpose |
/// | Median    | Slow  | Good    | Noisy recordings |
///
/// ## Example Usage
///
/// ```dart
/// // Music with dynamic range
/// WaveformConfig(algorithm: DownsamplingAlgorithm.rms)
///
/// // Drum tracks or percussive content
/// WaveformConfig(algorithm: DownsamplingAlgorithm.peak)
///
/// // Speech or podcasts
/// WaveformConfig(algorithm: DownsamplingAlgorithm.average)
///
/// // Noisy recordings or field recordings
/// WaveformConfig(algorithm: DownsamplingAlgorithm.median)
/// ```
enum DownsamplingAlgorithm {
  /// Root Mean Square - optimal for perceived loudness and musical content.
  ///
  /// Calculates the square root of the mean of squared amplitude values.
  /// This closely matches human auditory perception and provides excellent
  /// results for music, providing good representation of both loud and
  /// quiet sections while maintaining perceptual accuracy.
  ///
  /// **Best for:** Music, mixed content, general-purpose use
  /// **Computational cost:** Medium
  rms,

  /// Peak detection - preserves maximum amplitude in each segment.
  ///
  /// Finds the highest absolute amplitude value in each segment. Excellent
  /// for preserving transients, attacks, and sharp volume changes that are
  /// important for rhythmic content and speech consonants.
  ///
  /// **Best for:** Drums, percussion, speech, any transient-heavy content
  /// **Computational cost:** Low
  peak,

  /// Simple average - arithmetic mean of amplitude values.
  ///
  /// Calculates the arithmetic mean of all amplitude values in each segment.
  /// Fast and simple, provides smooth results but may miss important peaks
  /// or transients. Good for content with relatively stable amplitude.
  ///
  /// **Best for:** Ambient music, sustained tones, smooth content
  /// **Computational cost:** Low
  average,

  /// Median value - middle value when samples are sorted by amplitude.
  ///
  /// Uses the median amplitude value from each segment, providing excellent
  /// noise resistance and outlier rejection. Particularly effective for
  /// recordings with background noise or unwanted spikes.
  ///
  /// **Best for:** Noisy recordings, field recordings, cleaning up artifacts
  /// **Computational cost:** High (requires sorting)
  median,
}
