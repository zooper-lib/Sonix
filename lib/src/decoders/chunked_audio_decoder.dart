import '../models/audio_data.dart';
import '../models/file_chunk.dart';
import '../models/chunked_processing_models.dart';
import 'audio_decoder.dart';

/// Enhanced audio decoder interface that supports chunked processing
///
/// This interface extends the base AudioDecoder to provide chunked processing
/// capabilities, allowing for memory-efficient processing of large audio files
/// and efficient seeking within files.
abstract class ChunkedAudioDecoder extends AudioDecoder {
  /// Initialize the decoder for chunked processing
  ///
  /// [filePath] - Path to the audio file to process
  /// [chunkSize] - Size of file chunks to process (default: 10MB)
  /// [seekPosition] - Optional initial seek position
  ///
  /// Returns a Future that completes when initialization is done
  Future<void> initializeChunkedDecoding(
    String filePath, {
    int chunkSize = 10 * 1024 * 1024, // 10MB default
    Duration? seekPosition,
  });

  /// Process a single file chunk and return decoded audio chunks
  ///
  /// [fileChunk] - The file chunk to process
  ///
  /// Returns a list of AudioChunk objects containing the decoded audio data
  /// The list may be empty if the chunk contains no decodable audio data
  Future<List<AudioChunk>> processFileChunk(FileChunk fileChunk);

  /// Seek to a specific time position in the audio file
  ///
  /// [position] - The time position to seek to
  ///
  /// Returns a SeekResult indicating the actual position reached and whether
  /// the seek was exact or approximate
  Future<SeekResult> seekToTime(Duration position);

  /// Get format-specific chunk size recommendations
  ///
  /// [fileSize] - Size of the file in bytes
  ///
  /// Returns a ChunkSizeRecommendation with optimal chunk sizes for this format
  ChunkSizeRecommendation getOptimalChunkSize(int fileSize);

  /// Whether this format supports efficient seeking
  ///
  /// Some formats (like MP3) have limited seeking capabilities due to their
  /// structure, while others (like WAV) support sample-accurate seeking
  bool get supportsEfficientSeeking;

  /// Get the current decoding position
  ///
  /// Returns the current position in the audio stream
  Duration get currentPosition;

  /// Reset the decoder state
  ///
  /// This is useful after seeking or when recovering from errors.
  /// It clears any internal buffers and resets the decoder to a clean state.
  Future<void> resetDecoderState();

  /// Get format-specific metadata that may affect chunked processing
  ///
  /// Returns a map containing format-specific information such as:
  /// - Frame size (for MP3)
  /// - Block size (for FLAC)
  /// - Sample rate and channels
  /// - Seek table information (if available)
  Map<String, dynamic> getFormatMetadata();

  /// Estimate the total duration of the audio file
  ///
  /// This may be called before full initialization to provide progress estimates
  Future<Duration?> estimateDuration();

  /// Check if the decoder is ready for chunked processing
  ///
  /// Returns true if initializeChunkedDecoding has been called successfully
  bool get isInitialized;

  /// Clean up chunked processing resources
  ///
  /// This should be called when chunked processing is complete to free
  /// any format-specific resources
  Future<void> cleanupChunkedProcessing();
}
