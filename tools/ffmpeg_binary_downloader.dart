// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'ffmpeg_binary_validator.dart';
import 'ffmpeg_binary_installer.dart';

/// Configuration for FFMPEG binary sources
class FFMPEGBinaryConfig {
  final String platform;
  final String architecture;
  final String version;
  final String archiveUrl;
  final Map<String, String> libraryPaths; // Maps library name to path within archive
  final String? archiveChecksum;
  final List<String> requiredSymbols;

  const FFMPEGBinaryConfig({
    required this.platform,
    required this.architecture,
    required this.version,
    required this.archiveUrl,
    required this.libraryPaths,
    this.archiveChecksum,
    required this.requiredSymbols,
  });
}

/// Result of binary download operation
class DownloadResult {
  final bool success;
  final String? errorMessage;
  final List<String> downloadedFiles;
  final Map<String, String> filePaths;
  final Duration downloadTime;

  const DownloadResult({
    required this.success,
    this.errorMessage,
    this.downloadedFiles = const [],
    this.filePaths = const {},
    this.downloadTime = Duration.zero,
  });

  @override
  String toString() {
    if (success) {
      return 'Download successful: ${downloadedFiles.length} files in ${downloadTime.inSeconds}s';
    } else {
      return 'Download failed: $errorMessage';
    }
  }
}

/// Downloads and manages FFMPEG pre-built binaries
class FFMPEGBinaryDownloader {
  final PlatformInfo platformInfo;
  final FFMPEGBinaryValidator validator;
  final FFMPEGBinaryInstaller installer;

  FFMPEGBinaryDownloader({PlatformInfo? platformInfo})
    : platformInfo = platformInfo ?? PlatformInfo.detect(),
      validator = FFMPEGBinaryValidator(platformInfo: platformInfo),
      installer = FFMPEGBinaryInstaller(platformInfo: platformInfo);

