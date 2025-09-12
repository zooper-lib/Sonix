import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/chunked_processing_config.dart';

/// Manager for persisting and caching chunked processing configurations
///
/// This class handles configuration serialization, caching, and migration
/// across different versions of the library.
class ChunkedProcessingConfigManager {
  static const String _configFileName = 'chunked_processing_config.json';
  static const String _cacheFileName = 'config_cache.json';
  static const int _currentVersion = 1;

  final String _configDirectory;
  final Map<String, ChunkedProcessingConfig> _configCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheExpiry;

  ChunkedProcessingConfigManager({String? configDirectory, Duration cacheExpiry = const Duration(hours: 24)})
    : _configDirectory = configDirectory ?? _getDefaultConfigDirectory(),
      _cacheExpiry = cacheExpiry;

  /// Save configuration to persistent storage
  ///
  /// Requirements: 2.5, 8.5
  Future<void> saveConfiguration(ChunkedProcessingConfig config, {String? name}) async {
    final configName = name ?? 'default';

    try {
      // Validate configuration before saving
      final validation = config.validate();
      if (!validation.isValid) {
        throw ChunkedProcessingConfigException('Cannot save invalid configuration: ${validation.errors.join(', ')}');
      }

      // Ensure config directory exists
      final configDir = Directory(_configDirectory);
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      // Create configuration data with metadata
      final configData = {'version': _currentVersion, 'name': configName, 'createdAt': DateTime.now().toIso8601String(), 'config': config.toJson()};

      // Save to file
      final configFile = File(path.join(_configDirectory, '${configName}_$_configFileName'));
      await configFile.writeAsString(const JsonEncoder.withIndent('  ').convert(configData));

      // Update cache
      _configCache[configName] = config;
      _cacheTimestamps[configName] = DateTime.now();

      // Update cache file
      await _updateCacheFile();
    } catch (e) {
      throw ChunkedProcessingConfigException('Failed to save configuration "$configName": $e');
    }
  }

  /// Load configuration from persistent storage
  ///
  /// Requirements: 2.5, 8.5
  Future<ChunkedProcessingConfig?> loadConfiguration({String? name}) async {
    final configName = name ?? 'default';

    try {
      // Check cache first
      if (_isConfigCached(configName)) {
        return _configCache[configName];
      }

      // Load from file
      final configFile = File(path.join(_configDirectory, '${configName}_$_configFileName'));
      if (!await configFile.exists()) {
        return null;
      }

      final configContent = await configFile.readAsString();
      final configData = jsonDecode(configContent) as Map<String, dynamic>;

      // Handle version migration if needed
      final migratedData = await _migrateConfigurationData(configData);

      // Extract and validate configuration
      final configJson = migratedData['config'] as Map<String, dynamic>;
      final config = ChunkedProcessingConfig.fromJson(configJson);

      final validation = config.validate();
      if (!validation.isValid) {
        throw ChunkedProcessingConfigException('Loaded configuration is invalid: ${validation.errors.join(', ')}');
      }

      // Update cache
      _configCache[configName] = config;
      _cacheTimestamps[configName] = DateTime.now();

      return config;
    } catch (e) {
      throw ChunkedProcessingConfigException('Failed to load configuration "$configName": $e');
    }
  }

  /// Get or create configuration for a specific file size
  ///
  /// This method first checks the cache, then tries to load from storage,
  /// and finally creates a new optimized configuration if none exists.
  ///
  /// Requirements: 2.5, 8.5
  Future<ChunkedProcessingConfig> getConfigurationForFileSize(int fileSize, {String? baseName}) async {
    final configName = baseName ?? 'filesize_${_getFileSizeCategory(fileSize)}';

    try {
      // Try to load existing configuration
      var config = await loadConfiguration(name: configName);

      if (config != null) {
        // Optimize existing config for the specific file size
        config = config.optimize(targetFileSize: fileSize);
      } else {
        // Create new optimized configuration
        config = ChunkedProcessingConfig.forFileSize(fileSize);

        // Save for future use
        await saveConfiguration(config, name: configName);
      }

      return config;
    } catch (e) {
      // Fallback to creating a new configuration
      return ChunkedProcessingConfig.forFileSize(fileSize);
    }
  }

  /// List all saved configurations
  ///
  /// Requirements: 8.5
  Future<List<String>> listConfigurations() async {
    try {
      final configDir = Directory(_configDirectory);
      if (!await configDir.exists()) {
        return [];
      }

      final configFiles = await configDir.list().where((entity) => entity is File && entity.path.endsWith(_configFileName)).cast<File>().toList();

      final configNames = <String>[];
      for (final file in configFiles) {
        final fileName = path.basename(file.path);
        final configName = fileName.replaceAll('_$_configFileName', '');
        configNames.add(configName);
      }

      return configNames;
    } catch (e) {
      throw ChunkedProcessingConfigException('Failed to list configurations: $e');
    }
  }

  /// Delete a saved configuration
  ///
  /// Requirements: 8.5
  Future<bool> deleteConfiguration(String name) async {
    try {
      final configFile = File(path.join(_configDirectory, '${name}_$_configFileName'));

      if (await configFile.exists()) {
        await configFile.delete();

        // Remove from cache
        _configCache.remove(name);
        _cacheTimestamps.remove(name);

        // Update cache file
        await _updateCacheFile();

        return true;
      }

      return false;
    } catch (e) {
      throw ChunkedProcessingConfigException('Failed to delete configuration "$name": $e');
    }
  }

