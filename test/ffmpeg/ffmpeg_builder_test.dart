import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import '../../tools/ffmpeg/ffmpeg_builder.dart';
import '../../tools/ffmpeg/platform_builder.dart';

void main() {
  group('FFMPEGBuilder', () {
    late Directory tempDir;
    late FFMPEGBuilder builder;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ffmpeg_builder_test_');
      builder = FFMPEGBuilder(workingDirectory: tempDir.path, version: '6.1', verbose: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create working directory', () async {
      expect(await Directory(tempDir.path).exists(), isTrue);
    });

    test('should create builder instance with correct properties', () async {
      expect(builder.workingDirectory, equals(tempDir.path));
      expect(builder.version, equals('6.1'));
      expect(builder.verbose, isTrue);
    });

    test('should generate build report', () async {
      final results = <String, BuildResult>{
        'windows_x86_64': BuildResult.success(
          outputPath: '/path/to/output',
          generatedFiles: ['libavcodec.dll', 'libavformat.dll'],
          buildTime: Duration(seconds: 120),
        ),
        'linux_arm64': BuildResult.failure(errorMessage: 'Compilation failed', buildTime: Duration(seconds: 60)),
      };

      final report = await builder.generateBuildReport(results);

      expect(report, contains('FFMPEG Build Report'));
      expect(report, contains('windows_x86_64'));
      expect(report, contains('linux_arm64'));
      expect(report, contains('SUCCESS'));
      expect(report, contains('FAILURE'));
      expect(report, contains('Success Rate: 50.0%'));
    });

    test('should create build config correctly', () async {
      final config = BuildConfig.release(platform: TargetPlatform.windows, architecture: Architecture.x86_64);

      expect(config.platform, equals(TargetPlatform.windows));
      expect(config.architecture, equals(Architecture.x86_64));
      expect(config.isDebug, isFalse);
      expect(config.enabledDecoders, contains('mp3'));
      expect(config.enabledDecoders, contains('aac'));
    });

    test('should create debug build config correctly', () async {
      final config = BuildConfig.debug(platform: TargetPlatform.linux, architecture: Architecture.arm64);

      expect(config.platform, equals(TargetPlatform.linux));
      expect(config.architecture, equals(Architecture.arm64));
      expect(config.isDebug, isTrue);
    });
  });
}
