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
const int SONIX_FORMAT_OPUS = 5;

/// Error codes
const int SONIX_OK = 0;
const int SONIX_ERROR_INVALID_FORMAT = -1;
const int SONIX_ERROR_DECODE_FAILED = -2;
const int SONIX_ERROR_OUT_OF_MEMORY = -3;
const int SONIX_ERROR_INVALID_DATA = -4;

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

typedef SonixGetLastMp3DebugStatsNative = ffi.Pointer<SonixMp3DebugStats> Function();
typedef SonixGetLastMp3DebugStatsDart = ffi.Pointer<SonixMp3DebugStats> Function();

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
}
