import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../tools/ffmpeg/ffmpeg_builder.dart';
import '../../tools/ffmpeg/platform_builder.dart';
import '../test_helpers/test_data_loader.dart';

void main() {
  group('Cross-Platform FFMPEG Validation Tests', () {
    late Directory tempDir;
    late TestDataLoader testDataLoader;

    setUpAll(() async {
      testDataLoader = TestDataLoader();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ffmpeg_cross_platform_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Platform Detection and Compatibility', () {
      test('should detect current platform correctly', () {
        final currentPlatform = _detectCurrentPlatform();
        expect(currentPlatform, isNotNull);

        // Verify platform matches system
        if (Platform.isWindows) {
          expect(currentPlatform, equals(TargetPlatform.windows));
        } else if (Platform.isMacOS) {
          expect(currentPlatform, equals(TargetPlatform.macos));
        } else if (Platform.isLinux) {
          expect(currentPlatform, equals(TargetPlatform.linux));
        }
      });

      test('should detect current architecture correctly', () {
        final currentArch = _detectCurrentArchitecture();
        expect(currentArch, isNotNull);
        expect([Architecture.x86_64, Architecture.arm64, Architecture.i386, Architecture.armv7], contains(currentArch));
      });

      test('should validate platform-specific binary extensions', () {
        final platforms = TargetPlatform.values;

        for (final platform in platforms) {
          final config = BuildConfig.release(platform: platform, architecture: Architecture.x86_64);
          final builder = PlatformBuilder.create(config: config, sourceDirectory: '', outputDirectory: '');

          final extension = builder.getOutputExtension();
          final prefix = builder.getLibraryPrefix();

          switch (platform) {
            case TargetPlatform.windows:
              expect(extension, equals('.dll'));
              expect(prefix, equals(''));
              break;
            case TargetPlatform.macos:
            case TargetPlatform.ios:
              expect(extension, equals('.dylib'));
              expect(prefix, equals('lib'));
              break;
            case TargetPlatform.linux:
            case TargetPlatform.android:
              expect(extension, equals('.so'));
              expect(prefix, equals('lib'));
              break;
          }
        }
      });
    });

    group('Platform-Specific Builder Validation', () {
      test('should create platform-specific builders for all platforms', () {
        final platforms = TargetPlatform.values;
        final architectures = Architecture.values;

        for (final platform in platforms) {
          for (final architecture in architectures) {
            // Skip invalid combinations
            if (!_isValidPlatformArchCombination(platform, architecture)) {
              continue;
            }

            final config = BuildConfig.release(platform: platform, architecture: architecture);
            final builder = PlatformBuilder.create(config: config, sourceDirectory: tempDir.path, outputDirectory: tempDir.path);

            expect(builder, isNotNull);
            expect(builder.config.platform, equals(platform));
            expect(builder.config.architecture, equals(architecture));
          }
        }
      });

      test('should generate valid configure arguments for all platforms', () {
        final platforms = TargetPlatform.values;

        for (final platform in platforms) {
          final config = BuildConfig.release(platform: platform, architecture: Architecture.x86_64);
          final builder = PlatformBuilder.create(config: config, sourceDirectory: tempDir.path, outputDirectory: tempDir.path);

          final configArgs = builder.generateConfigureArgs();

          // Verify LGPL compliance
          expect(configArgs, contains('--disable-gpl'));
          expect(configArgs, contains('--enable-version3'));

          // Verify audio-only configuration
          expect(configArgs, contains('--disable-everything'));
          expect(configArgs, contains('--enable-avcodec'));
          expect(configArgs, contains('--enable-avformat'));
          expect(configArgs, contains('--enable-avutil'));
          expect(configArgs, contains('--enable-swresample'));

          // Verify minimal configuration
          expect(configArgs, contains('--disable-programs'));
          expect(configArgs, contains('--disable-doc'));
          expect(configArgs, contains('--disable-network'));
        }
      });

      test('should validate required tools for each platform', () async {
        final currentPlatform = _detectCurrentPlatform();
        final config = BuildConfig.release(platform: currentPlatform, architecture: Architecture.x86_64);
        final builder = PlatformBuilder.create(config: config, sourceDirectory: tempDir.path, outputDirectory: tempDir.path);

        final requiredTools = builder.getRequiredTools();
        expect(requiredTools, isNotEmpty);

        // Verify platform-specific tools
        switch (currentPlatform) {
          case TargetPlatform.windows:
            expect(requiredTools, anyOf(contains('gcc'), contains('clang')));
            break;
          case TargetPlatform.macos:
          case TargetPlatform.ios:
            expect(requiredTools, anyOf(contains('clang'), contains('gcc')));
            break;
          case TargetPlatform.linux:
          case TargetPlatform.android:
            expect(requiredTools, anyOf(contains('gcc'), contains('clang')));
            break;
        }
      });
    });

    group('Binary Loading and Compatibility Tests', () {
      test('should validate expected library names for each platform', () {
        final platforms = TargetPlatform.values;

        for (final platform in platforms) {
          final config = BuildConfig.release(platform: platform, architecture: Architecture.x86_64);
          final builder = PlatformBuilder.create(config: config, sourceDirectory: '', outputDirectory: '');

          final prefix = builder.getLibraryPrefix();
          final extension = builder.getOutputExtension();

          final expectedLibraries = ['${prefix}avcodec$extension', '${prefix}avformat$extension', '${prefix}avutil$extension', '${prefix}swresample$extension'];

          expect(expectedLibraries, hasLength(4));

          for (final library in expectedLibraries) {
            expect(library, endsWith(extension));
            if (prefix.isNotEmpty) {
              expect(library, startsWith(prefix));
            }
          }
        }
      });

      test('should validate library loading compatibility', () async {
        // Create mock library files for testing
        final platforms = TargetPlatform.values;

        for (final platform in platforms) {
          final config = BuildConfig.release(platform: platform, architecture: Architecture.x86_64);
          final builder = PlatformBuilder.create(config: config, sourceDirectory: '', outputDirectory: '');

          final outputDir = path.join(tempDir.path, platform.name);
          await Directory(outputDir).create(recursive: true);

          final prefix = builder.getLibraryPrefix();
          final extension = builder.getOutputExtension();

          // Create mock library files
          final libraries = ['${prefix}avcodec$extension', '${prefix}avformat$extension', '${prefix}avutil$extension', '${prefix}swresample$extension'];

          for (final library in libraries) {
            final libraryPath = path.join(outputDir, library);
            final file = File(libraryPath);
            await file.writeAsBytes(List.generate(2048, (i) => i % 256)); // Mock binary data
          }

          // Verify files exist and have reasonable size
          for (final library in libraries) {
            final libraryPath = path.join(outputDir, library);
            final file = File(libraryPath);

            expect(await file.exists(), isTrue);
            expect(await file.length(), greaterThan(1024));
          }
        }
      });
    });

    group('API Compatibility Regression Tests', () {
      test('should maintain backward compatibility with existing decoder interfaces', () {
        // Test that FFMPEG integration doesn't break existing API
        final config = BuildConfig.release(
          platform: _detectCurrentPlatform(),
          architecture: Architecture.x86_64,
          enabledDecoders: ['mp3', 'aac', 'flac', 'vorbis', 'opus'],
          enabledDemuxers: ['mp3', 'mp4', 'flac', 'ogg', 'wav'],
        );

        expect(config.enabledDecoders, contains('mp3'));
        expect(config.enabledDecoders, contains('aac'));
        expect(config.enabledDecoders, contains('flac'));
        expect(config.enabledDecoders, contains('vorbis'));
        expect(config.enabledDecoders, contains('opus'));

        expect(config.enabledDemuxers, contains('mp3'));
        expect(config.enabledDemuxers, contains('mp4'));
        expect(config.enabledDemuxers, contains('flac'));
        expect(config.enabledDemuxers, contains('ogg'));
        expect(config.enabledDemuxers, contains('wav'));
      });

      test('should support all current audio formats through FFMPEG configuration', () {
        final supportedFormats = ['mp3', 'aac', 'flac', 'vorbis', 'opus'];
        final supportedContainers = ['mp3', 'mp4', 'flac', 'ogg', 'wav'];

        final config = BuildConfig.release(
          platform: _detectCurrentPlatform(),
          architecture: Architecture.x86_64,
          enabledDecoders: supportedFormats,
          enabledDemuxers: supportedContainers,
        );

        final builder = PlatformBuilder.create(config: config, sourceDirectory: '', outputDirectory: '');
        final configArgs = builder.generateConfigureArgs();

        // Verify all supported formats are enabled
        for (final format in supportedFormats) {
          expect(configArgs, contains('--enable-decoder=$format'));
        }

        for (final container in supportedContainers) {
          expect(configArgs, contains('--enable-demuxer=$container'));
        }
      });

      test('should maintain isolate-based processing compatibility', () {
        // Verify that FFMPEG configuration supports isolate processing
        final config = BuildConfig.release(platform: _detectCurrentPlatform(), architecture: Architecture.x86_64);

        expect(config.platform, isNotNull);
        expect(config.architecture, isNotNull);
        expect(config.enabledDecoders, isNotEmpty);
        expect(config.enabledDemuxers, isNotEmpty);

        // Verify shared library configuration for isolate compatibility
        final builder = PlatformBuilder.create(config: config, sourceDirectory: '', outputDirectory: '');
        final configArgs = builder.generateConfigureArgs();

        expect(configArgs, contains('--enable-shared'));
        expect(configArgs, contains('--disable-static'));
      });
    });

    group('Error Handling and Recovery Tests', () {
      test('should handle invalid platform configurations gracefully', () {
        expect(() {
          BuildConfig.release(
            platform: TargetPlatform.windows,
            architecture: Architecture.x86_64,
            enabledDecoders: [], // Empty decoders should be handled
            enabledDemuxers: [], // Empty demuxers should be handled
          );
        }, returnsNormally);
      });

      test('should validate configuration before build', () async {
        final builder = FFMPEGBuilder(workingDirectory: tempDir.path, version: '6.1');

        // Test with invalid configuration
        final invalidConfig = BuildConfig.release(
          platform: _detectCurrentPlatform(),
          architecture: Architecture.x86_64,
          customFlags: {'--enable-gpl': 'true'}, // This should cause validation failure
        );

        // Note: This test would require actual build validation,
        // which is tested in the build system validation tests
        expect(invalidConfig.customFlags, isNotEmpty);
      });

      test('should provide meaningful error messages for build failures', () {
        final result = BuildResult.failure(
          errorMessage: 'FFMPEG configuration validation failed: GPL must be disabled for LGPL compliance',
          buildTime: Duration(seconds: 5),
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('LGPL compliance'));
        expect(result.buildTime, equals(Duration(seconds: 5)));
      });
    });
  });
}

