#!/usr/bin/env dart

/// Test runner script for isolate waveform generation tests
///
/// This script ensures test data is generated before running the tests
/// and provides options for different test scenarios.

import 'dart:io';
import 'test_data_generator.dart';

Future<void> main(List<String> args) async {
  print('Sonix Isolate Waveform Generation Test Runner');
  print('=' * 50);

  // Parse command line arguments
  final generateAll = args.contains('--generate-all');
  final cleanFirst = args.contains('--clean');
  final skipGeneration = args.contains('--skip-generation');

  try {
    // Clean up existing files if requested
    if (cleanFirst) {
      print('Cleaning up existing test files...');
      await TestFileManager.cleanupAllGeneratedFiles();
    }

    // Generate test data unless skipped
    if (!skipGeneration) {
      if (generateAll) {
        print('Generating comprehensive test data suite...');
        await TestDataGenerator.generateAllTestData(force: true);
      } else {
        print('Generating essential test data...');
        await TestDataGenerator.generateEssentialTestData();
      }
    }

    // Validate test files
    print('Validating test files...');
    final validationReport = await TestFileManager.validateAllTestFiles();
    print('Valid files: ${validationReport['validFiles'].length}');
    print('Invalid files: ${validationReport['invalidFiles'].length}');
    print('Total size: ${TestDataGenerator.formatFileSize(validationReport['totalSize'])}');

    if (validationReport['validationErrors'].isNotEmpty) {
      print('Validation errors:');
      for (final error in validationReport['validationErrors']) {
        print('  - $error');
      }
    }

    // Generate inventory
    await TestFileManager.generateTestFileInventory();

    print('\nTest data preparation complete!');
    print('You can now run the isolate waveform generation tests:');
    print('  flutter test test/isolate_waveform_generation_test.dart');
  } catch (e, stackTrace) {
    print('Error during test preparation: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
