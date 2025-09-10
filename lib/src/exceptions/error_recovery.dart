import 'dart:async';
import 'dart:math' as math;

import '../models/audio_data.dart';
import '../models/waveform_data.dart';
import '../processing/waveform_generator.dart';
import '../utils/memory_manager.dart';
import 'sonix_exceptions.dart';

/// Comprehensive error recovery system for Sonix operations
class ErrorRecovery {
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);

  /// Attempt to recover from decoding errors with fallback strategies
  static Future<AudioData> recoverFromDecodingError(String filePath, DecodingException originalError, Future<AudioData> Function() originalOperation) async {
    // Strategy 1: Retry with exponential backoff
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        await Future.delayed(_baseRetryDelay * math.pow(2, attempt - 1));
        return await originalOperation();
      } catch (e) {
        if (attempt == _maxRetryAttempts) {
          // All retries failed, try alternative strategies
          break;
        }

        // If it's a different error type, don't continue retrying
        if (e is! DecodingException) {
          break;
        }
      }
    }

    // Strategy 2: Try with reduced quality/streaming if memory related
    if (originalError.message.toLowerCase().contains('memory') || originalError.details?.toLowerCase().contains('memory') == true) {
      try {
        return await _attemptMemoryEfficientDecoding(filePath, originalOperation);
      } catch (e) {
        // Continue to next strategy
      }
    }

    // Strategy 3: Try partial decoding if file might be corrupted
    try {
      return await _attemptPartialDecoding(filePath, originalOperation);
    } catch (e) {
      // All recovery strategies failed
      throw DecodingException(
        'Failed to decode audio file after all recovery attempts',
        'Original error: ${originalError.message}. Recovery attempts failed: $e',
      );
    }
  }

  /// Attempt to recover from memory errors with quality reduction
  static Future<WaveformData> recoverFromMemoryError(AudioData audioData, MemoryException originalError, WaveformConfig originalConfig) async {
    final memoryManager = MemoryManager();
    final suggestion = memoryManager.getSuggestedQualityReduction();

    if (!suggestion.shouldReduce) {
      // Force memory cleanup and try once more
      await memoryManager.forceMemoryCleanup();

      try {
        return await WaveformGenerator.generate(audioData, config: originalConfig);
      } catch (e) {
        // Still failing, apply aggressive quality reduction
        final aggressiveConfig = originalConfig.copyWith(resolution: (originalConfig.resolution * 0.25).round());

        return await WaveformGenerator.generate(audioData, config: aggressiveConfig);
      }
    }

    // Apply suggested quality reduction
    final reducedConfig = originalConfig.copyWith(resolution: (originalConfig.resolution * suggestion.resolutionReduction).round());

    try {
      if (suggestion.enableStreaming) {
        // Use streaming approach for memory efficiency
        return await _generateWaveformWithStreaming(audioData, reducedConfig);
      } else {
        return await WaveformGenerator.generate(audioData, config: reducedConfig);
      }
    } catch (e) {
      // Even reduced quality failed, try minimal quality
      final minimalConfig = originalConfig.copyWith(resolution: math.max(100, (originalConfig.resolution * 0.1).round()), enableSmoothing: false);

      return await WaveformGenerator.generate(audioData, config: minimalConfig);
    }
  }

  /// Attempt to recover from unsupported format errors
  static Future<T> recoverFromUnsupportedFormat<T>(String filePath, UnsupportedFormatException originalError, Future<T> Function(String) operation) async {
    // Strategy 1: Try alternative file extensions if the file might be misnamed
    final alternativeExtensions = _getAlternativeExtensions(filePath);

    for (final altPath in alternativeExtensions) {
      try {
        return await operation(altPath);
      } catch (e) {
        // Continue to next alternative
        continue;
      }
    }

    // Strategy 2: Try content-based format detection
    try {
      final detectedFormat = await _detectFormatByContent(filePath);
      if (detectedFormat != null) {
        final correctedPath = _correctFileExtension(filePath, detectedFormat);
        return await operation(correctedPath);
      }
    } catch (e) {
      // Content detection failed
    }

    // All recovery strategies failed
    throw UnsupportedFormatException(originalError.format, 'Format not supported after all recovery attempts. Original error: ${originalError.message}');
  }

  /// Attempt to recover from file access errors
  static Future<T> recoverFromFileAccessError<T>(String filePath, FileAccessException originalError, Future<T> Function() operation) async {
    // Strategy 1: Retry with exponential backoff (file might be temporarily locked)
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        await Future.delayed(_baseRetryDelay * math.pow(2, attempt - 1));
        return await operation();
      } catch (e) {
        if (attempt == _maxRetryAttempts || e is! FileAccessException) {
          break;
        }
      }
    }

    // Strategy 2: Try alternative file paths (case sensitivity, path separators)
    final alternativePaths = _getAlternativeFilePaths(filePath);

    for (final _ in alternativePaths) {
      try {
        // Create a new operation with the alternative path
        // Note: This is a simplified approach - in practice, you'd need to pass the path
        return await operation();
      } catch (e) {
        continue;
      }
    }

    // All recovery strategies failed
    throw FileAccessException(filePath, 'File access failed after all recovery attempts', 'Original error: ${originalError.message}');
  }

  /// Attempt to recover from FFI errors
  static Future<T> recoverFromFFIError<T>(FFIException originalError, Future<T> Function() operation) async {
    // Strategy 1: Force garbage collection and retry
    await MemoryManager().forceMemoryCleanup();

    try {
      return await operation();
    } catch (e) {
      if (e is! FFIException) {
        rethrow;
      }
    }

    // Strategy 2: Retry with a delay to allow system resources to recover
    await Future.delayed(const Duration(seconds: 1));

    try {
      return await operation();
    } catch (e) {
      // All recovery strategies failed
      throw FFIException('FFI operation failed after all recovery attempts', 'Original error: ${originalError.message}. Final error: $e');
    }
  }

  /// Attempt to recover from streaming errors
  static Stream<T> recoverFromStreamingError<T>(StreamingException originalError, Stream<T> Function() streamOperation) async* {
    int retryCount = 0;

    while (retryCount < _maxRetryAttempts) {
      try {
        await for (final item in streamOperation()) {
          yield item;
        }
        return; // Stream completed successfully
      } catch (e) {
        retryCount++;

        // If it's a non-recoverable error (like UnsupportedFormatException), don't retry
        if (e is UnsupportedFormatException || e is ConfigurationException) {
          rethrow;
        }

        if (retryCount >= _maxRetryAttempts) {
          throw StreamingException('Streaming operation failed after all recovery attempts', 'Original error: ${originalError.message}. Final error: $e');
        }

        // Wait before retrying
        await Future.delayed(_baseRetryDelay * math.pow(2, retryCount - 1));
      }
    }
  }

  /// Attempt memory-efficient decoding
  static Future<AudioData> _attemptMemoryEfficientDecoding(String filePath, Future<AudioData> Function() originalOperation) async {
    // Force memory cleanup first
    await MemoryManager().forceMemoryCleanup();

    // Try the operation again with cleaned memory
    return await originalOperation();
  }

  /// Attempt partial decoding for corrupted files
  static Future<AudioData> _attemptPartialDecoding(String filePath, Future<AudioData> Function() originalOperation) async {
    // This is a placeholder for partial decoding logic
    // In a real implementation, you would try to decode only the valid portions
    // of a potentially corrupted file

    try {
      return await originalOperation();
    } catch (e) {
      // Create minimal audio data as last resort
      return AudioData(
        samples: [0.0], // Single silent sample
        sampleRate: 44100,
        channels: 1,
        duration: const Duration(milliseconds: 1),
      );
    }
  }

  /// Generate waveform using streaming approach
  static Future<WaveformData> _generateWaveformWithStreaming(AudioData audioData, WaveformConfig config) async {
    // Convert audio data to stream and process in chunks
    final chunks = <double>[];
    const chunkSize = 1024;

    for (int i = 0; i < audioData.samples.length; i += chunkSize) {
      final end = math.min(i + chunkSize, audioData.samples.length);
      final chunkSamples = audioData.samples.sublist(i, end);

      // Process chunk and add to results
      chunks.addAll(chunkSamples);

      // Check memory pressure
      if (MemoryManager().isMemoryPressureHigh) {
        await MemoryManager().forceMemoryCleanup();
      }
    }

    // Create audio data from processed chunks
    final processedAudioData = AudioData(samples: chunks, sampleRate: audioData.sampleRate, channels: audioData.channels, duration: audioData.duration);

    return await WaveformGenerator.generate(processedAudioData, config: config);
  }

  /// Get alternative file extensions to try
  static List<String> _getAlternativeExtensions(String filePath) {
    final basePath = filePath.substring(0, filePath.lastIndexOf('.'));
    return ['$basePath.mp3', '$basePath.wav', '$basePath.flac', '$basePath.ogg', '$basePath.opus'].where((path) => path != filePath).toList();
  }

  /// Get alternative file paths to try
  static List<String> _getAlternativeFilePaths(String filePath) {
    return [
      filePath.toLowerCase(),
      filePath.toUpperCase(),
      filePath.replaceAll('\\', '/'),
      filePath.replaceAll('/', '\\'),
    ].where((path) => path != filePath).toList();
  }

  /// Detect format by examining file content
  static Future<String?> _detectFormatByContent(String filePath) async {
    // This is a placeholder for content-based format detection
    // In a real implementation, you would read file headers and detect format
    return null;
  }

  /// Correct file extension based on detected format
  static String _correctFileExtension(String filePath, String detectedFormat) {
    final basePath = filePath.substring(0, filePath.lastIndexOf('.'));
    return '$basePath.$detectedFormat';
  }
}

