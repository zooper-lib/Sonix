import 'dart:async';
import 'dart:io';

import 'decoders/audio_decoder.dart';
import 'decoders/audio_decoder_factory.dart';
import 'decoders/chunked_audio_decoder.dart';
import 'models/waveform_data.dart';
import 'models/chunked_processing_config.dart';
import 'processing/waveform_generator.dart';
import 'processing/progressive_waveform_generator.dart';
import 'processing/waveform_aggregator.dart';
import 'utils/chunked_file_reader.dart';
import 'exceptions/sonix_exceptions.dart';
import 'exceptions/error_recovery.dart';
import 'utils/memory_efficient_sonix_api.dart';
import 'utils/resource_manager.dart';

/// Main API class for the Sonix package
///
/// Provides static methods for generating waveforms from audio files
/// and utility methods for format validation.
class Sonix {
  static bool _isInitialized = false;

  /// Initialize Sonix with optional memory and cache settings
  ///
  /// [memoryLimit] - Memory limit in bytes (default: 16GB - effectively unlimited)
  /// [maxWaveformCacheSize] - Maximum number of waveforms to cache (default: 50)
  /// [maxAudioDataCacheSize] - Maximum number of audio data to cache (default: 20)
  ///
  /// This should be called once at the start of your application.
  ///
  /// Example:
  /// ```dart
  /// Sonix.initialize(); // Uses 16GB default - handles very large audio files
  /// // Or set a custom limit if needed:
  /// // Sonix.initialize(memoryLimit: 100 * 1024 * 1024); // 100MB limit
  /// ```
  static void initialize({int? memoryLimit, int maxWaveformCacheSize = 50, int maxAudioDataCacheSize = 20}) {
    if (_isInitialized) return;

    MemoryEfficientSonixApi.initialize(memoryLimit: memoryLimit, maxWaveformCacheSize: maxWaveformCacheSize, maxAudioDataCacheSize: maxAudioDataCacheSize);

    _isInitialized = true;
  }

