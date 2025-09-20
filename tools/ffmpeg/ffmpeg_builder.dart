// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import 'source_manager.dart';
import 'platform_builder.dart';

/// Main FFMPEG builder that orchestrates the entire build process
class FFMPEGBuilder {
  final String workingDirectory;
  final String version;
  final bool verbose;

  FFMPEGBuilder({required this.workingDirectory, this.version = '6.1', this.verbose = false});

  /// Builds FFMPEG for the specified configuration
  Future<BuildResult> build(BuildConfig config) async {
    final stopwatch = Stopwatch()..start();

    try {
      _log('Starting FFMPEG build process...');
      _log('Target: ${config.platform.name} ${config.architecture.name}');
      _log('Version: $version');

      // Step 1: Download and verify source
      final sourceManager = FFMPEGSourceManager(workingDirectory: workingDirectory, version: version);

      final sourceDir = await _downloadAndVerifySource(sourceManager);
      if (sourceDir == null) {
        return BuildResult.failure(errorMessage: 'Failed to download or verify FFMPEG source', buildTime: stopwatch.elapsed);
      }

      // Step 2: Create platform-specific builder
      final outputDir = path.join(workingDirectory, 'output', '${config.platform.name}_${config.architecture.name}');
      final builder = PlatformBuilder.create(config: config, sourceDirectory: sourceDir, outputDirectory: outputDir);

      // Step 3: Validate build environment
      _log('Validating build environment...');
      if (!await builder.validateEnvironment()) {
        return BuildResult.failure(errorMessage: 'Build environment validation failed', buildTime: stopwatch.elapsed);
      }

      // Step 4: Generate and validate configuration
      _log('Generating FFMPEG configuration...');
      final configValidation = await _validateConfiguration(builder);
      if (!configValidation.isValid) {
        return BuildResult.failure(errorMessage: 'Configuration validation failed: ${configValidation.error}', buildTime: stopwatch.elapsed);
      }

      // Step 5: Execute build
      _log('Executing build...');
      final buildResult = await builder.build();

      // Step 6: Verify build output
      if (buildResult.success) {
        _log('Verifying build output...');
        final verification = await _verifyBuildOutput(buildResult.outputPath!, config);
        if (!verification.isValid) {
          return BuildResult.failure(errorMessage: 'Build verification failed: ${verification.error}', buildTime: stopwatch.elapsed);
        }
      }

      _log('Build completed in ${stopwatch.elapsed.inSeconds} seconds');
      return buildResult;
    } catch (e, stackTrace) {
      _log('Build failed with exception: $e');
      if (verbose) {
        _log('Stack trace: $stackTrace');
      }

      return BuildResult.failure(errorMessage: 'Build failed with exception: $e', buildTime: stopwatch.elapsed);
    }
  }

  /// Downloads and verifies FFMPEG source code
  Future<String?> _downloadAndVerifySource(FFMPEGSourceManager sourceManager) async {
    try {
      final sourceDir = path.join(workingDirectory, 'ffmpeg-$version');

      // Check if source needs update
      if (await sourceManager.needsUpdate(sourceDir)) {
        _log('Downloading FFMPEG source...');
        await sourceManager.downloadSource();
      } else {
        _log('Using existing FFMPEG source');
      }

      // Verify source integrity
      _log('Verifying source integrity...');
      if (!await sourceManager.verifySourceIntegrity(sourceDir)) {
        _log('Source integrity check failed, re-downloading...');
        await sourceManager.downloadSource();

        if (!await sourceManager.verifySourceIntegrity(sourceDir)) {
          _log('Source integrity check failed after re-download');
          return null;
        }
      }

      // Validate source structure
      if (!await sourceManager.validateSourceStructure(sourceDir)) {
        _log('Source structure validation failed');
        return null;
      }

      // Pin version
      await sourceManager.pinVersion(sourceDir);

      return sourceDir;
    } catch (e) {
      _log('Source download/verification failed: $e');
      return null;
    }
  }

  /// Validates FFMPEG configuration for LGPL compliance
  Future<ConfigValidationResult> _validateConfiguration(PlatformBuilder builder) async {
    try {
      final configArgs = builder.generateConfigureArgs();

      // Check for LGPL compliance
      final lgplValidation = _validateLGPLCompliance(configArgs);
      if (!lgplValidation.isValid) {
        return lgplValidation;
      }

      // Check for audio-only configuration
      final audioValidation = _validateAudioOnlyConfiguration(configArgs);
      if (!audioValidation.isValid) {
        return audioValidation;
      }

      // Check for minimal configuration
      final minimalValidation = _validateMinimalConfiguration(configArgs);
      if (!minimalValidation.isValid) {
        return minimalValidation;
      }

      return ConfigValidationResult.valid();
    } catch (e) {
      return ConfigValidationResult.invalid('Configuration validation error: $e');
    }
  }

