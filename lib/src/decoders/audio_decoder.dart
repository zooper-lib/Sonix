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
        return 1411000; // 1411 kbps (CD quality)
      case AudioFormat.wav:
        return 1411000; // 1411 kbps (CD quality)
      case AudioFormat.unknown:
        return 192000; // Conservative estimate
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

/// Extended decoder interface for formats that benefit from
/// stateful/streaming decoding (e.g., MP3 with frame boundaries).
///
/// This interface maintains state between decode calls, making it suitable
/// for processing large files in chunks without loading the entire file.
abstract class StreamingAudioDecoder implements AudioDecoder {
  /// Initialize the decoder with format-specific metadata.
  ///
  /// Some formats (like MP3) need header info before decoding chunks.
  /// This method should be called once before any decodeChunk() calls.
  ///
  /// [metadata] - Format-specific metadata extracted from file headers
  void initialize(Map<String, dynamic> metadata);

  /// Decode a chunk of audio data in a streaming context.
  ///
  /// Unlike [decode], this maintains state between calls for
  /// formats with frame boundaries or inter-frame dependencies.
  ///
  /// [chunk] - A portion of the audio file
  /// [isLast] - Whether this is the final chunk
  /// Returns decoded samples from this chunk.
  ///
  /// Throws [DecodingException] if the chunk cannot be decoded.
  AudioData decodeChunk(Uint8List chunk, {bool isLast = false});

  /// Reset decoder state (e.g., after seeking or error recovery).
  ///
  /// This clears any internal buffers and returns the decoder to
  /// a clean state, ready to process new data.
  void reset();

  /// Whether this decoder has been initialized and is ready for chunk processing.
  bool get isInitialized;
}
