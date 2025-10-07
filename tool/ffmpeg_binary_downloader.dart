// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'ffmpeg_binary_installer.dart';
import 'ffmpeg_binary_validator.dart';

/// Configuration for FFMPEG binary sources
class FFMPEGBinaryConfig {
  final String platform;
  final String architecture;
  final String version;
  final String archiveUrl;
  final Map<String, String> libraryPaths;
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
      final baseConfig = _getBinaryConfigForPlatform();
      // For macOS, resolve to a specific Homebrew bottle (e.g., ffmpeg@6) to get dylibs/headers
      final config = platformInfo.platform == 'macos' ? await _resolveMacOSBottleConfig(baseConfig) : baseConfig;
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

      // macOS: ensure generic dylib names exist (libavcodec.dylib, etc.)
      if (platformInfo.platform == 'macos') {
        await _normalizeMacOSLibs('$downloadPath/lib');
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
      try {
        String currentUrl = url;
        String? bearerToken;
        int redirectHops = 0;

        while (true) {
          final request = http.Request('GET', Uri.parse(currentUrl));
          request.headers['Accept'] = 'application/octet-stream';
          if (bearerToken != null) {
            request.headers['Authorization'] = 'Bearer $bearerToken';
          }

          final response = await client.send(request);

          // Handle redirects (3xx with Location)
          if (response.isRedirect || (response.statusCode >= 300 && response.statusCode < 400)) {
            final location = response.headers['location'];
            if (location != null && redirectHops < 5) {
              currentUrl = Uri.parse(currentUrl).resolve(location).toString();
              redirectHops++;
              // loop to retry
              continue;
            }
          }

          // Handle GHCR token challenge (401 with WWW-Authenticate)
          if (response.statusCode == 401 && currentUrl.contains('ghcr.io')) {
            final wwwAuth = response.headers['www-authenticate'] ?? response.headers['WWW-Authenticate'];
            if (wwwAuth != null && wwwAuth.toLowerCase().startsWith('bearer')) {
              final params = _parseAuthHeaderParams(wwwAuth.substring('bearer'.length));
              final realm = params['realm'];
              final service = params['service'];
              final scope = params['scope'];
              if (realm != null && service != null && scope != null) {
                final tokenUri = Uri.parse(realm).replace(queryParameters: {'service': service, 'scope': scope});
                final tokenResp = await http.get(tokenUri);
                if (tokenResp.statusCode == 200) {
                  final tokenJson = json.decode(tokenResp.body) as Map<String, dynamic>;
                  bearerToken = (tokenJson['token'] ?? tokenJson['access_token'])?.toString();
                  if (bearerToken != null) {
                    // retry same URL with token
                    continue;
                  }
                } else {
                  print('Failed to get GHCR token: ${tokenResp.statusCode}');
                }
              }
            }
          }

          if (response.statusCode != 200) {
            print('HTTP error ${response.statusCode} for $currentUrl');
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

          return Uint8List.fromList(bytes);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('Error downloading archive: $e');
      return null;
    }
  }

  Map<String, String> _parseAuthHeaderParams(String authParams) {
    // Parses key="value" pairs; tolerates commas/spaces
    final map = <String, String>{};
    for (final part in authParams.split(',')) {
      final kv = part.trim();
      if (kv.isEmpty) continue;
      final i = kv.indexOf('=');
      if (i <= 0) continue;
      final key = kv.substring(0, i).trim().replaceAll(RegExp(r'^,|^\s+'), '');
      var value = kv.substring(i + 1).trim();
      if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }
      if (key.isNotEmpty && value.isNotEmpty) {
        map[key] = value;
      }
    }
    return map;
  }

  /// Extracts libraries from downloaded archive
  Future<DownloadResult> _extractLibrariesFromArchive(Uint8List archiveBytes, FFMPEGBinaryConfig config, String targetPath) async {
    try {
      Archive archive;

      // Determine archive type via magic bytes (works for GHCR bottles without extensions)
      if (_looksLikeZip(archiveBytes)) {
        archive = ZipDecoder().decodeBytes(archiveBytes);
      } else if (_looksLikeGzip(archiveBytes)) {
        final decompressed = GZipDecoder().decodeBytes(archiveBytes);
        archive = TarDecoder().decodeBytes(decompressed);
      } else if (_looksLikeXz(archiveBytes)) {
        final decompressed = XZDecoder().decodeBytes(archiveBytes);
        archive = TarDecoder().decodeBytes(decompressed);
      } else if (_looksLikeTar(archiveBytes)) {
        archive = TarDecoder().decodeBytes(archiveBytes);
      } else {
        // Fallback based on URL if magic detection fails
        if (config.archiveUrl.endsWith('.zip') || config.archiveUrl.endsWith('/zip')) {
          archive = ZipDecoder().decodeBytes(archiveBytes);
        } else if (config.archiveUrl.endsWith('.tar.xz') || config.archiveUrl.endsWith('.tar.gz')) {
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
          // Extract entire directory; support wildcard with '*'
          final isWildcard = pathInArchive.contains('*');
          final prefixes = <String>{};
          if (isWildcard) {
            final regexStr = '^${RegExp.escape(pathInArchive.substring(0, pathInArchive.length - 1)).replaceAll(r'\*', '[^/]+')}/';
            final re = RegExp(regexStr);
            for (final file in archive.files) {
              if (!file.isFile) continue;
              final name = file.name;
              final match = re.firstMatch(name);
              if (match != null) {
                prefixes.add(match.group(0)!.substring(0, match.group(0)!.length - 1)); // drop trailing '/'
              }
            }
            // Fallback: if no matches and pattern targets include/, search any depth include/
            if (prefixes.isEmpty && pathInArchive.contains('/include/')) {
              for (final file in archive.files) {
                if (!file.isFile) continue;
                final name = file.name;
                final idx = name.indexOf('/include/');
                if (idx > 0) {
                  final prefix = name.substring(0, idx + '/include'.length);
                  prefixes.add(prefix);
                }
              }
            }
          } else {
            prefixes.add(pathInArchive.substring(0, pathInArchive.length - 1));
          }

          final matchingFiles = <ArchiveFile>[];
          for (final prefix in prefixes) {
            matchingFiles.addAll(archive.files.where((file) => file.isFile && file.name.startsWith('$prefix/')));
          }

          if (matchingFiles.isEmpty) {
            throw Exception('No files found in directory: $pathInArchive');
          }

          for (final file in matchingFiles) {
            // Calculate relative path within the chosen directory root
            String relativePath = file.name;
            for (final prefix in prefixes) {
              if (relativePath.startsWith('$prefix/')) {
                relativePath = relativePath.substring(prefix.length + 1);
                break;
              }
            }
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
          // Extract individual file
          ArchiveFile? targetFile;

          if (pathInArchive.contains('*')) {
            // Handle wildcard paths: safely escape non-wildcard chars, then expand '*' to a single-segment wildcard
            final pattern = RegExp('^${RegExp.escape(pathInArchive).replaceAll(r'\*', r'[^/]*')}\$');
            final matches = archive.files.where((file) => file.isFile && pattern.hasMatch(file.name)).toList();
            if (matches.isNotEmpty) {
              targetFile = matches.first;
            } else {
              // Fallback heuristic for macOS bottles: search for versioned dylib anywhere under a lib/ directory
              final expectedBase = libraryName.endsWith('.dylib') ? libraryName.substring(0, libraryName.length - '.dylib'.length) : libraryName;
              final heuristic = archive.files.firstWhere(
                (file) => file.isFile && file.name.contains('/lib/') && file.name.split('/').last.startsWith(expectedBase) && file.name.endsWith('.dylib'),
                orElse: () => ArchiveFile('', 0, null),
              );
              if (heuristic.name.isNotEmpty) {
                targetFile = heuristic;
              } else {
                throw Exception('File not found matching pattern: $pathInArchive');
              }
            }
          } else {
            // Direct path lookup
            targetFile = archive.files.firstWhere(
              (file) => file.name == pathInArchive || file.name.endsWith('/$pathInArchive'),
              orElse: () => throw Exception('File not found: $pathInArchive'),
            );
          }

          if (targetFile.isFile) {
            // If the path contains 'lib/', extract it into a lib/ subdirectory
            String outputPath;
            if (pathInArchive.contains('/lib/')) {
              outputPath = '$targetPath/lib/$libraryName';
            } else {
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

  bool _looksLikeZip(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 && // 'P'
        bytes[1] == 0x4B && // 'K'
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  bool _looksLikeGzip(Uint8List bytes) {
    return bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B;
  }

  bool _looksLikeXz(Uint8List bytes) {
    return bytes.length >= 6 && bytes[0] == 0xFD && bytes[1] == 0x37 && bytes[2] == 0x7A && bytes[3] == 0x58 && bytes[4] == 0x5A && bytes[5] == 0x00;
  }

  bool _looksLikeTar(Uint8List bytes) {
    // ustar signature at offset 257..261
    if (bytes.length < 265) return false;
    final off = 257;
    return bytes[off] == 0x75 && // 'u'
        bytes[off + 1] == 0x73 && // 's'
        bytes[off + 2] == 0x74 && // 't'
        bytes[off + 3] == 0x61 && // 'a'
        bytes[off + 4] == 0x72; // 'r'
  }

  /// Ensure generic dylib names exist on macOS by copying from versioned files when necessary.
  Future<void> _normalizeMacOSLibs(String libDirPath) async {
    final libDir = Directory(libDirPath);
    if (!await libDir.exists()) return;
    final bases = ['libavformat', 'libavcodec', 'libavutil', 'libswresample'];
    for (final base in bases) {
      final generic = File('$libDirPath/$base.dylib');
      if (!await generic.exists()) {
        File? versioned;
        await for (final entity in libDir.list()) {
          if (entity is File && entity.path.contains(RegExp('/$base\\.')) && entity.path.endsWith('.dylib')) {
            versioned = entity;
            break;
          }
        }
        if (versioned != null) {
          await versioned.copy(generic.path);
          print('Created generic $base.dylib from ${versioned.path.split('/').last}');
        }
      }
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

  /// macOS FFMPEG binary configuration (placeholder; resolved to bottle at download time)
  FFMPEGBinaryConfig _getMacOSConfig() {
    // Keep a valid URL for tests; real download will be the Homebrew bottle
    const archiveUrl = 'https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip';
    return FFMPEGBinaryConfig(
      platform: 'macos',
      architecture: platformInfo.architecture,
      version: '6', // target major; we'll resolve to ffmpeg@6 bottle
      archiveUrl: archiveUrl,
      libraryPaths: const {
        // Extract specific dylibs (match versioned names via wildcard) and headers
        'libavformat.dylib': '*/lib/libavformat*.dylib',
        'libavcodec.dylib': '*/lib/libavcodec*.dylib',
        'libavutil.dylib': '*/lib/libavutil*.dylib',
        'libswresample.dylib': '*/lib/libswresample*.dylib',
        'include': '*/include/',
      },
      requiredSymbols: const ['avformat_open_input', 'avcodec_find_decoder', 'swr_alloc'],
    );
  }

  /// Linux FFMPEG binary configuration
  FFMPEGBinaryConfig _getLinuxConfig() {
    const archiveUrl = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl-shared.tar.xz';

    return FFMPEGBinaryConfig(
      platform: 'linux',
      architecture: 'x64',
      version: '6.0',
      archiveUrl: archiveUrl,
      libraryPaths: {
        'libavformat.so.62': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavformat.so.62.*',
        'libavcodec.so.62': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavcodec.so.62.*',
        'libavutil.so.60': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavutil.so.60.*',
        'libswresample.so.6': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libswresample.so.6.*',
        // Also provide generic names for CMake find_library
        'libavformat.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavformat.so.62.*',
        'libavcodec.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavcodec.so.62.*',
        'libavutil.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libavutil.so.60.*',
        'libswresample.so': 'ffmpeg-master-latest-linux64-gpl-shared/lib/libswresample.so.6.*',
        // Development files (headers)
        'include': 'ffmpeg-master-latest-linux64-gpl-shared/include/',
      },
      requiredSymbols: ['avformat_open_input', 'avcodec_find_decoder', 'swr_alloc'],
    );
  }

  // Resolve macOS Homebrew bottle URL and set wildcard lib/include paths
  Future<FFMPEGBinaryConfig> _resolveMacOSBottleConfig(FFMPEGBinaryConfig base) async {
    try {
      final major = base.version.replaceAll(RegExp(r'[^0-9]'), '');
      final formula = major.isEmpty || major == '0' ? 'ffmpeg' : 'ffmpeg@$major';
      final apiUrl = 'https://formulae.brew.sh/api/formula/$formula.json';
      print('Resolving macOS ffmpeg bottles from $apiUrl ...');
      final resp = await http.get(Uri.parse(apiUrl));
      if (resp.statusCode != 200) {
        throw Exception('Failed to fetch formula info (${resp.statusCode})');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final bottles = (data['bottle'] ?? const {}) as Map<String, dynamic>;
      final stableFiles = (bottles['stable'] ?? const {})['files'] as Map<String, dynamic>?;
      if (stableFiles == null || stableFiles.isEmpty) {
        throw Exception('No bottles found in formula info');
      }

      final osCode = _macOSCodenameFromVersion(platformInfo.osVersion);
      final arch = _isArm64() ? 'arm64' : 'x86_64';
      final preferredKeys = <String>[
        if (arch == 'arm64') 'arm64_$osCode',
        osCode,
        if (arch == 'arm64') 'arm64_sonoma',
        'sonoma',
        'ventura',
        'monterey',
        'big_sur',
      ];

      MapEntry<String, dynamic>? chosen;
      for (final key in preferredKeys) {
        if (stableFiles.containsKey(key)) {
          chosen = MapEntry(key, stableFiles[key]);
          break;
        }
      }
      chosen ??= stableFiles.entries.first;

      final url = chosen.value['url'] as String;
      final sha = chosen.value['sha256'] as String?;

      return FFMPEGBinaryConfig(
        platform: 'macos',
        architecture: platformInfo.architecture,
        version: data['versions']?['stable']?.toString() ?? base.version,
        archiveUrl: url,
        archiveChecksum: sha,
        libraryPaths: const {
          'libavformat.dylib': '*/lib/libavformat*.dylib',
          'libavcodec.dylib': '*/lib/libavcodec*.dylib',
          'libavutil.dylib': '*/lib/libavutil*.dylib',
          'libswresample.dylib': '*/lib/libswresample*.dylib',
          'include': '*/include/',
        },
        requiredSymbols: base.requiredSymbols,
      );
    } catch (e) {
      print('Warning: Failed to resolve macOS bottle dynamically: $e');
      return base;
    }
  }

  String _macOSCodenameFromVersion(String osVersion) {
    final majorMatch = RegExp(r'Version\s+(\d+)').firstMatch(osVersion);
    final major = majorMatch != null ? int.tryParse(majorMatch.group(1)!) ?? 0 : 0;
    if (major >= 15) return 'sequoia';
    if (major == 14) return 'sonoma';
    if (major == 13) return 'ventura';
    if (major == 12) return 'monterey';
    if (major == 11) return 'big_sur';
    return 'monterey';
  }

  bool _isArm64() {
    final arch = platformInfo.architecture.toLowerCase();
    return arch.contains('arm') || arch.contains('aarch64') || arch.contains('arm64');
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
