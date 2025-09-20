// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import 'builders/windows_builder.dart';
import 'builders/macos_builder.dart';
import 'builders/linux_builder.dart';
import 'builders/android_builder.dart';
import 'builders/ios_builder.dart';

/// Supported target platforms for FFMPEG builds
enum TargetPlatform { windows, macos, linux, android, ios }

/// Supported architectures
enum Architecture { x86_64, arm64, armv7, i386 }

/// Build configuration for FFMPEG
class BuildConfig {
  final TargetPlatform platform;
  final Architecture architecture;
  final bool isDebug;
  final Map<String, String> customFlags;
  final List<String> enabledDecoders;
  final List<String> enabledDemuxers;

  const BuildConfig({
    required this.platform,
    required this.architecture,
    this.isDebug = false,
    this.customFlags = const {},
    this.enabledDecoders = const ['mp3', 'aac', 'flac', 'vorbis', 'opus'],
    this.enabledDemuxers = const ['mp3', 'mp4', 'flac', 'ogg', 'wav'],
  });

  /// Creates a release build configuration
  BuildConfig.release({
    required TargetPlatform platform,
    required Architecture architecture,
    Map<String, String> customFlags = const {},
    List<String> enabledDecoders = const ['mp3', 'aac', 'flac', 'vorbis', 'opus'],
    List<String> enabledDemuxers = const ['mp3', 'mp4', 'flac', 'ogg', 'wav'],
  }) : this(
         platform: platform,
         architecture: architecture,
         isDebug: false,
         customFlags: customFlags,
         enabledDecoders: enabledDecoders,
         enabledDemuxers: enabledDemuxers,
       );

  /// Creates a debug build configuration
  BuildConfig.debug({
    required TargetPlatform platform,
    required Architecture architecture,
    Map<String, String> customFlags = const {},
    List<String> enabledDecoders = const ['mp3', 'aac', 'flac', 'vorbis', 'opus'],
    List<String> enabledDemuxers = const ['mp3', 'mp4', 'flac', 'ogg', 'wav'],
  }) : this(
         platform: platform,
         architecture: architecture,
         isDebug: true,
         customFlags: customFlags,
         enabledDecoders: enabledDecoders,
         enabledDemuxers: enabledDemuxers,
       );
}

/// Build result information
class BuildResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;
  final List<String> generatedFiles;
  final Duration buildTime;

  const BuildResult({required this.success, this.outputPath, this.errorMessage, this.generatedFiles = const [], required this.buildTime});

  BuildResult.success({required String outputPath, required List<String> generatedFiles, required Duration buildTime})
    : this(success: true, outputPath: outputPath, generatedFiles: generatedFiles, buildTime: buildTime);

  BuildResult.failure({required String errorMessage, required Duration buildTime}) : this(success: false, errorMessage: errorMessage, buildTime: buildTime);
}

/// Abstract base class for platform-specific FFMPEG builders
abstract class PlatformBuilder {
  final BuildConfig config;
  final String sourceDirectory;
  final String outputDirectory;

  PlatformBuilder({required this.config, required this.sourceDirectory, required this.outputDirectory});

  /// Validates that the build environment is properly set up
  Future<bool> validateEnvironment();

  /// Gets the required build tools for this platform
  List<String> getRequiredTools();

  /// Generates FFMPEG configure arguments for this platform
  List<String> generateConfigureArgs();

  /// Executes the build process
  Future<BuildResult> build();

  /// Gets the expected output file extension for this platform
  String getOutputExtension();

  /// Gets the library prefix for this platform (e.g., 'lib' on Unix)
  String getLibraryPrefix();

  /// Validates that required tools are available
  Future<bool> checkRequiredTools() async {
    final requiredTools = getRequiredTools();

    for (final tool in requiredTools) {
      ProcessResult result;

      // Use appropriate command based on platform
      if (Platform.isWindows) {
        result = await Process.run('where', [tool]);
      } else {
        result = await Process.run('which', [tool]);
      }

      if (result.exitCode != 0) {
        print('Required tool not found: $tool');
        return false;
      }
    }

    return true;
  }

  /// Common LGPL-compliant configure arguments
  List<String> getBaseLGPLConfigureArgs() {
    return [
      '--enable-shared',
      '--disable-static',
      '--disable-programs',
      '--disable-doc',
      '--disable-htmlpages',
      '--disable-manpages',
      '--disable-podpages',
      '--disable-txtpages',
      '--disable-network',
      '--disable-autodetect',
      '--disable-everything',
      // Enable only LGPL components
      '--enable-avcodec',
      '--enable-avformat',
      '--enable-avutil',
      '--enable-swresample',
      // Enable only specified decoders
      ...config.enabledDecoders.map((decoder) => '--enable-decoder=$decoder'),
      // Enable only specified demuxers
      ...config.enabledDemuxers.map((demuxer) => '--enable-demuxer=$demuxer'),
      // Ensure LGPL compliance
      '--enable-version3',
      '--disable-gpl',
    ];
  }

  /// Runs the configure script with platform-specific arguments
  Future<ProcessResult> runConfigure() async {
    final configureScript = path.join(sourceDirectory, 'configure');
    final args = generateConfigureArgs();

    print('Running configure with args: ${args.join(' ')}');

    return await Process.run(configureScript, args, workingDirectory: sourceDirectory);
  }

  /// Runs make to compile FFMPEG
  Future<ProcessResult> runMake({int? jobs}) async {
    final makeArgs = <String>[];

    if (jobs != null) {
      makeArgs.addAll(['-j', jobs.toString()]);
    }

    print('Running make with ${jobs ?? 'default'} jobs...');

    return await Process.run('make', makeArgs, workingDirectory: sourceDirectory);
  }

  /// Copies built libraries to output directory
  Future<void> copyLibraries() async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final libraryExtension = getOutputExtension();
    final libraryPrefix = getLibraryPrefix();

    // Find and copy built libraries
    final sourceDir = Directory(sourceDirectory);
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith(libraryExtension)) {
        final fileName = path.basename(entity.path);
        if (fileName.startsWith(libraryPrefix)) {
          final targetPath = path.join(outputDirectory, fileName);
          await entity.copy(targetPath);
          print('Copied library: $fileName');
        }
      }
    }
  }

  /// Factory method to create platform-specific builders
  static PlatformBuilder create({required BuildConfig config, required String sourceDirectory, required String outputDirectory}) {
    switch (config.platform) {
      case TargetPlatform.windows:
        return WindowsBuilder(config: config, sourceDirectory: sourceDirectory, outputDirectory: outputDirectory);
      case TargetPlatform.macos:
        return MacOSBuilder(config: config, sourceDirectory: sourceDirectory, outputDirectory: outputDirectory);
      case TargetPlatform.linux:
        return LinuxBuilder(config: config, sourceDirectory: sourceDirectory, outputDirectory: outputDirectory);
      case TargetPlatform.android:
        return AndroidBuilder(config: config, sourceDirectory: sourceDirectory, outputDirectory: outputDirectory);
      case TargetPlatform.ios:
        return IOSBuilder(config: config, sourceDirectory: sourceDirectory, outputDirectory: outputDirectory);
    }
  }
}
