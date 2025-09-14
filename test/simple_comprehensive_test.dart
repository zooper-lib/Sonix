// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'test_data_generator.dart';

/// Simple comprehensive test to verify basic functionality
void main() {
  group('Simple Comprehensive Test', () {
    test('should generate basic test files', () async {
      print('Generating basic test files...');

      // Generate only essential files for faster testing
      await TestDataGenerator.generateEssentialTestData();

      // Verify some files were created
      final assetsDir = Directory(TestDataGenerator.assetsPath);
      expect(await assetsDir.exists(), isTrue);

      final files = await assetsDir.list().toList();
      expect(files.length, greaterThan(0));

      print('Generated ${files.length} test files successfully');
    });

    test('should validate test file metadata extraction', () async {
      // Test with a simple WAV file
      final testFile = '${TestDataGenerator.assetsPath}/test_mono_44100.wav';

      if (await File(testFile).exists()) {
        final metadata = await TestFileValidator.validateAndExtractMetadata(testFile);

        expect(metadata.format, equals('wav'));
        expect(metadata.size, greaterThan(0));
        expect(metadata.checksum, isNotEmpty);

        print('Metadata extraction successful for WAV file');
      } else {
        print('Test WAV file not found, skipping metadata test');
      }
    });

    test('should handle file size formatting', () {
      expect(TestDataGenerator.formatFileSize(1024), equals('1.0KB'));
      expect(TestDataGenerator.formatFileSize(1024 * 1024), equals('1.0MB'));
      expect(TestDataGenerator.formatFileSize(1024 * 1024 * 1024), equals('1.0GB'));

      print('File size formatting works correctly');
    });

    test('should list test files by format', () async {
      final wavFiles = await TestDataLoader.getTestFilesForFormat('wav');
      final mp3Files = await TestDataLoader.getTestFilesForFormat('mp3');

      print('Found ${wavFiles.length} WAV files');
      print('Found ${mp3Files.length} MP3 files');

      // Should have at least some files
      expect(wavFiles.length + mp3Files.length, greaterThan(0));
    });
  });
}
