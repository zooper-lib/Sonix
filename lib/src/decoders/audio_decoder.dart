import '../models/audio_data.dart';

/// Abstract interface for audio decoders
abstract class AudioDecoder {
  /// Decode an entire audio file to AudioData
  Future<AudioData> decode(String filePath);

  /// Clean up resources
  void dispose();
}

/// Supported audio formats
enum AudioFormat { mp3, wav, flac, ogg, mp4, aac, unknown }

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
      case AudioFormat.mp4:
        return ['mp4', 'm4a'];
      case AudioFormat.aac:
        return ['aac'];
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
      case AudioFormat.mp4:
        return 'MP4';
      case AudioFormat.aac:
        return 'AAC';
      case AudioFormat.unknown:
        return 'Unknown';
    }
  }
}
