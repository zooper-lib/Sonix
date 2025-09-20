// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import '../platform_builder.dart';

/// Android-specific FFMPEG builder using Android NDK
class AndroidBuilder extends PlatformBuilder {
  AndroidBuilder({required super.config, required super.sourceDirectory, required super.outputDirectory});

  @override
  Future<bool> validateEnvironment() async {
    // Check for Android NDK
    final ndkPath = _getAndroidNDKPath();
    if (ndkPath == null) {
      print('Error: Android NDK not found');
      print('Please set ANDROID_NDK_HOME or ANDROID_NDK_ROOT environment variable');
      return false;
    }

    print('Found Android NDK at: $ndkPath');

    // Validate NDK version
    final ndkVersion = await _getNDKVersion(ndkPath);
    if (ndkVersion == null) {
      print('Error: Could not determine NDK version');
      return false;
    }

    print('NDK Version: $ndkVersion');

    // Check for required NDK components
    final toolchainPath = _getToolchainPath(ndkPath);
    if (!await Directory(toolchainPath).exists()) {
      print('Error: NDK toolchain not found at: $toolchainPath');
      return false;
    }

    return await checkRequiredTools();
  }

  @override
  List<String> getRequiredTools() {
    return ['make'];
  }

  @override
  List<String> generateConfigureArgs() {
    final baseArgs = getBaseLGPLConfigureArgs();
    final ndkPath = _getAndroidNDKPath()!;
    final toolchainPath = _getToolchainPath(ndkPath);
    final sysrootPath = _getSysrootPath(ndkPath);

    final androidArgs = [
      '--target-os=android',
      '--arch=${_getFFMPEGArch()}',
      '--cpu=${_getCPUType()}',
      '--cross-prefix=${_getCrossPrefix(toolchainPath)}',
      '--enable-cross-compile',
      '--sysroot=$sysrootPath',
      '--enable-pic',
      '--enable-pthreads',
      '--disable-w32threads',
      '--disable-symver',
    ];

    // API level specific flags
    final apiLevel = _getAPILevel();
    androidArgs.addAll(['--extra-cflags=-D__ANDROID_API__=$apiLevel', '--extra-ldflags=-D__ANDROID_API__=$apiLevel']);

    // Architecture-specific flags
    switch (config.architecture) {
      case Architecture.arm64:
        androidArgs.addAll(['--extra-cflags=-march=armv8-a']);
        break;
      case Architecture.armv7:
        androidArgs.addAll(['--extra-cflags=-march=armv7-a -mfloat-abi=softfp -mfpu=neon']);
        break;
      case Architecture.x86_64:
        androidArgs.addAll(['--extra-cflags=-march=x86-64']);
        break;
      case Architecture.i386:
        androidArgs.addAll(['--extra-cflags=-march=i686']);
        break;
    }

    if (config.isDebug) {
      androidArgs.addAll(['--enable-debug', '--disable-optimizations', '--disable-stripping']);
    } else {
      androidArgs.addAll(['--disable-debug', '--enable-optimizations', '--enable-stripping']);
    }

    // Add custom flags
    for (final entry in config.customFlags.entries) {
      androidArgs.add('--${entry.key}=${entry.value}');
    }

    return [...baseArgs, ...androidArgs];
  }

  @override
  Future<BuildResult> build() async {
    final stopwatch = Stopwatch()..start();

    try {
      print('Starting Android FFMPEG build...');

      // Validate environment
      if (!await validateEnvironment()) {
        return BuildResult.failure(errorMessage: 'Environment validation failed', buildTime: stopwatch.elapsed);
      }

      // Set up build environment
      await _setupBuildEnvironment();

      // Run configure
      print('Configuring FFMPEG for Android...');
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

      // Strip libraries for release builds
      if (!config.isDebug) {
        await _stripLibraries();
      }

      // Verify output
      final generatedFiles = await _getGeneratedFiles();
      if (generatedFiles.isEmpty) {
        return BuildResult.failure(errorMessage: 'No libraries were generated', buildTime: stopwatch.elapsed);
      }

      print('Android build completed successfully');
      return BuildResult.success(outputPath: outputDirectory, generatedFiles: generatedFiles, buildTime: stopwatch.elapsed);
    } catch (e) {
      return BuildResult.failure(errorMessage: 'Build failed with exception: $e', buildTime: stopwatch.elapsed);
    }
  }

  @override
  String getOutputExtension() => '.so';

  @override
  String getLibraryPrefix() => 'lib';

  /// Gets Android NDK path from environment variables
  String? _getAndroidNDKPath() {
    return Platform.environment['ANDROID_NDK_HOME'] ?? Platform.environment['ANDROID_NDK_ROOT'] ?? Platform.environment['NDK_ROOT'];
  }

  /// Gets NDK version from source.properties file
  Future<String?> _getNDKVersion(String ndkPath) async {
    final propsFile = File(path.join(ndkPath, 'source.properties'));
    if (!await propsFile.exists()) {
      return null;
    }

    try {
      final content = await propsFile.readAsString();
      final versionMatch = RegExp(r'Pkg\.Revision\s*=\s*(.+)').firstMatch(content);
      return versionMatch?.group(1)?.trim();
    } catch (e) {
      return null;
    }
  }

