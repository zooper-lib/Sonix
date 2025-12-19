import 'dart:typed_data';

/// Raw decoded audio data from audio files
class AudioData {
  /// Audio samples as floating point values (-1.0 to 1.0)
  final List<double> samples;

  /// Sample rate in Hz (e.g., 44100, 48000)
  final int sampleRate;

  /// Number of audio channels (1 for mono, 2 for stereo)
  final int channels;

  /// Duration of the audio
  final Duration duration;

  const AudioData({required this.samples, required this.sampleRate, required this.channels, required this.duration});

  /// Dispose of resources (for memory management)
  void dispose() {
    // Typed lists (e.g. Float32List) are fixed-length and cannot be cleared.
    if (samples is TypedData) return;

    // Some fixed-length List<double> implementations may also throw.
    try {
      samples.clear();
    } on UnsupportedError {
      // Ignore.
    }
  }

  @override
  String toString() {
    return 'AudioData(samples: ${samples.length}, sampleRate: $sampleRate, '
        'channels: $channels, duration: $duration)';
  }
}

/// Represents a chunk of audio data for streaming processing
class AudioChunk {
  /// Audio samples in this chunk
  final List<double> samples;

  /// Starting sample index in the overall audio stream
  final int startSample;

  /// Whether this is the last chunk in the stream
  final bool isLast;

  const AudioChunk({required this.samples, required this.startSample, required this.isLast});

  @override
  String toString() {
    return 'AudioChunk(samples: ${samples.length}, startSample: $startSample, '
        'isLast: $isLast)';
  }
}
