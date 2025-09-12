import 'package:sonix/sonix.dart';

/// Example demonstrating the chunked processing configuration system
///
/// This example shows how to:
/// 1. Create configurations for different file sizes
/// 2. Save and load configurations
/// 3. Use the configuration manager for persistence
/// 4. Handle configuration validation and optimization
void main() async {
  print('=== Chunked Processing Configuration Example ===\n');

  // Example 1: Create configurations for different file sizes
  await demonstrateFileSizeOptimization();

  // Example 2: Configuration persistence and management
  await demonstrateConfigurationPersistence();

  // Example 3: Configuration validation and optimization
  await demonstrateConfigurationValidation();

  // Example 4: Specialized configurations
  await demonstrateSpecializedConfigurations();
}

/// Demonstrate automatic optimization for different file sizes
Future<void> demonstrateFileSizeOptimization() async {
  print('1. File Size Optimization:');

  // Small file (2MB)
  final smallFileConfig = ChunkedProcessingConfig.forFileSize(2 * 1024 * 1024);
  print('Small file (2MB): ${_formatConfig(smallFileConfig)}');

  // Medium file (25MB)
  final mediumFileConfig = ChunkedProcessingConfig.forFileSize(25 * 1024 * 1024);
  print('Medium file (25MB): ${_formatConfig(mediumFileConfig)}');

  // Large file (200MB)
  final largeFileConfig = ChunkedProcessingConfig.forFileSize(200 * 1024 * 1024);
  print('Large file (200MB): ${_formatConfig(largeFileConfig)}');

  // Very large file (2GB)
  final veryLargeFileConfig = ChunkedProcessingConfig.forFileSize(2 * 1024 * 1024 * 1024);
  print('Very large file (2GB): ${_formatConfig(veryLargeFileConfig)}');

  print('');
}

/// Demonstrate configuration persistence and caching
Future<void> demonstrateConfigurationPersistence() async {
  print('2. Configuration Persistence:');

  // Create a configuration manager (using temp directory for example)
  final configManager = ChunkedProcessingConfigManager(configDirectory: './temp_config', cacheExpiry: const Duration(hours: 1));

  try {
    // Create and save a custom configuration
    final customConfig = const ChunkedProcessingConfig(
      fileChunkSize: 15 * 1024 * 1024, // 15MB chunks
      maxMemoryUsage: 150 * 1024 * 1024, // 150MB max memory
      maxConcurrentChunks: 4,
      enableProgressReporting: true,
    );

    print('Saving custom configuration...');
    await configManager.saveConfiguration(customConfig, name: 'my_custom_config');

    // Load the configuration back
    print('Loading configuration...');
    final loadedConfig = await configManager.loadConfiguration(name: 'my_custom_config');
    print('Loaded config: ${_formatConfig(loadedConfig!)}');

    // Get optimized configuration for a specific file size
    print('Getting optimized config for 100MB file...');
    final optimizedConfig = await configManager.getConfigurationForFileSize(100 * 1024 * 1024);
    print('Optimized config: ${_formatConfig(optimizedConfig)}');

    // List all saved configurations
    final configNames = await configManager.listConfigurations();
    print('Saved configurations: $configNames');

    // Get cache statistics
    final cacheStats = configManager.getCacheStats();
    print('Cache stats: $cacheStats');

    // Clean up
    await configManager.deleteConfiguration('my_custom_config');
    print('Configuration deleted');
  } catch (e) {
    print('Error in configuration persistence: $e');
  }

  print('');
}

/// Demonstrate configuration validation and optimization
Future<void> demonstrateConfigurationValidation() async {
  print('3. Configuration Validation:');

  // Valid configuration
  const validConfig = ChunkedProcessingConfig(fileChunkSize: 10 * 1024 * 1024, maxMemoryUsage: 100 * 1024 * 1024, maxConcurrentChunks: 3);

  final validValidation = validConfig.validate();
  print('Valid config validation: ${validValidation.isValid ? 'PASSED' : 'FAILED'}');
  if (validValidation.hasWarnings) {
    print('  Warnings: ${validValidation.warnings.join(', ')}');
  }

  // Invalid configuration
  final invalidConfig = validConfig.copyWith(
    fileChunkSize: 0, // Invalid chunk size
    maxConcurrentChunks: 0, // Invalid concurrent chunks
  );

  final invalidValidation = invalidConfig.validate();
  print('Invalid config validation: ${invalidValidation.isValid ? 'PASSED' : 'FAILED'}');
  if (invalidValidation.hasErrors) {
    print('  Errors: ${invalidValidation.errors.join(', ')}');
  }

  // Optimize configuration
  final optimizedConfig = validConfig.optimize(
    targetFileSize: 500 * 1024 * 1024, // 500MB file
    availableMemory: 1024 * 1024 * 1024, // 1GB available
    isLowMemoryDevice: false,
  );
  print('Original config: ${_formatConfig(validConfig)}');
  print('Optimized config: ${_formatConfig(optimizedConfig)}');

  print('');
}

/// Demonstrate specialized configurations
Future<void> demonstrateSpecializedConfigurations() async {
  print('4. Specialized Configurations:');

  // Low memory device configuration
  final lowMemoryConfig = ChunkedProcessingConfig.forLowMemoryDevice(
    fileSize: 50 * 1024 * 1024, // 50MB file
  );
  print('Low memory device: ${_formatConfig(lowMemoryConfig)}');

  // High performance device configuration
  final highPerfConfig = ChunkedProcessingConfig.forHighPerformanceDevice(
    fileSize: 500 * 1024 * 1024, // 500MB file
  );
  print('High performance device: ${_formatConfig(highPerfConfig)}');

  // JSON serialization
  final jsonData = lowMemoryConfig.toJson();
  print('JSON serialization: ${jsonData.keys.join(', ')}');

  final deserializedConfig = ChunkedProcessingConfig.fromJson(jsonData);
  print('Deserialized matches original: ${deserializedConfig == lowMemoryConfig}');

  print('');
}

/// Format configuration for display
String _formatConfig(ChunkedProcessingConfig config) {
  return 'ChunkSize: ${_formatBytes(config.fileChunkSize)}, '
      'MaxMemory: ${_formatBytes(config.maxMemoryUsage)}, '
      'Concurrent: ${config.maxConcurrentChunks}, '
      'Seeking: ${config.enableSeeking}, '
      'Progress: ${config.enableProgressReporting}';
}

/// Format bytes for human-readable display
String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  } else if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  } else if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  } else {
    return '${bytes}B';
  }
}
