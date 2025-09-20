// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import '../platform_builder.dart';

/// Windows-specific FFMPEG builder using MSYS2/MinGW-w64
class WindowsBuilder extends PlatformBuilder {
  WindowsBuilder({required super.config, required super.sourceDirectory, required super.outputDirectory});

  @override
  Future<bool> validateEnvironment() async {
    // Check if we're on Windows
    if (!Platform.isWindows) {
      print('Error: Windows builder can only run on Windows');
      return false;
    }

    // Check for MSYS2 installation
    final msys2Paths = ['C:\\msys64', 'C:\\msys2', Platform.environment['MSYS2_PATH'] ?? ''];

    bool msys2Found = false;
    for (final msysPath in msys2Paths) {
      if (msysPath.isNotEmpty && await Directory(msysPath).exists()) {
        print('Found MSYS2 at: $msysPath');
        msys2Found = true;
        break;
      }
    }

    if (!msys2Found) {
      print('Error: MSYS2 not found. Please install MSYS2 from https://www.msys2.org/');
      return false;
    }

    // Set up MSYS2 environment before checking tools
    await _setupMSYS2Environment();

    return await checkRequiredTools();
  }

  @override
  List<String> getRequiredTools() {
    return ['gcc', 'make', 'pkg-config', 'yasm', 'nasm', 'ar'];
  }

  /// Override to check tools in MSYS2 environment
  @override
  Future<bool> checkRequiredTools() async {
    final requiredTools = getRequiredTools();
    final msys2Env = _getMSYS2Environment();

    for (final tool in requiredTools) {
      final result = await Process.run('where', [tool], environment: msys2Env);
      if (result.exitCode != 0) {
        print('Required tool not found: $tool');
        print('Make sure MSYS2 packages are installed: pacman -S mingw-w64-x86_64-$tool');
        return false;
      } else {
        print('Found tool: $tool at ${result.stdout.toString().trim()}');
      }
    }

    return true;
  }

  /// Override to run configure in MSYS2 bash environment
  @override
  Future<ProcessResult> runConfigure() async {
    final configureScript = './configure'; // Use relative path for bash
    final args = generateConfigureArgs();
    final msys2Env = _getMSYS2Environment();

    print('Running configure with args: ${args.join(' ')}');

    // Run configure using MSYS2 bash
    return await Process.run(
      'C:\\msys64\\usr\\bin\\bash.exe',
      ['-c', '$configureScript ${args.join(' ')}'],
      workingDirectory: sourceDirectory,
      environment: msys2Env,
    );
  }

  /// Override to run make in MSYS2 environment
  @override
  Future<ProcessResult> runMake({int? jobs}) async {
    final makeArgs = <String>[];

    if (jobs != null) {
      makeArgs.addAll(['-j', jobs.toString()]);
    }

    final msys2Env = _getMSYS2Environment();

    print('Running make with ${jobs ?? 'default'} jobs...');

    return await Process.run('C:\\msys64\\usr\\bin\\make.exe', makeArgs, workingDirectory: sourceDirectory, environment: msys2Env);
  }

  @override
  List<String> generateConfigureArgs() {
    final baseArgs = getBaseLGPLConfigureArgs();

    final windowsArgs = [
      '--target-os=mingw32',
      '--arch=${_getFFMPEGArch()}',
      '--cross-prefix=${_getCrossPrefix()}',
      '--enable-cross-compile',
      '--pkg-config=pkg-config',
      '--pkg-config-flags=--static',
      '--extra-cflags=-static-libgcc',
      '--extra-ldflags=-static-libgcc',
      '--enable-w32threads',
      '--disable-pthreads',
    ];

    if (config.isDebug) {
      windowsArgs.addAll(['--enable-debug', '--disable-optimizations', '--disable-stripping']);
    } else {
      windowsArgs.addAll(['--disable-debug', '--enable-optimizations', '--enable-stripping']);
    }

    // Add custom flags
    for (final entry in config.customFlags.entries) {
      windowsArgs.add('--${entry.key}=${entry.value}');
    }

    return [...baseArgs, ...windowsArgs];
  }

