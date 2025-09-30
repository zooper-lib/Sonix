#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';

/// Quick development build script for Sonix native library
///
/// This script is for DEVELOPMENT ONLY - it builds the native library
/// for local testing and development in the native/build/ directory.
///
/// For package distribution builds, use:
/// dart run tools/build_native_for_distribution.dart
///
class NativeDevelopmentBuilder {
  /// Main entry point
  Future<void> run(List<String> arguments) async {
    try {
      final options = _parseArguments(arguments);

      if (options['help'] == true) {
        _printUsage();
        return;
      }

      if (options['clean'] == true) {
        await _cleanBuild();
        return;
      }

      await _buildForDevelopment(options);
    } catch (e) {
      print('❌ Build failed: $e');
      exit(1);
    }
  }

  /// Builds the native library for development
  Future<void> _buildForDevelopment(Map<String, dynamic> options) async {
    final verbose = options['verbose'] as bool? ?? false;
    final buildType = options['build-type'] as String? ?? 'Release';

    print('Sonix Native Development Builder');
    print('===============================');
    print('');
    print('📝 NOTE: This is a development build for local testing.');
    print('   For package distribution builds, use:');
    print('   dart run tools/build_native_for_distribution.dart');
    print('');

    // Detect platform
    final platform = _getCurrentPlatform();
    print('Platform: $platform');
    print('Build type: $buildType');
    print('');

    // Validate prerequisites
    print('Validating build environment...');
    final validationResult = await _validateBuildEnvironment();
    if (!validationResult) {
      print('❌ Build environment validation failed');
      exit(1);
    }
    print('✅ Build environment validated');
    print('');

    // Create platform-specific build directory
    final buildDir = 'build/sonix/$platform';
    await _createBuildDirectory(buildDir);

    // Configure with CMake
    print('Configuring with CMake...');
    final configArgs = _getCMakeConfigArgs(platform, buildType);

    if (verbose) {
      print('CMake command: cmake ${configArgs.join(' ')}');
    }

    final configResult = await Process.run('cmake', configArgs);

    if (configResult.exitCode != 0) {
      print('❌ CMake configuration failed:');
      print(configResult.stderr);
      exit(1);
    }

    if (verbose) {
      print('CMake configuration output:');
      print(configResult.stdout);
    }

    print('✅ Configuration completed');
    print('');

    // Build
    print('Building native library...');
    final buildArgs = _getCMakeBuildArgs(platform, buildType);

    if (verbose) {
      print('Build command: cmake ${buildArgs.join(' ')}');
    }

    final buildResult = await Process.run('cmake', buildArgs);

    if (buildResult.exitCode != 0) {
      print('❌ Build failed:');
      print(buildResult.stderr);
      exit(1);
    }

    if (verbose) {
      print('Build output:');
      print(buildResult.stdout);
    }

    print('✅ Build completed successfully!');
    print('');

    // Show built files
    await _showBuiltFiles(buildDir, platform);

    // Copy the built library to runtime locations
    print('');
    await _copyBuiltLibraryToRuntimeLocations(buildDir, platform, buildType);

    print('');
    print('🎉 Development build completed!');
    print('');
    print('Next steps:');
    print('1. Test your changes with the example app');
    print('2. Run unit tests: flutter test');
    print('3. For distribution builds: dart run tools/build_native_for_distribution.dart');
  }

  /// Validates the build environment
  Future<bool> _validateBuildEnvironment() async {
    // Check CMake
    try {
      final cmakeResult = await Process.run('cmake', ['--version']);
      if (cmakeResult.exitCode != 0) {
        print('❌ CMake not found. Please install CMake 3.10 or later.');
        return false;
      }
    } catch (e) {
      print('❌ CMake not found. Please install CMake 3.10 or later.');
      return false;
    }

    // Check if we're in the right directory
    if (!await File('native/CMakeLists.txt').exists()) {
      print('❌ CMakeLists.txt not found in native/ directory.');
      print('   Make sure you\'re running this from the Sonix package root.');
      return false;
    }

    // Check FFMPEG binaries (optional for development)
    final platform = _getCurrentPlatform();
    final ffmpegDir = 'build/ffmpeg/$platform';
    if (!await Directory(ffmpegDir).exists()) {
      print('⚠️  FFMPEG binaries not found in $ffmpegDir');
      print('   Run: dart run tools/download_ffmpeg_binaries.dart');
      print('   Continuing anyway (build may fail if FFMPEG is required)...');
    }

    return true;
  }