  /// Gets the toolchain path for the current architecture
  String _getToolchainPath(String ndkPath) {
    final hostTag = _getHostTag();
    return path.join(ndkPath, 'toolchains', 'llvm', 'prebuilt', hostTag);
  }

  /// Gets the sysroot path for the current architecture and API level
  String _getSysrootPath(String ndkPath) {
    final toolchainPath = _getToolchainPath(ndkPath);
    return path.join(toolchainPath, 'sysroot');
  }

  /// Gets the host tag for the current platform
  String _getHostTag() {
    if (Platform.isWindows) {
      return 'windows-x86_64';
    } else if (Platform.isMacOS) {
      return 'darwin-x86_64';
    } else if (Platform.isLinux) {
      return 'linux-x86_64';
    }
    throw Exception('Unsupported host platform');
  }

  /// Gets the FFMPEG architecture string for the current config
  String _getFFMPEGArch() {
    switch (config.architecture) {
      case Architecture.arm64:
        return 'aarch64';
      case Architecture.armv7:
        return 'arm';
      case Architecture.x86_64:
        return 'x86_64';
      case Architecture.i386:
        return 'i386';
    }
  }

  /// Gets the CPU type for FFMPEG configure
  String _getCPUType() {
    switch (config.architecture) {
      case Architecture.arm64:
        return 'armv8-a';
      case Architecture.armv7:
        return 'armv7-a';
      case Architecture.x86_64:
        return 'x86_64';
      case Architecture.i386:
        return 'i686';
    }
  }

  /// Gets the cross-compilation prefix
  String _getCrossPrefix(String toolchainPath) {
    final binPath = path.join(toolchainPath, 'bin');
    final apiLevel = _getAPILevel();

    switch (config.architecture) {
      case Architecture.arm64:
        return '$binPath/aarch64-linux-android$apiLevel-';
      case Architecture.armv7:
        return '$binPath/armv7a-linux-androideabi$apiLevel-';
      case Architecture.x86_64:
        return '$binPath/x86_64-linux-android$apiLevel-';
      case Architecture.i386:
        return '$binPath/i686-linux-android$apiLevel-';
    }
  }

  /// Gets the minimum API level for the current architecture
  int _getAPILevel() {
    // Use API level 21 as minimum for all architectures
    // This provides good compatibility while supporting modern features
    return 21;
  }

  /// Sets up build environment variables
  Future<void> _setupBuildEnvironment() async {
    final ndkPath = _getAndroidNDKPath()!;
    final toolchainPath = _getToolchainPath(ndkPath);

    // Add NDK toolchain to PATH
    final currentPath = Platform.environment['PATH'] ?? '';
    final binPath = path.join(toolchainPath, 'bin');
    Platform.environment['PATH'] = '$binPath:$currentPath';

    // Set NDK environment variables
    Platform.environment['ANDROID_NDK_HOME'] = ndkPath;
    Platform.environment['TOOLCHAIN'] = toolchainPath;
  }

  /// Strips debug symbols from libraries
  Future<void> _stripLibraries() async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) return;

    print('Stripping debug symbols...');

    final ndkPath = _getAndroidNDKPath()!;
    final toolchainPath = _getToolchainPath(ndkPath);
    final stripTool = path.join(toolchainPath, 'bin', '${_getStripPrefix()}strip');

    await for (final entity in outputDir.list()) {
      if (entity is File && entity.path.endsWith('.so')) {
        final result = await Process.run(stripTool, ['--strip-unneeded', entity.path]);
        if (result.exitCode == 0) {
          print('Stripped ${path.basename(entity.path)}');
        } else {
          print('Warning: Failed to strip ${path.basename(entity.path)}');
        }
      }
    }
  }

  /// Gets the strip tool prefix for the current architecture
  String _getStripPrefix() {
    switch (config.architecture) {
      case Architecture.arm64:
        return 'aarch64-linux-android-';
      case Architecture.armv7:
        return 'arm-linux-androideabi-';
      case Architecture.x86_64:
        return 'x86_64-linux-android-';
      case Architecture.i386:
        return 'i686-linux-android-';
    }
  }

  /// Gets list of generated library files
  Future<List<String>> _getGeneratedFiles() async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in outputDir.list()) {
      if (entity is File && entity.path.endsWith('.so')) {
        files.add(path.basename(entity.path));
      }
    }

    return files;
  }

  /// Builds for all Android architectures
  Future<Map<Architecture, BuildResult>> buildAllArchitectures() async {
    final results = <Architecture, BuildResult>{};
    final architectures = [Architecture.arm64, Architecture.armv7, Architecture.x86_64, Architecture.i386];

    for (final arch in architectures) {
      print('Building for architecture: $arch');

      final archConfig = BuildConfig(
        platform: config.platform,
        architecture: arch,
        isDebug: config.isDebug,
        customFlags: config.customFlags,
        enabledDecoders: config.enabledDecoders,
        enabledDemuxers: config.enabledDemuxers,
      );

      final archBuilder = AndroidBuilder(config: archConfig, sourceDirectory: sourceDirectory, outputDirectory: path.join(outputDirectory, arch.name));

      results[arch] = await archBuilder.build();
    }

    return results;
  }
}