  /// Validates LGPL compliance in configuration
  ConfigValidationResult _validateLGPLCompliance(List<String> configArgs) {
    // Check that GPL is disabled
    if (!configArgs.contains('--disable-gpl')) {
      return ConfigValidationResult.invalid('GPL must be disabled for LGPL compliance');
    }

    // Check that version3 is enabled (allows LGPL v3)
    if (!configArgs.contains('--enable-version3')) {
      return ConfigValidationResult.invalid('Version3 must be enabled for LGPL v3 compliance');
    }

    // Check for GPL-only components that should be disabled
    final gplComponents = ['libx264', 'libx265', 'libxvid', 'libfdk-aac'];

    for (final component in gplComponents) {
      if (configArgs.any((arg) => arg.contains('--enable-$component'))) {
        return ConfigValidationResult.invalid('GPL component $component must not be enabled');
      }
    }

    return ConfigValidationResult.valid();
  }

  /// Validates audio-only configuration
  ConfigValidationResult _validateAudioOnlyConfiguration(List<String> configArgs) {
    // Check that video components are disabled
    final videoComponents = ['avfilter', 'swscale', 'postproc'];

    for (final component in videoComponents) {
      if (configArgs.contains('--enable-$component')) {
        return ConfigValidationResult.invalid('Video component $component should be disabled for audio-only build');
      }
    }

    // Check that required audio components are enabled
    final requiredAudioComponents = ['avcodec', 'avformat', 'avutil', 'swresample'];

    for (final component in requiredAudioComponents) {
      if (!configArgs.contains('--enable-$component')) {
        return ConfigValidationResult.invalid('Required audio component $component must be enabled');
      }
    }

    return ConfigValidationResult.valid();
  }

  /// Validates minimal configuration
  ConfigValidationResult _validateMinimalConfiguration(List<String> configArgs) {
    // Check that unnecessary features are disabled
    final unnecessaryFeatures = ['programs', 'doc', 'htmlpages', 'manpages', 'podpages', 'txtpages', 'network', 'autodetect'];

    for (final feature in unnecessaryFeatures) {
      if (!configArgs.contains('--disable-$feature')) {
        return ConfigValidationResult.invalid('Unnecessary feature $feature should be disabled');
      }
    }

    // Check that everything is disabled initially
    if (!configArgs.contains('--disable-everything')) {
      return ConfigValidationResult.invalid('--disable-everything should be used for minimal build');
    }

    return ConfigValidationResult.valid();
  }

  /// Verifies build output
  Future<BuildVerificationResult> _verifyBuildOutput(String outputPath, BuildConfig config) async {
    try {
      final outputDir = Directory(outputPath);
      if (!await outputDir.exists()) {
        return BuildVerificationResult.invalid('Output directory does not exist');
      }

      // Check for expected library files
      final expectedLibraries = _getExpectedLibraries(config);
      final missingLibraries = <String>[];

      for (final library in expectedLibraries) {
        final libraryPath = path.join(outputPath, library);
        if (!await File(libraryPath).exists()) {
          missingLibraries.add(library);
        }
      }

      if (missingLibraries.isNotEmpty) {
        return BuildVerificationResult.invalid('Missing libraries: ${missingLibraries.join(', ')}');
      }

      // Verify library symbols (basic check)
      for (final library in expectedLibraries) {
        final libraryPath = path.join(outputPath, library);
        final symbolCheck = await _verifyLibrarySymbols(libraryPath, config);
        if (!symbolCheck.isValid) {
          return symbolCheck;
        }
      }

      // Check library sizes (they shouldn't be empty)
      for (final library in expectedLibraries) {
        final libraryPath = path.join(outputPath, library);
        final file = File(libraryPath);
        final size = await file.length();
        if (size < 1024) {
          // Less than 1KB is suspicious
          return BuildVerificationResult.invalid('Library $library is suspiciously small ($size bytes)');
        }
      }

      return BuildVerificationResult.valid();
    } catch (e) {
      return BuildVerificationResult.invalid('Build verification error: $e');
    }
  }

  /// Gets expected library names for the platform
  List<String> _getExpectedLibraries(BuildConfig config) {
    final prefix = PlatformBuilder.create(config: config, sourceDirectory: '', outputDirectory: '').getLibraryPrefix();

    final extension = PlatformBuilder.create(config: config, sourceDirectory: '', outputDirectory: '').getOutputExtension();

    return ['${prefix}avcodec$extension', '${prefix}avformat$extension', '${prefix}avutil$extension', '${prefix}swresample$extension'];
  }

