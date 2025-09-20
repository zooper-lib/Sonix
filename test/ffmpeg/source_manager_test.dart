import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import '../../tools/ffmpeg/source_manager.dart';

void main() {
  group('FFMPEGSourceManager', () {
    late Directory tempDir;
    late FFMPEGSourceManager sourceManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ffmpeg_test_');
      sourceManager = FFMPEGSourceManager(workingDirectory: tempDir.path, version: '6.1');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create working directory', () async {
      expect(await Directory(tempDir.path).exists(), isTrue);
    });

    test('should detect when source needs update for non-existent directory', () async {
      final sourceDir = path.join(tempDir.path, 'ffmpeg-6.1');
      final needsUpdate = await sourceManager.needsUpdate(sourceDir);
      expect(needsUpdate, isTrue);
    });

    test('should validate source structure with mock files', () async {
      final sourceDir = path.join(tempDir.path, 'ffmpeg-6.1');
      await Directory(sourceDir).create(recursive: true);

      // Create mock required files/directories
      await File(path.join(sourceDir, 'configure')).create();
      await File(path.join(sourceDir, 'Makefile')).create();
      await Directory(path.join(sourceDir, 'libavcodec')).create();
      await Directory(path.join(sourceDir, 'libavformat')).create();
      await Directory(path.join(sourceDir, 'libavutil')).create();
      await Directory(path.join(sourceDir, 'libswresample')).create();

      final isValid = await sourceManager.validateSourceStructure(sourceDir);
      expect(isValid, isTrue);
    });

    test('should fail validation for incomplete source structure', () async {
      final sourceDir = path.join(tempDir.path, 'ffmpeg-6.1');
      await Directory(sourceDir).create(recursive: true);

      // Create only some required files
      await File(path.join(sourceDir, 'configure')).create();
      await File(path.join(sourceDir, 'Makefile')).create();

      final isValid = await sourceManager.validateSourceStructure(sourceDir);
      expect(isValid, isFalse);
    });

    test('should pin version information', () async {
      final sourceDir = path.join(tempDir.path, 'ffmpeg-6.1');
      await Directory(sourceDir).create(recursive: true);

      // Create a simple file for checksum calculation
      await File(path.join(sourceDir, 'test.txt')).writeAsString('test content');

      await sourceManager.pinVersion(sourceDir);

      final versionInfo = await sourceManager.getVersionInfo(sourceDir);
      expect(versionInfo, isNotNull);
      expect(versionInfo!['version'], equals('6.1'));
      expect(versionInfo['download_date'], isNotNull);
      expect(versionInfo['source_checksum'], isNotNull);
    });

    test('should handle version info correctly', () async {
      final sourceDir = path.join(tempDir.path, 'ffmpeg-6.1');
      await Directory(sourceDir).create(recursive: true);

      // Initially no version info should exist
      final initialInfo = await sourceManager.getVersionInfo(sourceDir);
      expect(initialInfo, isNull);

      // After pinning, version info should exist
      await File(path.join(sourceDir, 'test.txt')).writeAsString('test');
      await sourceManager.pinVersion(sourceDir);

      final versionInfo = await sourceManager.getVersionInfo(sourceDir);
      expect(versionInfo, isNotNull);
      expect(versionInfo!['version'], equals('6.1'));
    });

    test('should detect version mismatch', () async {
      final sourceDir = path.join(tempDir.path, 'ffmpeg-6.1');
      await Directory(sourceDir).create(recursive: true);

      // Create version info with different version
      final versionFile = File(path.join(sourceDir, '.ffmpeg_version'));
      await versionFile.writeAsString('{"version": "5.1", "download_date": "2023-01-01T00:00:00.000Z"}');

      final needsUpdate = await sourceManager.needsUpdate(sourceDir);
      expect(needsUpdate, isTrue);
    });
  });
}
