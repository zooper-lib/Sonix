import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'sonix_bindings.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/utils/sonix_logger.dart';

/// High-level wrapper for native audio bindings
class NativeAudioBindings {
  static bool _initialized = false;
  static bool _ffmpegInitialized = false;
  static int _memoryPressureThreshold = 100 * 1024 * 1024; // 100MB threshold

  /// Initialize the native bindings
  static void initialize() {
    if (_initialized) return;

    try {
      // Try to load the library to verify it's available
      SonixNativeBindings.lib;
      _initialized = true;

      // Try to initialize FFMPEG backend - REQUIRED for operation
      _initializeFFMPEG();
    } catch (e) {
      SonixLogger.native('initialization', 'Failed to initialize native audio bindings: ${e.toString()}', level: SonixLogLevel.error);
      throw FFIException(
        'Failed to initialize native audio bindings',
        'Make sure the native library is built and FFMPEG binaries are installed. '
            'Run: dart run tools/download_ffmpeg_binaries.dart\n'
            'Error: $e',
      );
    }
  }

  /// Initialize FFMPEG backend - REQUIRED for operation
  static void _initializeFFMPEG() {
    if (_ffmpegInitialized) return;

    try {
      final result = SonixNativeBindings.initFFMPEG();
      if (result == SONIX_OK) {
        _ffmpegInitialized = true;
      } else {
        // FFMPEG initialization failed - this is now a critical error
        final errorMsg = _getLastErrorMessage();
        throw FFIException(
          'FFMPEG initialization failed',
          'FFMPEG libraries are required but could not be initialized. '
              'Please ensure FFMPEG binaries are properly installed.\n'
              'Run: dart run tools/download_ffmpeg_binaries.dart\n'
              'Error: $errorMsg',
        );
      }
    } catch (e) {
      if (e is FFIException) {
        rethrow;
      }
      // FFMPEG libraries not found or other critical error
      SonixLogger.native('ffmpeg_init', 'FFMPEG libraries not available: ${e.toString()}', level: SonixLogLevel.error);
      throw FFIException(
        'FFMPEG libraries not available',
        'FFMPEG libraries are required but not found. '
            'Please install FFMPEG binaries.\n'
            'Run: dart run tools/download_ffmpeg_binaries.dart\n'
            'Error: $e',
      );
    }
  }

  /// Check if FFMPEG backend is available and initialized
  static bool get isFFMPEGAvailable {
    _ensureInitialized();
    return _ffmpegInitialized && SonixNativeBindings.isFFMPEGAvailable;
  }

  /// Get current backend type - always FFMPEG now
  static String get backendType {
    _ensureInitialized();
    if (!isFFMPEGAvailable) {
      throw FFIException(
        'FFMPEG backend not available',
        'FFMPEG is required but not properly initialized. '
            'Run: dart run tools/download_ffmpeg_binaries.dart',
      );
    }
    return 'FFMPEG';
  }

  /// Cleanup FFMPEG resources (call on app shutdown)
  static void cleanup() {
    if (_ffmpegInitialized) {
      try {
        SonixNativeBindings.cleanupFFMPEG();
      } catch (e) {
        SonixLogger.native('cleanup', 'FFMPEG cleanup error (safe to ignore): ${e.toString()}', level: SonixLogLevel.debug);
      }
      _ffmpegInitialized = false;
    }
  }

  /// Set FFMPEG log level to control verbosity
  /// 
  /// Levels:
  /// * -1 = QUIET (no output)
  /// * 0 = PANIC (only critical errors) 
  /// * 1 = FATAL
  /// * 2 = ERROR (recommended default, suppresses MP3 format warnings)
  /// * 3 = WARNING (shows all warnings including MP3 format detection)
  /// * 4 = INFO
  /// * 5 = VERBOSE
  /// * 6 = DEBUG
  static void setLogLevel(int level) {
    _ensureInitialized();
    try {
      SonixNativeBindings.setFFMPEGLogLevel(level);
    } catch (e) {
      SonixLogger.native('setLogLevel', 'Failed to set FFMPEG log level: ${e.toString()}', level: SonixLogLevel.warning);
    }
  }

  /// Set memory pressure threshold for streaming operations
  static void setMemoryPressureThreshold(int bytes) {
    _memoryPressureThreshold = bytes;
  }

  /// Get current memory pressure threshold
  static int get memoryPressureThreshold => _memoryPressureThreshold;

  /// Detect audio format from file data
  /// Uses FFMPEG probing - FFMPEG is required
  static AudioFormat detectFormat(Uint8List data) {
    _ensureInitialized();

    if (data.isEmpty) {
      throw DecodingException('Cannot detect format: empty data');
    }

    // Ensure FFMPEG is available before proceeding
    if (!isFFMPEGAvailable) {
      throw DecodingException(
        'FFMPEG not available for format detection',
        'FFMPEG libraries are required for audio format detection. '
            'Run: dart run tools/download_ffmpeg_binaries.dart',
      );
    }

    final pointer = _allocateUint8Array(data);

    try {
      final formatCode = SonixNativeBindings.detectFormat(pointer, data.length);
      final detectedFormat = formatCodeToEnum(formatCode);

      // If format detection failed, provide detailed error information
      if (detectedFormat == AudioFormat.unknown) {
        final errorMsg = _getLastErrorMessage();
        throw DecodingException(
          'FFMPEG format detection failed',
          'Could not detect audio format using FFMPEG. '
              'The file may be corrupted or use an unsupported format.\n'
              'Error: $errorMsg',
        );
      }

      return detectedFormat;
    } finally {
      malloc.free(pointer);
    }
  }

