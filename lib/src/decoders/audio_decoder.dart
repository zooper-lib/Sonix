import '../models/audio_data.dart';

/// Abstract interface for audio decoders
abstract class AudioDecoder {
  /// Decode an entire audio file to AudioData
  Future<AudioData> decode(String filePath);

  /// Clean up resources
  void dispose();
}

/// Supported audio formats
enum AudioFormat { mp3, wav, flac, ogg, opus, mp4, unknown }

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
      case AudioFormat.mp4:
        return ['mp4', 'm4a'];
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
      case AudioFormat.mp4:
        return 'MP4/AAC';
      case AudioFormat.unknown:
        return 'Unknown';
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

  /// Get typical compression ratio for memory estimation
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

  /// Get typical bitrate in bits per second for duration estimation
  int get typicalBitrate {
    switch (this) {
      case AudioFormat.mp3:
        return 192000; // 192 kbps
      case AudioFormat.ogg:
        return 160000; // 160 kbps
      case AudioFormat.opus:
        return 96000; // 96 kbps (Opus is very efficient)
      case AudioFormat.mp4:
        return 192000; // 192 kbps AAC
      case AudioFormat.flac:
        return 800000; // ~800 kbps average for FLAC
      case AudioFormat.wav:
        return 1411200; // CD quality: 44.1kHz * 16bit * 2ch
      case AudioFormat.unknown:
        return 128000; // Conservative 128 kbps
    }
  }
}