  /// Gets CMake configuration arguments for the platform
  List<String> _getCMakeConfigArgs(String platform, String buildType) {
    final args = ['-S', 'native', '-B', 'build/sonix/$platform', '-DCMAKE_BUILD_TYPE=$buildType'];

    // Add platform-specific configuration
    switch (platform) {
      case 'windows':
        args.addAll(['-G', 'Visual Studio 17 2022', '-A', 'x64']);
        break;
      case 'linux':
      case 'macos':
        // Use default generator (Make or Ninja)
        break;
    }

    // Add FFMPEG path if available
    final ffmpegDir = Directory('build/ffmpeg/$platform');
    if (ffmpegDir.existsSync()) {
      args.add('-DFFMPEG_ROOT=build/ffmpeg/$platform');
    }

    return args;
  }

  /// Gets CMake build arguments for the platform
  List<String> _getCMakeBuildArgs(String platform, String buildType) {
    final args = ['--build', 'build/sonix/$platform'];

    // Add platform-specific build options
    switch (platform) {
      case 'windows':
        args.addAll(['--config', buildType]);
        break;
      case 'linux':
      case 'macos':
        // Parallel build
        final cores = _getProcessorCount();
        args.addAll(['--parallel', cores.toString()]);
        break;
    }

    return args;
  }

