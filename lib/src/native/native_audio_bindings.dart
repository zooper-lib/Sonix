import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'sonix_bindings.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';

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
      return formatCodeToEnum(formatCode);
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
      final formatCode = formatEnumToCode(format);
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

  /// Get formatted error message for MP4-specific error codes
  static String getMP4ErrorMessage(int errorCode) {
    switch (errorCode) {
      case SONIX_ERROR_MP4_CONTAINER_INVALID:
        return 'Invalid MP4 container structure. The file may be corrupted or not a valid MP4 file.';
      case SONIX_ERROR_MP4_NO_AUDIO_TRACK:
        return 'No audio track found in MP4 file. The file may contain only video or be corrupted.';
      case SONIX_ERROR_MP4_UNSUPPORTED_CODEC:
        return 'Unsupported audio codec in MP4 file. Only AAC codec is currently supported.';
      default:
        return _getLastErrorMessage();
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
  static int formatEnumToCode(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        return SONIX_FORMAT_MP3;
      case AudioFormat.wav:
        return SONIX_FORMAT_WAV;
      case AudioFormat.flac:
        return SONIX_FORMAT_FLAC;
      case AudioFormat.ogg:
        return SONIX_FORMAT_OGG;
      case AudioFormat.mp4:
        return SONIX_FORMAT_MP4;
      case AudioFormat.unknown:
        return SONIX_FORMAT_UNKNOWN;
    }
  }

  /// Convert native format code to format enum
  static AudioFormat formatCodeToEnum(int formatCode) {
    switch (formatCode) {
      case SONIX_FORMAT_MP3:
        return AudioFormat.mp3;
      case SONIX_FORMAT_WAV:
        return AudioFormat.wav;
      case SONIX_FORMAT_FLAC:
        return AudioFormat.flac;
      case SONIX_FORMAT_OGG:
        return AudioFormat.ogg;
      case SONIX_FORMAT_MP4:
        return AudioFormat.mp4;
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
    // Use compression ratios from AudioFormat extension
    final compressionRatio = format.typicalCompressionRatio;

    // For MP4/AAC, provide more detailed estimation
    if (format == AudioFormat.mp4) {
      return _estimateMP4DecodedMemoryUsage(fileSize);
    }

    return (fileSize * compressionRatio).round();
  }

  /// Estimate memory usage specifically for MP4/AAC files
  static int _estimateMP4DecodedMemoryUsage(int fileSize) {
    // MP4/AAC typical characteristics:
    // - AAC compression ratio: ~10:1 for 128kbps, ~8:1 for 192kbps, ~6:1 for 256kbps
    // - Container overhead: ~2-5% of file size
    // - Sample format: 32-bit float (4 bytes per sample)

    // Conservative estimate assuming 128kbps AAC (10:1 compression)
    final baseEstimate = fileSize * 10.0;

    // Add 20% buffer for container overhead and processing
    final withOverhead = baseEstimate * 1.2;

    // Ensure minimum reasonable size (at least 4x file size for very compressed files)
    final minimumEstimate = fileSize * 4.0;

    return (withOverhead > minimumEstimate ? withOverhead : minimumEstimate).round();
  }

  /// Check if decoding would exceed memory limits
  static bool wouldExceedMemoryLimits(int fileSize, AudioFormat format) {
    final estimatedMemory = estimateDecodedMemoryUsage(fileSize, format);
    return estimatedMemory > _memoryPressureThreshold;
  }

  /// Get recommended chunk size for MP4 files based on memory constraints
  static int getRecommendedMP4ChunkSize(int fileSize) {
    // For MP4 files, recommend chunk sizes that align with AAC frame boundaries
    // AAC frames are typically 1024 samples, which at 44.1kHz stereo is ~46ms
    // Target chunks that contain multiple complete AAC frames

    if (fileSize < 2 * 1024 * 1024) {
      // < 2MB
      return (fileSize * 0.4).clamp(8192, 512 * 1024).round();
    } else if (fileSize < 100 * 1024 * 1024) {
      // < 100MB
      return 4 * 1024 * 1024; // 4MB
    } else {
      // >= 100MB
      return 8 * 1024 * 1024; // 8MB
    }
  }
}
