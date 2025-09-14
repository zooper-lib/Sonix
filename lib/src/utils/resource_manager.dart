import 'dart:async';

import '../models/audio_data.dart';
import '../decoders/audio_decoder.dart';
import 'memory_manager.dart';
import 'lru_cache.dart';

/// Manages all resources and their disposal in Sonix
class ResourceManager {
  static final ResourceManager _instance = ResourceManager._internal();
  factory ResourceManager() => _instance;
  ResourceManager._internal();

  // Track all managed resources
  final Set<Disposable> _managedResources = <Disposable>{};
  final Set<AudioDecoder> _activeDecoders = <AudioDecoder>{};
  final Set<StreamSubscription> _activeSubscriptions = <StreamSubscription>{};

  // Global caches
  late final WaveformCache _waveformCache;
  late final LRUCache<String, AudioData> _audioDataCache;

  // Memory manager integration
  final MemoryManager _memoryManager = MemoryManager();

  // Resource tracking
  final Map<String, ResourceInfo> _resourceInfo = <String, ResourceInfo>{};

  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Initialize the resource manager
  void initialize({int maxWaveformCacheSize = 50, int maxAudioDataCacheSize = 20, int? memoryLimit}) {
    if (_isInitialized) return;

    _waveformCache = WaveformCache(maxSize: maxWaveformCacheSize);
    _audioDataCache = LRUCache<String, AudioData>(maxAudioDataCacheSize);

    _memoryManager.initialize(memoryLimit: memoryLimit);

    // Register memory pressure callbacks
    _memoryManager.registerMemoryPressureCallback(_handleMemoryPressure);
    _memoryManager.registerCriticalMemoryCallback(_handleCriticalMemoryPressure);

    _isInitialized = true;
  }

  /// Get waveform cache
  WaveformCache get waveformCache {
    _ensureInitialized();
    return _waveformCache;
  }

  /// Get audio data cache
  LRUCache<String, AudioData> get audioDataCache {
    _ensureInitialized();
    return _audioDataCache;
  }

  /// Get memory manager
  MemoryManager get memoryManager => _memoryManager;

  /// Register a disposable resource for management
  T registerResource<T extends Disposable>(T resource, {String? identifier}) {
    _ensureInitialized();
    _checkDisposed();

    _managedResources.add(resource);

    if (identifier != null) {
      _resourceInfo[identifier] = ResourceInfo(resource: resource, createdAt: DateTime.now(), type: T.toString());
    }

    return resource;
  }

  /// Register an audio decoder for management
  T registerDecoder<T extends AudioDecoder>(T decoder, {String? identifier}) {
    _ensureInitialized();
    _checkDisposed();

    _activeDecoders.add(decoder);

    if (identifier != null) {
      _resourceInfo[identifier] = ResourceInfo(resource: decoder, createdAt: DateTime.now(), type: T.toString());
    }

    return decoder;
  }

  /// Register a stream subscription for management
  StreamSubscription<T> registerSubscription<T>(StreamSubscription<T> subscription, {String? identifier}) {
    _ensureInitialized();
    _checkDisposed();

    _activeSubscriptions.add(subscription);

    if (identifier != null) {
      _resourceInfo[identifier] = ResourceInfo(resource: subscription, createdAt: DateTime.now(), type: 'StreamSubscription<$T>');
    }

    return subscription;
  }

  /// Unregister and dispose a resource
  void unregisterResource(dynamic resource, {String? identifier}) {
    if (resource is Disposable) {
      _managedResources.remove(resource);
      resource.dispose();
    } else if (resource is AudioDecoder) {
      _activeDecoders.remove(resource);
      resource.dispose();
    } else if (resource is StreamSubscription) {
      _activeSubscriptions.remove(resource);
      resource.cancel();
    }

    if (identifier != null) {
      _resourceInfo.remove(identifier);
    }
  }

  /// Get resource information by identifier
  ResourceInfo? getResourceInfo(String identifier) {
    return _resourceInfo[identifier];
  }

  /// Get all resource information
  Map<String, ResourceInfo> getAllResourceInfo() {
    return Map.unmodifiable(_resourceInfo);
  }

  /// Get resource statistics
  ResourceStatistics getResourceStatistics() {
    return ResourceStatistics(
      managedResourceCount: _managedResources.length,
      activeDecoderCount: _activeDecoders.length,
      activeSubscriptionCount: _activeSubscriptions.length,
      waveformCacheStats: _waveformCache.getStatistics(),
      audioDataCacheStats: _audioDataCache.getStatistics(),
      memoryUsage: _memoryManager.currentMemoryUsage,
      memoryLimit: _memoryManager.memoryLimit,
    );
  }

  /// Optimize resource usage
  void optimizeResources() {
    _ensureInitialized();
    _checkDisposed();

    // Trigger memory pressure handling if needed
    if (_memoryManager.isMemoryPressureHigh) {
      _handleMemoryPressure();
    }

    // Clean up old resources
    _disposeOldResources();
  }