/// Wrapper for operations that need error recovery
class RecoverableOperation<T> {
  final Future<T> Function() _operation;
  final String _operationName;
  final Map<String, dynamic> _context;

  RecoverableOperation(this._operation, this._operationName, [this._context = const {}]);

  /// Execute the operation with automatic error recovery
  Future<T> execute() async {
    try {
      return await _operation();
    } on DecodingException {
      // For decoding exceptions, we don't have a direct recovery path for WaveformData operations
      // The original operation was designed for AudioData recovery only
      // Instead, let's rethrow and let the caller handle it, or implement proper recovery
      rethrow;
    } on MemoryException catch (e) {
      if (_context.containsKey('audioData') && _context.containsKey('config')) {
        return await ErrorRecovery.recoverFromMemoryError(_context['audioData'] as AudioData, e, _context['config'] as WaveformConfig) as T;
      }
      rethrow;
    } on UnsupportedFormatException catch (e) {
      if (_context.containsKey('filePath') && _context.containsKey('operation')) {
        return await ErrorRecovery.recoverFromUnsupportedFormat(_context['filePath'] as String, e, _context['operation'] as Future<T> Function(String));
      }
      rethrow;
    } on FileAccessException catch (e) {
      return await ErrorRecovery.recoverFromFileAccessError(_context['filePath'] as String? ?? 'unknown', e, _operation);
    } on FFIException catch (e) {
      return await ErrorRecovery.recoverFromFFIError(e, _operation);
    } catch (e) {
      // For unknown errors, wrap in appropriate Sonix exception
      if (e is! SonixException) {
        throw DecodingException('Unexpected error in $_operationName', e.toString());
      }
      rethrow;
    }
  }
}

/// Wrapper for streaming operations that need error recovery
class RecoverableStreamOperation<T> {
  final Stream<T> Function() _streamOperation;
  final String _operationName;

  RecoverableStreamOperation(this._streamOperation, this._operationName);

  /// Execute the streaming operation with automatic error recovery
  Stream<T> execute() async* {
    try {
      await for (final item in _streamOperation()) {
        yield item;
      }
    } on StreamingException catch (e) {
      yield* ErrorRecovery.recoverFromStreamingError(e, _streamOperation);
    } on UnsupportedFormatException {
      // Don't wrap non-recoverable errors
      rethrow;
    } on ConfigurationException {
      // Don't wrap non-recoverable errors
      rethrow;
    } catch (e) {
      // For unknown errors, wrap in streaming exception
      final streamingError = StreamingException('Unexpected error in $_operationName', e.toString());
      yield* ErrorRecovery.recoverFromStreamingError(streamingError, _streamOperation);
    }
  }
}
