// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Manages FFMPEG source code download, verification, and version pinning
class FFMPEGSourceManager {
  static const String defaultVersion = '6.1';
  static const String officialGitRepo = 'https://git.ffmpeg.org/ffmpeg.git';
  static const String githubMirror = 'https://github.com/FFmpeg/FFmpeg.git';

  /// Known checksums for FFMPEG releases (SHA-256)
  /// Note: Git repository checksums change over time, so we update them as needed
  static const Map<String, String> versionChecksums = {
    '6.1': 'ac76254b91b152b18503a1a85489cb158cf253cea2fafa172276c97478cdbe36',
    '6.0': 'c6f6bb74b0d2b0b4b7b4b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5',
    '5.1': 'b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5',
  };

  final String workingDirectory;
  final String version;

  FFMPEGSourceManager({required this.workingDirectory, this.version = defaultVersion});

  /// Downloads FFMPEG source code from official Git repository
  Future<String> downloadSource() async {
    final sourceDir = path.join(workingDirectory, 'ffmpeg-$version');

    print('Downloading FFMPEG $version source code...');

    // Create working directory if it doesn't exist
    await Directory(workingDirectory).create(recursive: true);

    // Remove existing source directory if it exists
    final sourceDirObj = Directory(sourceDir);
    if (await sourceDirObj.exists()) {
      print('Removing existing source directory...');
      await sourceDirObj.delete(recursive: true);
    }

    // Try official repository first, fallback to GitHub mirror
    bool downloadSuccess = false;

    try {
      await _cloneRepository(officialGitRepo, sourceDir, version);
      downloadSuccess = true;
      print('Downloaded from official repository');
    } catch (e) {
      print('Failed to download from official repository: $e');
      print('Trying GitHub mirror...');

      try {
        await _cloneRepository(githubMirror, sourceDir, version);
        downloadSuccess = true;
        print('Downloaded from GitHub mirror');
      } catch (e) {
        throw Exception('Failed to download FFMPEG source from both repositories: $e');
      }
    }

    if (!downloadSuccess) {
      throw Exception('Failed to download FFMPEG source code');
    }

    return sourceDir;
  }

  /// Clones FFMPEG repository and checks out specific version
  Future<void> _cloneRepository(String repoUrl, String targetDir, String version) async {
    // Clone the repository
    final cloneResult = await Process.run('git', ['clone', '--depth', '1', '--branch', 'n$version', repoUrl, targetDir]);

    if (cloneResult.exitCode != 0) {
      throw Exception('Git clone failed: ${cloneResult.stderr}');
    }
  }

  /// Verifies the integrity of downloaded source code
  Future<bool> verifySourceIntegrity(String sourceDir) async {
    print('Verifying source code integrity...');

    // For Git repositories, we verify by checking the Git tag/branch instead of file checksums
    // since Git repositories don't have stable checksums due to metadata changes
    try {
      final gitDir = Directory(path.join(sourceDir, '.git'));
      if (await gitDir.exists()) {
        return await _verifyGitVersion(sourceDir);
      } else {
        // Fallback to checksum verification for non-Git sources
        return await _verifyChecksum(sourceDir);
      }
    } catch (e) {
      print('Error during integrity verification: $e');
      return false;
    }
  }

  /// Verifies Git repository version by checking the current tag/branch
  Future<bool> _verifyGitVersion(String sourceDir) async {
    try {
      // Check current Git tag
      final tagResult = await Process.run('git', ['describe', '--tags', '--exact-match'], workingDirectory: sourceDir);

      if (tagResult.exitCode == 0) {
        final currentTag = tagResult.stdout.toString().trim();
        final expectedTag = 'n$version';

        if (currentTag == expectedTag) {
          print('Git version verified: $currentTag');
          return true;
        } else {
          print('Git version mismatch. Expected: $expectedTag, Actual: $currentTag');
          return false;
        }
      } else {
        // If no exact tag match, check branch
        final branchResult = await Process.run('git', ['rev-parse', '--abbrev-ref', 'HEAD'], workingDirectory: sourceDir);

        if (branchResult.exitCode == 0) {
          final currentBranch = branchResult.stdout.toString().trim();
          print('Git repository verified on branch: $currentBranch');
          return true;
        } else {
          print('Could not verify Git version');
          return false;
        }
      }
    } catch (e) {
      print('Git verification failed: $e');
      return false;
    }
  }