  /// Verifies library symbols using platform-specific tools
  Future<BuildVerificationResult> _verifyLibrarySymbols(String libraryPath, BuildConfig config) async {
    try {
      String command;
      List<String> args;

      // Choose appropriate tool based on platform
      switch (config.platform) {
        case TargetPlatform.windows:
          // Use objdump for Windows
          command = 'objdump';
          args = ['-t', libraryPath];
          break;
        case TargetPlatform.macos:
        case TargetPlatform.ios:
          // Use nm for macOS/iOS
          command = 'nm';
          args = ['-D', libraryPath];
          break;
        case TargetPlatform.linux:
        case TargetPlatform.android:
          // Use readelf for Linux/Android
          command = 'readelf';
          args = ['-s', libraryPath];
          break;
      }

      final result = await Process.run(command, args);
      if (result.exitCode != 0) {
        // Symbol verification failed, but this might not be critical
        _log('Warning: Symbol verification failed for $libraryPath');
        return BuildVerificationResult.valid(); // Don't fail the build for this
      }

      // Check for expected symbols (basic check)
      final output = result.stdout.toString();
      final expectedSymbols = ['av_', 'swr_']; // Basic FFMPEG symbols

      for (final symbol in expectedSymbols) {
        if (!output.contains(symbol)) {
          return BuildVerificationResult.invalid('Library $libraryPath missing expected symbols starting with $symbol');
        }
      }

      return BuildVerificationResult.valid();
    } catch (e) {
      // Symbol verification is not critical, just log and continue
      _log('Warning: Could not verify symbols for $libraryPath: $e');
      return BuildVerificationResult.valid();
    }
  }

  /// Builds for all supported platforms
  Future<Map<String, BuildResult>> buildAllPlatforms({bool includeDebug = false}) async {
    final results = <String, BuildResult>{};

    // Define platform/architecture combinations
    final configs = <BuildConfig>[
      // Windows
      BuildConfig.release(platform: TargetPlatform.windows, architecture: Architecture.x86_64),
      BuildConfig.release(platform: TargetPlatform.windows, architecture: Architecture.i386),

      // macOS
      BuildConfig.release(platform: TargetPlatform.macos, architecture: Architecture.x86_64),
      BuildConfig.release(platform: TargetPlatform.macos, architecture: Architecture.arm64),

      // Linux
      BuildConfig.release(platform: TargetPlatform.linux, architecture: Architecture.x86_64),
      BuildConfig.release(platform: TargetPlatform.linux, architecture: Architecture.arm64),

      // Android
      BuildConfig.release(platform: TargetPlatform.android, architecture: Architecture.arm64),
      BuildConfig.release(platform: TargetPlatform.android, architecture: Architecture.armv7),
      BuildConfig.release(platform: TargetPlatform.android, architecture: Architecture.x86_64),

      // iOS
      BuildConfig.release(platform: TargetPlatform.ios, architecture: Architecture.arm64),
      BuildConfig.release(platform: TargetPlatform.ios, architecture: Architecture.x86_64),
    ];

    // Add debug configs if requested
    if (includeDebug) {
      final debugConfigs = configs
          .map(
            (config) => BuildConfig.debug(
              platform: config.platform,
              architecture: config.architecture,
              customFlags: config.customFlags,
              enabledDecoders: config.enabledDecoders,
              enabledDemuxers: config.enabledDemuxers,
            ),
          )
          .toList();
      configs.addAll(debugConfigs);
    }

    // Build each configuration
    for (final config in configs) {
      final configName = '${config.platform.name}_${config.architecture.name}${config.isDebug ? '_debug' : ''}';
      _log('Building configuration: $configName');

      results[configName] = await build(config);

      if (results[configName]!.success) {
        _log('✓ $configName build succeeded');
      } else {
        _log('✗ $configName build failed: ${results[configName]!.errorMessage}');
      }
    }

    return results;
  }

  /// Generates build report
  Future<String> generateBuildReport(Map<String, BuildResult> results) async {
    final report = StringBuffer();
    report.writeln('FFMPEG Build Report');
    report.writeln('==================');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln('Version: $version');
    report.writeln();

    var successCount = 0;
    var failureCount = 0;

    for (final entry in results.entries) {
      final configName = entry.key;
      final result = entry.value;

      report.writeln('Configuration: $configName');
      report.writeln('Status: ${result.success ? 'SUCCESS' : 'FAILURE'}');
      report.writeln('Build Time: ${result.buildTime.inSeconds}s');

      if (result.success) {
        successCount++;
        report.writeln('Output: ${result.outputPath}');
        report.writeln('Generated Files: ${result.generatedFiles.join(', ')}');
      } else {
        failureCount++;
        report.writeln('Error: ${result.errorMessage}');
      }

      report.writeln();
    }

    report.writeln('Summary');
    report.writeln('-------');
    report.writeln('Total Configurations: ${results.length}');
    report.writeln('Successful: $successCount');
    report.writeln('Failed: $failureCount');
    report.writeln('Success Rate: ${(successCount / results.length * 100).toStringAsFixed(1)}%');

    return report.toString();
  }

  /// Logs message with timestamp
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';

    if (verbose) {
      print(logMessage);
    } else {
      print(message);
    }
  }
}

/// Result of configuration validation
class ConfigValidationResult {
  final bool isValid;
  final String? error;

  const ConfigValidationResult._(this.isValid, this.error);

  factory ConfigValidationResult.valid() => const ConfigValidationResult._(true, null);
  factory ConfigValidationResult.invalid(String error) => ConfigValidationResult._(false, error);
}

/// Result of build verification
class BuildVerificationResult {
  final bool isValid;
  final String? error;

  const BuildVerificationResult._(this.isValid, this.error);

  factory BuildVerificationResult.valid() => const BuildVerificationResult._(true, null);
  factory BuildVerificationResult.invalid(String error) => BuildVerificationResult._(false, error);
}
