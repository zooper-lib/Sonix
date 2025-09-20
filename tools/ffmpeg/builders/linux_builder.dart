// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import '../platform_builder.dart';

/// Linux-specific FFMPEG builder using system GCC/Clang
class LinuxBuilder extends PlatformBuilder {
  LinuxBuilder({required super.config, required super.sourceDirectory, required super.outputDirectory});

  @override
  Future<bool> validateEnvironment() async {
    // Check if we're on Linux
    if (!Platform.isLinux) {
      print('Error: Linux builder can only run on Linux');
      return false;
    }

    // Check for essential build tools
    final essentialTools = ['gcc', 'make'];
    for (final tool in essentialTools) {
      final result = await Process.run('which', [tool]);
      if (result.exitCode != 0) {
        print('Error: Essential tool not found: $tool');
        print('Please install build-essential package');
        return false;
      }
    }

    return await checkRequiredTools();
  }

  @override
  List<String> getRequiredTools() {
    return ['gcc', 'make', 'pkg-config', 'yasm', 'nasm'];
  }

  @override
  List<String> generateConfigureArgs() {
    final baseArgs = getBaseLGPLConfigureArgs();

    final linuxArgs = ['--target-os=linux', '--arch=${_getFFMPEGArch()}', '--enable-pthreads', '--disable-w32threads', '--enable-pic'];

    // Detect and use available compiler
    if (_isClangAvailable()) {
      linuxArgs.addAll(['--cc=clang', '--cxx=clang++']);
    } else {
      linuxArgs.addAll(['--cc=gcc', '--cxx=g++']);
    }

    // Architecture-specific flags
    switch (config.architecture) {
      case Architecture.x86_64:
        linuxArgs.addAll(['--extra-cflags=-m64', '--extra-ldflags=-m64']);
        break;
      case Architecture.i386:
        linuxArgs.addAll(['--extra-cflags=-m32', '--extra-ldflags=-m32']);
        break;
      case Architecture.arm64:
        linuxArgs.addAll(['--extra-cflags=-march=armv8-a']);
        break;
      case Architecture.armv7:
        linuxArgs.addAll(['--extra-cflags=-march=armv7-a -mfpu=neon']);
        break;
    }

    if (config.isDebug) {
      linuxArgs.addAll(['--enable-debug', '--disable-optimizations', '--disable-stripping']);
    } else {
      linuxArgs.addAll(['--disable-debug', '--enable-optimizations', '--enable-stripping']);
    }

    // Add custom flags
    for (final entry in config.customFlags.entries) {
      linuxArgs.add('--${entry.key}=${entry.value}');
    }

    return [...baseArgs, ...linuxArgs];
  }

  @override
  Future<BuildResult> build() async {
    final stopwatch = Stopwatch()..start();

    try {
      print('Starting Linux FFMPEG build...');

      // Validate environment
      if (!await validateEnvironment()) {
        return BuildResult.failure(errorMessage: 'Environment validation failed', buildTime: stopwatch.elapsed);
      }

      // Set up build environment
      await _setupBuildEnvironment();

      // Run configure
      print('Configuring FFMPEG for Linux...');
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

      // Set proper permissions and RPATH
      await _fixLibraryPermissions();

      // Verify output
      final generatedFiles = await _getGeneratedFiles();
      if (generatedFiles.isEmpty) {
        return BuildResult.failure(errorMessage: 'No libraries were generated', buildTime: stopwatch.elapsed);
      }

      print('Linux build completed successfully');
      return BuildResult.success(outputPath: outputDirectory, generatedFiles: generatedFiles, buildTime: stopwatch.elapsed);
    } catch (e) {
      return BuildResult.failure(errorMessage: 'Build failed with exception: $e', buildTime: stopwatch.elapsed);
    }
  }

  @override
  String getOutputExtension() => '.so';

  @override
  String getLibraryPrefix() => 'lib';

  /// Gets the FFMPEG architecture string for the current config
  String _getFFMPEGArch() {
    switch (config.architecture) {
      case Architecture.x86_64:
        return 'x86_64';
      case Architecture.i386:
        return 'i386';
      case Architecture.arm64:
        return 'aarch64';
      case Architecture.armv7:
        return 'armv7';
    }
  }

