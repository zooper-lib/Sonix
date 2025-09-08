import 'dart:async';
import 'dart:math' as math;

import '../models/waveform_data.dart';
import '../models/audio_data.dart';
import '../processing/waveform_generator.dart';
import 'memory_manager.dart';
import 'lru_cache.dart';

/// Lazy-loaded waveform data that loads segments on demand
class LazyWaveformData implements Disposable {
  final String _filePath;
  final WaveformConfig _config;
  final Duration _duration;
  final int _sampleRate;
  final WaveformMetadata _metadata;

  // Lazy loading configuration
  final int _segmentSize;
  final int _totalSegments;

  // Cache for loaded segments
  final LRUCache<int, List<double>> _segmentCache;
  final MemoryManager _memoryManager = MemoryManager();

  // Audio data provider (function that loads audio data)
  final Future<AudioData> Function() _audioDataProvider;

  // Cached full data (loaded on demand)
  WaveformData? _fullWaveformData;
  bool _isDisposed = false;

  LazyWaveformData._({
    required String filePath,
    required WaveformConfig config,
    required Duration duration,
    required int sampleRate,
    required WaveformMetadata metadata,
    required Future<AudioData> Function() audioDataProvider,
    int segmentSize = 100,
    int maxCachedSegments = 10,
  }) : _filePath = filePath,
       _config = config,
       _duration = duration,
       _sampleRate = sampleRate,
       _metadata = metadata,
       _audioDataProvider = audioDataProvider,
       _segmentSize = segmentSize,
       _totalSegments = (config.resolution / segmentSize).ceil(),
       _segmentCache = LRUCache<int, List<double>>(maxCachedSegments);

  /// Create lazy waveform data from audio data provider
  static Future<LazyWaveformData> create({
    required String filePath,
    required WaveformConfig config,
    required Future<AudioData> Function() audioDataProvider,
    int segmentSize = 100,
    int maxCachedSegments = 10,
  }) async {
    // Load minimal metadata without processing full audio
    final audioData = await audioDataProvider();

    final metadata = WaveformMetadata(resolution: config.resolution, type: config.type, normalized: config.normalize, generatedAt: DateTime.now());

    return LazyWaveformData._(
      filePath: filePath,
      config: config,
      duration: audioData.duration,
      sampleRate: audioData.sampleRate,
      metadata: metadata,
      audioDataProvider: audioDataProvider,
      segmentSize: segmentSize,
      maxCachedSegments: maxCachedSegments,
    );
  }

  /// Get file path
  String get filePath => _filePath;

  /// Get configuration
  WaveformConfig get config => _config;

  /// Get duration
  Duration get duration => _duration;

  /// Get sample rate
  int get sampleRate => _sampleRate;

  /// Get metadata
  WaveformMetadata get metadata => _metadata;

  /// Get total number of amplitude points
  int get length => _config.resolution;

  /// Get number of segments
  int get segmentCount => _totalSegments;

  /// Get segment size
  int get segmentSize => _segmentSize;

  /// Check if disposed
  bool get isDisposed => _isDisposed;

  /// Get amplitude at specific index (loads segment if needed)
  Future<double> getAmplitudeAt(int index) async {
    _checkDisposed();

    if (index < 0 || index >= _config.resolution) {
      throw RangeError.index(index, this, 'index', null, _config.resolution);
    }

    final segmentIndex = index ~/ _segmentSize;
    final indexInSegment = index % _segmentSize;

    final segment = await _getSegment(segmentIndex);

    if (indexInSegment >= segment.length) {
      return 0.0; // Return 0 for out-of-bounds within segment
    }

    return segment[indexInSegment];
  }

  /// Get amplitude range (loads necessary segments)
  Future<List<double>> getAmplitudeRange(int start, int end) async {
    _checkDisposed();

    if (start < 0 || end > _config.resolution || start >= end) {
      throw RangeError('Invalid range: $start to $end');
    }

    final result = <double>[];
    final startSegment = start ~/ _segmentSize;
    final endSegment = (end - 1) ~/ _segmentSize;

    for (int segmentIndex = startSegment; segmentIndex <= endSegment; segmentIndex++) {
      final segment = await _getSegment(segmentIndex);

      final segmentStart = math.max(0, start - (segmentIndex * _segmentSize));
      final segmentEnd = math.min(segment.length, end - (segmentIndex * _segmentSize));

      if (segmentStart < segmentEnd) {
        result.addAll(segment.sublist(segmentStart, segmentEnd));
      }
    }

    return result;
  }

  /// Get all amplitudes (loads full waveform data)
  Future<List<double>> getAllAmplitudes() async {
    _checkDisposed();

    // Check if we should load full data based on memory constraints
    final estimatedMemory = MemoryManager.estimateWaveformMemoryUsage(_config.resolution);

    if (_memoryManager.wouldExceedMemoryLimit(estimatedMemory)) {
      // Use segment-based approach for memory efficiency
      return await getAmplitudeRange(0, _config.resolution);
    }

    // Load full waveform data if not already loaded
    if (_fullWaveformData == null) {
      await _loadFullWaveformData();
    }

    return _fullWaveformData!.amplitudes;
  }