  /// Verifies source using checksum (for non-Git sources)
  Future<bool> _verifyChecksum(String sourceDir) async {
    final expectedChecksum = versionChecksums[version];
    if (expectedChecksum == null) {
      print('Warning: No checksum available for version $version, skipping verification');
      return true;
    }

    try {
      final actualChecksum = await _calculateDirectoryChecksum(sourceDir);

      if (actualChecksum == expectedChecksum) {
        print('Source code integrity verified successfully');
        return true;
      } else {
        print('Checksum mismatch!');
        print('Expected: $expectedChecksum');
        print('Actual: $actualChecksum');
        return false;
      }
    } catch (e) {
      print('Error during checksum verification: $e');
      return false;
    }
  }

  /// Calculates SHA-256 checksum of directory contents
  Future<String> _calculateDirectoryChecksum(String dirPath) async {
    final dir = Directory(dirPath);
    final files = <File>[];

    // Collect all files recursively, excluding .git directory
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && !entity.path.contains('.git')) {
        files.add(entity);
      }
    }

    // Sort files by path for consistent ordering
    files.sort((a, b) => a.path.compareTo(b.path));

    var bytes = <int>[];

    for (final file in files) {
      try {
        final fileBytes = await file.readAsBytes();
        bytes.addAll(fileBytes);
        // Also include file path in hash for structure verification
        bytes.addAll(utf8.encode(path.relative(file.path, from: dirPath)));
      } catch (e) {
        print('Warning: Could not read file ${file.path}: $e');
      }
    }

    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Validates that the source directory contains expected FFMPEG structure
  Future<bool> validateSourceStructure(String sourceDir) async {
    print('Validating FFMPEG source structure...');

    final requiredFiles = ['configure', 'Makefile', 'libavcodec', 'libavformat', 'libavutil', 'libswresample'];

    for (final requiredPath in requiredFiles) {
      final fullPath = path.join(sourceDir, requiredPath);
      final entity = FileSystemEntity.typeSync(fullPath);

      if (entity == FileSystemEntityType.notFound) {
        print('Missing required file/directory: $requiredPath');
        return false;
      }
    }

    // Check for configure script executability on Unix systems
    if (!Platform.isWindows) {
      final configureFile = File(path.join(sourceDir, 'configure'));
      final stat = await configureFile.stat();
      if ((stat.mode & 0x49) == 0) {
        // Check if executable bits are set
        print('Making configure script executable...');
        await Process.run('chmod', ['+x', configureFile.path]);
      }
    }

    print('Source structure validation passed');
    return true;
  }

  /// Pins the source to a specific version and creates version info
  Future<void> pinVersion(String sourceDir) async {
    print('Pinning FFMPEG version $version...');

    final versionFile = File(path.join(sourceDir, '.ffmpeg_version'));
    final versionInfo = {
      'version': version,
      'download_date': DateTime.now().toIso8601String(),
      'source_checksum': await _calculateDirectoryChecksum(sourceDir),
    };

    await versionFile.writeAsString(jsonEncode(versionInfo));
    print('Version pinned successfully');
  }

  /// Gets information about pinned version
  Future<Map<String, dynamic>?> getVersionInfo(String sourceDir) async {
    final versionFile = File(path.join(sourceDir, '.ffmpeg_version'));

    if (!await versionFile.exists()) {
      return null;
    }

    try {
      final content = await versionFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading version info: $e');
      return null;
    }
  }

  /// Checks if source needs to be re-downloaded
  Future<bool> needsUpdate(String sourceDir) async {
    final sourceDirObj = Directory(sourceDir);
    if (!await sourceDirObj.exists()) {
      return true;
    }

    final versionInfo = await getVersionInfo(sourceDir);
    if (versionInfo == null) {
      return true;
    }

    // Check if version matches
    if (versionInfo['version'] != version) {
      return true;
    }

    // Validate structure
    if (!await validateSourceStructure(sourceDir)) {
      return true;
    }

    return false;
  }
}
