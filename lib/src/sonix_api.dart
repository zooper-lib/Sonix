import 'dart:async';

import 'decoders/audio_decoder_factory.dart';
import 'models/waveform_data.dart';
import 'processing/waveform_generator.dart';
import 'exceptions/sonix_exceptions.dart';
import 'exceptions/error_recovery.dart';
import 'utils/memory_efficient_sonix_api.dart';
import 'utils/resource_manager.dart';

/// Main API class for the Sonix package
///
/// Provides static methods for generating waveforms from audio files
/// and utility methods for format validation.
class Sonix {
  // Private constructor to prevent instantiation
  Sonix._();

  static bool _isInitialized = false;

  /// Initialize Sonix with memory management
  ///
  /// [memoryLimit] - Maximum memory usage in bytes (default: 100MB)
  /// [maxWaveformCacheSize] - Maximum number of waveforms to cache (default: 50)
  /// [maxAudioDataCacheSize] - Maximum number of audio data to cache (default: 20)
  ///
  /// This should be called once at the start of your application.
  ///
  /// Example:
  /// ```dart
  /// Sonix.initialize(memoryLimit: 50 * 1024 * 1024); // 50MB limit
  /// ```
  static void initialize({int? memoryLimit, int maxWaveformCacheSize = 50, int maxAudioDataCacheSize = 20}) {
    if (_isInitialized) return;

    MemoryEfficientSonixApi.initialize(memoryLimit: memoryLimit, maxWaveformCacheSize: maxWaveformCacheSize, maxAudioDataCacheSize: maxAudioDataCacheSize);

    _isInitialized = true;
  }

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
    final operation = RecoverableOperation<WaveformData>(
      () async {
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
      },
      'generateWaveform',
      {
        'filePath': filePath,
        'operation': (String path) async => generateWaveform(path, resolution: resolution, type: type, normalize: normalize, config: config),
      },
    );

    return await operation.execute();
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
    final streamOperation = RecoverableStreamOperation<WaveformChunk>(() async* {
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
    }, 'generateWaveformStream');

    yield* streamOperation.execute();
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
    _ensureInitialized();

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

  /// Generate waveform with automatic caching and memory management
  ///
  /// This method uses intelligent caching and memory management to optimize
  /// performance and memory usage. It automatically adjusts quality based
  /// on memory pressure.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced configuration options (optional)
  /// [useCache] - Whether to use caching (default: true)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Example:
  /// ```dart
  /// final waveformData = await Sonix.generateWaveformCached('audio.mp3');
  /// ```
  static Future<WaveformData> generateWaveformCached(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
    bool useCache = true,
  }) async {
    _ensureInitialized();

    return MemoryEfficientSonixApi.generateWaveformCached(
      filePath,
      resolution: resolution,
      type: type,
      normalize: normalize,
      config: config,
      useCache: useCache,
    );
  }

  /// Generate waveform with adaptive quality based on file size
  ///
  /// This method automatically chooses the best approach based on file size:
  /// - Small files: Regular generation with caching
  /// - Large files: Memory-efficient generation
  /// - Huge files: Lazy loading
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced configuration options (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Example:
  /// ```dart
  /// final waveformData = await Sonix.generateWaveformAdaptive('any_size_audio.wav');
  /// ```
  static Future<WaveformData> generateWaveformAdaptive(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
  }) async {
    _ensureInitialized();

    return MemoryEfficientSonixApi.generateWaveformAdaptive(filePath, resolution: resolution, type: type, normalize: normalize, config: config);
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

  /// Get memory and resource usage statistics
  ///
  /// Returns detailed information about current memory usage, cache statistics,
  /// and active resources.
  ///
  /// Example:
  /// ```dart
  /// final stats = Sonix.getResourceStatistics();
  /// print('Memory usage: ${stats.memoryUsagePercentage * 100}%');
  /// ```
  static ResourceStatistics getResourceStatistics() {
    _ensureInitialized();
    return MemoryEfficientSonixApi.getResourceStatistics();
  }

  /// Force cleanup of all cached resources and memory
  ///
  /// This method clears all caches and disposes of managed resources
  /// to free up memory. Use this when you need to free up memory
  /// or when shutting down your application.
  ///
  /// Example:
  /// ```dart
  /// await Sonix.forceCleanup();
  /// ```
  static Future<void> forceCleanup() async {
    if (!_isInitialized) return;
    await MemoryEfficientSonixApi.forceCleanup();
  }

  /// Clear specific file from all caches
  ///
  /// [filePath] - Path to the file to remove from caches
  ///
  /// This is useful when you know a file has been modified or deleted
  /// and want to ensure fresh data on next access.
  ///
  /// Example:
  /// ```dart
  /// Sonix.clearFileFromCaches('modified_audio.mp3');
  /// ```
  static void clearFileFromCaches(String filePath) {
    if (!_isInitialized) return;
    MemoryEfficientSonixApi.clearFileFromCaches(filePath);
  }

  /// Preload audio data into cache for faster waveform generation
  ///
  /// [filePath] - Path to the audio file to preload
  ///
  /// This method loads and caches the audio data without generating
  /// a waveform, which can speed up subsequent waveform generation.
  ///
  /// Example:
  /// ```dart
  /// await Sonix.preloadAudioData('upcoming_audio.mp3');
  /// // Later...
  /// final waveform = await Sonix.generateWaveformCached('upcoming_audio.mp3');
  /// ```
  static Future<void> preloadAudioData(String filePath) async {
    _ensureInitialized();
    await MemoryEfficientSonixApi.preloadAudioData(filePath);
  }

  /// Dispose of all Sonix resources
  ///
  /// This should be called when shutting down your application
  /// to ensure all resources are properly disposed of.
  ///
  /// Example:
  /// ```dart
  /// await Sonix.dispose();
  /// ```
  static Future<void> dispose() async {
    if (!_isInitialized) return;

    await MemoryEfficientSonixApi.dispose();
    _isInitialized = false;
  }

  /// Extract file extension from a file path
  static String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1);
  }

  /// Ensure Sonix is initialized
  static void _ensureInitialized() {
    if (!_isInitialized) {
      // Auto-initialize with default settings
      initialize();
    }
  }
}
