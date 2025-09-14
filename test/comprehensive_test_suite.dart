// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'test_data_generator.dart';

/// Comprehensive test suite for chunked audio processing
///
/// This test suite generates and validates test files of various sizes
/// and characteristics for thorough testing of the chunked processing system.
void main() {
  group('Comprehensive Test File Suite', () {
    setUpAll(() async {
      print('Setting up comprehensive test file suite...');

      // Generate essential test data (only if not already present)
      await TestDataGenerator.generateEssentialTestData();

      // Generate test file inventory
      await TestFileManager.generateTestFileInventory();

      print('Test file suite setup complete');
    });

    tearDownAll(() async {
      // Cleanup large files after tests to save disk space
      if (Platform.environment['CLEANUP_LARGE_FILES'] == 'true') {
        await TestFileManager.cleanupLargeFiles();
      }
    });

    group('Test File Generation', () {
      test('should generate files of all supported formats', () async {
        for (final format in TestDataGenerator.supportedFormats) {
          final files = await TestDataLoader.getTestFilesForFormat(format);
          expect(files, isNotEmpty, reason: 'No test files found for format: $format');

          print('Generated ${files.length} test files for format: $format');
        }
      });

      test('should generate files of various sizes', () async {
        final filesBySize = await TestDataLoader.getTestFilesBySize();

        for (final sizeEntry in TestDataGenerator.fileSizes.entries) {
          final sizeName = sizeEntry.key;
          final files = filesBySize[sizeName] ?? [];

          // Skip massive and huge files when they weren't generated
          if ((sizeName == 'massive' || sizeName == 'huge') && files.isEmpty) {
            print('Skipping validation for $sizeName files (not generated)');
            continue;
          }

          expect(files, isNotEmpty, reason: 'No test files found for size category: $sizeName');
          print('Generated ${files.length} files for size category: $sizeName');
        }
      });

      test('should generate files with various audio characteristics', () async {
        // Check that files with different sample rates and channels exist
        final allFiles = <String>[];
        for (final format in TestDataGenerator.supportedFormats) {
          final files = await TestDataLoader.getTestFilesForFormat(format);
          allFiles.addAll(files);
        }

        // Verify we have files with different characteristics
        final hasMono = allFiles.any((f) => f.contains('_1ch'));
        final hasStereo = allFiles.any((f) => f.contains('_2ch'));
        final hasMultiChannel = allFiles.any((f) => f.contains('_6ch'));
        final hasLowSampleRate = allFiles.any((f) => f.contains('_8000_'));
        final hasHighSampleRate = allFiles.any((f) => f.contains('_96000_'));

        expect(hasMono, isTrue, reason: 'No mono test files found');
        expect(hasStereo, isTrue, reason: 'No stereo test files found');
        expect(hasMultiChannel, isTrue, reason: 'No multi-channel test files found');
        expect(hasLowSampleRate, isTrue, reason: 'No low sample rate test files found');
        expect(hasHighSampleRate, isTrue, reason: 'No high sample rate test files found');
      });

      test('should generate corrupted files for error testing', () async {
        final corruptedFiles = await TestDataLoader.getCorruptedTestFiles();
        expect(corruptedFiles, isNotEmpty, reason: 'No corrupted test files found');

        // Verify we have corrupted files for each format
        for (final format in TestDataGenerator.supportedFormats) {
          final formatCorrupted = corruptedFiles.where((f) => f.endsWith('.$format')).toList();
          expect(formatCorrupted, isNotEmpty, reason: 'No corrupted files for format: $format');
        }

        print('Generated ${corruptedFiles.length} corrupted test files');
      });
    });

    group('Test File Validation', () {
      test('should validate all generated test files', () async {
        final validationReport = await TestFileManager.validateAllTestFiles();

        expect(validationReport['validationErrors'], isEmpty, reason: 'Validation errors: ${validationReport['validationErrors']}');

        final validFiles = validationReport['validFiles'] as List;
        final invalidFiles = validationReport['invalidFiles'] as List;

        expect(validFiles, isNotEmpty, reason: 'No valid test files found');

        print('Validation report:');
        print('  Valid files: ${validFiles.length}');
        print('  Invalid files: ${invalidFiles.length}');
        print('  Total size: ${TestDataGenerator.formatFileSize(validationReport['totalSize'])}');
      });

      test('should extract metadata from test files', () async {
        // Test metadata extraction for each format
        for (final format in TestDataGenerator.supportedFormats) {
          final files = await TestDataLoader.getTestFilesForFormat(format);

          if (files.isNotEmpty) {
            final testFile = files.first;
            final filePath = TestDataLoader.getAssetPath(testFile);

            final metadata = await TestFileValidator.validateAndExtractMetadata(filePath);

            expect(metadata.format, equals(format));
            expect(metadata.size, greaterThan(0));
            expect(metadata.checksum, isNotEmpty);
            expect(metadata.metadata, isNotEmpty);

            print('Extracted metadata for $testFile: ${metadata.metadata}');
          }
        }
      });

      test('should detect corrupted files correctly', () async {
        final corruptedFiles = await TestDataLoader.getCorruptedTestFiles();

        for (final corruptedFile in corruptedFiles.take(5)) {
          // Test first 5 to avoid long test times
          final filePath = TestDataLoader.getAssetPath(corruptedFile);

          if (await File(filePath).exists()) {
            final metadata = await TestFileValidator.validateAndExtractMetadata(filePath);

            // Most corrupted files should be detected as invalid
            // (Some might still pass basic header validation but fail in processing)
            if (corruptedFile.contains('corrupted_') || corruptedFile.contains('invalid_')) {
              expect(metadata.isValid, isFalse, reason: 'Corrupted file $corruptedFile was not detected as invalid');
            }
          }
        }
      });
    });

    group('File Size Verification', () {
      test('should generate files close to target sizes', () async {
        final filesBySize = await TestDataLoader.getTestFilesBySize();

        for (final sizeEntry in TestDataGenerator.fileSizes.entries) {
          final sizeName = sizeEntry.key;
          final targetSize = sizeEntry.value;
          final files = filesBySize[sizeName] ?? [];

          // Skip massive and huge files when they weren't generated
          if ((sizeName == 'massive' || sizeName == 'huge') && files.isEmpty) {
            print('Skipping size verification for $sizeName files (not generated)');
            continue;
          }

          if (files.isNotEmpty) {
            final testFile = files.first;
            final actualSize = await TestDataLoader.getAssetSize(testFile);

            // Allow 10% variance from target size
            final tolerance = targetSize * 0.1;
            final sizeDiff = (actualSize - targetSize).abs();

            expect(sizeDiff, lessThanOrEqualTo(tolerance), reason: 'File $testFile size $actualSize is too far from target $targetSize');

            print(
              'Size verification for $sizeName: target=${TestDataGenerator.formatFileSize(targetSize)}, '
              'actual=${TestDataGenerator.formatFileSize(actualSize)}',
            );
          }
        }
      });

      test('should have appropriate file size distribution', () async {
        final filesBySize = await TestDataLoader.getTestFilesBySize();

        // Verify we have files across the size spectrum
        final hasSmallFiles = filesBySize['tiny']?.isNotEmpty == true || filesBySize['small']?.isNotEmpty == true;
        final hasMediumFiles = filesBySize['medium']?.isNotEmpty == true;
        final hasLargeFiles = filesBySize['large']?.isNotEmpty == true || filesBySize['xlarge']?.isNotEmpty == true;

        expect(hasSmallFiles, isTrue, reason: 'No small test files found');
        expect(hasMediumFiles, isTrue, reason: 'No medium test files found');
        expect(hasLargeFiles, isTrue, reason: 'No large test files found');
      });
    });

    group('Test File Inventory', () {
      test('should generate comprehensive inventory', () async {
        final inventoryFile = File('${TestDataLoader.assetsPath}/test_file_inventory.json');
        expect(await inventoryFile.exists(), isTrue, reason: 'Test file inventory not generated');

        final inventoryContent = await inventoryFile.readAsString();
        expect(inventoryContent, isNotEmpty);

        print('Test file inventory generated at: ${inventoryFile.path}');
      });

      test('should track all generated files', () async {
        // Verify that the inventory includes all expected file categories
        final filesBySize = await TestDataLoader.getTestFilesBySize();
        final corruptedFiles = await TestDataLoader.getCorruptedTestFiles();

        int totalFiles = 0;
        for (final files in filesBySize.values) {
          totalFiles += files.length;
        }
        totalFiles += corruptedFiles.length;

        expect(totalFiles, greaterThan(0), reason: 'No test files tracked in inventory');
        print('Total test files in inventory: $totalFiles');
      });
    });

    group('Performance Baseline', () {
      test('should establish file generation performance baseline', () async {
        final stopwatch = Stopwatch()..start();

        // Generate a small test file to measure performance
        await TestDataGenerator.generateWavFileWithSize(
          '${TestDataLoader.assetsPath}/perf_baseline.wav',
          1024 * 1024, // 1MB
          44100,
          2,
          16,
        );

        stopwatch.stop();

        final generationTime = stopwatch.elapsedMilliseconds;
        expect(
          generationTime,
          lessThan(5000), // Should take less than 5 seconds
          reason: 'File generation took too long: ${generationTime}ms',
        );

        print('File generation baseline: ${generationTime}ms for 1MB WAV file');

        // Cleanup
        await File('${TestDataLoader.assetsPath}/perf_baseline.wav').delete();
      });

      test('should establish validation performance baseline', () async {
        final files = await TestDataLoader.getTestFilesForFormat('wav');

        if (files.isNotEmpty) {
          final testFile = files.first;
          final filePath = TestDataLoader.getAssetPath(testFile);

          final stopwatch = Stopwatch()..start();
          await TestFileValidator.validateAndExtractMetadata(filePath);
          stopwatch.stop();

          final validationTime = stopwatch.elapsedMilliseconds;
          expect(
            validationTime,
            lessThan(1000), // Should take less than 1 second
            reason: 'File validation took too long: ${validationTime}ms',
          );

          print('File validation baseline: ${validationTime}ms for $testFile');
        }
      });
    });
  });
}
