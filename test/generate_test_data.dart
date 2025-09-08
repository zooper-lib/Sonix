// ignore_for_file: avoid_print

import 'test_data_generator.dart';

/// Script to generate all test data files
/// Run with: dart test/generate_test_data.dart
void main() async {
  print('Generating test data for Sonix audio waveform package...');

  try {
    await TestDataGenerator.generateAllTestData();
    print('\n✅ Test data generation completed successfully!');
    print('Test assets are available in test/assets/');
  } catch (e) {
    print('\n❌ Error generating test data: $e');
  }
}
