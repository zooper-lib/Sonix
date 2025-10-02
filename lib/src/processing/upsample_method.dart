/// Methods for upsampling when data points are fewer than display resolution
enum UpsampleMethod {
  /// Linear interpolation between points
  linear,

  /// Repeat each point to fill space
  repeat,

  /// Cubic interpolation for smoother curves
  cubic,
}