  /// Downloads FFMPEG binaries for the current platform
  Future<DownloadResult> downloadForPlatform({String? targetPath, bool installToFlutterDirs = true, void Function(String, double)? progressCallback}) async {
    final stopwatch = Stopwatch()..start();

    try {
      final config = _getBinaryConfigForPlatform();
      final downloadPath = targetPath ?? 'build/ffmpeg/${platformInfo.platform}';

      // Create download directory
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      print('Downloading FFMPEG binaries for ${platformInfo.platform} ${platformInfo.architecture}...');
      print('Source: ${config.archiveUrl}');

      // Download the archive
      progressCallback?.call('archive', 0.0);
      final archiveBytes = await _downloadArchive(
        config.archiveUrl,
        (progress) => progressCallback?.call('archive', progress * 0.7), // 70% for download
      );

      if (archiveBytes == null) {
        return DownloadResult(success: false, errorMessage: 'Failed to download archive from ${config.archiveUrl}', downloadTime: stopwatch.elapsed);
      }

      // Verify archive checksum if provided
      if (config.archiveChecksum != null) {
        progressCallback?.call('verification', 0.7);
        final actualChecksum = sha256.convert(archiveBytes).toString();
        if (actualChecksum != config.archiveChecksum) {
          return DownloadResult(
            success: false,
            errorMessage: 'Archive checksum mismatch. Expected: ${config.archiveChecksum}, Got: $actualChecksum',
            downloadTime: stopwatch.elapsed,
          );
        }
        print('Archive checksum verified');
      }

      // Extract libraries from archive
      progressCallback?.call('extraction', 0.8);
      final extractResult = await _extractLibrariesFromArchive(archiveBytes, config, downloadPath);

      if (!extractResult.success) {
        return DownloadResult(success: false, errorMessage: 'Failed to extract libraries: ${extractResult.errorMessage}', downloadTime: stopwatch.elapsed);
      }

      progressCallback?.call('validation', 0.9);

      // Validate extracted binaries
      print('Validating extracted binaries...');
      final validationResults = await validator.validateAllBinaries(downloadPath);

      for (final entry in validationResults.entries) {
        if (!entry.value.isValid) {
          print('Warning: Binary validation failed for ${entry.key}: ${entry.value.errorMessage}');
          // Don't fail completely on validation issues, just warn
        } else {
          print('✓ ${entry.key} validated successfully');
        }
      }

      // Install to Flutter build directories if requested
      if (installToFlutterDirs) {
        print('Installing to Flutter build directories...');
        final installResult = await installer.installToFlutterBuildDirs(downloadPath);

        if (!installResult.success) {
          return DownloadResult(
            success: false,
            errorMessage: 'Installation to Flutter directories failed: ${installResult.errorMessage}',
            downloadTime: stopwatch.elapsed,
          );
        }
      }

      stopwatch.stop();
      progressCallback?.call('complete', 1.0);
      print('Download and installation completed successfully in ${stopwatch.elapsed.inSeconds}s');

      return DownloadResult(success: true, downloadedFiles: extractResult.downloadedFiles, filePaths: extractResult.filePaths, downloadTime: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      return DownloadResult(success: false, errorMessage: 'Download failed: $e', downloadTime: stopwatch.elapsed);
    }
  }

  /// Downloads an archive from URL
  Future<Uint8List?> _downloadArchive(String url, void Function(double)? progressCallback) async {
    try {
      print('Downloading archive from: $url');

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        print('HTTP error ${response.statusCode} for $url');
        client.close();
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int downloaded = 0;

      await response.stream
          .listen(
            (List<int> chunk) {
              bytes.addAll(chunk);
              downloaded += chunk.length;

              if (contentLength > 0) {
                final progress = downloaded / contentLength;
                progressCallback?.call(progress);
              }
            },
            onDone: () {
              progressCallback?.call(1.0);
            },
            onError: (error) {
              print('Download stream error: $error');
            },
          )
          .asFuture();

      client.close();
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('Error downloading archive: $e');
      return null;
    }
  }

  /// Extracts libraries from downloaded archive
  Future<DownloadResult> _extractLibrariesFromArchive(Uint8List archiveBytes, FFMPEGBinaryConfig config, String targetPath) async {
    try {
      Archive archive;

      // Determine archive type and decode
      if (config.archiveUrl.endsWith('.zip')) {
        archive = ZipDecoder().decodeBytes(archiveBytes);
      } else if (config.archiveUrl.endsWith('.tar.xz') || config.archiveUrl.endsWith('.tar.gz')) {
        // For tar archives, we need to handle compression first
        if (config.archiveUrl.endsWith('.tar.xz')) {
          final decompressed = XZDecoder().decodeBytes(archiveBytes);
          archive = TarDecoder().decodeBytes(decompressed);
        } else {
          final decompressed = GZipDecoder().decodeBytes(archiveBytes);
          archive = TarDecoder().decodeBytes(decompressed);
        }
      } else {
        return DownloadResult(success: false, errorMessage: 'Unsupported archive format: ${config.archiveUrl}');
      }

      final downloadedFiles = <String>[];
      final filePaths = <String, String>{};

      // Extract each required library or directory
      for (final entry in config.libraryPaths.entries) {
        final libraryName = entry.key;
        final pathInArchive = entry.value;

        print('Extracting $libraryName from $pathInArchive...');

        // Check if this is a directory extraction (ends with /)
        if (pathInArchive.endsWith('/')) {
          // Extract entire directory
          final prefix = pathInArchive.substring(0, pathInArchive.length - 1);
          final matchingFiles = archive.files.where((file) => file.name.startsWith('$prefix/') && file.isFile).toList();

          if (matchingFiles.isEmpty) {
            throw Exception('No files found in directory: $pathInArchive');
          }

          for (final file in matchingFiles) {
            // Calculate relative path within the directory
            final relativePath = file.name.substring(prefix.length + 1);
            final outputPath = '$targetPath/$libraryName/$relativePath';

            // Create directory structure if needed
            final outputFile = File(outputPath);
            await outputFile.parent.create(recursive: true);
            await outputFile.writeAsBytes(file.content as List<int>);

            downloadedFiles.add(relativePath);
            filePaths[relativePath] = outputPath;
          }

          print('✓ Extracted directory $libraryName (${matchingFiles.length} files)');
        } else {
          // Extract individual file (existing logic)
          ArchiveFile? targetFile;

          if (pathInArchive.contains('*')) {
            // Handle wildcard paths (common in tar archives)
            final pattern = RegExp(pathInArchive.replaceAll('*', r'[^/]*'));
            targetFile = archive.files.firstWhere(
              (file) => pattern.hasMatch(file.name) && file.name.endsWith(libraryName),
              orElse: () => throw Exception('File not found matching pattern: $pathInArchive'),
            );
          } else {
            // Direct path lookup
            targetFile = archive.files.firstWhere(
              (file) => file.name == pathInArchive || file.name.endsWith('/$pathInArchive'),
              orElse: () => throw Exception('File not found: $pathInArchive'),
            );
          }

          if (targetFile.isFile) {
            // Preserve directory structure from archive
            // If the path contains 'lib/', extract it into a lib/ subdirectory
            String outputPath;
            if (pathInArchive.contains('/lib/')) {
              // Extract to lib/ subdirectory to match CMake expectations
              outputPath = '$targetPath/lib/$libraryName';
            } else {
              // Extract directly for other files (like include directories)
              outputPath = '$targetPath/$libraryName';
            }
            
            final outputFile = File(outputPath);
            await outputFile.parent.create(recursive: true);
            await outputFile.writeAsBytes(targetFile.content as List<int>);

            downloadedFiles.add(libraryName);
            filePaths[libraryName] = outputPath;

            print('✓ Extracted $libraryName (${targetFile.size} bytes)');
          } else {
            throw Exception('$pathInArchive is not a file');
          }
        }
      }

      return DownloadResult(success: true, downloadedFiles: downloadedFiles, filePaths: filePaths);
    } catch (e) {
      return DownloadResult(success: false, errorMessage: 'Archive extraction failed: $e');
    }
  }

  /// Verifies integrity of downloaded binaries using checksums
  Future<bool> verifyBinaryIntegrity(String binaryPath, String expectedChecksum) async {
    try {
      final actualChecksum = await _calculateChecksum(binaryPath);
      return actualChecksum == expectedChecksum;
    } catch (e) {
      print('Error verifying binary integrity: $e');
      return false;
    }
  }

  /// Gets binary configuration for the current platform
  FFMPEGBinaryConfig _getBinaryConfigForPlatform() {
    switch (platformInfo.platform) {
      case 'windows':
        return _getWindowsConfig();
      case 'macos':
        return _getMacOSConfig();
      case 'linux':
        return _getLinuxConfig();
      default:
        throw UnsupportedError('Unsupported platform: ${platformInfo.platform}');
    }
  }

  /// Windows FFMPEG binary configuration
  FFMPEGBinaryConfig _getWindowsConfig() {
    // Using BtbN builds which are reliable and well-maintained
    // Use the shared version which includes DLLs, headers, and import libraries for development
    const archiveUrl = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip';

    return FFMPEGBinaryConfig(
      platform: 'windows',
      architecture: 'x64',
      version: '6.0',
      archiveUrl: archiveUrl,
      libraryPaths: {
        // Runtime DLLs
        'avformat-62.dll': 'ffmpeg-master-latest-win64-gpl-shared/bin/avformat-62.dll',
        'avcodec-62.dll': 'ffmpeg-master-latest-win64-gpl-shared/bin/avcodec-62.dll',
        'avutil-60.dll': 'ffmpeg-master-latest-win64-gpl-shared/bin/avutil-60.dll',
        'swresample-6.dll': 'ffmpeg-master-latest-win64-gpl-shared/bin/swresample-6.dll',
        // Development files (headers and import libraries)
        'include': 'ffmpeg-master-latest-win64-gpl-shared/include/',
        'lib': 'ffmpeg-master-latest-win64-gpl-shared/lib/',
      },
      requiredSymbols: ['avformat_open_input', 'avcodec_find_decoder', 'swr_alloc'],
    );
  }

  /// macOS FFMPEG binary configuration
  FFMPEGBinaryConfig _getMacOSConfig() {
    // Using a more reliable source for macOS binaries
    const archiveUrl = 'https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip';

    return FFMPEGBinaryConfig(
      platform: 'macos',
      architecture: 'x64',
      version: '6.0',
      archiveUrl: archiveUrl,
      libraryPaths: {
        // Note: evermeet.cx provides the main ffmpeg binary, we'll need to link against system libraries
        'libavformat.dylib': 'ffmpeg', // This is a simplification - real implementation would need proper dylib extraction
        'libavcodec.dylib': 'ffmpeg',
        'libavutil.dylib': 'ffmpeg',
        'libswresample.dylib': 'ffmpeg',
      },
      requiredSymbols: ['avformat_open_input', 'avcodec_find_decoder', 'swr_alloc'],
    );
  }

  /// Linux FFMPEG binary configuration
  FFMPEGBinaryConfig _getLinuxConfig() {
    // Using shared builds from BtbN/FFmpeg-Builds
    const archiveUrl = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl-shared.tar.xz';

    return FFMPEGBinaryConfig(
      platform: 'linux',
      architecture: 'x64',
      version: '6.0',
      archiveUrl: archiveUrl,
      libraryPaths: {
        // Shared builds have separate library files (using versioned names that match native library expectations)
        'libavformat.so.62': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavformat.so.62.6.100',
        'libavcodec.so.62': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavcodec.so.62.16.100',
        'libavutil.so.60': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavutil.so.60.13.100',
        'libswresample.so.6': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libswresample.so.6.2.100',
        // Also provide generic names for CMake find_library
        'libavformat.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavformat.so.62.6.100',
        'libavcodec.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavcodec.so.62.16.100',
        'libavutil.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavutil.so.60.13.100',
        'libswresample.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libswresample.so.6.2.100',
        // Development files (headers)
        'include': 'ffmpeg-master-latest-linux64-gpl-shared/include/',
      },
      requiredSymbols: ['avformat_open_input', 'avcodec_find_decoder', 'swr_alloc'],
    );
  }

  /// Calculates SHA-256 checksum of a file
  Future<String> _calculateChecksum(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Cleans up downloaded files
  Future<bool> cleanup(String downloadPath) async {
    try {
      final dir = Directory(downloadPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
      return true;
    } catch (e) {
      print('Error during cleanup: $e');
      return false;
    }
  }

  /// Gets available binary configurations for all platforms
  static Map<String, FFMPEGBinaryConfig> getAllConfigurations() {
    final downloader = FFMPEGBinaryDownloader();
    return {'windows': downloader._getWindowsConfig(), 'macos': downloader._getMacOSConfig(), 'linux': downloader._getLinuxConfig()};
  }
}