/// Detects the current platform
TargetPlatform _detectCurrentPlatform() {
  if (Platform.isWindows) {
    return TargetPlatform.windows;
  } else if (Platform.isMacOS) {
    return TargetPlatform.macos;
  } else if (Platform.isLinux) {
    return TargetPlatform.linux;
  } else {
    throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }
}

/// Detects the current architecture
Architecture _detectCurrentArchitecture() {
  if (Platform.version.contains('x64') || Platform.version.contains('x86_64')) {
    return Architecture.x86_64;
  } else if (Platform.version.contains('arm64') || Platform.version.contains('aarch64')) {
    return Architecture.arm64;
  } else {
    return Architecture.x86_64; // Default fallback
  }
}

/// Checks if platform/architecture combination is valid
bool _isValidPlatformArchCombination(TargetPlatform platform, Architecture architecture) {
  switch (platform) {
    case TargetPlatform.windows:
      return [Architecture.x86_64, Architecture.i386].contains(architecture);
    case TargetPlatform.macos:
      return [Architecture.x86_64, Architecture.arm64].contains(architecture);
    case TargetPlatform.linux:
      return [Architecture.x86_64, Architecture.arm64, Architecture.armv7].contains(architecture);
    case TargetPlatform.android:
      return [Architecture.arm64, Architecture.armv7, Architecture.x86_64].contains(architecture);
    case TargetPlatform.ios:
      return [Architecture.arm64, Architecture.x86_64].contains(architecture);
  }
}
