// Generated FFI bindings for Sonix native audio library
// ignore_for_file: always_specify_types, constant_identifier_names
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

/// Audio format constants
const int SONIX_FORMAT_UNKNOWN = 0;
const int SONIX_FORMAT_MP3 = 1;
const int SONIX_FORMAT_FLAC = 2;
const int SONIX_FORMAT_WAV = 3;
const int SONIX_FORMAT_OGG = 4;
const int SONIX_FORMAT_MP4 = 5;

/// Error codes
const int SONIX_OK = 0;
const int SONIX_ERROR_INVALID_FORMAT = -1;
const int SONIX_ERROR_DECODE_FAILED = -2;
const int SONIX_ERROR_OUT_OF_MEMORY = -3;
const int SONIX_ERROR_INVALID_DATA = -4;

/// MP4-specific error codes
const int SONIX_ERROR_MP4_CONTAINER_INVALID = -10;
const int SONIX_ERROR_MP4_NO_AUDIO_TRACK = -11;
const int SONIX_ERROR_MP4_UNSUPPORTED_CODEC = -12;

/// Native audio data structure
final class SonixAudioData extends ffi.Struct {
  external ffi.Pointer<ffi.Float> samples;
  @ffi.Uint32()
  external int sample_count;
  @ffi.Uint32()
  external int sample_rate;
  @ffi.Uint32()
  external int channels;
  @ffi.Uint32()
  external int duration_ms;
}

/// Debug stats (development) for last MP3 decode
final class SonixMp3DebugStats extends ffi.Struct {
  @ffi.Uint32()
  external int frame_count;
  @ffi.Uint32()
  external int total_samples; // interleaved stored samples
  @ffi.Uint32()
  external int channels;
  @ffi.Uint32()
  external int sample_rate;
  @ffi.Uint64()
  external int processed_bytes;
  @ffi.Uint64()
  external int file_size;
}

/// Chunked processing structures
final class SonixFileChunk extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> data;
  @ffi.Size()
  external int size;
  @ffi.Uint64()
  external int position;
  @ffi.Int32()
  external int is_last;
}

final class SonixAudioChunk extends ffi.Struct {
  external ffi.Pointer<ffi.Float> samples;
  @ffi.Uint32()
  external int sample_count;
  @ffi.Uint64()
  external int start_sample;
  @ffi.Int32()
  external int is_last;
}

final class SonixChunkResult extends ffi.Struct {
  external ffi.Pointer<SonixAudioChunk> chunks;
  @ffi.Uint32()
  external int chunk_count;
  @ffi.Int32()
  external int error_code;
  external ffi.Pointer<ffi.Char> error_message;
}

/// Opaque chunked decoder handle
final class SonixChunkedDecoder extends ffi.Opaque {}

typedef SonixGetLastMp3DebugStatsNative = ffi.Pointer<SonixMp3DebugStats> Function();
typedef SonixGetLastMp3DebugStatsDart = ffi.Pointer<SonixMp3DebugStats> Function();

// Chunked processing function signatures
typedef SonixInitChunkedDecoderNative = ffi.Pointer<SonixChunkedDecoder> Function(ffi.Int32 format, ffi.Pointer<ffi.Char> filePath);
typedef SonixInitChunkedDecoderDart = ffi.Pointer<SonixChunkedDecoder> Function(int format, ffi.Pointer<ffi.Char> filePath);

typedef SonixProcessFileChunkNative = ffi.Pointer<SonixChunkResult> Function(ffi.Pointer<SonixChunkedDecoder> decoder, ffi.Pointer<SonixFileChunk> fileChunk);
typedef SonixProcessFileChunkDart = ffi.Pointer<SonixChunkResult> Function(ffi.Pointer<SonixChunkedDecoder> decoder, ffi.Pointer<SonixFileChunk> fileChunk);

typedef SonixSeekToTimeNative = ffi.Int32 Function(ffi.Pointer<SonixChunkedDecoder> decoder, ffi.Uint32 timeMs);
typedef SonixSeekToTimeDart = int Function(ffi.Pointer<SonixChunkedDecoder> decoder, int timeMs);

typedef SonixGetOptimalChunkSizeNative = ffi.Uint32 Function(ffi.Int32 format, ffi.Uint64 fileSize);
typedef SonixGetOptimalChunkSizeDart = int Function(int format, int fileSize);

typedef SonixCleanupChunkedDecoderNative = ffi.Void Function(ffi.Pointer<SonixChunkedDecoder> decoder);
typedef SonixCleanupChunkedDecoderDart = void Function(ffi.Pointer<SonixChunkedDecoder> decoder);

