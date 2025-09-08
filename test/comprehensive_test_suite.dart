import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'audio_decoding_test.dart' as audio_decoding_tests;
import 'waveform_generation_test.dart' as waveform_generation_tests;
import 'memory_management_test.dart' as memory_management_tests;
import 'error_handling_test.dart' as error_handling_tests;
import 'performance_benchmark_test.dart' as performance_benchmark_tests;
import 'waveform_algorithms_test.dart' as waveform_algorithms_tests;
import 'sonix_api_test.dart' as sonix_api_tests;

/// Comprehensive test suite that runs all tests for the Sonix package
///
/// This test suite covers:
/// - Audio decoding accuracy for all supported formats
/// - Waveform generation algorithms and accuracy
/// - Memory management and resource disposal
/// - Error handling scenarios
/// - Performance benchmarks
/// - API functionality
///
/// Run with: flutter test test/comprehensive_test_suite.dart
void main() {
  group('Sonix Comprehensive Test Suite', () {
    group('Audio Decoding Tests', () {
      audio_decoding_tests.main();
    });

    group('Waveform Generation Tests', () {
      waveform_generation_tests.main();
    });

    group('Memory Management Tests', () {
      memory_management_tests.main();
    });

    group('Error Handling Tests', () {
      error_handling_tests.main();
    });

    group('Performance Benchmark Tests', () {
      performance_benchmark_tests.main();
    });

    group('Waveform Algorithms Tests', () {
      waveform_algorithms_tests.main();
    });

    group('Sonix API Tests', () {
      sonix_api_tests.main();
    });
  });
}
