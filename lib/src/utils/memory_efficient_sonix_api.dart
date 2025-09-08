import 'dart:async';
import 'dart:io';

import 'package:sonix/src/decoders/audio_decoder.dart';

import 'package:sonix/src/models/waveform_data.dart';
import 'package:sonix/src/models/audio_data.dart';
import 'package:sonix/src/processing/waveform_generator.dart';
import 'package:sonix/src/decoders/audio_decoder_factory.dart';
import 'package:sonix/src/exceptions/sonix_exceptions.dart';
import 'package:sonix/src/exceptions/error_recovery.dart';
import 'memory_manager.dart';
import 'resource_manager.dart';
import 'lazy_waveform_data.dart';

/// Memory-efficient extensions to the Sonix API
class MemoryEfficientSonixApi {
  static final ResourceManager _resourceManager = ResourceManager();
  static final MemoryManager _memoryManager = MemoryManager();

  /// Initialize memory management system
  static void initialize({int? memoryLimit, int maxWaveformCacheSize = 50, int maxAudioDataCacheSize = 20}) {
    _resourceManager.initialize(memoryLimit: memoryLimit, maxWaveformCacheSize: maxWaveformCacheSize, maxAudioDataCacheSize: maxAudioDataCacheSize);
  }

  /// Generate waveform with automatic memory management and caching
  static Future<WaveformData> generateWaveformCached(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
    bool useCache = true,
  }) async {
    final actualConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

    // Generate cache key
    final configHash = _generateConfigHash(actualConfig);

    // Check cache first if enabled
    if (useCache) {
      final cachedWaveform = _resourceManager.waveformCache.getWaveform(filePath, configHash);
      if (cachedWaveform != null) {
        return cachedWaveform;
      }
    }

    // Check memory constraints and adjust quality if needed
    final suggestion = _memoryManager.getSuggestedQualityReduction();
    WaveformConfig adjustedConfig = actualConfig;

    if (suggestion.shouldReduce) {
      adjustedConfig = actualConfig.copyWith(resolution: (actualConfig.resolution * suggestion.resolutionReduction).round());
    }

    final operation = RecoverableOperation<WaveformData>(
      () async {
        // Validate file format
        if (!AudioDecoderFactory.isFormatSupported(filePath)) {
          final extension = _getFileExtension(filePath);
          throw UnsupportedFormatException(
            extension,
            'Unsupported audio format: $extension. Supported formats: ${AudioDecoderFactory.getSupportedFormatNames().join(', ')}',
          );
        }

        // Create and register decoder
        final decoder = _resourceManager.registerDecoder(AudioDecoderFactory.createDecoder(filePath), identifier: 'decoder_$filePath');

        try {
          WaveformData waveformData;

          if (suggestion.enableStreaming) {
            // Use streaming approach for memory efficiency
            waveformData = await _generateWaveformStreaming(filePath, decoder, adjustedConfig);
          } else {
            // Use regular approach
            final audioData = await decoder.decode(filePath);
            _resourceManager.registerResource(audioData, identifier: 'audio_$filePath');

            waveformData = await WaveformGenerator.generate(audioData, config: adjustedConfig);
          }

          // Register the waveform data for management
          _resourceManager.registerResource(waveformData, identifier: 'waveform_$filePath');

          // Cache the result if enabled
          if (useCache) {
            _resourceManager.waveformCache.putWaveform(filePath, configHash, waveformData);
          }

          return waveformData;
        } finally {
          // Unregister decoder
          _resourceManager.unregisterResource(decoder, identifier: 'decoder_$filePath');
        }
      },
      'generateWaveformCached',
      {
        'filePath': filePath,
        'audioData': null, // Will be set during execution if needed
        'config': adjustedConfig,
        'originalOperation': () async {
          final decoder = AudioDecoderFactory.createDecoder(filePath);
          try {
            return await decoder.decode(filePath);
          } finally {
            decoder.dispose();
          }
        },
        'operation': (String path) async =>
            generateWaveformCached(path, resolution: resolution, type: type, normalize: normalize, config: config, useCache: useCache),
      },
    );

    return await operation.execute();
  }

  /// Generate lazy waveform data for large files
  static Future<LazyWaveformData> generateLazyWaveform(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
  }) async {
    final actualConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

    // Validate file format
    if (!AudioDecoderFactory.isFormatSupported(filePath)) {
      final extension = _getFileExtension(filePath);
      throw UnsupportedFormatException(
        extension,
        'Unsupported audio format: $extension. Supported formats: ${AudioDecoderFactory.getSupportedFormatNames().join(', ')}',
      );
    }

    // Create audio data provider function
    Future<AudioData> audioDataProvider() async {
      // Check cache first
      final cachedAudioData = _resourceManager.audioDataCache.get(filePath);
      if (cachedAudioData != null) {
        return cachedAudioData;
      }

      // Load and cache audio data
      final decoder = AudioDecoderFactory.createDecoder(filePath);
      try {
        final audioData = await decoder.decode(filePath);
        _resourceManager.audioDataCache.put(filePath, audioData);
        return audioData;
      } finally {
        decoder.dispose();
      }
    }

    // Create lazy waveform data
    final lazyWaveform = await LazyWaveformDataFactory.create(filePath: filePath, config: actualConfig, audioDataProvider: audioDataProvider);

    // Register for management
    _resourceManager.registerResource(lazyWaveform, identifier: 'lazy_waveform_$filePath');

    return lazyWaveform;
  }

  /// Generate waveform with automatic quality adjustment based on file size
  static Future<WaveformData> generateWaveformAdaptive(
    String filePath, {
    int resolution = 1000,
    WaveformType type = WaveformType.bars,
    bool normalize = true,
    WaveformConfig? config,
  }) async {
    // Get file size to determine approach
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileAccessException(filePath, 'File does not exist');
    }

    final fileSize = await file.length();
    const largeSizeThreshold = 50 * 1024 * 1024; // 50MB
    const hugeSizeThreshold = 200 * 1024 * 1024; // 200MB

    if (fileSize > hugeSizeThreshold) {
      // Use lazy loading for huge files
      return (await generateLazyWaveform(filePath, resolution: resolution, type: type, normalize: normalize, config: config)).toWaveformData();
    } else if (fileSize > largeSizeThreshold) {
      // Use memory-efficient generation for large files
      final actualConfig = config ?? WaveformConfig(resolution: resolution, type: type, normalize: normalize);

      final decoder = AudioDecoderFactory.createDecoder(filePath);
      try {
        final audioData = await decoder.decode(filePath);
        return await WaveformGenerator.generateMemoryEfficient(
          audioData,
          config: actualConfig,
          maxMemoryUsage: 25 * 1024 * 1024, // 25MB limit
        );
      } finally {
        decoder.dispose();
      }
    } else {
      // Use cached generation for normal files
      return generateWaveformCached(filePath, resolution: resolution, type: type, normalize: normalize, config: config);
    }
  }

  /// Get memory and resource statistics
  static ResourceStatistics getResourceStatistics() {
    return _resourceManager.getResourceStatistics();
  }

  /// Force cleanup of all cached resources
  static Future<void> forceCleanup() async {
    await _resourceManager.forceCleanup();
  }

  /// Clear specific file from all caches
  static void clearFileFromCaches(String filePath) {
    _resourceManager.waveformCache.clearWaveformsForFile(filePath);
    _resourceManager.audioDataCache.remove(filePath);
  }

  /// Preload audio data into cache
  static Future<void> preloadAudioData(String filePath) async {
    if (_resourceManager.audioDataCache.containsKey(filePath)) {
      return; // Already cached
    }

    final decoder = AudioDecoderFactory.createDecoder(filePath);
    try {
      final audioData = await decoder.decode(filePath);
      _resourceManager.audioDataCache.put(filePath, audioData);
    } finally {
      decoder.dispose();
    }
  }

  /// Generate streaming waveform for memory efficiency
  static Future<WaveformData> _generateWaveformStreaming(String filePath, AudioDecoder decoder, WaveformConfig config) async {
    final chunks = <WaveformChunk>[];
    final audioStream = decoder.decodeStream(filePath);

    await for (final chunk in WaveformGenerator.generateStream(audioStream, config: config)) {
      chunks.add(chunk);
    }

    // Combine chunks into final waveform data
    final allAmplitudes = <double>[];
    Duration totalDuration = Duration.zero;

    for (final chunk in chunks) {
      allAmplitudes.addAll(chunk.amplitudes);
      totalDuration += chunk.startTime;
    }

    final metadata = WaveformMetadata(resolution: allAmplitudes.length, type: config.type, normalized: config.normalize, generatedAt: DateTime.now());

    return WaveformData(
      amplitudes: allAmplitudes,
      duration: totalDuration,
      sampleRate: 44100, // Default assumption for streaming
      metadata: metadata,
    );
  }

  /// Generate configuration hash for caching
  static String _generateConfigHash(WaveformConfig config) {
    return '${config.resolution}_${config.type.name}_${config.normalize}_'
        '${config.algorithm.name}_${config.normalizationMethod.name}_'
        '${config.scalingCurve.name}_${config.scalingFactor}_'
        '${config.enableSmoothing}_${config.smoothingWindowSize}';
  }

  /// Extract file extension from path
  static String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot + 1);
  }

  /// Dispose of all resources
  static Future<void> dispose() async {
    await _resourceManager.dispose();
  }
}
