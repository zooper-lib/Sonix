// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import '../platform_builder.dart';

/// iOS-specific FFMPEG builder using Xcode toolchain
class IOSBuilder extends PlatformBuilder {
  IOSBuilder({required super.config, required super.sourceDirectory, required super.outputDirectory});

  @override
  Future<bool> validateEnvironment() async {
    // Check if we're on macOS (required for iOS builds)
    if (!Platform.isMacOS) {
      print('Error: iOS builder can only run on macOS');
      return false;
    }

    // Check for Xcode
    final xcodeResult = await Process.run('xcode-select', ['-p']);
    if (xcodeResult.exitCode != 0) {
      print('Error: Xcode not installed or not configured');
      print('Please install Xcode and run: xcode-select --install');
      return false;
    }

    final xcodePath = xcodeResult.stdout.toString().trim();
    print('Found Xcode at: $xcodePath');

    // Check for iOS SDK
    final sdkResult = await Process.run('xcrun', ['--sdk', 'iphoneos', '--show-sdk-path']);
    if (sdkResult.exitCode != 0) {
      print('Error: iOS SDK not found');
      return false;
    }

    final sdkPath = sdkResult.stdout.toString().trim();
    print('Found iOS SDK at: $sdkPath');

    return await checkRequiredTools();
  }

  @override
  List<String> getRequiredTools() {
    return ['xcrun', 'make'];
  }

  @override
  List<String> generateConfigureArgs() {
    final baseArgs = getBaseLGPLConfigureArgs();
    final sdkPath = _getSDKPath();
    final deploymentTarget = _getDeploymentTarget();

    final iosArgs = [
      '--target-os=darwin',
      '--arch=${_getFFMPEGArch()}',
      '--cc=xcrun -sdk iphoneos clang',
      '--cxx=xcrun -sdk iphoneos clang++',
      '--enable-cross-compile',
      '--disable-programs',
      '--disable-doc',
      '--enable-pic',
      '--enable-pthreads',
      '--disable-w32threads',
      '--sysroot=$sdkPath',
    ];

    // Architecture-specific flags
    final archFlags = _getArchitectureFlags();
    iosArgs.addAll([
      '--extra-cflags=${archFlags.join(' ')} -mios-version-min=$deploymentTarget',
      '--extra-ldflags=${archFlags.join(' ')} -mios-version-min=$deploymentTarget',
    ]);

    if (config.isDebug) {
      iosArgs.addAll(['--enable-debug', '--disable-optimizations', '--disable-stripping']);
    } else {
      iosArgs.addAll(['--disable-debug', '--enable-optimizations', '--enable-stripping']);
    }

    // Add custom flags
    for (final entry in config.customFlags.entries) {
      iosArgs.add('--${entry.key}=${entry.value}');
    }

    return [...baseArgs, ...iosArgs];
  }

  @override
  Future<BuildResult> build() async {
    final stopwatch = Stopwatch()..start();

    try {
      print('Starting iOS FFMPEG build...');

      // Validate environment
      if (!await validateEnvironment()) {
        return BuildResult.failure(errorMessage: 'Environment validation failed', buildTime: stopwatch.elapsed);
      }

      // Set up build environment
      await _setupBuildEnvironment();

      // Run configure
      print('Configuring FFMPEG for iOS...');
      final configureResult = await runConfigure();
      if (configureResult.exitCode != 0) {
        return BuildResult.failure(errorMessage: 'Configure failed: ${configureResult.stderr}', buildTime: stopwatch.elapsed);
      }

      // Run make
      print('Compiling FFMPEG...');
      final makeResult = await runMake(jobs: Platform.numberOfProcessors);
      if (makeResult.exitCode != 0) {
        return BuildResult.failure(errorMessage: 'Make failed: ${makeResult.stderr}', buildTime: stopwatch.elapsed);
      }

      // Copy libraries
      print('Copying libraries...');
      await copyLibraries();

      // Create framework if needed
      await _createFramework();

      // Verify output
      final generatedFiles = await _getGeneratedFiles();
      if (generatedFiles.isEmpty) {
        return BuildResult.failure(errorMessage: 'No libraries were generated', buildTime: stopwatch.elapsed);
      }

      print('iOS build completed successfully');
      return BuildResult.success(outputPath: outputDirectory, generatedFiles: generatedFiles, buildTime: stopwatch.elapsed);
    } catch (e) {
      return BuildResult.failure(errorMessage: 'Build failed with exception: $e', buildTime: stopwatch.elapsed);
    }
  }

  @override
  String getOutputExtension() => '.a';

  @override
  String getLibraryPrefix() => 'lib';

  /// Gets the iOS SDK path
  String _getSDKPath() {
    // This will be set during environment setup
    return Platform.environment['IOS_SDK_PATH'] ?? '';
  }

