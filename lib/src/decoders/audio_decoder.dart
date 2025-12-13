import 'dart:typed_data';
import '../models/audio_data.dart';

/// Audio format enumeration.
enum AudioFormat {
  mp3,
  wav,
  flac,
  ogg,
  opus,
  mp4,
  unknown;

  /// Get human-readable name for this format
  String get name {
    switch (this) {
      case AudioFormat.mp3:
        return 'MP3';
      case AudioFormat.wav:
        return 'WAV';
      case AudioFormat.flac:
        return 'FLAC';
      case AudioFormat.ogg:
        return 'OGG Vorbis';
      case AudioFormat.opus:
        return 'Opus';
      case AudioFormat.mp4:
        return 'MP4/AAC';
      case AudioFormat.unknown:
        return 'Unknown';
    }
  }

  /// Get typical compression ratio for this format
  double get typicalCompressionRatio {
    switch (this) {
      case AudioFormat.mp3:
        return 10.0; // MP3 is typically ~10:1 compression
      case AudioFormat.ogg:
        return 8.0; // OGG Vorbis is typically ~8:1 compression
      case AudioFormat.opus:
        return 12.0; // Opus is typically ~12:1 compression
      case AudioFormat.mp4:
        return 10.0; // MP4/AAC is typically ~10:1 compression
      case AudioFormat.flac:
        return 2.0; // FLAC is typically ~2:1 compression
      case AudioFormat.wav:
        return 1.0; // WAV is uncompressed
      case AudioFormat.unknown:
        return 10.0; // Conservative estimate
    }
  }

  /// Get list of file extensions for this format
  List<String> get extensions {
    switch (this) {
      case AudioFormat.mp3:
        return ['mp3'];
      case AudioFormat.wav:
        return ['wav', 'wave'];
      case AudioFormat.flac:
        return ['flac'];
      case AudioFormat.ogg:
        return ['ogg'];
      case AudioFormat.opus:
        return ['opus'];
      case AudioFormat.mp4:
        return ['mp4', 'm4a', 'aac'];
      case AudioFormat.unknown:
        return [];
    }
  }

  /// Check if this format supports chunked processing
  bool get supportsChunkedProcessing {
    switch (this) {
      case AudioFormat.mp3:
      case AudioFormat.wav:
      case AudioFormat.flac:
      case AudioFormat.ogg:
      case AudioFormat.opus:
      case AudioFormat.mp4:
        return true;
      case AudioFormat.unknown:
        return false;
    }
  }
}

/// Audio decoder - converts audio bytes to PCM samples.
///
/// Decoders are stateless and handle NO file I/O.
/// They simply transform encoded audio bytes into decoded samples.
abstract class AudioDecoder {
  /// Decode audio bytes into PCM samples.
  ///
  /// [data] - The encoded audio bytes (e.g., MP3 frame data, WAV file contents)
  /// Returns [AudioData] containing PCM samples and metadata.
  ///
  /// Throws [DecodingException] if the data cannot be decoded.
  AudioData decode(Uint8List data);

  /// The audio format this decoder handles.
  AudioFormat get format;

  /// Release any native resources held by this decoder.
  void dispose();
}
