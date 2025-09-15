/// Methods for downsampling when data points exceed display resolution
enum DownsampleMethod {
  /// Use maximum amplitude in each group (preserves peaks)
  max,

  /// Use RMS (Root Mean Square) of each group (preserves energy)
  rms,

  /// Use average amplitude of each group (smooth representation)
  average,

  /// Use both min and max to preserve dynamic range (returns pairs)
  minMax,
}