  /// Gets the minimum iOS deployment target
  String _getDeploymentTarget() {
    // iOS 12.0 as minimum for good compatibility
    return '12.0';
  }

  /// Gets the FFMPEG architecture string for the current config
  String _getFFMPEGArch() {
    switch (config.architecture) {
      case Architecture.arm64:
        return 'arm64';
      case Architecture.armv7:
        return 'armv7';
      case Architecture.x86_64:
        return 'x86_64';
      case Architecture.i386:
        return 'i386';
    }
  }

  /// Gets architecture-specific compiler flags
  List<String> _getArchitectureFlags() {
    switch (config.architecture) {
      case Architecture.arm64:
        return ['-arch', 'arm64'];
      case Architecture.armv7:
        return ['-arch', 'armv7'];
      case Architecture.x86_64:
        return ['-arch', 'x86_64'];
      case Architecture.i386:
        return ['-arch', 'i386'];
    }
  }

  /// Sets up build environment variables
  Future<void> _setupBuildEnvironment() async {
    // Get iOS SDK path
    final sdkResult = await Process.run('xcrun', ['--sdk', 'iphoneos', '--show-sdk-path']);
    if (sdkResult.exitCode == 0) {
      Platform.environment['IOS_SDK_PATH'] = sdkResult.stdout.toString().trim();
    }

    // Set up Xcode environment
    Platform.environment['DEVELOPER_DIR'] = await _getXcodePath();

    // Set compiler environment variables
    Platform.environment['CC'] = 'xcrun -sdk iphoneos clang';
    Platform.environment['CXX'] = 'xcrun -sdk iphoneos clang++';
    Platform.environment['AR'] = 'xcrun -sdk iphoneos ar';
    Platform.environment['RANLIB'] = 'xcrun -sdk iphoneos ranlib';
    Platform.environment['STRIP'] = 'xcrun -sdk iphoneos strip';
  }