typedef SonixFreeChunkResultNative = ffi.Void Function(ffi.Pointer<SonixChunkResult> result);
typedef SonixFreeChunkResultDart = void Function(ffi.Pointer<SonixChunkResult> result);

/// Function signatures for native library
typedef SonixDetectFormatNative = ffi.Int32 Function(ffi.Pointer<ffi.Uint8> data, ffi.Size size);

typedef SonixDetectFormatDart = int Function(ffi.Pointer<ffi.Uint8> data, int size);

typedef SonixDecodeAudioNative = ffi.Pointer<SonixAudioData> Function(ffi.Pointer<ffi.Uint8> data, ffi.Size size, ffi.Int32 format);

typedef SonixDecodeAudioDart = ffi.Pointer<SonixAudioData> Function(ffi.Pointer<ffi.Uint8> data, int size, int format);

typedef SonixFreeAudioDataNative = ffi.Void Function(ffi.Pointer<SonixAudioData> audioData);

typedef SonixFreeAudioDataDart = void Function(ffi.Pointer<SonixAudioData> audioData);

typedef SonixGetErrorMessageNative = ffi.Pointer<ffi.Char> Function();

typedef SonixGetErrorMessageDart = ffi.Pointer<ffi.Char> Function();

/// Native library bindings
class SonixNativeBindings {
  static ffi.DynamicLibrary? _lib;

  /// Load the native library
  static ffi.DynamicLibrary _loadLibrary() {
    if (_lib != null) return _lib!;

    const String libName = 'sonix_native';

    if (Platform.isAndroid) {
      _lib = ffi.DynamicLibrary.open('lib$libName.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _lib = ffi.DynamicLibrary.open('lib$libName.dylib');
    } else if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open('$libName.dll');
    } else if (Platform.isLinux) {
      _lib = ffi.DynamicLibrary.open('lib$libName.so');
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    return _lib!;
  }

  /// Get the native library instance
  static ffi.DynamicLibrary get lib => _loadLibrary();

  /// Detect audio format from file data
  static final SonixDetectFormatDart detectFormat = lib.lookup<ffi.NativeFunction<SonixDetectFormatNative>>('sonix_detect_format').asFunction();

  /// Decode audio data from memory
  static final SonixDecodeAudioDart decodeAudio = lib.lookup<ffi.NativeFunction<SonixDecodeAudioNative>>('sonix_decode_audio').asFunction();

  /// Free audio data allocated by decode_audio
  static final SonixFreeAudioDataDart freeAudioData = lib.lookup<ffi.NativeFunction<SonixFreeAudioDataNative>>('sonix_free_audio_data').asFunction();

  /// Get error message for the last error
  static final SonixGetErrorMessageDart getErrorMessage = lib.lookup<ffi.NativeFunction<SonixGetErrorMessageNative>>('sonix_get_error_message').asFunction();

  // Debug: MP3 stats accessor (may return nullptr if not applicable)
  static final SonixGetLastMp3DebugStatsDart getLastMp3DebugStats = lib
      .lookup<ffi.NativeFunction<SonixGetLastMp3DebugStatsNative>>('sonix_get_last_mp3_debug_stats')
      .asFunction();

  // Chunked processing functions

  /// Initialize chunked decoder for a specific format
  static final SonixInitChunkedDecoderDart initChunkedDecoder = lib
      .lookup<ffi.NativeFunction<SonixInitChunkedDecoderNative>>('sonix_init_chunked_decoder')
      .asFunction();

  /// Process a file chunk and return decoded audio chunks
  static final SonixProcessFileChunkDart processFileChunk = lib
      .lookup<ffi.NativeFunction<SonixProcessFileChunkNative>>('sonix_process_file_chunk')
      .asFunction();

  /// Seek to a specific time position in the audio file
  static final SonixSeekToTimeDart seekToTime = lib.lookup<ffi.NativeFunction<SonixSeekToTimeNative>>('sonix_seek_to_time').asFunction();

  /// Get optimal chunk size for a given format and file size
  static final SonixGetOptimalChunkSizeDart getOptimalChunkSize = lib
      .lookup<ffi.NativeFunction<SonixGetOptimalChunkSizeNative>>('sonix_get_optimal_chunk_size')
      .asFunction();

  /// Cleanup chunked decoder and free resources
  static final SonixCleanupChunkedDecoderDart cleanupChunkedDecoder = lib
      .lookup<ffi.NativeFunction<SonixCleanupChunkedDecoderNative>>('sonix_cleanup_chunked_decoder')
      .asFunction();

  /// Free chunk result allocated by processFileChunk
  static final SonixFreeChunkResultDart freeChunkResult = lib.lookup<ffi.NativeFunction<SonixFreeChunkResultNative>>('sonix_free_chunk_result').asFunction();
}
