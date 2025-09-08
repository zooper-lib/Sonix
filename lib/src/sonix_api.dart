import 'dart:async';

import 'decoders/audio_decoder_factory.dart';
import 'models/waveform_data.dart';
import 'processing/waveform_generator.dart';
import 'exceptions/sonix_exceptions.dart';

/// Main API class for the Sonix package
///
/// Provides static methods for generating waveforms from audio files
/// and utility methods for format validation.
class Sonix {
  // Private constructor to prevent instantiation
  Sonix._();

  /// Generate waveform data from an audio file
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced configuration options (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Throws [UnsupportedFormatException] if the audio format is not supported
  /// Throws [DecodingException] if audio decoding fails
  /// Throws [FileSystemException] if the file cannot be accessed
  ///
  /// Example:
  /// ```dart
  /// final waveformData = await Sonix.generateWaveform('audio.mp3');
  /// ```
  static Future<WaveformData> generateWaveform(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
  }) async {
    try {
      // Validate file format
      if (!isFormatSupported(filePath)) {
        final extension = _getFileExtension(filePath);
        throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
      }

      // Create decoder for the file
      final decoder = AudioDecoderFactory.createDecoder(filePath);

      try {
        // Decode the audio file
        final audioData = await decoder.decode(filePath);

        // Use provided config or create default config
        final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

        // Generate waveform data
        final waveformData = await WaveformGenerator.generate(audioData, config: waveformConfig);

        return waveformData;
      } finally {
        // Always dispose of the decoder
        decoder.dispose();
      }
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }

      // Wrap other exceptions in DecodingException
      throw DecodingException('Failed to generate waveform from file: $filePath', e.toString());
    }
  }

  /// Generate waveform data from an audio file using streaming processing
  ///
  /// This method is more memory-efficient for large files as it processes
  /// the audio in chunks rather than loading the entire file into memory.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [chunkSize] - Size of each output chunk in data points (default: 100)
  /// [config] - Advanced configuration options (optional)
  ///
  /// Returns a [Stream<WaveformChunk>] that emits waveform data chunks
  ///
  /// Throws [UnsupportedFormatException] if the audio format is not supported
  /// Throws [DecodingException] if audio decoding fails
  /// Throws [FileSystemException] if the file cannot be accessed
  ///
  /// Example:
  /// ```dart
  /// await for (final chunk in Sonix.generateWaveformStream('large_audio.mp3')) {
  ///   // Process each chunk as it becomes available
  ///   print('Received chunk with ${chunk.amplitudes.length} data points');
  /// }
  /// ```
  static Stream<WaveformChunk> generateWaveformStream(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    int chunkSize = 100,
    WaveformConfig? config,
  }) async* {
    try {
      // Validate file format
      if (!isFormatSupported(filePath)) {
        final extension = _getFileExtension(filePath);
        throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
      }

      // Create decoder for the file
      final decoder = AudioDecoderFactory.createDecoder(filePath);

      try {
        // Get audio stream
        final audioStream = decoder.decodeStream(filePath);

        // Use provided config or create default config
        final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

        // Generate waveform stream
        yield* WaveformGenerator.generateStream(audioStream, config: waveformConfig, chunkSize: chunkSize);
      } finally {
        // Always dispose of the decoder
        decoder.dispose();
      }
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }

      // Wrap other exceptions in DecodingException
      throw DecodingException('Failed to generate waveform stream from file: $filePath', e.toString());
    }
  }

  /// Get a list of supported audio format names
  ///
  /// Returns a list of human-readable format names (e.g., ['MP3', 'WAV', 'FLAC'])
  ///
  /// Example:
  /// ```dart
  /// final formats = Sonix.getSupportedFormats();
  /// print('Supported formats: ${formats.join(', ')}');
  /// ```
  static List<String> getSupportedFormats() {
    return AudioDecoderFactory.getSupportedFormatNames();
  }

  /// Get a list of supported file extensions
  ///
  /// Returns a list of file extensions (e.g., ['mp3', 'wav', 'flac'])
  ///
  /// Example:
  /// ```dart
  /// final extensions = Sonix.getSupportedExtensions();
  /// print('Supported extensions: ${extensions.join(', ')}');
  /// ```
  static List<String> getSupportedExtensions() {
    return AudioDecoderFactory.getSupportedExtensions();
  }

  /// Check if a specific audio format is supported
  ///
  /// [filePath] - Path to the audio file or just the filename with extension
  ///
  /// Returns true if the format is supported, false otherwise
  ///
  /// Example:
  /// ```dart
  /// if (Sonix.isFormatSupported('audio.mp3')) {
  ///   // Process the file
  /// } else {
  ///   // Show error message
  /// }
  /// ```
  static bool isFormatSupported(String filePath) {
    return AudioDecoderFactory.isFormatSupported(filePath);
  }

  /// Check if a specific file extension is supported
  ///
  /// [extension] - File extension (with or without the dot)
  ///
  /// Returns true if the extension is supported, false otherwise
  ///
  /// Example:
  /// ```dart
  /// if (Sonix.isExtensionSupported('mp3')) {
  ///   // Extension is supported
  /// }
  /// ```
  static bool isExtensionSupported(String extension) {
    final cleanExtension = extension.startsWith('.') ? extension.substring(1) : extension;

    return getSupportedExtensions().map((ext) => ext.toLowerCase()).contains(cleanExtension.toLowerCase());
  }

  /// Generate waveform with memory-efficient processing for large files
  ///
  /// This method automatically manages memory usage and is recommended
  /// for files larger than 50MB or when memory is constrained.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [maxMemoryUsage] - Maximum memory usage in bytes (default: 50MB)
  /// [config] - Advanced configuration options (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Example:
  /// ```dart
  /// final waveformData = await Sonix.generateWaveformMemoryEfficient(
  ///   'large_audio.wav',
  ///   maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
  /// );
  /// ```
  static Future<WaveformData> generateWaveformMemoryEfficient(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    int maxMemoryUsage = 50 * 1024 * 1024, // 50MB default
    WaveformConfig? config,
  }) async {
    try {
      // Validate file format
      if (!isFormatSupported(filePath)) {
        final extension = _getFileExtension(filePath);
        throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
      }

      // Create decoder for the file
      final decoder = AudioDecoderFactory.createDecoder(filePath);

      try {
        // Decode the audio file
        final audioData = await decoder.decode(filePath);

        // Use provided config or create default config
        final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

        // Generate waveform data with memory efficiency
        final waveformData = await WaveformGenerator.generateMemoryEfficient(audioData, config: waveformConfig, maxMemoryUsage: maxMemoryUsage);

        return waveformData;
      } finally {
        // Always dispose of the decoder
        decoder.dispose();
      }
    } catch (e) {
      if (e is SonixException) {
        rethrow;
      }

      // Wrap other exceptions in DecodingException
      throw DecodingException('Failed to generate memory-efficient waveform from file: $filePath', e.toString());
    }
  }

  /// Get optimal configuration for different use cases
  ///
  /// [useCase] - The intended use case for the waveform
  /// [customResolution] - Override the default resolution for the use case
  ///
  /// Returns a [WaveformConfig] optimized for the specified use case
  ///
  /// Example:
  /// ```dart
  /// final config = Sonix.getOptimalConfig(
  ///   useCase: WaveformUseCase.musicVisualization,
  ///   customResolution: 2000,
  /// );
  /// final waveformData = await Sonix.generateWaveform(
  ///   'music.mp3',
  ///   config: config,
  /// );
  /// ```
  static WaveformConfig getOptimalConfig({required WaveformUseCase useCase, int? customResolution}) {
    return WaveformGenerator.getOptimalConfig(useCase: useCase, customResolution: customResolution);
  }

  /// Extract file extension from a file path
  static String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1);
  }
}