  /// Gets the Xcode developer directory path
  Future<String> _getXcodePath() async {
    final result = await Process.run('xcode-select', ['-p']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return '/Applications/Xcode.app/Contents/Developer';
  }

  /// Creates iOS framework from static libraries
  Future<void> _createFramework() async {
    final frameworkName = 'FFMPEG';
    final frameworkDir = path.join(outputDirectory, '$frameworkName.framework');

    // Create framework directory structure
    await Directory(frameworkDir).create(recursive: true);
    await Directory(path.join(frameworkDir, 'Headers')).create();

    // Find static libraries
    final staticLibs = <String>[];
    final outputDir = Directory(outputDirectory);
    await for (final entity in outputDir.list()) {
      if (entity is File && entity.path.endsWith('.a')) {
        staticLibs.add(entity.path);
      }
    }

    if (staticLibs.isNotEmpty) {
      // Combine static libraries into framework binary
      final frameworkBinary = path.join(frameworkDir, frameworkName);
      final libtoolResult = await Process.run('libtool', ['-static', '-o', frameworkBinary, ...staticLibs]);

      if (libtoolResult.exitCode == 0) {
        print('Created framework: $frameworkName.framework');

        // Copy headers
        await _copyHeaders(path.join(frameworkDir, 'Headers'));

        // Create Info.plist
        await _createInfoPlist(frameworkDir, frameworkName);
      } else {
        print('Warning: Failed to create framework: ${libtoolResult.stderr}');
      }
    }
  }

  /// Copies FFMPEG headers to framework
  Future<void> _copyHeaders(String headersDir) async {
    final headerDirs = ['libavcodec', 'libavformat', 'libavutil', 'libswresample'];

    for (final headerDir in headerDirs) {
      final sourceHeaderDir = path.join(sourceDirectory, headerDir);
      final sourceDir = Directory(sourceHeaderDir);

      if (await sourceDir.exists()) {
        await for (final entity in sourceDir.list()) {
          if (entity is File && entity.path.endsWith('.h')) {
            final headerName = path.basename(entity.path);
            final targetPath = path.join(headersDir, headerName);
            await entity.copy(targetPath);
          }
        }
      }
    }
  }

  /// Creates Info.plist for the framework
  Future<void> _createInfoPlist(String frameworkDir, String frameworkName) async {
    final infoPlist =
        '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$frameworkName</string>
    <key>CFBundleIdentifier</key>
    <string>org.ffmpeg.$frameworkName</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$frameworkName</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>6.1</string>
    <key>CFBundleVersion</key>
    <string>6.1</string>
    <key>MinimumOSVersion</key>
    <string>${_getDeploymentTarget()}</string>
</dict>
</plist>''';

    final infoPlistFile = File(path.join(frameworkDir, 'Info.plist'));
    await infoPlistFile.writeAsString(infoPlist);
  }

  /// Gets list of generated library files
  Future<List<String>> _getGeneratedFiles() async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in outputDir.list()) {
      if (entity is File && (entity.path.endsWith('.a') || entity.path.endsWith('.framework'))) {
        files.add(path.basename(entity.path));
      } else if (entity is Directory && entity.path.endsWith('.framework')) {
        files.add(path.basename(entity.path));
      }
    }

    return files;
  }

  /// Builds for both device and simulator architectures
  Future<Map<String, BuildResult>> buildUniversal() async {
    final results = <String, BuildResult>{};

    // Build for device (arm64)
    print('Building for iOS device (arm64)...');
    final deviceConfig = BuildConfig(
      platform: config.platform,
      architecture: Architecture.arm64,
      isDebug: config.isDebug,
      customFlags: config.customFlags,
      enabledDecoders: config.enabledDecoders,
      enabledDemuxers: config.enabledDemuxers,
    );

    final deviceBuilder = IOSBuilder(config: deviceConfig, sourceDirectory: sourceDirectory, outputDirectory: path.join(outputDirectory, 'device'));

    results['device'] = await deviceBuilder.build();

    // Build for simulator (x86_64)
    print('Building for iOS simulator (x86_64)...');
    final simulatorConfig = BuildConfig(
      platform: config.platform,
      architecture: Architecture.x86_64,
      isDebug: config.isDebug,
      customFlags: config.customFlags,
      enabledDecoders: config.enabledDecoders,
      enabledDemuxers: config.enabledDemuxers,
    );

    final simulatorBuilder = IOSBuilder(config: simulatorConfig, sourceDirectory: sourceDirectory, outputDirectory: path.join(outputDirectory, 'simulator'));

    // Use simulator SDK for simulator build
    Platform.environment['IOS_SDK_PATH'] = await _getSimulatorSDKPath();
    Platform.environment['CC'] = 'xcrun -sdk iphonesimulator clang';
    Platform.environment['CXX'] = 'xcrun -sdk iphonesimulator clang++';

    results['simulator'] = await simulatorBuilder.build();

    // Create universal framework
    if (results['device']!.success && results['simulator']!.success) {
      await _createUniversalFramework(path.join(outputDirectory, 'device'), path.join(outputDirectory, 'simulator'), path.join(outputDirectory, 'universal'));
    }

    return results;
  }

  /// Gets the iOS simulator SDK path
  Future<String> _getSimulatorSDKPath() async {
    final result = await Process.run('xcrun', ['--sdk', 'iphonesimulator', '--show-sdk-path']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return '';
  }

  /// Creates universal framework combining device and simulator builds
  Future<void> _createUniversalFramework(String deviceDir, String simulatorDir, String outputDir) async {
    print('Creating universal framework...');

    final universalDir = Directory(outputDir);
    if (await universalDir.exists()) {
      await universalDir.delete(recursive: true);
    }
    await universalDir.create(recursive: true);

    // Find framework in device build
    final deviceFramework = await _findFramework(deviceDir);
    final simulatorFramework = await _findFramework(simulatorDir);

    if (deviceFramework != null && simulatorFramework != null) {
      final frameworkName = path.basenameWithoutExtension(deviceFramework);
      final universalFramework = path.join(outputDir, '$frameworkName.framework');

      // Copy device framework as base
      await _copyDirectory(deviceFramework, universalFramework);

      // Create universal binary using lipo
      final deviceBinary = path.join(deviceFramework, frameworkName);
      final simulatorBinary = path.join(simulatorFramework, frameworkName);
      final universalBinary = path.join(universalFramework, frameworkName);

      final lipoResult = await Process.run('lipo', ['-create', deviceBinary, simulatorBinary, '-output', universalBinary]);

      if (lipoResult.exitCode == 0) {
        print('Created universal framework successfully');
      } else {
        print('Warning: Failed to create universal binary: ${lipoResult.stderr}');
      }
    }
  }

  /// Finds framework directory in build output
  Future<String?> _findFramework(String buildDir) async {
    final dir = Directory(buildDir);
    if (!await dir.exists()) return null;

    await for (final entity in dir.list()) {
      if (entity is Directory && entity.path.endsWith('.framework')) {
        return entity.path;
      }
    }
    return null;
  }

  /// Copies directory recursively
  Future<void> _copyDirectory(String source, String destination) async {
    final sourceDir = Directory(source);
    final destDir = Directory(destination);

    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    await for (final entity in sourceDir.list(recursive: false)) {
      if (entity is File) {
        final destPath = path.join(destination, path.basename(entity.path));
        await entity.copy(destPath);
      } else if (entity is Directory) {
        final destPath = path.join(destination, path.basename(entity.path));
        await _copyDirectory(entity.path, destPath);
      }
    }
  }
}
