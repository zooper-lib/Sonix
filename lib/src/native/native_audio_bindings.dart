import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'sonix_bindings.dart';
import '../models/audio_data.dart';
import '../decoders/audio_decoder.dart';
import '../exceptions/sonix_exceptions.dart';

/// High-level wrapper for native audio bindings
class NativeAudioBindings {
  static bool _initialized = false;
  static int _memoryPressureThreshold = 100 * 1024 * 1024; // 100MB threshold

  /// Initialize the native bindings
  static void initialize() {
    if (_initialized) return;

    try {
      // Try to load the library to verify it's available
      SonixNativeBindings.lib;
      _initialized = true;
    } catch (e) {
      throw FFIException('Failed to initialize native audio bindings', 'Make sure the native library is built and available: $e');
    }
  }

  /// Set memory pressure threshold for streaming operations
  static void setMemoryPressureThreshold(int bytes) {
    _memoryPressureThreshold = bytes;
  }

  /// Get current memory pressure threshold
  static int get memoryPressureThreshold => _memoryPressureThreshold;

  /// Detect audio format from file data
  static AudioFormat detectFormat(Uint8List data) {
    _ensureInitialized();

    if (data.isEmpty) {
      throw DecodingException('Cannot detect format: empty data');
    }

    final pointer = _allocateUint8Array(data);

    try {
      final formatCode = SonixNativeBindings.detectFormat(pointer, data.length);
      return _formatCodeToEnum(formatCode);
    } finally {
      malloc.free(pointer);
    }
  }

  /// Decode audio data from memory
  static AudioData decodeAudio(Uint8List data, AudioFormat format) {
    _ensureInitialized();

    if (data.isEmpty) {
      throw DecodingException('Cannot decode: empty data');
    }

    // Check for memory pressure before large allocations
    if (data.length > _memoryPressureThreshold) {
      throw MemoryException('File size exceeds memory pressure threshold', 'File size: ${data.length} bytes, threshold: $_memoryPressureThreshold bytes');
    }

    final dataPointer = _allocateUint8Array(data);

    try {
      final formatCode = _formatEnumToCode(format);
      final resultPointer = SonixNativeBindings.decodeAudio(dataPointer, data.length, formatCode);

      if (resultPointer == ffi.nullptr) {
        final errorMsg = _getLastErrorMessage();
        throw DecodingException('Failed to decode audio', errorMsg);
      }

      try {
        return _convertNativeAudioData(resultPointer.ref);
      } finally {
        SonixNativeBindings.freeAudioData(resultPointer);
      }
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw DecodingException('Native decoding failed', 'Error during FFI operation: $e');
    } finally {
      malloc.free(dataPointer);
    }
  }

  /// Check if memory pressure would be exceeded for given data size
  static bool wouldExceedMemoryPressure(int dataSize) {
    return dataSize > _memoryPressureThreshold;
  }

  /// Get the last error message from native library
  static String _getLastErrorMessage() {
    try {
      final errorPointer = SonixNativeBindings.getErrorMessage();
      if (errorPointer == ffi.nullptr) {
        return 'Unknown error';
      }
      return errorPointer.cast<Utf8>().toDartString();
    } catch (e) {
      return 'Failed to get error message: $e';
    }
  }

  /// Convert native audio data to Dart AudioData
  static AudioData _convertNativeAudioData(SonixAudioData nativeData) {
    if (nativeData.samples == ffi.nullptr || nativeData.sample_count == 0) {
      throw DecodingException('Invalid native audio data');
    }

    // Convert native float array to Dart list
    final samples = <double>[];
    for (int i = 0; i < nativeData.sample_count; i++) {
      samples.add(nativeData.samples[i]);
    }

    return AudioData(
      samples: samples,
      sampleRate: nativeData.sample_rate,
      channels: nativeData.channels,
      duration: Duration(milliseconds: nativeData.duration_ms),
    );
  }

  /// Allocate native memory for Uint8List
  static ffi.Pointer<ffi.Uint8> _allocateUint8Array(Uint8List data) {
    final pointer = malloc<ffi.Uint8>(data.length);
    final nativeData = pointer.asTypedList(data.length);
    nativeData.setAll(0, data);
    return pointer;
  }

  /// Convert format enum to native format code
  static int _formatEnumToCode(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        return SONIX_FORMAT_MP3;
      case AudioFormat.wav:
        return SONIX_FORMAT_WAV;
      case AudioFormat.flac:
        return SONIX_FORMAT_FLAC;
      case AudioFormat.ogg:
        return SONIX_FORMAT_OGG;
      case AudioFormat.opus:
        return SONIX_FORMAT_OPUS;
      case AudioFormat.unknown:
        return SONIX_FORMAT_UNKNOWN;
    }
  }

  /// Convert native format code to format enum
  static AudioFormat _formatCodeToEnum(int formatCode) {
    switch (formatCode) {
      case SONIX_FORMAT_MP3:
        return AudioFormat.mp3;
      case SONIX_FORMAT_WAV:
        return AudioFormat.wav;
      case SONIX_FORMAT_FLAC:
        return AudioFormat.flac;
      case SONIX_FORMAT_OGG:
        return AudioFormat.ogg;
      case SONIX_FORMAT_OPUS:
        return AudioFormat.opus;
      case SONIX_FORMAT_UNKNOWN:
      default:
        return AudioFormat.unknown;
    }
  }

  /// Ensure bindings are initialized
  static void _ensureInitialized() {
    if (!_initialized) {
      initialize();
    }
  }

  /// Estimate memory usage for decoded audio
  static int estimateDecodedMemoryUsage(int fileSize, AudioFormat format) {
    // Rough estimates based on typical compression ratios
    switch (format) {
      case AudioFormat.mp3:
        return fileSize * 10; // MP3 is typically ~10:1 compression
      case AudioFormat.ogg:
        return fileSize * 8; // OGG Vorbis is typically ~8:1 compression
      case AudioFormat.flac:
        return fileSize * 2; // FLAC is typically ~2:1 compression
      case AudioFormat.wav:
        return fileSize; // WAV is uncompressed
      case AudioFormat.opus:
        return fileSize * 12; // Opus can be very efficient
      case AudioFormat.unknown:
        return fileSize * 10; // Conservative estimate
    }
  }

  /// Check if decoding would exceed memory limits
  static bool wouldExceedMemoryLimits(int fileSize, AudioFormat format) {
    final estimatedMemory = estimateDecodedMemoryUsage(fileSize, format);
    return estimatedMemory > _memoryPressureThreshold;
  }
}
