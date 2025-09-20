// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import '../platform_builder.dart';

/// macOS-specific FFMPEG builder using Xcode command line tools
class MacOSBuilder extends PlatformBuilder {
  MacOSBuilder({required super.config, required super.sourceDirectory, required super.outputDirectory});

  @override
  Future<bool> validateEnvironment() async {
    // Check if we're on macOS
    if (!Platform.isMacOS) {
      print('Error: macOS builder can only run on macOS');
      return false;
    }

    // Check for Xcode command line tools
    final xcodeResult = await Process.run('xcode-select', ['-p']);
    if (xcodeResult.exitCode != 0) {
      print('Error: Xcode command line tools not installed');
      print('Please run: xcode-select --install');
      return false;
    }

    print('Xcode command line tools found at: ${xcodeResult.stdout.toString().trim()}');
    return await checkRequiredTools();
  }

  @override
  List<String> getRequiredTools() {
    return ['clang', 'make', 'pkg-config', 'yasm', 'nasm'];
  }

  @override
  List<String> generateConfigureArgs() {
    final baseArgs = getBaseLGPLConfigureArgs();

    final macosArgs = [
      '--target-os=darwin',
      '--arch=${_getFFMPEGArch()}',
      '--cc=clang',
      '--cxx=clang++',
      '--enable-pthreads',
      '--disable-w32threads',
      '--enable-videotoolbox',
      '--enable-audiotoolbox',
    ];

    // Handle universal binary for Apple Silicon and Intel
    if (config.architecture == Architecture.arm64) {
      macosArgs.addAll(['--extra-cflags=-arch arm64 -mmacosx-version-min=11.0', '--extra-ldflags=-arch arm64 -mmacosx-version-min=11.0']);
    } else if (config.architecture == Architecture.x86_64) {
      macosArgs.addAll(['--extra-cflags=-arch x86_64 -mmacosx-version-min=10.15', '--extra-ldflags=-arch x86_64 -mmacosx-version-min=10.15']);
    }

    if (config.isDebug) {
      macosArgs.addAll(['--enable-debug', '--disable-optimizations', '--disable-stripping']);
    } else {
      macosArgs.addAll(['--disable-debug', '--enable-optimizations', '--enable-stripping']);
    }

    // Add custom flags
    for (final entry in config.customFlags.entries) {
      macosArgs.add('--${entry.key}=${entry.value}');
    }

    return [...baseArgs, ...macosArgs];
  }

  @override
  Future<BuildResult> build() async {
    final stopwatch = Stopwatch()..start();

    try {
      print('Starting macOS FFMPEG build...');

      // Validate environment
      if (!await validateEnvironment()) {
        return BuildResult.failure(errorMessage: 'Environment validation failed', buildTime: stopwatch.elapsed);
      }

      // Set up build environment
      await _setupBuildEnvironment();

      // Run configure
      print('Configuring FFMPEG for macOS...');
      final configureResult = await runConfigureMacOS();
      if (configureResult.exitCode != 0) {
        return BuildResult.failure(errorMessage: 'Configure failed: ${configureResult.stderr}', buildTime: stopwatch.elapsed);
      }

      // Run make
      print('Compiling FFMPEG...');
      final makeResult = await runMakeMacOS(jobs: Platform.numberOfProcessors);
      if (makeResult.exitCode != 0) {
        return BuildResult.failure(errorMessage: 'Make failed: ${makeResult.stderr}', buildTime: stopwatch.elapsed);
      }

      // Copy libraries
      print('Copying libraries...');
      await copyLibraries();

      // Fix library install names for macOS
      await _fixLibraryInstallNames();

      // Verify output
      final generatedFiles = await _getGeneratedFiles();
      if (generatedFiles.isEmpty) {
        return BuildResult.failure(errorMessage: 'No libraries were generated', buildTime: stopwatch.elapsed);
      }

      print('macOS build completed successfully');
      return BuildResult.success(outputPath: outputDirectory, generatedFiles: generatedFiles, buildTime: stopwatch.elapsed);
    } catch (e) {
      return BuildResult.failure(errorMessage: 'Build failed with exception: $e', buildTime: stopwatch.elapsed);
    }
  }

  @override
  String getOutputExtension() => '.dylib';

  @override
  String getLibraryPrefix() => 'lib';

  /// Gets the FFMPEG architecture string for the current config
  String _getFFMPEGArch() {
    switch (config.architecture) {
      case Architecture.x86_64:
        return 'x86_64';
      case Architecture.arm64:
        return 'arm64';
      case Architecture.armv7:
        return 'armv7';
      case Architecture.i386:
        return 'i386';
    }
  }

  /// Sets up build environment variables
  Future<void> _setupBuildEnvironment() async {
    // Note: Platform.environment is unmodifiable, so we'll pass environment
    // variables directly to Process.run calls instead of modifying the global environment
    print('Build environment setup completed (environment variables will be passed to processes)');
  }