  /// Decode audio data from memory
  /// Uses FFMPEG backend - FFMPEG is required
  static AudioData decodeAudio(Uint8List data, AudioFormat format) {
    _ensureInitialized();

    if (data.isEmpty) {
      throw DecodingException('Cannot decode: empty data');
    }

    // Ensure FFMPEG is available before proceeding
    if (!isFFMPEGAvailable) {
      throw DecodingException(
        'FFMPEG not available for audio decoding',
        'FFMPEG libraries are required for audio decoding. '
            'Run: dart run tools/download_ffmpeg_binaries.dart',
      );
    }

    // Check for memory pressure before large allocations
    if (data.length > _memoryPressureThreshold) {
      throw MemoryException(
        'File size exceeds memory pressure threshold',
        'File size: ${data.length} bytes, threshold: $_memoryPressureThreshold bytes. '
            'Consider using chunked processing for large files.',
      );
    }

    final dataPointer = _allocateUint8Array(data);

    try {
      final formatCode = formatEnumToCode(format);
      final resultPointer = SonixNativeBindings.decodeAudio(dataPointer, data.length, formatCode);

      if (resultPointer == ffi.nullptr) {
        final errorMsg = _getLastErrorMessage();

        // Provide detailed FFMPEG-specific error messages
        if (errorMsg.contains('not found') || errorMsg.contains('download')) {
          throw DecodingException(
            'FFMPEG libraries not found',
            'FFMPEG libraries are required but not properly installed. '
                'Run: dart run tools/download_ffmpeg_binaries.dart\n'
                'Error: $errorMsg',
          );
        } else if (errorMsg.contains('probe')) {
          throw DecodingException(
            'FFMPEG format probing failed',
            'The file format could not be detected by FFMPEG. '
                'The file may be corrupted or use an unsupported format variant.\n'
                'Error: $errorMsg',
          );
        } else if (errorMsg.contains('codec')) {
          throw DecodingException(
            'FFMPEG codec not found',
            'The required codec for this audio format is not available in the FFMPEG build.\n'
                'Error: $errorMsg',
          );
        } else if (errorMsg.contains('decode')) {
          throw DecodingException(
            'FFMPEG decoding failed',
            'FFMPEG could not decode the audio data. The file may be corrupted.\n'
                'Error: $errorMsg',
          );
        } else {
          throw DecodingException(
            'FFMPEG audio decoding failed',
            'FFMPEG failed to decode the audio data.\n'
                'Error: $errorMsg',
          );
        }
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
      SonixLogger.native('decode', 'Native decoding failed: ${e.toString()}', level: SonixLogLevel.error);
      throw DecodingException(
        'Native decoding failed',
        'Error during FFI operation. Ensure FFMPEG libraries are properly installed.\n'
            'Run: dart run tools/download_ffmpeg_binaries.dart\n'
            'Error: $e',
      );
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
      SonixLogger.native('error_message', 'Failed to retrieve native error message: ${e.toString()}', level: SonixLogLevel.debug);
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

  /// Get formatted error message for FFMPEG-specific error codes
  static String getFFMPEGErrorMessage(int errorCode) {
    switch (errorCode) {
      case SONIX_ERROR_FFMPEG_INIT_FAILED:
        return 'Failed to initialize FFMPEG libraries. Please check FFMPEG installation.';
      case SONIX_ERROR_FFMPEG_PROBE_FAILED:
        return 'FFMPEG failed to probe the audio format. The file may be corrupted or unsupported.';
      case SONIX_ERROR_FFMPEG_CODEC_NOT_FOUND:
        return 'FFMPEG codec not found for this audio format. The codec may not be available in this build.';
      case SONIX_ERROR_FFMPEG_DECODE_FAILED:
        return 'FFMPEG failed to decode the audio data. The file may be corrupted or use an unsupported variant.';
      case SONIX_ERROR_FFMPEG_CONTEXT_FAILED:
        return 'FFMPEG failed to create decoding context. This may indicate insufficient memory or invalid parameters.';
      case SONIX_ERROR_FFMPEG_STREAM_NOT_FOUND:
        return 'FFMPEG could not find an audio stream in the file. The file may not contain audio data.';
      case SONIX_ERROR_FFMPEG_PACKET_READ_FAILED:
        return 'FFMPEG failed to read audio packets from the file. The file may be corrupted or truncated.';
      case SONIX_ERROR_FFMPEG_FRAME_DECODE_FAILED:
        return 'FFMPEG failed to decode audio frames. The file may contain corrupted audio data.';
      case SONIX_ERROR_FFMPEG_RESAMPLE_FAILED:
        return 'FFMPEG failed to resample audio data. This may indicate incompatible audio parameters.';
      case SONIX_ERROR_FFMPEG_NOT_AVAILABLE:
        return 'FFMPEG libraries are not available. Please run the setup script to build FFMPEG libraries.';
      default:
        return _getLastErrorMessage();
    }
  }

  /// Check if an error code is FFMPEG-related
  static bool isFFMPEGError(int errorCode) {
    return errorCode >= SONIX_ERROR_FFMPEG_RESAMPLE_FAILED && errorCode <= SONIX_ERROR_FFMPEG_INIT_FAILED;
  }

  /// Get backend-specific error message
  static String getBackendErrorMessage(int errorCode) {
    if (isFFMPEGError(errorCode)) {
      return getFFMPEGErrorMessage(errorCode);
    } else if (errorCode >= SONIX_ERROR_MP4_UNSUPPORTED_CODEC && errorCode <= SONIX_ERROR_MP4_CONTAINER_INVALID) {
      return getMP4ErrorMessage(errorCode);
    } else {
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
      case AudioFormat.opus:
        return SONIX_FORMAT_OPUS;
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
      case SONIX_FORMAT_OPUS:
        return AudioFormat.opus;
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