  /// Convert to regular WaveformData (loads all data)
  Future<WaveformData> toWaveformData() async {
    _checkDisposed();

    if (_fullWaveformData == null) {
      await _loadFullWaveformData();
    }

    return _fullWaveformData!;
  }

  /// Get cache statistics
  CacheStatistics getCacheStatistics() {
    return _segmentCache.getStatistics();
  }

  /// Preload specific segments
  Future<void> preloadSegments(List<int> segmentIndices) async {
    _checkDisposed();

    for (final segmentIndex in segmentIndices) {
      if (segmentIndex >= 0 && segmentIndex < _totalSegments) {
        await _getSegment(segmentIndex);
      }
    }
  }

  /// Preload range of segments
  Future<void> preloadSegmentRange(int startSegment, int endSegment) async {
    _checkDisposed();

    final clampedStart = math.max(0, startSegment);
    final clampedEnd = math.min(_totalSegments - 1, endSegment);

    for (int i = clampedStart; i <= clampedEnd; i++) {
      await _getSegment(i);
    }
  }

  /// Clear cached segments to free memory
  void clearCache() {
    _segmentCache.clear();
  }

  /// Get segment by index (loads if not cached)
  Future<List<double>> _getSegment(int segmentIndex) async {
    if (segmentIndex < 0 || segmentIndex >= _totalSegments) {
      throw RangeError.index(segmentIndex, this, 'segmentIndex', null, _totalSegments);
    }

    // Check cache first
    final cachedSegment = _segmentCache.get(segmentIndex);
    if (cachedSegment != null) {
      return cachedSegment;
    }

    // Load segment
    final segment = await _loadSegment(segmentIndex);

    // Cache the segment
    _segmentCache.put(segmentIndex, segment);

    return segment;
  }

  /// Load specific segment from audio data
  Future<List<double>> _loadSegment(int segmentIndex) async {
    // Load full audio data (this could be optimized to load only needed portion)
    final audioData = await _audioDataProvider();

    // Calculate segment boundaries
    final startIndex = segmentIndex * _segmentSize;
    final endIndex = math.min(startIndex + _segmentSize, _config.resolution);

    // Generate waveform for this segment
    final segmentConfig = _config.copyWith(resolution: endIndex - startIndex);

    // Calculate which audio samples correspond to this segment
    final samplesPerPoint = audioData.samples.length / _config.resolution;
    final audioStartIndex = (startIndex * samplesPerPoint).floor();
    final audioEndIndex = math.min((endIndex * samplesPerPoint).ceil(), audioData.samples.length);

    // Extract audio samples for this segment
    final segmentAudioSamples = audioData.samples.sublist(audioStartIndex, audioEndIndex);

    // Create audio data for this segment
    final segmentAudioData = AudioData(
      samples: segmentAudioSamples,
      sampleRate: audioData.sampleRate,
      channels: audioData.channels,
      duration: Duration(microseconds: (segmentAudioSamples.length * Duration.microsecondsPerSecond) ~/ (audioData.sampleRate * audioData.channels)),
    );

    // Generate waveform for this segment
    final segmentWaveform = await WaveformGenerator.generate(segmentAudioData, config: segmentConfig);

    return segmentWaveform.amplitudes;
  }

  /// Load full waveform data
  Future<void> _loadFullWaveformData() async {
    if (_fullWaveformData != null) return;

    final audioData = await _audioDataProvider();
    _fullWaveformData = await WaveformGenerator.generate(audioData, config: _config);
  }

  /// Check if object is disposed
  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('LazyWaveformData has been disposed');
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _segmentCache.clear();
    _fullWaveformData?.dispose();
    _fullWaveformData = null;
  }
}

/// Factory for creating lazy waveform data
class LazyWaveformDataFactory {
  /// Create lazy waveform data with automatic memory management
  static Future<LazyWaveformData> create({
    required String filePath,
    required WaveformConfig config,
    required Future<AudioData> Function() audioDataProvider,
  }) async {
    final memoryManager = MemoryManager();

    // Determine optimal segment size based on memory constraints
    final estimatedTotalMemory = MemoryManager.estimateWaveformMemoryUsage(config.resolution);

    int segmentSize;
    int maxCachedSegments;

    if (memoryManager.wouldExceedMemoryLimit(estimatedTotalMemory)) {
      // Use smaller segments for memory efficiency
      segmentSize = 50;
      maxCachedSegments = 5;
    } else if (estimatedTotalMemory > (memoryManager.memoryLimit * 0.5)) {
      // Use medium segments
      segmentSize = 100;
      maxCachedSegments = 10;
    } else {
      // Use larger segments for better performance
      segmentSize = 200;
      maxCachedSegments = 20;
    }

    return LazyWaveformData.create(
      filePath: filePath,
      config: config,
      audioDataProvider: audioDataProvider,
      segmentSize: segmentSize,
      maxCachedSegments: maxCachedSegments,
    );
  }
}
