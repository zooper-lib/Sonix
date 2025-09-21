#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import 'ffmpeg/ffmpeg_builder.dart';
import 'ffmpeg/platform_builder.dart';

/// Main setup script for FFMPEG integration
void main(List<String> arguments) async {
  print('FFMPEG Setup for Sonix');
  print('======================');

  try {
    final setupManager = FFMPEGSetupManager();
    await setupManager.run(arguments);
  } catch (e, stackTrace) {
    print('Setup failed with error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

/// Manages the FFMPEG setup process
class FFMPEGSetupManager {
  static const String defaultWorkingDir = 'build/ffmpeg';
  static const String defaultVersion = '6.1';

  /// Runs the setup process
  Future<void> run(List<String> arguments) async {
    final config = _parseArguments(arguments);

    if (config.showHelp) {
      _printHelp();
      return;
    }

    if (config.showVersion) {
      _printVersion();
      return;
    }

    print('Starting FFMPEG setup...');
    print('Working directory: ${config.workingDirectory}');
    print('FFMPEG version: ${config.version}');
    print('Target platform: ${config.platform?.name ?? 'auto-detect'}');
    print('Verbose: ${config.verbose}');
    print('');

    // Step 1: Detect platform if not specified
    final targetPlatform = config.platform ?? _detectCurrentPlatform();
    final targetArchitecture = config.architecture ?? _detectCurrentArchitecture();

    print('Detected platform: ${targetPlatform.name}');
    print('Detected architecture: ${targetArchitecture.name}');
    print('');

    // Step 2: Validate environment
    print('Validating environment...');
    final envValidation = await _validateEnvironment(targetPlatform);
    if (!envValidation.isValid) {
      print('Environment validation failed: ${envValidation.error}');

      if (config.installDependencies) {
        print('Attempting to install dependencies...');
        await _installDependencies(targetPlatform);
      } else {
        print('Use --install-deps to automatically install dependencies');
        exit(1);
      }
    }

    // Step 3: Create build configuration
    final buildConfig = BuildConfig.release(
      platform: targetPlatform,
      architecture: targetArchitecture,
      customFlags: config.customFlags,
      enabledDecoders: config.enabledDecoders,
      enabledDemuxers: config.enabledDemuxers,
    );

    // Step 4: Build FFMPEG
    print('Building FFMPEG...');
    final builder = FFMPEGBuilder(workingDirectory: config.workingDirectory, version: config.version, verbose: config.verbose);

    final buildResult = await builder.build(buildConfig);

    // Step 5: Handle build result
    if (buildResult.success) {
      print('✓ FFMPEG build completed successfully!');
      print('Output directory: ${buildResult.outputPath}');
      print('Generated files: ${buildResult.generatedFiles.join(', ')}');
      print('Build time: ${buildResult.buildTime.inSeconds} seconds');

      // Step 6: Install libraries to project
      if (config.installToProject) {
        await _installToProject(buildResult.outputPath!, targetPlatform);
      }

      print('');
      print('Setup completed successfully!');
      print('You can now use FFMPEG in your Sonix project.');
    } else {
      print('✗ FFMPEG build failed: ${buildResult.errorMessage}');
      exit(1);
    }
  }

  /// Parses command line arguments
  SetupConfig _parseArguments(List<String> arguments) {
    var workingDirectory = defaultWorkingDir;
    var version = defaultVersion;
    var verbose = false;
    var showHelp = false;
    var showVersion = false;
    var installDependencies = false;
    var installToProject = true;
    TargetPlatform? platform;
    Architecture? architecture;
    final customFlags = <String, String>{};
    var enabledDecoders = <String>['mp3', 'aac', 'flac', 'vorbis', 'opus'];
    var enabledDemuxers = <String>['mp3', 'mp4', 'flac', 'ogg', 'wav'];

    for (var i = 0; i < arguments.length; i++) {
      final arg = arguments[i];

      switch (arg) {
        case '--help':
        case '-h':
          showHelp = true;
          break;
        case '--version':
        case '-v':
          showVersion = true;
          break;
        case '--verbose':
          verbose = true;
          break;
        case '--install-deps':
          installDependencies = true;
          break;
        case '--no-install':
          installToProject = false;
          break;
        case '--working-dir':
          if (i + 1 < arguments.length) {
            workingDirectory = arguments[++i];
          }
          break;
        case '--ffmpeg-version':
          if (i + 1 < arguments.length) {
            version = arguments[++i];
          }
          break;
        case '--platform':
          if (i + 1 < arguments.length) {
            platform = _parsePlatform(arguments[++i]);
          }
          break;
        case '--architecture':
          if (i + 1 < arguments.length) {
            architecture = _parseArchitecture(arguments[++i]);
          }
          break;
        case '--decoders':
          if (i + 1 < arguments.length) {
            enabledDecoders = arguments[++i].split(',');
          }
          break;
        case '--demuxers':
          if (i + 1 < arguments.length) {
            enabledDemuxers = arguments[++i].split(',');
          }
          break;
        default:
          if (arg.startsWith('--')) {
            // Custom flag
            final parts = arg.substring(2).split('=');
            if (parts.length == 2) {
              customFlags[parts[0]] = parts[1];
            }
          }
          break;
      }
    }

    return SetupConfig(
      workingDirectory: workingDirectory,
      version: version,
      verbose: verbose,
      showHelp: showHelp,
      showVersion: showVersion,
      installDependencies: installDependencies,
      installToProject: installToProject,
      platform: platform,
      architecture: architecture,
      customFlags: customFlags,
      enabledDecoders: enabledDecoders,
      enabledDemuxers: enabledDemuxers,
    );
  }

  /// Parses platform string
  TargetPlatform? _parsePlatform(String platformStr) {
    switch (platformStr.toLowerCase()) {
      case 'windows':
        return TargetPlatform.windows;
      case 'macos':
        return TargetPlatform.macos;
      case 'linux':
        return TargetPlatform.linux;
      case 'android':
        return TargetPlatform.android;
      case 'ios':
        return TargetPlatform.ios;
      default:
        print('Warning: Unknown platform: $platformStr');
        return null;
    }
  }

  /// Parses architecture string
  Architecture? _parseArchitecture(String archStr) {
    switch (archStr.toLowerCase()) {
      case 'x86_64':
      case 'x64':
        return Architecture.x86_64;
      case 'arm64':
      case 'aarch64':
        return Architecture.arm64;
      case 'armv7':
      case 'arm':
        return Architecture.armv7;
      case 'i386':
      case 'x86':
        return Architecture.i386;
      default:
        print('Warning: Unknown architecture: $archStr');
        return null;
    }
  }

  /// Detects current platform
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

  /// Detects current architecture
  Architecture _detectCurrentArchitecture() {
    // This is a simplified detection - in practice, you might want more sophisticated detection
    if (Platform.version.contains('x64') || Platform.version.contains('x86_64')) {
      return Architecture.x86_64;
    } else if (Platform.version.contains('arm64') || Platform.version.contains('aarch64')) {
      return Architecture.arm64;
    } else {
      return Architecture.x86_64; // Default fallback
    }
  }

  /// Validates build environment
  Future<ValidationResult> _validateEnvironment(TargetPlatform platform) async {
    try {
      // Create a temporary builder to validate environment
      final tempConfig = BuildConfig.release(
        platform: platform,
        architecture: Architecture.x86_64, // Doesn't matter for validation
      );

      final builder = PlatformBuilder.create(config: tempConfig, sourceDirectory: '', outputDirectory: '');

      final isValid = await builder.validateEnvironment();
      if (isValid) {
        return ValidationResult.valid();
      } else {
        return ValidationResult.invalid('Platform builder validation failed');
      }
    } catch (e) {
      return ValidationResult.invalid('Environment validation error: $e');
    }
  }

  /// Installs platform-specific dependencies
  Future<void> _installDependencies(TargetPlatform platform) async {
    print('Installing dependencies for ${platform.name}...');

    try {
      switch (platform) {
        case TargetPlatform.windows:
          await _installWindowsDependencies();
          break;
        case TargetPlatform.macos:
          await _installMacOSDependencies();
          break;
        case TargetPlatform.linux:
          await _installLinuxDependencies();
          break;
        case TargetPlatform.android:
          await _installAndroidDependencies();
          break;
        case TargetPlatform.ios:
          await _installIOSDependencies();
          break;
      }

      print('Dependencies installed successfully');
    } catch (e) {
      print('Failed to install dependencies: $e');
      print('Please install dependencies manually');
    }
  }

  /// Installs Windows dependencies
  Future<void> _installWindowsDependencies() async {
    print('Installing MSYS2 and build tools...');

    try {
      // Check if MSYS2 is already installed
      final msys2Paths = ['C:\\msys64', 'C:\\msys2', Platform.environment['MSYS2_PATH'] ?? ''];

      bool msys2Found = false;
      String? msys2Path;
      for (final path in msys2Paths) {
        if (path.isNotEmpty && await Directory(path).exists()) {
          msys2Found = true;
          msys2Path = path;
          print('Found existing MSYS2 at: $path');
          break;
        }
      }

      if (!msys2Found) {
        print('Installing MSYS2...');

        // Try winget first (most reliable)
        try {
          print('Using Windows Package Manager (winget)...');
          final wingetResult = await Process.run('winget', ['install', 'MSYS2.MSYS2', '--accept-package-agreements', '--accept-source-agreements', '--silent']);
          if (wingetResult.exitCode == 0) {
            print('✓ MSYS2 installed successfully!');
            msys2Path = 'C:\\msys64';
          } else {
            throw Exception('Winget installation failed');
          }
        } catch (e) {
          print('Winget failed, trying alternative method...');
          await _downloadAndInstallMSYS2();
          msys2Path = 'C:\\msys64';
        }
      }

      // Install required packages
      print('Installing build packages...');
      await _installMSYS2Packages(msys2Path!);

      print('MSYS2 and build tools installed successfully!');
      print('Note: You may need to restart your terminal for PATH changes to take effect.');
    } catch (e) {
      print('Failed to install MSYS2 automatically: $e');
      print('Please install MSYS2 manually from https://www.msys2.org/');
      print('Then run: pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-pkg-config mingw-w64-x86_64-yasm mingw-w64-x86_64-nasm make');
    }
  }

  /// Downloads and installs MSYS2
  Future<void> _downloadAndInstallMSYS2() async {
    // MSYS2 installer URL (latest version)
    const installerUrl = 'https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe';
    final tempDir = Directory.systemTemp;
    final installerPath = path.join(tempDir.path, 'msys2-installer.exe');

    print('Downloading MSYS2 installer...');

    // Download the installer
    final downloadResult = await Process.run('powershell', ['-Command', 'Invoke-WebRequest -Uri "$installerUrl" -OutFile "$installerPath"']);

    if (downloadResult.exitCode != 0) {
      throw Exception('Failed to download MSYS2 installer: ${downloadResult.stderr}');
    }

    print('Running MSYS2 installer...');

    // Run the installer silently
    final installResult = await Process.run(installerPath, ['install', '--confirm-command', '--accept-messages', '--root', 'C:\\msys64']);

    if (installResult.exitCode != 0) {
      // Try alternative installation method
      print('Trying alternative installation method...');
      final altInstallResult = await Process.run('powershell', [
        '-Command',
        'Start-Process -FilePath "$installerPath" -ArgumentList "install --confirm-command --accept-messages --root C:\\msys64" -Wait',
      ]);

      if (altInstallResult.exitCode != 0) {
        throw Exception('Failed to install MSYS2: ${altInstallResult.stderr}');
      }
    }

    // Clean up installer
    try {
      await File(installerPath).delete();
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Installs required packages in MSYS2
  Future<void> _installMSYS2Packages(String msys2Path) async {
    final pacmanPath = path.join(msys2Path, 'usr', 'bin', 'pacman.exe');

    if (!await File(pacmanPath).exists()) {
      throw Exception('Pacman not found at: $pacmanPath');
    }

    final packages = [
      'mingw-w64-x86_64-toolchain', // Complete toolchain including ar, ranlib, etc.
      'mingw-w64-x86_64-pkg-config',
      'mingw-w64-x86_64-yasm',
      'mingw-w64-x86_64-nasm',
      'make',
    ];

    // Update package database first
    print('Updating MSYS2 package database...');
    final updateResult = await Process.run(pacmanPath, ['-Sy', '--noconfirm']);
    if (updateResult.exitCode != 0) {
      print('Warning: Failed to update package database: ${updateResult.stderr}');
    }

    // Install packages
    for (final package in packages) {
      print('Installing $package...');
      final result = await Process.run(pacmanPath, ['-S', '--noconfirm', package]);
      if (result.exitCode != 0) {
        print('Warning: Failed to install $package: ${result.stderr}');
      } else {
        print('Successfully installed $package');
      }
    }
  }

  /// Installs macOS dependencies
  Future<void> _installMacOSDependencies() async {
    // Try to install via Homebrew
    final brewResult = await Process.run('which', ['brew']);
    if (brewResult.exitCode == 0) {
      await Process.run('brew', ['install', 'pkg-config', 'yasm', 'nasm']);
    } else {
      print('Please install Homebrew from https://brew.sh/');
      print('Then run: brew install pkg-config yasm nasm');
    }
  }

  /// Installs Linux dependencies
  Future<void> _installLinuxDependencies() async {
    // Try to detect package manager and install
    final packageManagers = ['apt-get', 'yum', 'dnf', 'pacman', 'zypper'];

    for (final pm in packageManagers) {
      final result = await Process.run('which', [pm]);
      if (result.exitCode == 0) {
        switch (pm) {
          case 'apt-get':
            await Process.run('sudo', ['apt-get', 'install', '-y', 'build-essential', 'pkg-config', 'yasm', 'nasm']);
            break;
          case 'yum':
          case 'dnf':
            await Process.run('sudo', [pm, 'install', '-y', 'gcc', 'gcc-c++', 'make', 'pkgconfig', 'yasm', 'nasm']);
            break;
          case 'pacman':
            await Process.run('sudo', ['pacman', '-S', '--noconfirm', 'base-devel', 'pkg-config', 'yasm', 'nasm']);
            break;
          case 'zypper':
            await Process.run('sudo', ['zypper', 'install', '-y', 'gcc', 'gcc-c++', 'make', 'pkg-config', 'yasm', 'nasm']);
            break;
        }
        return;
      }
    }

    print('Could not detect package manager. Please install build tools manually.');
  }

  /// Installs Android dependencies
  Future<void> _installAndroidDependencies() async {
    print('Please ensure Android NDK is installed and ANDROID_NDK_HOME is set');
    print('Download from: https://developer.android.com/ndk/downloads');
  }

  /// Installs iOS dependencies
  Future<void> _installIOSDependencies() async {
    print('Please ensure Xcode is installed');
    print('Run: xcode-select --install');
  }

  /// Installs built libraries to project
  Future<void> _installToProject(String outputPath, TargetPlatform platform) async {
    print('Installing libraries to project...');

    final projectNativeDir = path.join('native', platform.name);
    await Directory(projectNativeDir).create(recursive: true);

    final outputDir = Directory(outputPath);
    await for (final entity in outputDir.list()) {
      if (entity is File) {
        final fileName = path.basename(entity.path);
        final targetPath = path.join(projectNativeDir, fileName);
        await entity.copy(targetPath);
        print('Installed: $fileName');
      }
    }

    // Provide user guidance for testing
    _printTestingInstructions(platform);
  }

  /// Prints instructions for testing the built libraries
  void _printTestingInstructions(TargetPlatform platform) async {
    print('');
    print('📋 TESTING INSTRUCTIONS');
    print('======================');
    print('FFMPEG libraries have been installed to native/${platform.name}/');
    print('');
    print('To test with your Flutter app:');
    print('');
    print('1. Build the native library:');
    switch (platform) {
      case TargetPlatform.windows:
        print('   cd native && build.bat');
        break;
      case TargetPlatform.macos:
      case TargetPlatform.linux:
        print('   cd native && ./build.sh');
        break;
      case TargetPlatform.android:
        print('   cd native && ./build.sh android');
        break;
      case TargetPlatform.ios:
        print('   cd native && ./build.sh ios');
        break;
    }
    print('');
    print('2. Copy DLLs to Flutter app directory when testing:');
    switch (platform) {
      case TargetPlatform.windows:
        print('   For example app testing:');
        print('   - Copy native/windows/*.dll to example/build/windows/x64/runner/Debug/');
        print('   - Or copy to example/ directory for quick testing');
        print('');
        print('   For unit tests:');
        print('   - Copy native/windows/*.dll to test/ directory');
        print('   - Or copy sonix_native.dll to project root');
        break;
      case TargetPlatform.macos:
        print('   For example app testing:');
        print('   - Copy native/macos/*.dylib to example/build/macos/Build/Products/Debug/');
        print('   - Or copy to example/ directory for quick testing');
        print('');
        print('   For unit tests:');
        print('   - Copy native/macos/*.dylib to test/ directory');
        break;
      case TargetPlatform.linux:
        print('   For example app testing:');
        print('   - Copy native/linux/*.so to example/build/linux/x64/debug/bundle/lib/');
        print('   - Or copy to example/ directory for quick testing');
        print('');
        print('   For unit tests:');
        print('   - Copy native/linux/*.so to test/ directory');
        break;
      case TargetPlatform.android:
        print('   Android libraries are automatically bundled during build');
        break;
      case TargetPlatform.ios:
        print('   iOS libraries are automatically bundled during build');
        break;
    }
    print('');
    print('3. Run your Flutter app or tests');
    print('');
    print('💡 TIP: The build script will place sonix_native.dll in the build directory,');
    print('   but you need to manually copy the FFMPEG DLLs for testing.');
  }

  /// Prints help information
  void _printHelp() {
    print('''
FFMPEG Setup for Sonix

Usage: dart run tools/setup_ffmpeg.dart [options]

This tool builds FFMPEG libraries and installs them to native/[platform]/ directory.
After building, you'll need to manually copy DLLs to test/build directories for testing.

Options:
  -h, --help                Show this help message
  -v, --version             Show version information
  --verbose                 Enable verbose output
  --install-deps            Automatically install dependencies
  --no-install              Don't install libraries to project
  --working-dir <dir>       Set working directory (default: $defaultWorkingDir)
  --ffmpeg-version <ver>    Set FFMPEG version (default: $defaultVersion)
  --platform <platform>     Target platform (windows|macos|linux|android|ios)
  --architecture <arch>     Target architecture (x86_64|arm64|armv7|i386)
  --decoders <list>         Comma-separated list of decoders to enable
  --demuxers <list>         Comma-separated list of demuxers to enable

Examples:
  dart run tools/setup_ffmpeg.dart
  dart run tools/setup_ffmpeg.dart --platform windows --architecture x86_64
  dart run tools/setup_ffmpeg.dart --verbose --install-deps
  dart run tools/setup_ffmpeg.dart --decoders mp3,aac,flac --demuxers mp3,mp4

Workflow:
1. Run this tool to build and install FFMPEG libraries
2. Build the native library: cd native && build.bat (Windows) or ./build.sh (Unix)
3. Copy DLLs to Flutter build directories or test directory for testing
4. The tool will show you exactly which files to copy and where
''');
  }

  /// Prints version information
  void _printVersion() {
    print('FFMPEG Setup for Sonix v1.0.0');
    print('Default FFMPEG version: $defaultVersion');
  }
}

/// Setup configuration
class SetupConfig {
  final String workingDirectory;
  final String version;
  final bool verbose;
  final bool showHelp;
  final bool showVersion;
  final bool installDependencies;
  final bool installToProject;
  final TargetPlatform? platform;
  final Architecture? architecture;
  final Map<String, String> customFlags;
  final List<String> enabledDecoders;
  final List<String> enabledDemuxers;

  const SetupConfig({
    required this.workingDirectory,
    required this.version,
    required this.verbose,
    required this.showHelp,
    required this.showVersion,
    required this.installDependencies,
    required this.installToProject,
    required this.platform,
    required this.architecture,
    required this.customFlags,
    required this.enabledDecoders,
    required this.enabledDemuxers,
  });
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult._(this.isValid, this.error);

  factory ValidationResult.valid() => const ValidationResult._(true, null);
  factory ValidationResult.invalid(String error) => ValidationResult._(false, error);
}
