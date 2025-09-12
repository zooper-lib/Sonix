// ignore_for_file: avoid_print

import 'dart:io';
import '../test_data_generator.dart';

/// Utility for managing test file cache and generation
///
/// This helps optimize test performance by managing when test files
/// are generated and cached.
class TestFileCacheManager {
  static const String cacheInfoFile = 'test/assets/.cache_info.json';

  /// Checks if test files need regeneration based on cache info
  static Future<bool> needsRegeneration() async {
    final cacheFile = File(cacheInfoFile);

    if (!await cacheFile.exists()) {
      return true;
    }

    // Check if essential files exist
    try {
      await TestDataGenerator.generateEssentialTestData();
      return false; // If generation succeeds without doing work, files exist
    } catch (e) {
      return true; // If there's an error, assume we need regeneration
    }

    // Check cache age (regenerate if older than 7 days)
    final cacheStats = await cacheFile.stat();
    final age = DateTime.now().difference(cacheStats.modified);

    return age.inDays > 7;
  }

  /// Generates test files only if needed
  static Future<void> ensureTestFiles({bool force = false}) async {
    if (force || await needsRegeneration()) {
      print('🔄 Generating/updating test files...');
      await TestDataGenerator.generateEssentialTestData(force: force);
      await _updateCacheInfo();
      print('✅ Test files ready');
    } else {
      print('✅ Test files already cached and up to date');
    }
  }

  /// Cleans up test files to save space
  static Future<void> cleanupTestFiles() async {
    print('🧹 Cleaning up test files...');

    await TestFileManager.cleanupLargeFiles();

    // Remove cache info to force regeneration next time
    final cacheFile = File(cacheInfoFile);
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }

    print('✅ Test files cleaned up');
  }

  /// Forces regeneration of all test files
  static Future<void> regenerateTestFiles() async {
    print('🔄 Forcing regeneration of all test files...');

    // Clean up first
    await TestFileManager.cleanupAllGeneratedFiles();

    // Generate fresh files
    await TestDataGenerator.generateEssentialTestData(force: true);
    await _updateCacheInfo();

    print('✅ Test files regenerated');
  }

  /// Shows test file cache status
  static Future<void> showCacheStatus() async {
    print('📊 Test File Cache Status');
    print('========================');

    final cacheFile = File(cacheInfoFile);
    if (await cacheFile.exists()) {
      final cacheStats = await cacheFile.stat();
      final age = DateTime.now().difference(cacheStats.modified);

      print('Cache file: ${cacheFile.path}');
      print('Last updated: ${cacheStats.modified}');
      print('Age: ${age.inDays} days, ${age.inHours % 24} hours');
    } else {
      print('No cache file found');
    }

    // Check essential files by trying to load test configurations
    final hasEssential = await TestDataLoader.assetExists('test_configurations.json');
    print('Essential files: ${hasEssential ? "✅ Present" : "❌ Missing"}');

    // Check file counts
    final filesByFormat = <String, int>{};
    for (final format in TestDataGenerator.supportedFormats) {
      final files = await TestDataLoader.getTestFilesForFormat(format);
      filesByFormat[format] = files.length;
    }

    print('Files by format:');
    for (final entry in filesByFormat.entries) {
      print('  ${entry.key}: ${entry.value} files');
    }

    // Calculate total size
    int totalSize = 0;
    final assetsDir = Directory(TestDataLoader.assetsPath);
    if (await assetsDir.exists()) {
      await for (final entity in assetsDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }

    print('Total cache size: ${TestDataGenerator.formatFileSize(totalSize)}');

    final needsRegen = await needsRegeneration();
    print('Status: ${needsRegen ? "❌ Needs regeneration" : "✅ Up to date"}');
  }

  /// Updates cache info file
  static Future<void> _updateCacheInfo() async {
    final cacheFile = File(cacheInfoFile);
    await cacheFile.parent.create(recursive: true);

    final cacheInfo = {'generated_at': DateTime.now().toIso8601String(), 'version': '1.0', 'type': 'essential'};

    await cacheFile.writeAsString(cacheInfo.toString());
  }
}

/// Command-line utility for managing test files
void main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    return;
  }

  final command = args[0].toLowerCase();

  try {
    switch (command) {
      case 'status':
        await TestFileCacheManager.showCacheStatus();
        break;

      case 'ensure':
        await TestFileCacheManager.ensureTestFiles();
        break;

      case 'clean':
        await TestFileCacheManager.cleanupTestFiles();
        break;

      case 'regenerate':
        await TestFileCacheManager.regenerateTestFiles();
        break;

      case 'force':
        await TestFileCacheManager.ensureTestFiles(force: true);
        break;

      default:
        print('❌ Unknown command: $command');
        _printUsage();
        exit(1);
    }
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

void _printUsage() {
  print('Test File Cache Manager');
  print('======================');
  print('');
  print('Usage: dart test/utils/test_file_cache_manager.dart <command>');
  print('');
  print('Commands:');
  print('  status     - Show cache status and file counts');
  print('  ensure     - Generate test files only if needed');
  print('  clean      - Clean up large test files');
  print('  regenerate - Force regeneration of all test files');
  print('  force      - Force generation even if files exist');
  print('');
  print('Examples:');
  print('  dart test/utils/test_file_cache_manager.dart status');
  print('  dart test/utils/test_file_cache_manager.dart ensure');
  print('  dart test/utils/test_file_cache_manager.dart clean');
}
