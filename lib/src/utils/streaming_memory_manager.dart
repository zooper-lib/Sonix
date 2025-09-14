import 'dart:io';

import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/native/native_audio_bindings.dart';
import 'package:sonix/src/decoders/audio_decoder.dart';

/// Manages memory pressure during streaming audio operations
class StreamingMemoryManager {
  static const int _defaultChunkSize = 64 * 1024; // 64KB
  static const int _maxChunkSize = 1024 * 1024; // 1MB
  static const int _minChunkSize = 16 * 1024; // 16KB

  /// Calculate optimal chunk size based on file size and available memory
  static int calculateOptimalChunkSize(int fileSize, AudioFormat format) {
    // Check if the entire file would exceed memory limits
    if (NativeAudioBindings.wouldExceedMemoryLimits(fileSize, format)) {
      // Use smaller chunks for large files
      final estimatedMemory = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, format);
      final threshold = NativeAudioBindings.memoryPressureThreshold;

      // Calculate chunk size to stay within memory limits
      final ratio = threshold / estimatedMemory;
      final adjustedChunkSize = (_defaultChunkSize * ratio).round();

      return adjustedChunkSize.clamp(_minChunkSize, _maxChunkSize);
    }

    return _defaultChunkSize;
  }

  /// Check if we should use streaming for a given file
  static bool shouldUseStreaming(int fileSize, AudioFormat format) {
    return NativeAudioBindings.wouldExceedMemoryLimits(fileSize, format);
  }

  /// Get file size safely
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileAccessException(filePath, 'File does not exist');
      }
      return await file.length();
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }
      throw FileAccessException(filePath, 'Failed to get file size', e.toString());
    }
  }

  /// Monitor memory usage during streaming operations
  static void checkMemoryPressure() {
    // This is a placeholder for actual memory monitoring
    // In a real implementation, you might check system memory usage
    // For now, we rely on the threshold-based approach
  }

  /// Suggest quality reduction if memory pressure is high
  static Map<String, dynamic> suggestQualityReduction(int fileSize, AudioFormat format) {
    if (!shouldUseStreaming(fileSize, format)) {
      return {'shouldReduce': false};
    }

    final estimatedMemory = NativeAudioBindings.estimateDecodedMemoryUsage(fileSize, format);
    final threshold = NativeAudioBindings.memoryPressureThreshold;
    final ratio = estimatedMemory / threshold;

    if (ratio > 2.0) {
      return {
        'shouldReduce': true,
        'suggestedSampleRate': 22050, // Reduce from typical 44100
        'suggestedChannels': 1, // Convert to mono
        'reason': 'High memory pressure detected (${ratio.toStringAsFixed(1)}x threshold)',
      };
    } else if (ratio > 1.5) {
      return {
        'shouldReduce': true,
        'suggestedSampleRate': 32000, // Moderate reduction
        'suggestedChannels': null, // Keep original channels
        'reason': 'Moderate memory pressure detected (${ratio.toStringAsFixed(1)}x threshold)',
      };
    }

    return {'shouldReduce': false};
  }
}