  /// Gets the number of processor cores for parallel builds
  int _getProcessorCount() {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final result = Process.runSync('nproc', []);
        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim()) ?? 4;
        }
      }
      if (Platform.isMacOS) {
        final result = Process.runSync('sysctl', ['-n', 'hw.ncpu']);
        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim()) ?? 4;
        }
      }
    } catch (e) {
      // Fallback to 4 cores
    }
    return 4;
  }

  /// Shows the built files
  Future<void> _showBuiltFiles(String buildDir, String platform) async {
    print('Built files:');

    final extensions = _getLibraryExtensions(platform);
    bool foundFiles = false;

    for (final ext in extensions) {
      final files = await _findFilesWithExtension(buildDir, ext);
      for (final file in files) {
        final stat = await file.stat();
        final size = _formatFileSize(stat.size);
        print('  ✅ ${file.path} ($size)');
        foundFiles = true;
      }
    }

    if (!foundFiles) {
      print('  ⚠️  No library files found. Build may have failed.');
    }

    print('');
    print('Build directory: ${Directory(buildDir).absolute.path}');
  }

  /// Copies the built native library to runtime locations
  Future<void> _copyBuiltLibraryToRuntimeLocations(String buildDir, String platform, String buildType) async {
    print('Copying native library to runtime locations...');

    final libraryName = _getLibraryName(platform);
    final sourcePath = _getBuiltLibraryPath(buildDir, platform, buildType, libraryName);
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      print('⚠️  Built library not found: $sourcePath');
      return;
    }

    final targetLocations = _getRuntimeLibraryLocations(platform);
    bool anySuccess = false;

    for (final targetLocation in targetLocations) {
      try {
        final targetDir = Directory(targetLocation);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        final targetFile = File('$targetLocation/$libraryName');
        await sourceFile.copy(targetFile.path);

        final size = _formatFileSize(await sourceFile.length());
        print('  ✅ Copied to: $targetLocation ($size)');
        anySuccess = true;

        // On macOS, fix up install names so FFmpeg dylibs resolve within the bundle
        if (platform == 'macos') {
          // Ensure FFmpeg dylibs are present in the same directory
          await _copyMacOSFFmpegLibs(targetLocation);
          // Then fix install names for both libsonix_native and ffmpeg dylibs
          await _fixMacOSInstallNames(targetLocation, libraryName);
          // Finally, code-sign the modified binaries and app bundle
          await _codesignMacOSArtifacts(targetLocation);
        }
      } catch (e) {
        print('  ⚠️  Failed to copy to $targetLocation: $e');
      }
    }

    if (anySuccess) {
      print('✅ Native library deployed to runtime locations');
    } else {
      print('⚠️  Failed to deploy native library to any runtime location');
    }
  }

  /// Code-sign dylibs we modified and the enclosing app bundle (ad-hoc), to satisfy macOS dyld
  Future<void> _codesignMacOSArtifacts(String targetDir) async {
    try {
      // Ensure codesign exists
      final which = Process.runSync('which', ['codesign']);
      if (which.exitCode != 0) return;

      // Find app bundle root from targetDir (look upwards for *.app)
      String? appBundlePath;
      var dir = Directory(targetDir).absolute;
      for (int i = 0; i < 8; i++) {
        final name = dir.path.split('/').last;
        if (name.endsWith('.app')) {
          appBundlePath = dir.path;
          break;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }

      // First, sign all dylibs inside targetDir
      final d = Directory(targetDir);
      await for (final entity in d.list()) {
        if (entity is File && entity.path.endsWith('.dylib')) {
          await Process.run('codesign', ['--force', '--timestamp=none', '--sign', '-', entity.path]);
        }
      }

      // Then, sign the app bundle (deep) so its code signature reflects nested changes
      if (appBundlePath != null) {
        await Process.run('codesign', ['--force', '--deep', '--timestamp=none', '--sign', '-', appBundlePath]);
      }
    } catch (e) {
      print('  ⚠️  Failed to code-sign macOS artifacts in $targetDir: $e');
    }
  }

  /// Copy FFmpeg dylibs into the specified macOS target directory
  Future<void> _copyMacOSFFmpegLibs(String targetDir) async {
    final sourceLibDir = Directory('build/ffmpeg/macos/lib');
    if (!await sourceLibDir.exists()) return;

    final bases = ['libavformat', 'libavcodec', 'libavutil', 'libswresample'];
    for (final base in bases) {
      // Prefer generic name
      File src = File('${sourceLibDir.path}/$base.dylib');
      if (!await src.exists()) {
        // Pick first versioned dylib
        final match = sourceLibDir
            .listSync()
            .whereType<File>()
            .firstWhere((f) => f.path.split('/').last.startsWith(base) && f.path.endsWith('.dylib'), orElse: () => File(''));
        if (match.path.isNotEmpty) {
          src = match;
        }
      }
      if (await src.exists()) {
        final dst = File('$targetDir/$base.dylib');
        await src.copy(dst.path);
      }
    }
  }

  /// macOS: Use install_name_tool to rewrite absolute Homebrew paths to @rpath and set IDs
  Future<void> _fixMacOSInstallNames(String targetDir, String libraryName) async {
    try {
      // Ensure tool exists
      final which = Process.runSync('which', ['install_name_tool']);
      if (which.exitCode != 0) return;

      final dylibPath = '$targetDir/$libraryName';
      final dylibFile = File(dylibPath);
      if (!await dylibFile.exists()) return;

      // Helper to parse dependencies from otool -L
      Future<List<String>> depsOf(String path) async {
        final res = await Process.run('otool', ['-L', path]);
        if (res.exitCode != 0) return [];
        final lines = res.stdout.toString().split('\n');
        final deps = <String>[];
        for (final line in lines.skip(1)) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final space = trimmed.indexOf(' ');
          final name = space > 0 ? trimmed.substring(0, space) : trimmed;
          if (name.endsWith('.dylib')) deps.add(name);
        }
        return deps;
      }

      // Discover Homebrew prefix if available (used to replace @@HOMEBREW_PREFIX@@)
      String? brewPrefix;
      try {
        var bp = Process.runSync('brew', ['--prefix']);
        if (bp.exitCode == 0) {
          brewPrefix = (bp.stdout as String).trim();
        }
        if (brewPrefix == null || brewPrefix.isEmpty) {
          // Try common path on Apple Silicon
          bp = Process.runSync('/opt/homebrew/bin/brew', ['--prefix']);
          if (bp.exitCode == 0) {
            brewPrefix = (bp.stdout as String).trim();
          }
        }
      } catch (_) {}
      // Fallback defaults
      if (brewPrefix == null || brewPrefix.isEmpty) {
        // Detect arch to choose default Homebrew location
        final uname = Process.runSync('uname', ['-m']);
        final m = uname.exitCode == 0 ? (uname.stdout as String).trim().toLowerCase() : '';
        if (m.contains('arm64') || m.contains('aarch64')) {
          brewPrefix = '/opt/homebrew';
        } else {
          brewPrefix = '/usr/local';
        }
      }

      bool _isSystemLib(String p) {
        return p.startsWith('/usr/lib/') ||
            p.startsWith('/System/Library/') ||
            p.startsWith('/System/Volumes/Preboot/');
      }

      bool _isFfmpegLibBase(String base) {
        return base.startsWith('libav') || base.startsWith('libswresample');
      }

      // Fix libsonix_native dependencies to @rpath for FFmpeg libs; replace Homebrew placeholders when present.
      final deps = await depsOf(dylibPath);
      for (final dep in deps) {
        // If a core system lib was accidentally rewritten to @rpath, correct it back
        if (dep.endsWith('libSystem.B.dylib') && !dep.startsWith('/usr/lib/')) {
          await Process.run('install_name_tool', ['-change', dep, '/usr/lib/libSystem.B.dylib', dylibPath]);
          continue;
        }
        if (dep.endsWith('libobjc.A.dylib') && !dep.startsWith('/usr/lib/')) {
          await Process.run('install_name_tool', ['-change', dep, '/usr/lib/libobjc.A.dylib', dylibPath]);
          continue;
        }
        // Skip already-correct rpath/system libs
        if (dep.startsWith('@rpath') || _isSystemLib(dep)) continue;

        final base = dep.split('/').last;
        final genericBase = base.replaceAll(RegExp(r"\.[0-9]+(?=\.dylib$)"), '');

        if (_isFfmpegLibBase(genericBase)) {
          // FFmpeg deps should resolve via @rpath within the bundle
          final newName = '@rpath/$genericBase';
          await Process.run('install_name_tool', ['-change', dep, newName, dylibPath]);
          continue;
        }

        if (dep.contains('@@HOMEBREW_PREFIX@@') && brewPrefix.isNotEmpty) {
          // Replace placeholder with actual Homebrew prefix for dev machine
          final newName = dep.replaceAll('@@HOMEBREW_PREFIX@@', brewPrefix);
          await Process.run('install_name_tool', ['-change', dep, newName, dylibPath]);
          continue;
        }

        // Otherwise, leave dependency as-is (do not accidentally rewrite system libs like libSystem.B.dylib)
      }

      // Also patch FFmpeg dylibs in same directory
      final dir = Directory(targetDir);
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.dylib') && entity.path.contains(RegExp('libav|libswresample'))) {
          final path = entity.path;
          // Set their ID to @rpath/<basename>
          final base = path.split('/').last;
          final genericBase = base.replaceAll(RegExp(r"\.[0-9]+(?=\.dylib$)"), '');
          await Process.run('install_name_tool', ['-id', '@rpath/$genericBase', path]);
          // Rewrite any ffmpeg deps inside them to @rpath as well; replace Homebrew placeholders if needed
          final innerDeps = await depsOf(path);
          for (final dep in innerDeps) {
            // Correct core system libs if they were rewritten to @rpath
            if (dep.endsWith('libSystem.B.dylib') && !dep.startsWith('/usr/lib/')) {
              await Process.run('install_name_tool', ['-change', dep, '/usr/lib/libSystem.B.dylib', path]);
              continue;
            }
            if (dep.endsWith('libobjc.A.dylib') && !dep.startsWith('/usr/lib/')) {
              await Process.run('install_name_tool', ['-change', dep, '/usr/lib/libobjc.A.dylib', path]);
              continue;
            }
            if (dep.startsWith('@rpath') || _isSystemLib(dep)) continue;

            final depBase = dep.split('/').last;
            final depGeneric = depBase.replaceAll(RegExp(r"\.[0-9]+(?=\.dylib$)"), '');

            if (_isFfmpegLibBase(depGeneric)) {
              final newDep = '@rpath/$depGeneric';
              await Process.run('install_name_tool', ['-change', dep, newDep, path]);
              continue;
            }

            if (dep.contains('@@HOMEBREW_PREFIX@@') && brewPrefix.isNotEmpty) {
              final newDep = dep.replaceAll('@@HOMEBREW_PREFIX@@', brewPrefix);
              await Process.run('install_name_tool', ['-change', dep, newDep, path]);
              continue;
            }

            // Otherwise leave as-is
          }
        }
      }

      // After normalizing, bundle Homebrew-linked dependencies for FFmpeg libs so the app is self-contained
  await _bundleMacOSHomebrewDeps(targetDir, brewPrefix);
    } catch (e) {
      print('  ⚠️  Failed to fix macOS install names in $targetDir: $e');
    }
  }

  /// Recursively bundle Homebrew-installed dylibs referenced by FFmpeg libs into targetDir
  Future<void> _bundleMacOSHomebrewDeps(String targetDir, String brewPrefix) async {
    try {
      final dir = Directory(targetDir);
      final ffmpegLibs = <String>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.dylib') && entity.path.contains(RegExp('libav|libswresample'))) {
          ffmpegLibs.add(entity.path);
        }
      }

      final visited = <String>{};
      for (final lib in ffmpegLibs) {
        print('  🔧 Bundling Homebrew deps for ${lib.split('/').last}');
        await _bundleDepsForFile(lib, targetDir, brewPrefix, visited);
      }
    } catch (e) {
      print('  ⚠️  Failed to bundle Homebrew dependencies in $targetDir: $e');
    }
  }

  Future<void> _bundleDepsForFile(
    String filePath,
    String targetDir,
    String brewPrefix,
    Set<String> visited,
  ) async {
    // Helper: parse deps
    Future<List<String>> depsOf(String path) async {
      final res = await Process.run('otool', ['-L', path]);
      if (res.exitCode != 0) return [];
      final lines = res.stdout.toString().split('\n');
      final deps = <String>[];
      for (final line in lines.skip(1)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final space = trimmed.indexOf(' ');
        final name = space > 0 ? trimmed.substring(0, space) : trimmed;
        if (name.endsWith('.dylib')) deps.add(name);
      }
      return deps;
    }

  bool isSystem(String p) => p.startsWith('/usr/lib/') || p.startsWith('/System/');
  bool isRpath(String p) => p.startsWith('@rpath');

    final deps = await depsOf(filePath);
    for (final dep in deps) {
      // Debug: show each dependency discovered
      print('    • Found dep: $dep');
      if (isSystem(dep)) {
        print('      ↳ Skipping (rpath/system)');
        continue;
      }

      // If the dependency is already an @rpath reference, ensure the target exists in our bundle.
      if (isRpath(dep)) {
        final baseName = dep.split('/').last; // e.g. libsharpyuv.0.dylib
        final destPath = '$targetDir/$baseName';
        final destFile = File(destPath);
        if (await destFile.exists()) {
          print('      ↳ @rpath target already present in bundle');
        } else {
          final located = await _locateHomebrewLibrary(brewPrefix, baseName);
          if (located != null) {
            // Copy into bundle and set ID to @rpath/<basename>, then recurse
            try {
              print('      ↳ Resolving @rpath via Homebrew: $located');
              if (!visited.add(baseName) && await destFile.exists()) {
                // Already handled
              } else {
                await File(located).copy(destPath);
                final idRes = await Process.run('install_name_tool', ['-id', '@rpath/$baseName', destPath]);
                if (idRes.exitCode != 0) {
                  print('      ⚠️  Failed to set install name for $baseName: ${idRes.stderr}');
                }
              }
              // Recurse to bundle this dependency's deps
              await _bundleDepsForFile(destPath, targetDir, brewPrefix, visited);
            } catch (e) {
              print('      ⚠️  Failed to copy @rpath lib $baseName from $located: $e');
            }
          } else {
            print('      ⚠️  Could not locate $baseName under Homebrew to satisfy @rpath');
          }
        }
        continue;
      }

      // Only bundle Homebrew/local deps
      if (dep.contains('@@HOMEBREW_PREFIX@@')) {
        // Replace placeholder with actual prefix
        final real = dep.replaceAll('@@HOMEBREW_PREFIX@@', brewPrefix);
        print('      ↳ Homebrew placeholder -> $real');
        await _copyAndRewriteDep(filePath, real, targetDir, brewPrefix, visited);
      } else if (dep.startsWith(brewPrefix) || dep.startsWith('/usr/local/')) {
        print('      ↳ Homebrew/local dep, will bundle');
        await _copyAndRewriteDep(filePath, dep, targetDir, brewPrefix, visited);
      } else {
        print('      ↳ Not a Homebrew/local dep; leaving as-is');
      }
    }
  }

  /// Try to locate a Homebrew-provided dylib by basename, under typical paths
  Future<String?> _locateHomebrewLibrary(String brewPrefix, String baseName) async {
    // Quick heuristics for common libraries to avoid scanning everything
    final heuristics = <String>[
      // webp/sharpyuv
      '$brewPrefix/opt/webp/lib/$baseName',
      // jpeg-xl
      '$brewPrefix/opt/jpeg-xl/lib/$baseName',
      // brotli
      '$brewPrefix/opt/brotli/lib/$baseName',
      // libpng
      '$brewPrefix/opt/libpng/lib/$baseName',
      // zlib/xz
      '$brewPrefix/opt/xz/lib/$baseName',
      // fallback plain lib dir (rare)
      '$brewPrefix/lib/$baseName',
    ];
    for (final p in heuristics) {
      final f = File(p);
      if (await f.exists()) return p;
    }
    // Scan opt/*/lib for the file (bounded scan to opt only)
    final optDir = Directory('$brewPrefix/opt');
    if (await optDir.exists()) {
      try {
        await for (final pkg in optDir.list(followLinks: false)) {
          if (pkg is Directory) {
            final candidate = File('${pkg.path}/lib/$baseName');
            if (await candidate.exists()) return candidate.path;
          }
        }
      } catch (_) {}
    }
    // As a last resort, scan Cellar/*/*/lib
    final cellarDir = Directory('$brewPrefix/Cellar');
    if (await cellarDir.exists()) {
      try {
        await for (final pkg in cellarDir.list(followLinks: false)) {
          if (pkg is Directory) {
            await for (final ver in pkg.list(followLinks: false)) {
              if (ver is Directory) {
                final candidate = File('${ver.path}/lib/$baseName');
                if (await candidate.exists()) return candidate.path;
              }
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _copyAndRewriteDep(
    String refererPath,
    String sourceDepPath,
    String targetDir,
    String brewPrefix,
    Set<String> visited,
  ) async {
    try {
      final srcFile = File(sourceDepPath);
      if (!await srcFile.exists()) return;

      // Resolve symlinks to get the real file, but keep the basename from the reference
      String realPath;
      try {
        realPath = await srcFile.resolveSymbolicLinks();
      } catch (_) {
        realPath = sourceDepPath;
      }

      final baseName = sourceDepPath.split('/').last; // keep version suffix if any
      final destPath = '$targetDir/$baseName';
      if (!visited.add(baseName) && await File(destPath).exists()) {
        // Already processed
      } else {
        print('    📦 Copying dependency $baseName from $realPath');
        await File(realPath).copy(destPath);
        // Set the ID of the copied dylib to @rpath/<basename>
        final idRes = await Process.run('install_name_tool', ['-id', '@rpath/$baseName', destPath]);
        if (idRes.exitCode != 0) {
          print('    ⚠️  Failed to set install name for $baseName: ${idRes.stderr}');
        }
      }

      // Rewrite the reference in the referer to point to @rpath/<basename>
      final chRes = await Process.run('install_name_tool', ['-change', sourceDepPath, '@rpath/$baseName', refererPath]);
      if (chRes.exitCode != 0) {
        print('    ⚠️  Failed to rewrite reference in ${refererPath.split('/').last} for $baseName: ${chRes.stderr}');
      } else {
        print('    🔗 Rewrote ${refererPath.split('/').last}: $sourceDepPath -> @rpath/$baseName');
      }

      // Recurse to bundle this dependency's own deps
  await _bundleDepsForFile(destPath, targetDir, brewPrefix, visited);
    } catch (e) {
      print('    ⚠️  Failed to copy/rewrite $sourceDepPath for $refererPath: $e');
    }
  }

  /// Gets the platform-specific library name
  String _getLibraryName(String platform) {
    switch (platform) {
      case 'windows':
        return 'sonix_native.dll';
      case 'linux':
        return 'libsonix_native.so';
      case 'macos':
        return 'libsonix_native.dylib';
      default:
        throw UnsupportedError('Unsupported platform: $platform');
    }
  }

  /// Gets the path to the built library
  String _getBuiltLibraryPath(String buildDir, String platform, String buildType, String libraryName) {
    switch (platform) {
      case 'windows':
        return '$buildDir/$buildType/$libraryName';
      case 'linux':
      case 'macos':
        return '$buildDir/$libraryName';
      default:
        throw UnsupportedError('Unsupported platform: $platform');
    }
  }

  /// Gets the runtime locations where the library should be copied
  List<String> _getRuntimeLibraryLocations(String platform) {
    final locations = <String>[];

    // Test fixtures directory (so native library is co-located with FFMPEG libraries)
    locations.add('test/fixtures/ffmpeg');

    // Example app build directories
    switch (platform) {
      case 'windows':
        locations.addAll(['example/build/windows/x64/runner/Debug', 'example/build/windows/x64/runner/Release']);
        break;
      case 'linux':
        locations.addAll(['example/build/linux/x64/debug/bundle/lib', 'example/build/linux/x64/release/bundle/lib']);
        break;
      case 'macos':
        locations.addAll([
          // Product roots (legacy fallback)
          'example/build/macos/Build/Products/Debug',
          'example/build/macos/Build/Products/Release',
          // Inside app bundle so dyld can find it
          'example/build/macos/Build/Products/Debug/example.app/Contents/Frameworks',
          'example/build/macos/Build/Products/Release/example.app/Contents/Frameworks',
          // Also allow placement next to executable as a fallback
          'example/build/macos/Build/Products/Debug/example.app/Contents/MacOS',
          'example/build/macos/Build/Products/Release/example.app/Contents/MacOS',
        ]);
        break;
    }

    return locations;
  }

  /// Gets library file extensions for the platform
  List<String> _getLibraryExtensions(String platform) {
    switch (platform) {
      case 'windows':
        return ['.dll', '.lib'];
      case 'linux':
        return ['.so', '.a'];
      case 'macos':
        return ['.dylib', '.a'];
      default:
        return ['.so', '.dylib', '.dll', '.a', '.lib'];
    }
  }

  /// Finds files with specific extension in directory
  Future<List<File>> _findFilesWithExtension(String dirPath, String extension) async {
    final files = <File>[];
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      return files;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith(extension)) {
        files.add(entity);
      }
    }

    return files;
  }

  /// Formats file size in human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Creates build directory
  Future<void> _createBuildDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      // Don't delete existing build directory for incremental builds
      print('Using existing build directory: $path');
    } else {
      await dir.create(recursive: true);
      print('Created build directory: $path');
    }
  }

  /// Cleans the build directory
  Future<void> _cleanBuild() async {
    print('Cleaning development build...');

    // Clean all platform-specific build directories
    final platforms = ['windows', 'linux', 'macos'];
    bool anyDeleted = false;

    for (final platform in platforms) {
      final buildDir = Directory('build/sonix/$platform');
      if (await buildDir.exists()) {
        await buildDir.delete(recursive: true);
        print('✅ Removed: ${buildDir.path}');
        anyDeleted = true;
      }
    }

    if (!anyDeleted) {
      print('No platform build directories found to clean');
    }

    print('✅ Clean completed');
  }

  /// Gets the current platform
  String _getCurrentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Parses command line arguments
  Map<String, dynamic> _parseArguments(List<String> arguments) {
    final options = <String, dynamic>{};

    for (int i = 0; i < arguments.length; i++) {
      final arg = arguments[i];

      switch (arg) {
        case '--help':
        case '-h':
          options['help'] = true;
          break;
        case '--verbose':
        case '-v':
          options['verbose'] = true;
          break;
        case '--clean':
        case '-c':
          options['clean'] = true;
          break;
        case '--build-type':
        case '-t':
          if (i + 1 < arguments.length) {
            options['build-type'] = arguments[++i];
          }
          break;
        default:
          if (arg.startsWith('-')) {
            throw ArgumentError('Unknown option: $arg');
          }
      }
    }

    return options;
  }

  /// Prints usage information
  void _printUsage() {
    print('''
Sonix Native Development Builder
===============================

Quick development build script for the Sonix native library.
Builds to native/build/ directory for local testing and development.

Usage:
  dart run tools/build_native_for_development.dart [options]

Options:
  -h, --help              Show this help message
  -v, --verbose           Show detailed build output
  -c, --clean             Clean build directory and exit
  -t, --build-type <type> Build type (Debug, Release, RelWithDebInfo)
                         Default: Release

Examples:
  # Quick development build
  dart run tools/build_native_for_development.dart

  # Debug build with verbose output
  dart run tools/build_native_for_development.dart --build-type Debug --verbose

  # Clean build directory
  dart run tools/build_native_for_development.dart --clean

Build Output:
  - Windows: build/sonix/windows/Release/sonix_native.dll
  - Linux: build/sonix/linux/libsonix_native.so
  - macOS: build/sonix/macos/libsonix_native.dylib

Note: This is for development only. For package distribution builds, use:
  dart run tools/build_native_for_distribution.dart

Prerequisites:
  1. CMake 3.10 or later installed
  2. Platform-specific toolchain (MSVC, GCC, Clang)
  3. FFMPEG binaries (optional): dart run tools/download_ffmpeg_binaries.dart
''');
  }
}

/// Main entry point
Future<void> main(List<String> arguments) async {
  final builder = NativeDevelopmentBuilder();
  await builder.run(arguments);
}