  /// Clear all cached configurations
  ///
  /// Requirements: 8.5
  void clearCache() {
    _configCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get cache statistics
  ///
  /// Requirements: 8.5
  ChunkedProcessingConfigCacheStats getCacheStats() {
    final now = DateTime.now();
    int expiredEntries = 0;

    for (final timestamp in _cacheTimestamps.values) {
      if (now.difference(timestamp) > _cacheExpiry) {
        expiredEntries++;
      }
    }

    return ChunkedProcessingConfigCacheStats(
      totalEntries: _configCache.length,
      expiredEntries: expiredEntries,
      cacheHitRate: 0.0, // Would be calculated based on usage statistics
      memoryUsage: _estimateCacheMemoryUsage(),
    );
  }

  /// Migrate configuration data from older versions
  ///
  /// Requirements: 2.6, 8.6
  Future<Map<String, dynamic>> _migrateConfigurationData(Map<String, dynamic> configData) async {
    final version = configData['version'] as int? ?? 0;

    if (version == _currentVersion) {
      return configData; // No migration needed
    }

    var migratedData = Map<String, dynamic>.from(configData);

    // Migration from version 0 to 1
    if (version < 1) {
      migratedData = await _migrateFromV0ToV1(migratedData);
    }

    // Future migrations would be added here
    // if (version < 2) {
    //   migratedData = await _migrateFromV1ToV2(migratedData);
    // }

    // Update version
    migratedData['version'] = _currentVersion;
    migratedData['migratedAt'] = DateTime.now().toIso8601String();

    return migratedData;
  }

  /// Migrate configuration from version 0 to version 1
  ///
  /// Requirements: 2.6, 8.6
  Future<Map<String, dynamic>> _migrateFromV0ToV1(Map<String, dynamic> configData) async {
    final config = configData['config'] as Map<String, dynamic>? ?? {};

    // Add new fields with defaults if they don't exist
    config.putIfAbsent('enableMemoryPressureDetection', () => true);
    config.putIfAbsent('memoryPressureThreshold', () => 0.8);
    config.putIfAbsent('enableAdaptiveChunkSize', () => true);
    config.putIfAbsent('minChunkSize', () => 1 * 1024 * 1024);
    config.putIfAbsent('maxChunkSize', () => 50 * 1024 * 1024);
    config.putIfAbsent('enablePlatformOptimizations', () => true);

    // Convert old field names if they exist
    if (config.containsKey('chunkSize')) {
      config['fileChunkSize'] = config.remove('chunkSize');
    }

    return {
      ...configData,
      'config': config,
      'migrationLog': ['Migrated from v0 to v1: Added new memory management fields'],
    };
  }

  /// Check if configuration is cached and not expired
  bool _isConfigCached(String name) {
    if (!_configCache.containsKey(name)) {
      return false;
    }

    final timestamp = _cacheTimestamps[name];
    if (timestamp == null) {
      return false;
    }

    return DateTime.now().difference(timestamp) <= _cacheExpiry;
  }

  /// Update the cache file with current cache state
  Future<void> _updateCacheFile() async {
    try {
      final cacheFile = File(path.join(_configDirectory, _cacheFileName));

      final cacheData = {
        'version': _currentVersion,
        'updatedAt': DateTime.now().toIso8601String(),
        'entries': _configCache.map((name, config) => MapEntry(name, {'config': config.toJson(), 'cachedAt': _cacheTimestamps[name]?.toIso8601String()})),
      };

      await cacheFile.writeAsString(const JsonEncoder.withIndent('  ').convert(cacheData));
    } catch (e) {
      // Cache file update failure is not critical, just log it
      // In a real implementation, this would use proper logging
      print('Warning: Failed to update cache file: $e');
    }
  }

  /// Get file size category for configuration naming
  String _getFileSizeCategory(int fileSize) {
    if (fileSize < 5 * 1024 * 1024) return 'small';
    if (fileSize < 50 * 1024 * 1024) return 'medium';
    if (fileSize < 500 * 1024 * 1024) return 'large';
    return 'xlarge';
  }

  /// Estimate memory usage of the configuration cache
  int _estimateCacheMemoryUsage() {
    // Rough estimation: each config takes about 1KB in memory
    return _configCache.length * 1024;
  }

  /// Get default configuration directory based on platform
  static String _getDefaultConfigDirectory() {
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          return path.join(appData, 'Sonix', 'config');
        }
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return path.join(home, 'Library', 'Application Support', 'Sonix');
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return path.join(home, '.config', 'sonix');
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, this would typically use the app's documents directory
        // This is a placeholder - in a real Flutter app, you'd use path_provider
        return path.join('app_documents', 'sonix_config');
      }

      // Fallback to current directory
      return path.join(Directory.current.path, '.sonix_config');
    } catch (e) {
      // Ultimate fallback
      return '.sonix_config';
    }
  }
}

/// Statistics about the configuration cache
class ChunkedProcessingConfigCacheStats {
  final int totalEntries;
  final int expiredEntries;
  final double cacheHitRate;
  final int memoryUsage; // in bytes

  const ChunkedProcessingConfigCacheStats({required this.totalEntries, required this.expiredEntries, required this.cacheHitRate, required this.memoryUsage});

  int get activeEntries => totalEntries - expiredEntries;

  @override
  String toString() {
    return 'ConfigCacheStats('
        'total: $totalEntries, '
        'active: $activeEntries, '
        'expired: $expiredEntries, '
        'hitRate: ${(cacheHitRate * 100).toStringAsFixed(1)}%, '
        'memory: ${(memoryUsage / 1024).toStringAsFixed(1)}KB'
        ')';
  }
}

/// Exception thrown by configuration manager operations
class ChunkedProcessingConfigException implements Exception {
  final String message;

  const ChunkedProcessingConfigException(this.message);

  @override
  String toString() => 'ChunkedProcessingConfigException: $message';
}