  /// Gets the build environment variables
  Map<String, String> _getBuildEnvironment() {
    final env = Map<String, String>.from(Platform.environment);

    // Set up PKG_CONFIG_PATH for Homebrew if available
    try {
      final brewPrefixResult = Process.runSync('brew', ['--prefix']);
      if (brewPrefixResult.exitCode == 0) {
        final brewPrefix = brewPrefixResult.stdout.toString().trim();
        final pkgConfigPath = '$brewPrefix/lib/pkgconfig:$brewPrefix/share/pkgconfig';
        env['PKG_CONFIG_PATH'] = pkgConfigPath;
        print('Set PKG_CONFIG_PATH to: $pkgConfigPath');
      }
    } catch (e) {
      // Homebrew not available, continue without it
    }

    // Ensure we use the system clang
    env['CC'] = 'clang';
    env['CXX'] = 'clang++';

    return env;
  }

  /// Fixes library install names for proper dynamic linking on macOS
  Future<void> _fixLibraryInstallNames() async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) return;

    print('Fixing library install names...');

    final dylibFiles = <String>[];
    await for (final entity in outputDir.list()) {
      if (entity is File && entity.path.endsWith('.dylib')) {
        dylibFiles.add(entity.path);
      }
    }

    for (final dylibPath in dylibFiles) {
      final fileName = path.basename(dylibPath);

      // Change install name to @rpath/filename
      final installNameResult = await Process.run('install_name_tool', ['-id', '@rpath/$fileName', dylibPath]);

      if (installNameResult.exitCode != 0) {
        print('Warning: Failed to fix install name for $fileName');
      } else {
        print('Fixed install name for $fileName');
      }

      // Update dependencies to use @rpath
      for (final otherDylib in dylibFiles) {
        if (otherDylib != dylibPath) {
          final otherFileName = path.basename(otherDylib);
          await Process.run('install_name_tool', ['-change', otherDylib, '@rpath/$otherFileName', dylibPath]);
        }
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
      if (entity is File && entity.path.endsWith('.dylib')) {
        files.add(path.basename(entity.path));
      }
    }

    return files;
  }

  /// Installs required dependencies using Homebrew
  Future<void> installBrewDependencies() async {
    print('Installing Homebrew dependencies...');

    final packages = ['pkg-config', 'yasm', 'nasm'];

    // Check if Homebrew is installed
    final brewResult = await Process.run('which', ['brew']);
    if (brewResult.exitCode != 0) {
      print('Homebrew not found. Please install from https://brew.sh/');
      return;
    }

    for (final package in packages) {
      print('Installing $package...');
      final result = await Process.run('brew', ['install', package]);
      if (result.exitCode != 0) {
        print('Warning: Failed to install $package: ${result.stderr}');
      }
    }
  }

  /// Creates a universal binary combining x86_64 and arm64 architectures
  Future<BuildResult> buildUniversal({required String x86OutputDir, required String armOutputDir}) async {
    final stopwatch = Stopwatch()..start();

    try {
      print('Creating universal binary...');

      final universalDir = Directory(path.join(outputDirectory, 'universal'));
      if (await universalDir.exists()) {
        await universalDir.delete(recursive: true);
      }
      await universalDir.create(recursive: true);

      // Get list of libraries from x86_64 build
      final x86Dir = Directory(x86OutputDir);
      final x86Files = <String>[];
      await for (final entity in x86Dir.list()) {
        if (entity is File && entity.path.endsWith('.dylib')) {
          x86Files.add(path.basename(entity.path));
        }
      }

      // Create universal binaries using lipo
      for (final fileName in x86Files) {
        final x86Path = path.join(x86OutputDir, fileName);
        final armPath = path.join(armOutputDir, fileName);
        final universalPath = path.join(universalDir.path, fileName);

        if (await File(armPath).exists()) {
          final lipoResult = await Process.run('lipo', ['-create', x86Path, armPath, '-output', universalPath]);

          if (lipoResult.exitCode != 0) {
            print('Warning: Failed to create universal binary for $fileName');
          } else {
            print('Created universal binary: $fileName');
          }
        }
      }

      return BuildResult.success(outputPath: universalDir.path, generatedFiles: x86Files, buildTime: stopwatch.elapsed);
    } catch (e) {
      return BuildResult.failure(errorMessage: 'Universal binary creation failed: $e', buildTime: stopwatch.elapsed);
    }
  }

  /// Runs the configure script with macOS-specific environment
  Future<ProcessResult> runConfigureMacOS() async {
    final configureScript = path.join(sourceDirectory, 'configure');
    final args = generateConfigureArgs();
    final env = _getBuildEnvironment();

    print('Running configure with args: ${args.join(' ')}');
    print('Configure script path: $configureScript');
    print('Working directory: $sourceDirectory');

    // Use absolute paths to avoid path resolution issues
    final absoluteConfigureScript = path.isAbsolute(configureScript) ? configureScript : path.join(Directory.current.path, configureScript);
    final absoluteSourceDirectory = path.isAbsolute(sourceDirectory) ? sourceDirectory : path.join(Directory.current.path, sourceDirectory);

    return await Process.run(absoluteConfigureScript, args, workingDirectory: absoluteSourceDirectory, environment: env);
  }

  /// Runs make with macOS-specific environment
  Future<ProcessResult> runMakeMacOS({int? jobs}) async {
    final makeArgs = <String>[];

    if (jobs != null) {
      makeArgs.addAll(['-j', jobs.toString()]);
    }

    final env = _getBuildEnvironment();
    print('Running make with ${jobs ?? 'default'} jobs...');

    return await Process.run('make', makeArgs, workingDirectory: sourceDirectory, environment: env);
  }
}