  /// Generate waveform data from an audio file
  ///
  /// This method automatically detects when to use chunked processing based on file size
  /// and available memory. For large files (>50MB), it will automatically use chunked
  /// processing for better memory efficiency.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced configuration options (optional)
  /// [chunkedConfig] - Configuration for chunked processing (optional)
  /// [forceChunkedProcessing] - Force chunked processing regardless of file size (default: false)
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
    ChunkedProcessingConfig? chunkedConfig,
    bool forceChunkedProcessing = false,
  }) async {
    final operation = RecoverableOperation<WaveformData>(
      () async {
        // Validate file format
        if (!isFormatSupported(filePath)) {
          final extension = _getFileExtension(filePath);
          throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
        }

        // Check file size to determine processing method
        final file = File(filePath);
        final fileSize = await file.length();

        // Use chunked processing for large files (>50MB) or when forced
        const chunkThreshold = 50 * 1024 * 1024; // 50MB
        final shouldUseChunkedProcessing = forceChunkedProcessing || fileSize > chunkThreshold;

        if (shouldUseChunkedProcessing) {
          // Use chunked processing
          return await _generateWaveformChunked(
            filePath,
            resolution: resolution,
            type: type,
            normalize: normalize,
            config: config,
            chunkedConfig: chunkedConfig,
          );
        } else {
          // Use traditional processing for smaller files
          return await _generateWaveformTraditional(filePath, resolution: resolution, type: type, normalize: normalize, config: config);
        }
      },
      'generateWaveform',
      {
        'filePath': filePath,
        'operation': (String path) async => generateWaveform(
          path,
          resolution: resolution,
          type: type,
          normalize: normalize,
          config: config,
          chunkedConfig: chunkedConfig,
          forceChunkedProcessing: forceChunkedProcessing,
        ),
      },
    );

    return await operation.execute();
  }

  /// Generate waveform data from an audio file using streaming processing
  ///
  /// This method uses the new chunked infrastructure for memory-efficient processing
  /// of large files. It automatically detects the optimal processing method based on
  /// file size and decoder capabilities.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [chunkSize] - Size of each output chunk in data points (default: 100)
  /// [config] - Advanced configuration options (optional)
  /// [chunkedConfig] - Configuration for chunked processing (optional)
  /// [onProgress] - Callback for progress updates (optional)
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
    ChunkedProcessingConfig? chunkedConfig,
    ProgressCallback? onProgress,
  }) async* {
    final streamOperation = RecoverableStreamOperation<WaveformChunk>(() async* {
      // Validate file format
      if (!isFormatSupported(filePath)) {
        final extension = _getFileExtension(filePath);
        throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
      }

      // Check file size and decoder capabilities
      final file = File(filePath);
      final fileSize = await file.length();
      final decoder = AudioDecoderFactory.createDecoder(filePath);

      try {
        // Use chunked processing if decoder supports it
        if (decoder is ChunkedAudioDecoder) {
          yield* _generateWaveformStreamChunked(
            filePath,
            decoder,
            resolution: resolution,
            type: type,
            normalize: normalize,
            chunkSize: chunkSize,
            config: config,
            chunkedConfig: chunkedConfig ?? ChunkedProcessingConfig.forFileSize(fileSize),
            onProgress: onProgress,
          );
        } else {
          // Fallback to traditional streaming
          yield* _generateWaveformStreamTraditional(
            decoder,
            filePath,
            resolution: resolution,
            type: type,
            normalize: normalize,
            chunkSize: chunkSize,
            config: config,
          );
        }
      } finally {
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

  /// Generate waveform using traditional (non-chunked) processing
  static Future<WaveformData> _generateWaveformTraditional(
    String filePath, {
    required int resolution,
    required WaveformType type,
    required bool normalize,
    WaveformConfig? config,
  }) async {
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
  }

  /// Generate waveform using chunked processing
  static Future<WaveformData> _generateWaveformChunked(
    String filePath, {
    required int resolution,
    required WaveformType type,
    required bool normalize,
    WaveformConfig? config,
    ChunkedProcessingConfig? chunkedConfig,
  }) async {
    // Get file size for optimal configuration
    final file = File(filePath);
    final fileSize = await file.length();

    // Create chunked processing configuration
    final effectiveChunkedConfig = chunkedConfig ?? ChunkedProcessingConfig.forFileSize(fileSize);

    // Create decoder for the file
    final decoder = AudioDecoderFactory.createDecoder(filePath);

    // Check if decoder supports chunked processing
    if (decoder is! ChunkedAudioDecoder) {
      // Fallback to traditional processing if chunked processing is not supported
      try {
        return await _generateWaveformTraditional(filePath, resolution: resolution, type: type, normalize: normalize, config: config);
      } finally {
        decoder.dispose();
      }
    }

    final chunkedDecoder = decoder;

    try {
      // Initialize chunked decoding
      await chunkedDecoder.initializeChunkedDecoding(filePath, chunkSize: effectiveChunkedConfig.fileChunkSize);

      // Create file reader
      final fileReader = await ChunkedFileReaderFactory.createForFile(
        filePath,
        chunkSize: effectiveChunkedConfig.fileChunkSize,
        enableSeeking: effectiveChunkedConfig.enableSeeking,
      );

      try {
        // Create waveform configuration
        final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

        // Create progressive waveform generator
        final progressiveGenerator = ProgressiveWaveformGenerator(config: waveformConfig);

        // Process file chunks and generate waveform
        final processedChunks = _processFileChunks(fileReader, chunkedDecoder, effectiveChunkedConfig);
        final waveformData = await progressiveGenerator.generateCompleteWaveform(processedChunks);

        return waveformData;
      } finally {
        await fileReader.close();
      }
    } finally {
      await chunkedDecoder.cleanupChunkedProcessing();
      decoder.dispose();
    }
  }

  /// Process file chunks using the chunked decoder
  static Stream<ProcessedChunk> _processFileChunks(ChunkedFileReader fileReader, ChunkedAudioDecoder decoder, ChunkedProcessingConfig config) async* {
    await for (final fileChunk in fileReader.readChunks()) {
      try {
        final audioChunks = await decoder.processFileChunk(fileChunk);
        yield ProcessedChunk(fileChunk: fileChunk, audioChunks: audioChunks);
      } catch (error) {
        // Yield error chunk but continue processing
        yield ProcessedChunk(fileChunk: fileChunk, audioChunks: [], error: error);
      }
    }
  }

  /// Generate waveform stream using chunked processing
  static Stream<WaveformChunk> _generateWaveformStreamChunked(
    String filePath,
    ChunkedAudioDecoder decoder, {
    required int resolution,
    required WaveformType type,
    required bool normalize,
    required int chunkSize,
    WaveformConfig? config,
    required ChunkedProcessingConfig chunkedConfig,
    ProgressCallback? onProgress,
  }) async* {
    // Initialize chunked decoding
    await decoder.initializeChunkedDecoding(filePath, chunkSize: chunkedConfig.fileChunkSize);

    // Create file reader
    final fileReader = await ChunkedFileReaderFactory.createForFile(
      filePath,
      chunkSize: chunkedConfig.fileChunkSize,
      enableSeeking: chunkedConfig.enableSeeking,
    );

    try {
      // Create waveform configuration
      final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

      // Create progressive waveform generator
      final progressiveGenerator = ProgressiveWaveformGenerator(config: waveformConfig, onProgress: onProgress);

      // Process file chunks and generate waveform stream
      final processedChunks = _processFileChunks(fileReader, decoder, chunkedConfig);

      // Estimate totals for better resolution/timing control
      int? estimatedTotalSamples;
      Duration? estimatedDuration;
      try {
        final duration = await decoder.estimateDuration();
        final meta = decoder.getFormatMetadata();
        final sr = (meta['sampleRate'] as int?) ?? 44100;
        final ch = (meta['channels'] as int?) ?? 1;
        if (duration != null) {
          estimatedDuration = duration;
          estimatedTotalSamples = ((duration.inMicroseconds * sr * ch) / Duration.microsecondsPerSecond).round();
        }
      } catch (_) {}

      final stream = progressiveGenerator.generateFromChunks(
        processedChunks,
        expectedTotalSamples: estimatedTotalSamples,
        expectedTotalDuration: estimatedDuration,
      );

      await for (final waveformChunk in stream) {
        // Convert enhanced chunk to regular chunk for compatibility
        yield WaveformChunk(amplitudes: waveformChunk.amplitudes, startTime: waveformChunk.startTime, isLast: waveformChunk.isLast);
      }
    } finally {
      await fileReader.close();
      await decoder.cleanupChunkedProcessing();
    }
  }

  /// Generate waveform stream using traditional processing (fallback)
  static Stream<WaveformChunk> _generateWaveformStreamTraditional(
    AudioDecoder decoder,
    String filePath, {
    required int resolution,
    required WaveformType type,
    required bool normalize,
    required int chunkSize,
    WaveformConfig? config,
  }) async* {
    // Get audio stream
    final audioStream = decoder.decodeStream(filePath);

    // Use provided config or create default config
    final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

    // Generate waveform stream
    yield* WaveformGenerator.generateStream(audioStream, config: waveformConfig, chunkSize: chunkSize);
  }

  // ========== NEW CHUNKED-SPECIFIC API METHODS ==========

  /// Generate waveform using explicit chunked processing
  ///
  /// This method forces the use of chunked processing regardless of file size,
  /// providing fine-grained control over the chunked processing configuration.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced waveform configuration options (optional)
  /// [chunkedConfig] - Configuration for chunked processing (optional)
  /// [onProgress] - Callback for progress updates (optional)
  /// [onError] - Callback for error handling (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Throws [UnsupportedFormatException] if the audio format is not supported
  /// Throws [DecodingException] if audio decoding fails
  /// Throws [FileSystemException] if the file cannot be accessed
  /// Throws [SonixUnsupportedOperationException] if chunked processing is not supported for this format
  ///
  /// Example:
  /// ```dart
  /// final waveformData = await Sonix.generateWaveformChunked(
  ///   'large_audio.wav',
  ///   chunkedConfig: ChunkedProcessingConfig.forFileSize(fileSize),
  ///   onProgress: (progress) {
  ///     print('Progress: ${progress.progressPercentage * 100}%');
  ///   },
  /// );
  /// ```
  static Future<WaveformData> generateWaveformChunked(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
    ChunkedProcessingConfig? chunkedConfig,
    ProgressCallback? onProgress,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final operation = RecoverableOperation<WaveformData>(
      () async {
        // Validate file format
        if (!isFormatSupported(filePath)) {
          final extension = _getFileExtension(filePath);
          throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
        }

        // Get file size for optimal configuration
        final file = File(filePath);
        final fileSize = await file.length();

        // Create chunked processing configuration
        final effectiveChunkedConfig = chunkedConfig ?? ChunkedProcessingConfig.forFileSize(fileSize);

        // Create decoder for the file
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        // Check if decoder supports chunked processing
        if (decoder is! ChunkedAudioDecoder) {
          decoder.dispose();
          throw SonixUnsupportedOperationException(
            'Chunked processing is not supported for this audio format. '
            'Supported formats for chunked processing: MP3, FLAC, WAV, OGG',
          );
        }

        final chunkedDecoder = decoder;

        try {
          // Initialize chunked decoding
          await chunkedDecoder.initializeChunkedDecoding(filePath, chunkSize: effectiveChunkedConfig.fileChunkSize);

          // Create file reader
          final fileReader = await ChunkedFileReaderFactory.createForFile(
            filePath,
            chunkSize: effectiveChunkedConfig.fileChunkSize,
            enableSeeking: effectiveChunkedConfig.enableSeeking,
          );

          try {
            // Create waveform configuration
            final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

            // Create progressive waveform generator with callbacks
            final progressiveGenerator = ProgressiveWaveformGenerator(config: waveformConfig, onProgress: onProgress, onError: onError);

            // Process file chunks and generate waveform
            final processedChunks = _processFileChunks(fileReader, chunkedDecoder, effectiveChunkedConfig);

            // Try to estimate total samples and duration for better control
            int? estimatedTotalSamples;
            Duration? estimatedDuration;
            try {
              final duration = await chunkedDecoder.estimateDuration();
              final meta = chunkedDecoder.getFormatMetadata();
              final sr = (meta['sampleRate'] as int?) ?? 44100;
              final ch = (meta['channels'] as int?) ?? 1;
              if (duration != null) {
                estimatedDuration = duration;
                estimatedTotalSamples = ((duration.inMicroseconds * sr * ch) / Duration.microsecondsPerSecond).round();
              }
            } catch (_) {}

            // If we have an estimate, stream chunks with expected totals so aggregator targets resolution
            if (estimatedTotalSamples != null && estimatedTotalSamples > 0) {
              final chunks = <WaveformChunk>[];
              await for (final wc in progressiveGenerator.generateFromChunks(
                processedChunks,
                expectedTotalSamples: estimatedTotalSamples,
                expectedTotalDuration: estimatedDuration,
              )) {
                chunks.add(WaveformChunk(amplitudes: wc.amplitudes, startTime: wc.startTime, isLast: wc.isLast));
              }
              final waveformData = WaveformAggregator.combineChunks(chunks, waveformConfig);
              return waveformData;
            }

            final waveformData = await progressiveGenerator.generateCompleteWaveform(processedChunks);

            return waveformData;
          } finally {
            await fileReader.close();
          }
        } finally {
          await chunkedDecoder.cleanupChunkedProcessing();
          decoder.dispose();
        }
      },
      'generateWaveformChunked',
      {
        'filePath': filePath,
        'operation': (String path) async => generateWaveformChunked(
          path,
          resolution: resolution,
          type: type,
          normalize: normalize,
          config: config,
          chunkedConfig: chunkedConfig,
          onProgress: onProgress,
          onError: onError,
        ),
      },
    );

    return await operation.execute();
  }

  /// Generate waveform with progress reporting
  ///
  /// This method provides detailed progress reporting during waveform generation,
  /// automatically choosing the optimal processing method (chunked or traditional)
  /// based on file size and decoder capabilities.
  ///
  /// [filePath] - Path to the audio file
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced waveform configuration options (optional)
  /// [chunkedConfig] - Configuration for chunked processing (optional)
  /// [onProgress] - Callback for progress updates (required)
  /// [onError] - Callback for error handling (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata
  ///
  /// Example:
  /// ```dart
  /// final waveformData = await Sonix.generateWaveformWithProgress(
  ///   'audio.mp3',
  ///   onProgress: (progress) {
  ///     print('Progress: ${progress.progressPercentage * 100}%');
  ///     if (progress.estimatedTimeRemaining != null) {
  ///       print('ETA: ${progress.estimatedTimeRemaining}');
  ///     }
  ///   },
  /// );
  /// ```
  static Future<WaveformData> generateWaveformWithProgress(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
    ChunkedProcessingConfig? chunkedConfig,
    required ProgressCallback onProgress,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    // Validate file format first
    if (!isFormatSupported(filePath)) {
      final extension = _getFileExtension(filePath);
      throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
    }

    // Check file size to determine processing method
    final file = File(filePath);
    final fileSize = await file.length();

    // Use chunked processing for files that benefit from progress reporting
    const progressThreshold = 10 * 1024 * 1024; // 10MB
    final shouldUseChunkedProcessing = fileSize > progressThreshold;

    if (shouldUseChunkedProcessing) {
      return await generateWaveformChunked(
        filePath,
        resolution: resolution,
        type: type,
        normalize: normalize,
        config: config,
        chunkedConfig: chunkedConfig,
        onProgress: onProgress,
        onError: onError,
      );
    } else {
      // For smaller files, provide simulated progress
      onProgress(ProgressInfo(processedChunks: 0, totalChunks: 1));

      final result = await generateWaveform(filePath, resolution: resolution, type: type, normalize: normalize, config: config);

      onProgress(ProgressInfo(processedChunks: 1, totalChunks: 1));
      return result;
    }
  }

  /// Seek to a specific time position and generate waveform for a portion of the audio
  ///
  /// This method uses chunked processing to efficiently seek to a specific position
  /// and generate a waveform for only a portion of the audio file, which is useful
  /// for large files where you only need to visualize a specific section.
  ///
  /// [filePath] - Path to the audio file
  /// [seekPosition] - Time position to seek to
  /// [duration] - Duration of audio to process from the seek position (optional, processes to end if null)
  /// [resolution] - Number of data points in the waveform (default: 1000)
  /// [type] - Type of waveform visualization (default: bars)
  /// [normalize] - Whether to normalize amplitude values (default: true)
  /// [config] - Advanced waveform configuration options (optional)
  /// [chunkedConfig] - Configuration for chunked processing (optional)
  /// [onProgress] - Callback for progress updates (optional)
  ///
  /// Returns [WaveformData] containing amplitude values and metadata for the specified portion
  ///
  /// Throws [UnsupportedFormatException] if the audio format is not supported
  /// Throws [SonixUnsupportedOperationException] if seeking is not supported for this format
  ///
  /// Example:
  /// ```dart
  /// // Generate waveform for 30 seconds starting at 2 minutes
  /// final waveformData = await Sonix.seekAndGenerateWaveform(
  ///   'long_audio.mp3',
  ///   seekPosition: Duration(minutes: 2),
  ///   duration: Duration(seconds: 30),
  /// );
  /// ```
  static Future<WaveformData> seekAndGenerateWaveform(
    String filePath, {
    required Duration seekPosition,
    Duration? duration,
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
    ChunkedProcessingConfig? chunkedConfig,
    ProgressCallback? onProgress,
  }) async {
    final operation = RecoverableOperation<WaveformData>(
      () async {
        // Validate file format
        if (!isFormatSupported(filePath)) {
          final extension = _getFileExtension(filePath);
          throw UnsupportedFormatException(extension, 'Unsupported audio format: $extension. Supported formats: ${getSupportedFormats().join(', ')}');
        }

        // Get file size for optimal configuration
        final file = File(filePath);
        final fileSize = await file.length();

        // Create chunked processing configuration
        final effectiveChunkedConfig = chunkedConfig ?? ChunkedProcessingConfig.forFileSize(fileSize);

        // Create decoder for the file
        final decoder = AudioDecoderFactory.createDecoder(filePath);

        // Check if decoder supports chunked processing and seeking
        if (decoder is! ChunkedAudioDecoder) {
          decoder.dispose();
          throw SonixUnsupportedOperationException(
            'Seeking with chunked processing is not supported for this audio format. '
            'Supported formats: MP3, FLAC, WAV, OGG',
          );
        }

        final chunkedDecoder = decoder;

        if (!chunkedDecoder.supportsEfficientSeeking) {
          decoder.dispose();
          throw SonixUnsupportedOperationException('Efficient seeking is not supported for this audio format');
        }

        try {
          // Initialize chunked decoding with seek position
          await chunkedDecoder.initializeChunkedDecoding(filePath, chunkSize: effectiveChunkedConfig.fileChunkSize, seekPosition: seekPosition);

          // Perform the seek
          final seekResult = await chunkedDecoder.seekToTime(seekPosition);
          if (!seekResult.isExact && seekResult.warning != null) {
            // Log warning about approximate seek
          }

          // Create file reader starting from seek position
          final fileReader = await ChunkedFileReaderFactory.createForFile(
            filePath,
            chunkSize: effectiveChunkedConfig.fileChunkSize,
            enableSeeking: effectiveChunkedConfig.enableSeeking,
          );

          // Seek file reader to the appropriate byte position
          await fileReader.seekToPosition(seekResult.bytePosition);

          try {
            // Create waveform configuration
            final waveformConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

            // Create progressive waveform generator
            final progressiveGenerator = ProgressiveWaveformGenerator(config: waveformConfig, onProgress: onProgress);

            // Process file chunks with duration limit
            final processedChunks = _processFileChunksWithDuration(fileReader, chunkedDecoder, effectiveChunkedConfig, duration, seekResult.actualPosition);

            final waveformData = await progressiveGenerator.generateCompleteWaveform(processedChunks);

            return waveformData;
          } finally {
            await fileReader.close();
          }
        } finally {
          await chunkedDecoder.cleanupChunkedProcessing();
          decoder.dispose();
        }
      },
      'seekAndGenerateWaveform',
      {
        'filePath': filePath,
        'seekPosition': seekPosition,
        'operation': (String path) async => seekAndGenerateWaveform(
          path,
          seekPosition: seekPosition,
          duration: duration,
          resolution: resolution,
          type: type,
          normalize: normalize,
          config: config,
          chunkedConfig: chunkedConfig,
          onProgress: onProgress,
        ),
      },
    );

    return await operation.execute();
  }

  /// Get chunked processing capabilities for the current system and audio format
  ///
  /// This method provides information about what chunked processing features
  /// are available for different audio formats on the current platform.
  ///
  /// [filePath] - Optional path to check format-specific capabilities
  ///
  /// Returns a map containing capability information
  ///
  /// Example:
  /// ```dart
  /// final capabilities = await Sonix.getChunkedProcessingCapabilities('audio.mp3');
  /// print('Supports chunked processing: ${capabilities['supportsChunkedProcessing']}');
  /// print('Supports seeking: ${capabilities['supportsEfficientSeeking']}');
  /// ```
  static Future<Map<String, dynamic>> getChunkedProcessingCapabilities([String? filePath]) async {
    final capabilities = <String, dynamic>{
      'supportsChunkedProcessing': true,
      'supportedFormats': <String>[],
      'supportsEfficientSeeking': <String, bool>{},
      'recommendedChunkSizes': <String, Map<String, int>>{},
      'platformOptimizations': <String, dynamic>{},
    };

    // Check each supported format
    final supportedFormats = getSupportedFormats();
    final chunkedSupportedFormats = <String>[];
    final seekingSupport = <String, bool>{};
    final chunkSizeRecommendations = <String, Map<String, int>>{};

    for (final formatName in supportedFormats) {
      try {
        // Create a temporary decoder to check capabilities
        final tempFilePath = 'temp.$formatName'.toLowerCase();
        final decoder = AudioDecoderFactory.createDecoder(tempFilePath);

        if (decoder is ChunkedAudioDecoder) {
          chunkedSupportedFormats.add(formatName);
          seekingSupport[formatName] = decoder.supportsEfficientSeeking;

          // Get chunk size recommendations for different file sizes
          final smallFileRec = decoder.getOptimalChunkSize(10 * 1024 * 1024); // 10MB
          final largeFileRec = decoder.getOptimalChunkSize(1024 * 1024 * 1024); // 1GB

          chunkSizeRecommendations[formatName] = {
            'smallFile': smallFileRec.recommendedSize,
            'largeFile': largeFileRec.recommendedSize,
            'minSize': smallFileRec.minSize,
            'maxSize': largeFileRec.maxSize,
          };
        }

        decoder.dispose();
      } catch (e) {
        // Format not supported for chunked processing
      }
    }

    capabilities['supportedFormats'] = chunkedSupportedFormats;
    capabilities['supportsEfficientSeeking'] = seekingSupport;
    capabilities['recommendedChunkSizes'] = chunkSizeRecommendations;

    // Platform-specific information
    capabilities['platformOptimizations'] = {
      'maxRecommendedMemoryUsage': Platform.isAndroid || Platform.isIOS
          ? 100 *
                1024 *
                1024 // 100MB for mobile
          : 500 * 1024 * 1024, // 500MB for desktop
      'maxRecommendedConcurrentChunks': Platform.isAndroid || Platform.isIOS ? 2 : 4,
      'supportsMemoryPressureDetection': true,
      'supportsProgressReporting': true,
    };

    // If a specific file path is provided, add file-specific information
    if (filePath != null && isFormatSupported(filePath)) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          final optimalConfig = ChunkedProcessingConfig.forFileSize(fileSize);

          capabilities['fileSpecific'] = {
            'fileSize': fileSize,
            'recommendedChunkSize': optimalConfig.fileChunkSize,
            'recommendedMemoryUsage': optimalConfig.maxMemoryUsage,
            'recommendedConcurrentChunks': optimalConfig.maxConcurrentChunks,
            'enableSeeking': optimalConfig.enableSeeking,
            'enableProgressReporting': optimalConfig.enableProgressReporting,
          };
        }
      } catch (e) {
        // File-specific information not available
      }
    }

    return capabilities;
  }

  /// Process file chunks with duration limit for partial waveform generation
  static Stream<ProcessedChunk> _processFileChunksWithDuration(
    ChunkedFileReader fileReader,
    ChunkedAudioDecoder decoder,
    ChunkedProcessingConfig config,
    Duration? maxDuration,
    Duration startPosition,
  ) async* {
    Duration currentPosition = startPosition;

    await for (final fileChunk in fileReader.readChunks()) {
      try {
        final audioChunks = await decoder.processFileChunk(fileChunk);

        // Calculate duration of processed audio
        if (audioChunks.isNotEmpty && maxDuration != null) {
          // Estimate duration based on sample count and sample rate
          // This is a simplified calculation - real implementation would use format metadata
          final totalSamples = audioChunks.fold<int>(0, (sum, chunk) => sum + chunk.samples.length);
          const estimatedSampleRate = 44100; // Default assumption
          final chunkDuration = Duration(microseconds: (totalSamples * Duration.microsecondsPerSecond) ~/ estimatedSampleRate);

          currentPosition += chunkDuration;

          // Stop if we've exceeded the requested duration
          if (currentPosition >= startPosition + maxDuration) {
            // Yield the chunk and then stop
            yield ProcessedChunk(fileChunk: fileChunk, audioChunks: audioChunks);
            break;
          }
        }

        yield ProcessedChunk(fileChunk: fileChunk, audioChunks: audioChunks);
      } catch (error) {
        // Yield error chunk but continue processing
        yield ProcessedChunk(fileChunk: fileChunk, audioChunks: [], error: error);
      }
    }
  }
}
