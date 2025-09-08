// ignore_for_file: avoid_print

import 'dart:io';
import 'test_data_generator.dart';

/// Script to run all comprehensive tests for the Sonix package
///
/// This script:
/// 1. Generates test data if needed
/// 2. Runs all test suites
/// 3. Provides detailed reporting
///
/// Usage:
/// - Run all tests: dart test/run_all_tests.dart
/// - Run specific category: dart test/run_all_tests.dart --category=audio_decoding
/// - Run with coverage: dart test/run_all_tests.dart --coverage
void main(List<String> args) async {
  print('🧪 Sonix Comprehensive Test Runner');
  print('==================================\n');

  // Parse command line arguments
  final category = _getArgValue(args, '--category');
  final coverage = args.contains('--coverage');
  final verbose = args.contains('--verbose');

  try {
    // Step 1: Ensure test data exists
    print('📁 Checking test data...');
    if (!await TestDataLoader.assetExists('test_configurations.json')) {
      print('   Generating test data...');
      await TestDataGenerator.generateAllTestData();
      print('   ✅ Test data generated successfully');
    } else {
      print('   ✅ Test data already exists');
    }

    // Step 2: Run tests based on category
    if (category != null) {
      await _runCategoryTests(category, coverage, verbose);
    } else {
      await _runAllTests(coverage, verbose);
    }
  } catch (e) {
    print('❌ Error running tests: $e');
    exit(1);
  }
}

/// Run all test categories
Future<void> _runAllTests(bool coverage, bool verbose) async {
  print('\n🚀 Running all test categories...\n');

  final categories = [
    'audio_decoding',
    'waveform_generation',
    'memory_management',
    'error_handling',
    'performance_benchmark',
    'waveform_algorithms',
    'sonix_api',
  ];

  var totalPassed = 0;
  var totalFailed = 0;

  for (final category in categories) {
    final result = await _runCategoryTests(category, coverage, verbose);
    totalPassed += result.passed;
    totalFailed += result.failed;
  }

  // Final summary
  print('\n📊 Final Test Summary');
  print('====================');
  print('Total Passed: $totalPassed');
  print('Total Failed: $totalFailed');
  print('Success Rate: ${(totalPassed / (totalPassed + totalFailed) * 100).toStringAsFixed(1)}%');

  if (totalFailed > 0) {
    print('\n❌ Some tests failed. Please review the output above.');
    exit(1);
  } else {
    print('\n✅ All tests passed successfully!');
  }
}

/// Run tests for a specific category
Future<TestResult> _runCategoryTests(String category, bool coverage, bool verbose) async {
  print('🧪 Running $category tests...');

  final testFile = 'test/${category}_test.dart';

  // Check if test file exists
  if (!await File(testFile).exists()) {
    print('   ⚠️  Test file not found: $testFile');
    return TestResult(0, 1);
  }

  // Build flutter test command
  final command = ['flutter', 'test'];

  if (coverage) {
    command.addAll(['--coverage']);
  }

  if (verbose) {
    command.add('--verbose');
  }

  command.add(testFile);

  // Run the test
  final process = await Process.run(command.first, command.skip(1).toList(), workingDirectory: Directory.current.path);

  // Parse results
  final output = process.stdout as String;
  final errorOutput = process.stderr as String;

  if (verbose) {
    print('   Output: $output');
    if (errorOutput.isNotEmpty) {
      print('   Errors: $errorOutput');
    }
  }

  // Simple result parsing (this could be more sophisticated)
  final passedMatch = RegExp(r'(\d+) passed').firstMatch(output);
  final failedMatch = RegExp(r'(\d+) failed').firstMatch(output);

  final passed = passedMatch != null ? int.parse(passedMatch.group(1)!) : 0;
  final failed = failedMatch != null ? int.parse(failedMatch.group(1)!) : 0;

  if (process.exitCode == 0) {
    print('   ✅ $category tests completed successfully');
    if (passed > 0) print('      Passed: $passed tests');
  } else {
    print('   ❌ $category tests failed');
    if (failed > 0) print('      Failed: $failed tests');
    if (errorOutput.isNotEmpty) {
      print('      Error: $errorOutput');
    }
  }

  return TestResult(passed, failed);
}

/// Get command line argument value
String? _getArgValue(List<String> args, String argName) {
  for (final arg in args) {
    if (arg.startsWith('$argName=')) {
      return arg.split('=')[1];
    }
  }
  return null;
}

/// Test result data class
class TestResult {
  final int passed;
  final int failed;

  TestResult(this.passed, this.failed);
}