  /// Checks if Clang is available on the system
  bool _isClangAvailable() {
    try {
      final result = Process.runSync('which', ['clang']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Sets up build environment variables
  Future<void> _setupBuildEnvironment() async {
    // Set up PKG_CONFIG_PATH for common locations
    final pkgConfigPaths = [
      '/usr/lib/pkgconfig',
      '/usr/lib/x86_64-linux-gnu/pkgconfig',
      '/usr/lib/aarch64-linux-gnu/pkgconfig',
      '/usr/lib/arm-linux-gnueabihf/pkgconfig',
      '/usr/share/pkgconfig',
      '/usr/local/lib/pkgconfig',
    ];

    final existingPaths = pkgConfigPaths.where((p) => Directory(p).existsSync());
    if (existingPaths.isNotEmpty) {
      Platform.environment['PKG_CONFIG_PATH'] = existingPaths.join(':');
      print('Set PKG_CONFIG_PATH to: ${existingPaths.join(':')}');
    }

    // Set compiler flags for position-independent code
    Platform.environment['CFLAGS'] = '${Platform.environment['CFLAGS'] ?? ''} -fPIC';
    Platform.environment['CXXFLAGS'] = '${Platform.environment['CXXFLAGS'] ?? ''} -fPIC';
  }

  /// Fixes library permissions and sets RPATH
  Future<void> _fixLibraryPermissions() async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) return;

    print('Fixing library permissions...');

    await for (final entity in outputDir.list()) {
      if (entity is File && entity.path.endsWith('.so')) {
        // Set executable permissions
        await Process.run('chmod', ['755', entity.path]);

        // Strip debug symbols in release mode
        if (!config.isDebug) {
          await Process.run('strip', ['--strip-unneeded', entity.path]);
        }

        print('Fixed permissions for ${path.basename(entity.path)}');
      }
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

  /// Installs required dependencies using system package manager
  Future<void> installSystemDependencies() async {
    print('Installing system dependencies...');

    // Detect package manager
    final packageManagers = {
      'apt': ['apt-get', 'install', '-y'],
      'yum': ['yum', 'install', '-y'],
      'dnf': ['dnf', 'install', '-y'],
      'pacman': ['pacman', '-S', '--noconfirm'],
      'zypper': ['zypper', 'install', '-y'],
    };

    String? availableManager;
    for (final manager in packageManagers.keys) {
      final result = await Process.run('which', [manager]);
      if (result.exitCode == 0) {
        availableManager = manager;
        break;
      }
    }

    if (availableManager == null) {
      print('No supported package manager found');
      return;
    }

    print('Using package manager: $availableManager');

    // Package names for different distributions
    final packages = _getPackagesForManager(availableManager);
    final command = packageManagers[availableManager]!;

    for (final package in packages) {
      print('Installing $package...');
      final result = await Process.run(command[0], [...command.sublist(1), package]);
      if (result.exitCode != 0) {
        print('Warning: Failed to install $package: ${result.stderr}');
      }
    }
  }

  /// Gets package names for specific package manager
  List<String> _getPackagesForManager(String manager) {
    switch (manager) {
      case 'apt':
        return ['build-essential', 'pkg-config', 'yasm', 'nasm'];
      case 'yum':
      case 'dnf':
        return ['gcc', 'gcc-c++', 'make', 'pkgconfig', 'yasm', 'nasm'];
      case 'pacman':
        return ['base-devel', 'pkg-config', 'yasm', 'nasm'];
      case 'zypper':
        return ['gcc', 'gcc-c++', 'make', 'pkg-config', 'yasm', 'nasm'];
      default:
        return [];
    }
  }

  /// Detects the Linux distribution
  Future<String> detectDistribution() async {
    try {
      final osReleaseFile = File('/etc/os-release');
      if (await osReleaseFile.exists()) {
        final content = await osReleaseFile.readAsString();
        if (content.contains('Ubuntu') || content.contains('Debian')) {
          return 'debian';
        } else if (content.contains('CentOS') || content.contains('RHEL')) {
          return 'rhel';
        } else if (content.contains('Fedora')) {
          return 'fedora';
        } else if (content.contains('Arch')) {
          return 'arch';
        } else if (content.contains('openSUSE')) {
          return 'opensuse';
        }
      }
    } catch (e) {
      print('Could not detect distribution: $e');
    }

    return 'unknown';
  }
}
