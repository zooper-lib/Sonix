/// Represents a portion of waveform data used in streaming processing.
///
/// This class is used internally during chunked/streaming waveform generation
/// to provide partial results as audio processing progresses. Each chunk
/// contains amplitude data for a specific time segment of the audio.
///
/// ## Use Cases
///
/// - **Real-time visualization**: Show waveform as it's being generated
/// - **Large file processing**: Process audio in manageable segments
/// - **Progressive loading**: Display partial waveforms for better UX
/// - **Memory optimization**: Avoid loading entire waveform at once
///
/// ## Example
/// ```dart
/// // Typically received through streaming API
/// await for (final progress in sonix.generateWaveformStream('audio.mp3')) {
///   if (progress.partialData != null) {
///     final chunk = progress.partialData!.chunks?.last;
///     if (chunk != null) {
///       print('Chunk: ${chunk.amplitudes.length} points');
///       print('Time offset: ${chunk.startTime}');
///       print('Is final chunk: ${chunk.isLast}');
///     }
///   }
/// }
/// ```
class WaveformChunk {
  /// Amplitude values contained in this specific chunk.
  ///
  /// Each value represents the waveform amplitude for this time segment,
  /// normalized to 0.0-1.0 range. The number of values depends on the
  /// chunk size and resolution settings.
  final List<double> amplitudes;

  /// Time offset from the beginning of the audio where this chunk starts.
  ///
  /// This allows proper positioning of the chunk data within the complete
  /// waveform timeline. Use this to calculate the absolute time position
  /// of each amplitude value in the chunk.
  final Duration startTime;

  /// Whether this is the final chunk in the processing stream.
  ///
  /// When true, indicates that waveform processing is complete and no
  /// more chunks will follow. Use this to trigger final UI updates or
  /// cleanup operations.
  final bool isLast;

  const WaveformChunk({required this.amplitudes, required this.startTime, required this.isLast});

  @override
  String toString() {
    return 'WaveformChunk(amplitudes: ${amplitudes.length}, '
        'startTime: $startTime, isLast: $isLast)';
  }
}
