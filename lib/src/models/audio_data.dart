import '../utils/lru_cache.dart';

/// Raw decoded audio data from audio files
class AudioData implements Disposable {
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
  @override
  void dispose() {
    // Clear the samples list to help with garbage collection
    samples.clear();
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

/// Metadata about an audio file
class AudioMetadata {
  /// File format (e.g., 'mp3', 'wav', 'flac')
  final String format;

  /// Bitrate in kbps
  final int? bitrate;

  /// File size in bytes
  final int? fileSize;

  /// Title metadata
  final String? title;

  /// Artist metadata
  final String? artist;

  /// Album metadata
  final String? album;

  const AudioMetadata({required this.format, this.bitrate, this.fileSize, this.title, this.artist, this.album});

  @override
  String toString() {
    return 'AudioMetadata(format: $format, bitrate: $bitrate, '
        'fileSize: $fileSize, title: $title, artist: $artist, album: $album)';
  }
}
