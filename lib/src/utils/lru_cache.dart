import 'dart:collection';

import '../models/waveform_data.dart';
import 'memory_manager.dart';

/// LRU (Least Recently Used) cache for waveform data
class LRUCache<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap();
  final MemoryManager _memoryManager = MemoryManager();

  /// Create LRU cache with maximum size
  LRUCache(this._maxSize) {
    if (_maxSize <= 0) {
      throw ArgumentError('Cache size must be positive');
    }
  }

  /// Get current cache size
  int get size => _cache.length;

  /// Get maximum cache size
  int get maxSize => _maxSize;

  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache is full
  bool get isFull => _cache.length >= _maxSize;

  /// Get value from cache
  V? get(K key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      // Move to end (most recently used)
      _cache[key] = entry;
      entry.lastAccessed = DateTime.now();
      return entry.value;
    }
    return null;
  }

  /// Put value in cache
  void put(K key, V value) {
    // Remove existing entry if present
    final existingEntry = _cache.remove(key);
    if (existingEntry != null) {
      _deallocateMemory(existingEntry.value);
    }

    // Check memory constraints before adding
    final memoryUsage = _estimateMemoryUsage(value);
    if (_memoryManager.wouldExceedMemoryLimit(memoryUsage)) {
      // Try to free up space by removing old entries
      _evictToFreeMemory(memoryUsage);
    }

    // Add new entry
    final entry = _CacheEntry(value, DateTime.now(), memoryUsage);
    _cache[key] = entry;
    _memoryManager.allocateMemory(memoryUsage);

    // Evict oldest entries if cache is full
    while (_cache.length > _maxSize) {
      _evictOldest();
    }
  }

  /// Remove value from cache
  V? remove(K key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _deallocateMemory(entry.value);
      return entry.value;
    }
    return null;
  }

  /// Check if key exists in cache
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  /// Clear all entries from cache
  void clear() {
    for (final entry in _cache.values) {
      _deallocateMemory(entry.value);
    }
    _cache.clear();
  }

  /// Get all keys in cache (ordered by recency)
  Iterable<K> get keys => _cache.keys;

  /// Get all values in cache (ordered by recency)
  Iterable<V> get values => _cache.values.map((entry) => entry.value);

  /// Get cache statistics
  CacheStatistics getStatistics() {
    final now = DateTime.now();
    var totalMemoryUsage = 0;
    var oldestAccess = now;
    var newestAccess = DateTime.fromMillisecondsSinceEpoch(0);

    for (final entry in _cache.values) {
      totalMemoryUsage += entry.memoryUsage;
      if (entry.lastAccessed.isBefore(oldestAccess)) {
        oldestAccess = entry.lastAccessed;
      }
      if (entry.lastAccessed.isAfter(newestAccess)) {
        newestAccess = entry.lastAccessed;
      }
    }

    return CacheStatistics(
      size: _cache.length,
      maxSize: _maxSize,
      memoryUsage: totalMemoryUsage,
      oldestAccess: _cache.isEmpty ? null : oldestAccess,
      newestAccess: _cache.isEmpty ? null : newestAccess,
    );
  }

  /// Evict entries to free up specified amount of memory
  void _evictToFreeMemory(int requiredMemory) {
    var freedMemory = 0;
    final keysToRemove = <K>[];

    // Collect keys to remove (oldest first)
    for (final entry in _cache.entries) {
      keysToRemove.add(entry.key);
      freedMemory += entry.value.memoryUsage;

      if (freedMemory >= requiredMemory) {
        break;
      }
    }

    // Remove the entries
    for (final key in keysToRemove) {
      remove(key);
    }
  }

  /// Evict the oldest entry
  void _evictOldest() {
    if (_cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      remove(oldestKey);
    }
  }

  /// Estimate memory usage for a value
  int _estimateMemoryUsage(V value) {
    if (value is WaveformData) {
      return MemoryManager.estimateWaveformMemoryUsage(value.amplitudes.length);
    }
    // Default estimate for unknown types
    return 1024; // 1KB default
  }

  /// Deallocate memory for a value
  void _deallocateMemory(V value) {
    final memoryUsage = _estimateMemoryUsage(value);
    _memoryManager.deallocateMemory(memoryUsage);

    // Call dispose if the value supports it
    if (value is Disposable) {
      (value as Disposable).dispose();
    }
  }
}

/// Cache entry with metadata
class _CacheEntry<V> {
  final V value;
  DateTime lastAccessed;
  final int memoryUsage;

  _CacheEntry(this.value, this.lastAccessed, this.memoryUsage);
}

/// Cache statistics
class CacheStatistics {
  /// Current number of entries
  final int size;

  /// Maximum number of entries
  final int maxSize;

  /// Total memory usage in bytes
  final int memoryUsage;

  /// Timestamp of oldest access
  final DateTime? oldestAccess;

  /// Timestamp of newest access
  final DateTime? newestAccess;

  const CacheStatistics({required this.size, required this.maxSize, required this.memoryUsage, this.oldestAccess, this.newestAccess});

  /// Get cache utilization as percentage (0.0 to 1.0)
  double get utilization => size / maxSize;

  /// Get age of oldest entry
  Duration? get oldestEntryAge {
    if (oldestAccess == null) return null;
    return DateTime.now().difference(oldestAccess!);
  }

  @override
  String toString() {
    return 'CacheStatistics(size: $size/$maxSize, '
        'memoryUsage: ${(memoryUsage / 1024).toStringAsFixed(1)}KB, '
        'utilization: ${(utilization * 100).toStringAsFixed(1)}%)';
  }
}

/// Interface for objects that can be disposed
abstract class Disposable {
  void dispose();
}

/// Specialized LRU cache for waveform data
class WaveformCache extends LRUCache<String, WaveformData> {
  WaveformCache({int maxSize = 50}) : super(maxSize);

  /// Get waveform data by file path and configuration hash
  WaveformData? getWaveform(String filePath, String configHash) {
    final key = '$filePath:$configHash';
    return get(key);
  }

  /// Put waveform data with file path and configuration hash
  void putWaveform(String filePath, String configHash, WaveformData waveformData) {
    final key = '$filePath:$configHash';
    put(key, waveformData);
  }

  /// Remove waveform data by file path and configuration hash
  WaveformData? removeWaveform(String filePath, String configHash) {
    final key = '$filePath:$configHash';
    return remove(key);
  }

  /// Check if waveform exists in cache
  bool hasWaveform(String filePath, String configHash) {
    final key = '$filePath:$configHash';
    return containsKey(key);
  }

  /// Clear all waveforms for a specific file
  void clearWaveformsForFile(String filePath) {
    final keysToRemove = keys.where((key) => key.startsWith('$filePath:')).toList();
    for (final key in keysToRemove) {
      remove(key);
    }
  }
}
