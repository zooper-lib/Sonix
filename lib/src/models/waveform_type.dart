/// Types of waveform visualization available for rendering.
///
/// Each type provides a different visual representation of the audio waveform:
/// - [bars]: Traditional bar-style waveform (default), where each amplitude
///   is represented as a vertical bar
/// - [line]: Continuous line connecting amplitude points, suitable for detailed
///   waveform analysis
/// - [filled]: Filled area under the waveform line, creating a solid shape
///   visualization
enum WaveformType { bars, line, filled }
