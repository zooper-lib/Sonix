// ignore_for_file: avoid_print

import 'dart:io';
import 'package:test/test.dart';
import 'package:archive/archive.dart';
import '../../tools/ffmpeg_binary_validator.dart';
import '../../tools/ffmpeg_binary_installer.dart';
import '../../tools/ffmpeg_binary_downloader.dart';

void main() {
  group('FFMPEG Binary Download System', () {
    late FFMPEGBinaryValidator validator;
    late FFMPEGBinaryInstaller installer;
    late FFMPEGBinaryDownloader downloader;
    late Directory tempDir;

    setUp(() async {
      validator = FFMPEGBinaryValidator();
      installer = FFMPEGBinaryInstaller();
      downloader = FFMPEGBinaryDownloader();

      // Create temporary directory for tests
      tempDir = await Directory.systemTemp.createTemp('ffmpeg_test_');
    });

    tearDown(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Platform Detection', () {
      test('should detect current platform correctly', () {
        final platformInfo = PlatformInfo.detect();

        expect(platformInfo.platform, isIn(['windows', 'macos', 'linux']));
        expect(platformInfo.architecture, isNotEmpty);
        expect(platformInfo.expectedLibraryExtensions, isNotEmpty);
        expect(platformInfo.librarySearchPaths, isNotEmpty);
      });

      test('should return correct library names for platform', () {
        final platformInfo = PlatformInfo.detect();
        final libraryNames = platformInfo.getExpectedLibraryNames();

        expect(libraryNames, isNotEmpty);
        expect(libraryNames.length, equals(4)); // avformat, avcodec, avutil, swresample

        switch (platformInfo.platform) {
          case 'windows':
            expect(libraryNames.every((name) => name.endsWith('.dll')), isTrue);
            break;
          case 'macos':
            expect(libraryNames.every((name) => name.endsWith('.dylib')), isTrue);
            break;
          case 'linux':
            expect(libraryNames.every((name) => name.endsWith('.so')), isTrue);
            break;
        }
      });
    });

    group('Binary Validator', () {
      test('should return required FFMPEG symbols', () async {
        final symbols = await validator.getRequiredSymbols();

        expect(symbols, isNotEmpty);
        expect(symbols, contains('avformat_open_input'));
        expect(symbols, contains('avcodec_find_decoder'));
        expect(symbols, contains('swr_alloc'));
      });

      test('should validate non-existent binary as invalid', () async {
        final result = await validator.validateBinary('non_existent_file.dll');

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('does not exist'));
      });

      test('should handle validation errors gracefully', () async {
        // Create an empty file to test validation
        final tempFile = File('${tempDir.path}/test_empty_binary.tmp');
        await tempFile.writeAsBytes([]);

        final result = await validator.validateBinary(tempFile.path);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('empty'));
      });
    });

    group('Binary Installer', () {
      test('should identify Flutter build directories correctly', () async {
        final platformInfo = PlatformInfo.detect();
        final status = await installer.getInstallationStatus();

        expect(status.keys, isNotEmpty);

        switch (platformInfo.platform) {
          case 'windows':
            expect(status.keys.any((dir) => dir.contains('windows')), isTrue);
            break;
          case 'macos':
            expect(status.keys.any((dir) => dir.contains('macos')), isTrue);
            break;
          case 'linux':
            expect(status.keys.any((dir) => dir.contains('linux')), isTrue);
            break;
        }
      });

      test('should get installation status without errors', () async {
        final status = await installer.getInstallationStatus();

        expect(status, isA<Map<String, Map<String, bool>>>());
        expect(status.keys, isNotEmpty);

        // Should include test directory
        expect(status.keys.any((key) => key.contains('test')), isTrue);
      });

      test('should copy binaries between directories', () async {
        final platformInfo = PlatformInfo.detect();
        final sourceDir = Directory('${tempDir.path}/source');
        final targetDir = Directory('${tempDir.path}/target');

        await sourceDir.create();
        await targetDir.create();

        // Create mock binary files
        final libraryNames = platformInfo.getExpectedLibraryNames();
        for (final libraryName in libraryNames) {
          final mockFile = File('${sourceDir.path}/$libraryName');
          await mockFile.writeAsString('mock binary content for $libraryName');
        }

        // Test copying
        final result = await installer.copyBinaries(sourceDir.path, targetDir.path);

        expect(result.success, isTrue);
        expect(result.installedFiles.length, equals(libraryNames.length));

        // Verify files were copied
        for (final libraryName in libraryNames) {
          final copiedFile = File('${targetDir.path}/$libraryName');
          expect(await copiedFile.exists(), isTrue);
          final content = await copiedFile.readAsString();
          expect(content, contains('mock binary content for $libraryName'));
        }
      });
    });

    group('Binary Downloader Configuration', () {
      test('should get binary configurations for all platforms', () {
        final configs = FFMPEGBinaryDownloader.getAllConfigurations();

        expect(configs, hasLength(3));
        expect(configs.keys, containsAll(['windows', 'macos', 'linux']));

        for (final config in configs.values) {
          expect(config.platform, isNotEmpty);
          expect(config.architecture, isNotEmpty);
          expect(config.version, isNotEmpty);
          expect(config.archiveUrl, isNotEmpty);
          expect(config.libraryPaths, isNotEmpty);
          expect(config.requiredSymbols, isNotEmpty);
        }
      });

      test('should have valid URLs in configurations', () {
        final configs = FFMPEGBinaryDownloader.getAllConfigurations();

        for (final config in configs.values) {
          final uri = Uri.tryParse(config.archiveUrl);
          expect(uri, isNotNull);
          expect(uri!.scheme, isIn(['http', 'https']));
        }
      });
    });

    group('Archive Handling', () {
      test('should create and extract ZIP archive correctly', () async {
        // Create a test ZIP archive with mock files
        final archive = Archive();

        final platformInfo = PlatformInfo.detect();
        final libraryNames = platformInfo.getExpectedLibraryNames();

        // Add mock library files to archive
        for (final libraryName in libraryNames) {
          final fileContent = 'Mock content for $libraryName';
          final archiveFile = ArchiveFile('bin/$libraryName', fileContent.length, fileContent.codeUnits);
          archive.addFile(archiveFile);
        }

        // Encode archive to bytes
        final zipBytes = ZipEncoder().encode(archive);
        expect(zipBytes, isNotNull);

        // Test extraction (simulate what the downloader does)
        final extractedArchive = ZipDecoder().decodeBytes(zipBytes!);
        expect(extractedArchive.files.length, equals(libraryNames.length));

        // Verify each file can be found and extracted
        for (final libraryName in libraryNames) {
          final file = extractedArchive.files.firstWhere((f) => f.name.endsWith(libraryName));
          expect(file.isFile, isTrue);
          expect(file.content, isNotNull);
        }
      });

      test('should handle checksum verification', () async {
        // Create a test file with known content
        final testFile = File('${tempDir.path}/test_checksum.tmp');
        await testFile.writeAsString('test content for checksum');

        // Test verification - we can only test the public interface
        final isInvalid = await downloader.verifyBinaryIntegrity(testFile.path, 'wrong_checksum');
        expect(isInvalid, isFalse); // Should be false since checksum is definitely wrong
      });
    });

    group('Integration Tests', () {
      test('should handle complete workflow without actual download', () async {
        // Test the workflow without actually downloading files
        final platformInfo = PlatformInfo.detect();

        // Check platform detection
        expect(platformInfo.platform, isNotEmpty);

        // Check configuration availability
        final configs = FFMPEGBinaryDownloader.getAllConfigurations();
        expect(configs[platformInfo.platform], isNotNull);

        // Check installation status (should work even without binaries)
        final status = await installer.getInstallationStatus();
        expect(status, isNotNull);

        print('Platform: ${platformInfo.platform}');
        print('Expected libraries: ${platformInfo.getExpectedLibraryNames()}');
        print('Installation status keys: ${status.keys.toList()}');

        final config = configs[platformInfo.platform]!;
        print('Archive URL: ${config.archiveUrl}');
        print('Library paths: ${config.libraryPaths}');
      });

      test('should simulate download and extraction workflow', () async {
        // Create a mock archive that simulates what we'd download
        final platformInfo = PlatformInfo.detect();
        final libraryNames = platformInfo.getExpectedLibraryNames();

        // Create mock archive
        final archive = Archive();
        for (final libraryName in libraryNames) {
          final content = 'Mock FFMPEG library: $libraryName\n' * 100; // Make it somewhat realistic in size
          final archiveFile = ArchiveFile('bin/$libraryName', content.length, content.codeUnits);
          archive.addFile(archiveFile);
        }

        final zipBytes = ZipEncoder().encode(archive)!;

        // Simulate extraction process
        final extractedArchive = ZipDecoder().decodeBytes(zipBytes);
        final extractDir = Directory('${tempDir.path}/extracted');
        await extractDir.create();

        // Extract files
        final extractedFiles = <String>[];
        for (final libraryName in libraryNames) {
          final archiveFile = extractedArchive.files.firstWhere((f) => f.name.endsWith(libraryName));

          final outputFile = File('${extractDir.path}/$libraryName');
          await outputFile.writeAsBytes(archiveFile.content as List<int>);
          extractedFiles.add(libraryName);
        }

        expect(extractedFiles.length, equals(libraryNames.length));

        // Verify extracted files exist and have content
        for (final libraryName in libraryNames) {
          final file = File('${extractDir.path}/$libraryName');
          expect(await file.exists(), isTrue);
          final stat = await file.stat();
          expect(stat.size, greaterThan(0));
        }

        print('Successfully simulated extraction of ${extractedFiles.length} files');
      });
    });
  });
}