  @override
  Future<BuildResult> build() async {
    final stopwatch = Stopwatch()..start();

    try {
      print('Starting Windows FFMPEG build...');

      // Validate environment
      if (!await validateEnvironment()) {
        return BuildResult.failure(errorMessage: 'Environment validation failed', buildTime: stopwatch.elapsed);
      }

      // Set up MSYS2 environment
      await _setupMSYS2Environment();

      // Run configure
      print('Configuring FFMPEG for Windows...');
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

      // Verify output
      final generatedFiles = await _getGeneratedFiles();
      if (generatedFiles.isEmpty) {
        return BuildResult.failure(errorMessage: 'No libraries were generated', buildTime: stopwatch.elapsed);
      }

      print('Windows build completed successfully');
      return BuildResult.success(outputPath: outputDirectory, generatedFiles: generatedFiles, buildTime: stopwatch.elapsed);
    } catch (e) {
      return BuildResult.failure(errorMessage: 'Build failed with exception: $e', buildTime: stopwatch.elapsed);
    }
  }

  @override
  String getOutputExtension() => '.dll';

  @override
  String getLibraryPrefix() => '';

  /// Gets the FFMPEG architecture string for the current config
  String _getFFMPEGArch() {
    switch (config.architecture) {
      case Architecture.x86_64:
        return 'x86_64';
      case Architecture.i386:
        return 'i686';
      case Architecture.arm64:
        return 'aarch64';
      case Architecture.armv7:
        return 'armv7';
    }
  }

  /// Gets the cross-compilation prefix
  String _getCrossPrefix() {
    switch (config.architecture) {
      case Architecture.x86_64:
        return 'x86_64-w64-mingw32-';
      case Architecture.i386:
        return 'i686-w64-mingw32-';
      case Architecture.arm64:
        return 'aarch64-w64-mingw32-';
      case Architecture.armv7:
        return 'armv7-w64-mingw32-';
    }
  }

  /// Sets up MSYS2 environment variables
  Future<void> _setupMSYS2Environment() async {
    // We can't modify Platform.environment directly, so we'll handle this in process execution
    print('MSYS2 environment will be set up for build processes');
  }

  /// Gets MSYS2 environment variables for process execution
  Map<String, String> _getMSYS2Environment() {
    final msys2Paths = ['C:\\msys64\\mingw64\\bin', 'C:\\msys64\\usr\\bin', 'C:\\msys2\\mingw64\\bin', 'C:\\msys2\\usr\\bin'];
    final currentPath = Platform.environment['PATH'] ?? '';
    final newPath = '${msys2Paths.where((p) => Directory(p).existsSync()).join(';')};$currentPath';

    return {...Platform.environment, 'PATH': newPath, 'PKG_CONFIG_PATH': 'C:\\msys64\\mingw64\\lib\\pkgconfig'};
  }

  /// Gets list of generated library files
  Future<List<String>> _getGeneratedFiles() async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in outputDir.list()) {
      if (entity is File && entity.path.endsWith('.dll')) {
        files.add(path.basename(entity.path));
      }
    }

    return files;
  }

  /// Installs required MSYS2 packages
  Future<void> installMSYS2Dependencies() async {
    print('Installing MSYS2 dependencies...');

    final packages = ['mingw-w64-x86_64-gcc', 'mingw-w64-x86_64-pkg-config', 'mingw-w64-x86_64-yasm', 'mingw-w64-x86_64-nasm', 'make'];

    for (final package in packages) {
      print('Installing $package...');
      final result = await Process.run('pacman', ['-S', '--noconfirm', package]);
      if (result.exitCode != 0) {
        print('Warning: Failed to install $package: ${result.stderr}');
      }
    }
  }
}
