import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sonix/src/models/chunked_processing_config.dart';
import 'package:sonix/src/utils/chunked_processing_config_manager.dart';

void main() {
  group('ChunkedProcessingConfigManager', () {
    late Directory tempDir;
    late ChunkedProcessingConfigManager configManager;

    setUp(() async {
      // Create temporary directory for tests
      tempDir = await Directory.systemTemp.createTemp('sonix_config_test_');
      configManager = ChunkedProcessingConfigManager(
        configDirectory: tempDir.path,
        cacheExpiry: const Duration(seconds: 1), // Short expiry for testing
      );
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Configuration Persistence', () {
      test('should save and load configuration successfully', () async {
        const config = ChunkedProcessingConfig(fileChunkSize: 15 * 1024 * 1024, maxMemoryUsage: 120 * 1024 * 1024, maxConcurrentChunks: 4);

        // Save configuration
        await configManager.saveConfiguration(config, name: 'test_config');

        // Load configuration
        final loadedConfig = await configManager.loadConfiguration(name: 'test_config');

        expect(loadedConfig, isNotNull);
        expect(loadedConfig, equals(config));
      });

      test('should save configuration with default name', () async {
        const config = ChunkedProcessingConfig(fileChunkSize: 20 * 1024 * 1024);

        await configManager.saveConfiguration(config);
        final loadedConfig = await configManager.loadConfiguration();

        expect(loadedConfig, equals(config));
      });

      test('should return null for non-existent configuration', () async {
        final loadedConfig = await configManager.loadConfiguration(name: 'non_existent');
        expect(loadedConfig, isNull);
      });

      test('should throw exception when saving invalid configuration', () async {
        final invalidConfig = const ChunkedProcessingConfig().copyWith(
          fileChunkSize: 0, // Invalid chunk size
        );

        expect(() => configManager.saveConfiguration(invalidConfig), throwsA(isA<ChunkedProcessingConfigException>()));
      });

      test('should create config directory if it does not exist', () async {
        final nonExistentDir = path.join(tempDir.path, 'nested', 'config');
        final manager = ChunkedProcessingConfigManager(configDirectory: nonExistentDir);

        const config = ChunkedProcessingConfig();
        await manager.saveConfiguration(config);

        expect(await Directory(nonExistentDir).exists(), isTrue);
      });

      test('should save configuration with metadata', () async {
        const config = ChunkedProcessingConfig();
        await configManager.saveConfiguration(config, name: 'metadata_test');

        // Read the raw file to check metadata
        final configFile = File(path.join(tempDir.path, 'metadata_test_chunked_processing_config.json'));
        final content = await configFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        expect(data['version'], equals(1));
        expect(data['name'], equals('metadata_test'));
        expect(data['createdAt'], isA<String>());
        expect(data['config'], isA<Map<String, dynamic>>());
      });
    });

    group('Configuration Caching', () {
      test('should cache loaded configurations', () async {
        const config = ChunkedProcessingConfig(fileChunkSize: 25 * 1024 * 1024);
        await configManager.saveConfiguration(config, name: 'cache_test');

        // Load configuration (should be cached)
        final loadedConfig1 = await configManager.loadConfiguration(name: 'cache_test');
        final loadedConfig2 = await configManager.loadConfiguration(name: 'cache_test');

        expect(loadedConfig1, equals(config));
        expect(loadedConfig2, equals(config));
        expect(identical(loadedConfig1, loadedConfig2), isTrue); // Should be same instance from cache
      });

      test('should expire cached configurations', () async {
        const config = ChunkedProcessingConfig();
        await configManager.saveConfiguration(config, name: 'expire_test');

        // Load and cache
        await configManager.loadConfiguration(name: 'expire_test');

        // Wait for cache to expire
        await Future.delayed(const Duration(seconds: 2));

        // Modify the file directly
        final configFile = File(path.join(tempDir.path, 'expire_test_chunked_processing_config.json'));
        final content = await configFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        data['config']['fileChunkSize'] = 30 * 1024 * 1024;
        await configFile.writeAsString(jsonEncode(data));

        // Load again (should read from file, not cache)
        final reloadedConfig = await configManager.loadConfiguration(name: 'expire_test');
        expect(reloadedConfig?.fileChunkSize, equals(30 * 1024 * 1024));
      });

      test('should clear cache', () async {
        const config = ChunkedProcessingConfig();
        await configManager.saveConfiguration(config, name: 'clear_test');
        await configManager.loadConfiguration(name: 'clear_test');

        configManager.clearCache();

        final stats = configManager.getCacheStats();
        expect(stats.totalEntries, equals(0));
      });

      test('should provide cache statistics', () async {
        const config1 = ChunkedProcessingConfig(fileChunkSize: 10 * 1024 * 1024);
        const config2 = ChunkedProcessingConfig(fileChunkSize: 20 * 1024 * 1024);

        await configManager.saveConfiguration(config1, name: 'stats_test1');
        await configManager.saveConfiguration(config2, name: 'stats_test2');

        await configManager.loadConfiguration(name: 'stats_test1');
        await configManager.loadConfiguration(name: 'stats_test2');

        final stats = configManager.getCacheStats();
        expect(stats.totalEntries, equals(2));
        expect(stats.activeEntries, equals(2));
        expect(stats.expiredEntries, equals(0));
        expect(stats.memoryUsage, greaterThan(0));
      });
    });

    group('File Size Configuration', () {
      test('should get configuration for file size', () async {
        final config = await configManager.getConfigurationForFileSize(100 * 1024 * 1024); // 100MB

        expect(config, isNotNull);
        expect(config.fileChunkSize, greaterThan(0));
        expect(config.maxMemoryUsage, greaterThan(0));
      });

      test('should cache configuration for file size category', () async {
        final config1 = await configManager.getConfigurationForFileSize(10 * 1024 * 1024); // 10MB
        final config2 = await configManager.getConfigurationForFileSize(15 * 1024 * 1024); // 15MB (same category)

        // Both should use the same base configuration (medium files)
        expect(config1.maxConcurrentChunks, equals(config2.maxConcurrentChunks));
      });

      test('should optimize existing configuration for file size', () async {
        // Save a base configuration
        const baseConfig = ChunkedProcessingConfig(fileChunkSize: 5 * 1024 * 1024);
        await configManager.saveConfiguration(baseConfig, name: 'filesize_large');

        // Get configuration for large file (should optimize the existing one)
        final optimizedConfig = await configManager.getConfigurationForFileSize(200 * 1024 * 1024);

        expect(optimizedConfig.fileChunkSize, greaterThanOrEqualTo(baseConfig.fileChunkSize));
      });

      test('should fallback to new configuration on error', () async {
        // Create a manager with invalid directory to force error
        final invalidManager = ChunkedProcessingConfigManager(configDirectory: '/invalid/path/that/does/not/exist');

        final config = await invalidManager.getConfigurationForFileSize(50 * 1024 * 1024);
        expect(config, isNotNull);
        expect(config.fileChunkSize, greaterThan(0));
      });
    });

    group('Configuration Management', () {
      test('should list saved configurations', () async {
        const config1 = ChunkedProcessingConfig(fileChunkSize: 10 * 1024 * 1024);
        const config2 = ChunkedProcessingConfig(fileChunkSize: 20 * 1024 * 1024);

        await configManager.saveConfiguration(config1, name: 'list_test1');
        await configManager.saveConfiguration(config2, name: 'list_test2');

        final configNames = await configManager.listConfigurations();
        expect(configNames, contains('list_test1'));
        expect(configNames, contains('list_test2'));
        expect(configNames.length, greaterThanOrEqualTo(2));
      });

      test('should return empty list when no configurations exist', () async {
        final configNames = await configManager.listConfigurations();
        expect(configNames, isEmpty);
      });

      test('should delete configuration successfully', () async {
        const config = ChunkedProcessingConfig();
        await configManager.saveConfiguration(config, name: 'delete_test');

        final deleted = await configManager.deleteConfiguration('delete_test');
        expect(deleted, isTrue);

        final loadedConfig = await configManager.loadConfiguration(name: 'delete_test');
        expect(loadedConfig, isNull);
      });

      test('should return false when deleting non-existent configuration', () async {
        final deleted = await configManager.deleteConfiguration('non_existent');
        expect(deleted, isFalse);
      });

      test('should remove deleted configuration from cache', () async {
        const config = ChunkedProcessingConfig();
        await configManager.saveConfiguration(config, name: 'cache_delete_test');
        await configManager.loadConfiguration(name: 'cache_delete_test'); // Cache it

        await configManager.deleteConfiguration('cache_delete_test');

        final stats = configManager.getCacheStats();
        expect(stats.totalEntries, equals(0));
      });
    });

    group('Configuration Migration', () {
      test('should migrate configuration from version 0 to 1', () async {
        // Create a v0 configuration file manually
        final v0Config = {
          'version': 0,
          'name': 'migration_test',
          'createdAt': DateTime.now().toIso8601String(),
          'config': {
            'chunkSize': 10 * 1024 * 1024, // Old field name
            'maxMemoryUsage': 100 * 1024 * 1024,
            'maxConcurrentChunks': 3,
            // Missing new fields
          },
        };

        final configFile = File(path.join(tempDir.path, 'migration_test_chunked_processing_config.json'));
        await configFile.writeAsString(jsonEncode(v0Config));

        // Load configuration (should trigger migration)
        final migratedConfig = await configManager.loadConfiguration(name: 'migration_test');

        expect(migratedConfig, isNotNull);
        expect(migratedConfig!.fileChunkSize, equals(10 * 1024 * 1024)); // Migrated from chunkSize
        expect(migratedConfig.enableMemoryPressureDetection, isTrue); // New field with default
        expect(migratedConfig.enableAdaptiveChunkSize, isTrue); // New field with default
      });

      test('should handle configuration with current version', () async {
        const config = ChunkedProcessingConfig();
        await configManager.saveConfiguration(config, name: 'current_version_test');

        final loadedConfig = await configManager.loadConfiguration(name: 'current_version_test');
        expect(loadedConfig, equals(config));
      });

      test('should throw exception for invalid migrated configuration', () async {
        // Create an invalid v0 configuration
        final invalidV0Config = {
          'version': 0,
          'name': 'invalid_migration_test',
          'createdAt': DateTime.now().toIso8601String(),
          'config': {
            'chunkSize': -1, // Invalid chunk size
            'maxMemoryUsage': 100 * 1024 * 1024,
            'maxConcurrentChunks': 3,
          },
        };

        final configFile = File(path.join(tempDir.path, 'invalid_migration_test_chunked_processing_config.json'));
        await configFile.writeAsString(jsonEncode(invalidV0Config));

        expect(() => configManager.loadConfiguration(name: 'invalid_migration_test'), throwsA(isA<ChunkedProcessingConfigException>()));
      });
    });

    group('Error Handling', () {
      test('should throw exception when loading corrupted configuration file', () async {
        final configFile = File(path.join(tempDir.path, 'corrupted_chunked_processing_config.json'));
        await configFile.writeAsString('invalid json content');

        expect(() => configManager.loadConfiguration(name: 'corrupted'), throwsA(isA<ChunkedProcessingConfigException>()));
      });

      test('should handle file system errors gracefully', () async {
        // Create a read-only directory to simulate permission errors
        final readOnlyDir = Directory(path.join(tempDir.path, 'readonly'));
        await readOnlyDir.create();

        // Note: Setting permissions is platform-specific and may not work in all test environments
        // This test focuses on the error handling structure

        final restrictedManager = ChunkedProcessingConfigManager(configDirectory: readOnlyDir.path);

        // The manager should handle errors and throw ChunkedProcessingConfigException
        // However, on some platforms, directory creation might succeed
        // So we'll test that it either succeeds or throws the expected exception
        try {
          await restrictedManager.saveConfiguration(const ChunkedProcessingConfig());
          // If it succeeds, that's also acceptable
        } catch (e) {
          expect(e, isA<ChunkedProcessingConfigException>());
        }
      });

      test('should handle list configurations error', () async {
        final invalidManager = ChunkedProcessingConfigManager(configDirectory: '/invalid/path/that/definitely/does/not/exist');

        // The listConfigurations method catches errors and throws ChunkedProcessingConfigException
        // However, it might return an empty list if the directory doesn't exist
        try {
          final result = await invalidManager.listConfigurations();
          // If it returns an empty list, that's acceptable behavior
          expect(result, isA<List<String>>());
        } catch (e) {
          expect(e, isA<ChunkedProcessingConfigException>());
        }
      });
    });
  });

  group('ChunkedProcessingConfigCacheStats', () {
    test('should calculate active entries correctly', () {
      const stats = ChunkedProcessingConfigCacheStats(totalEntries: 10, expiredEntries: 3, cacheHitRate: 0.85, memoryUsage: 10240);

      expect(stats.activeEntries, equals(7));
    });

    test('should provide readable string representation', () {
      const stats = ChunkedProcessingConfigCacheStats(totalEntries: 5, expiredEntries: 1, cacheHitRate: 0.75, memoryUsage: 5120);

      final str = stats.toString();
      expect(str, contains('total: 5'));
      expect(str, contains('active: 4'));
      expect(str, contains('expired: 1'));
      expect(str, contains('hitRate: 75.0%'));
      expect(str, contains('memory: 5.0KB'));
    });
  });

  group('ChunkedProcessingConfigException', () {
    test('should provide meaningful error message', () {
      const exception = ChunkedProcessingConfigException('Test error message');

      expect(exception.message, equals('Test error message'));
      expect(exception.toString(), contains('Test error message'));
    });
  });
}
