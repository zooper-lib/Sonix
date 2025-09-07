import '../models/audio_data.dart';

/// Abstract interface for audio decoders
abstract class AudioDecoder {
  /// Decode an entire audio file to AudioData
  Future<AudioData> decode(String filePath);

  /// Decode audio file as a stream of chunks for memory efficiency
  Stream<AudioChunk> decodeStream(String filePath);

  /// Get metadata from an audio file without full decoding
  Future<AudioMetadata> getMetadata(String filePath);

  /// Clean up resources
  void dispose();
}

/// Supported audio formats
enum AudioFormat { mp3, wav, flac, ogg, opus, unknown }

/// Extension methods for AudioFormat
extension AudioFormatExtension on AudioFormat {
  /// Get file extensions for this format
  List<String> get extensions {
    switch (this) {
      case AudioFormat.mp3:
        return ['mp3'];
      case AudioFormat.wav:
        return ['wav'];
      case AudioFormat.flac:
        return ['flac'];
      case AudioFormat.ogg:
        return ['ogg'];
      case AudioFormat.opus:
        return ['opus'];
      case AudioFormat.unknown:
        return [];
    }
  }

  /// Get format name
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
      case AudioFormat.unknown:
        return 'Unknown';
    }
  }
}