  /// Force cleanup of all resources
  Future<void> forceCleanup() async {
    _ensureInitialized();

    // Clear caches first
    _waveformCache.clear();
    _audioDataCache.clear();

    // Dispose managed resources
    for (final resource in _managedResources.toList()) {
      try {
        resource.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
    }
    _managedResources.clear();

    // Dispose decoders
    for (final decoder in _activeDecoders.toList()) {
      try {
        decoder.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
    }
    _activeDecoders.clear();

    // Cancel subscriptions
    for (final subscription in _activeSubscriptions.toList()) {
      try {
        await subscription.cancel();
      } catch (e) {
        // Ignore cancellation errors
      }
    }
    _activeSubscriptions.clear();

    // Clear resource info
    _resourceInfo.clear();

    // Force memory cleanup
    await _memoryManager.forceMemoryCleanup();
  }

  /// Handle memory pressure by cleaning up resources
  void _handleMemoryPressure() {
    // Clear least recently used cache entries
    final waveformStats = _waveformCache.getStatistics();
    final audioStats = _audioDataCache.getStatistics();

    // Remove 25% of cached items
    final waveformToRemove = (waveformStats.size * 0.25).ceil();
    final audioToRemove = (audioStats.size * 0.25).ceil();

    _evictCacheEntries(_waveformCache, waveformToRemove);
    _evictCacheEntries(_audioDataCache, audioToRemove);
  }

  /// Handle critical memory pressure by aggressive cleanup
  void _handleCriticalMemoryPressure() {
    // Clear 50% of cached items
    final waveformStats = _waveformCache.getStatistics();
    final audioStats = _audioDataCache.getStatistics();

    final waveformToRemove = (waveformStats.size * 0.5).ceil();
    final audioToRemove = (audioStats.size * 0.5).ceil();

    _evictCacheEntries(_waveformCache, waveformToRemove);
    _evictCacheEntries(_audioDataCache, audioToRemove);

    // Also dispose of old managed resources
    _disposeOldResources();
  }

  /// Evict entries from cache
  void _evictCacheEntries<K, V>(LRUCache<K, V> cache, int count) {
    final keysToRemove = cache.keys.take(count).toList();
    for (final key in keysToRemove) {
      cache.remove(key);
    }
  }

  /// Dispose of old managed resources
  void _disposeOldResources() {
    final now = DateTime.now();
    final oldThreshold = now.subtract(const Duration(minutes: 5));

    final resourcesToDispose = <String>[];

    for (final entry in _resourceInfo.entries) {
      if (entry.value.createdAt.isBefore(oldThreshold)) {
        resourcesToDispose.add(entry.key);
      }
    }

    for (final identifier in resourcesToDispose) {
      final info = _resourceInfo[identifier];
      if (info != null) {
        unregisterResource(info.resource, identifier: identifier);
      }
    }
  }

  /// Ensure resource manager is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('ResourceManager must be initialized before use');
    }
  }

  /// Check if resource manager is disposed
  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('ResourceManager has been disposed');
    }
  }

  /// Dispose of the resource manager
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await forceCleanup();
    _memoryManager.dispose();
  }
}

/// Information about a managed resource
class ResourceInfo {
  /// The resource instance
  final dynamic resource;

  /// When the resource was created
  final DateTime createdAt;

  /// Type of the resource
  final String type;

  /// When the resource was last accessed
  DateTime lastAccessed;

  ResourceInfo({required this.resource, required this.createdAt, required this.type}) : lastAccessed = createdAt;

  /// Age of the resource
  Duration get age => DateTime.now().difference(createdAt);

  /// Time since last access
  Duration get timeSinceLastAccess => DateTime.now().difference(lastAccessed);

  /// Mark resource as accessed
  void markAccessed() {
    lastAccessed = DateTime.now();
  }

  @override
  String toString() {
    return 'ResourceInfo(type: $type, age: $age, '
        'timeSinceLastAccess: $timeSinceLastAccess)';
  }
}

/// Statistics about resource usage
class ResourceStatistics {
  /// Number of managed disposable resources
  final int managedResourceCount;

  /// Number of active audio decoders
  final int activeDecoderCount;

  /// Number of active stream subscriptions
  final int activeSubscriptionCount;

  /// Waveform cache statistics
  final CacheStatistics waveformCacheStats;

  /// Audio data cache statistics
  final CacheStatistics audioDataCacheStats;

  /// Current memory usage in bytes
  final int memoryUsage;

  /// Memory limit in bytes
  final int memoryLimit;

  const ResourceStatistics({
    required this.managedResourceCount,
    required this.activeDecoderCount,
    required this.activeSubscriptionCount,
    required this.waveformCacheStats,
    required this.audioDataCacheStats,
    required this.memoryUsage,
    required this.memoryLimit,
  });

  /// Get memory usage as percentage (0.0 to 1.0)
  double get memoryUsagePercentage => memoryUsage / memoryLimit;

  /// Get total cache memory usage
  int get totalCacheMemoryUsage => waveformCacheStats.memoryUsage + audioDataCacheStats.memoryUsage;

  @override
  String toString() {
    return 'ResourceStatistics(\n'
        '  managedResources: $managedResourceCount\n'
        '  activeDecoders: $activeDecoderCount\n'
        '  activeSubscriptions: $activeSubscriptionCount\n'
        '  waveformCache: $waveformCacheStats\n'
        '  audioDataCache: $audioDataCacheStats\n'
        '  memoryUsage: ${(memoryUsage / 1024 / 1024).toStringAsFixed(1)}MB / '
        '${(memoryLimit / 1024 / 1024).toStringAsFixed(1)}MB '
        '(${(memoryUsagePercentage * 100).toStringAsFixed(1)}%)\n'
        ')';
  }
}
