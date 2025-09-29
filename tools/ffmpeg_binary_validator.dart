// ignore_for_file: avoid_print

import 'dart:io';

/// Result of binary validation containing validation status and details
class BinaryValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> missingSymbols;
  final String? detectedVersion;
  final Map<String, dynamic> metadata;

  const BinaryValidationResult({required this.isValid, this.errorMessage, this.missingSymbols = const [], this.detectedVersion, this.metadata = const {}});

  @override
  String toString() {
    if (isValid) {
      return 'Valid binary (version: $detectedVersion)';
    } else {
      return 'Invalid binary: $errorMessage';
    }
  }
}

/// Platform information for binary validation
class PlatformInfo {
  final String platform;
  final String architecture;
  final String osVersion;
  final List<String> expectedLibraryExtensions;
  final List<String> librarySearchPaths;

  const PlatformInfo({
    required this.platform,
    required this.architecture,
    required this.osVersion,
    required this.expectedLibraryExtensions,
    required this.librarySearchPaths,
  });

  static PlatformInfo detect() {
    final platform = Platform.operatingSystem;
    final architecture = _detectArchitecture();
    final osVersion = Platform.operatingSystemVersion;

    switch (platform) {
      case 'windows':
        return PlatformInfo(
          platform: platform,
          architecture: architecture,
          osVersion: osVersion,
          expectedLibraryExtensions: ['.dll'],
          librarySearchPaths: ['native/windows', 'build/windows/x64/runner/Debug'],
        );
      case 'macos':
        return PlatformInfo(
          platform: platform,
          architecture: architecture,
          osVersion: osVersion,
          expectedLibraryExtensions: ['.dylib'],
          librarySearchPaths: ['native/macos', 'build/macos/Build/Products/Debug'],
        );
      case 'linux':
        return PlatformInfo(
          platform: platform,
          architecture: architecture,
          osVersion: osVersion,
          expectedLibraryExtensions: ['.so'],
          librarySearchPaths: ['native/linux', 'build/linux/x64/debug/bundle/lib'],
        );
      default:
        throw UnsupportedError('Unsupported platform: $platform');
    }
  }

  static String _detectArchitecture() {
    // Simple architecture detection - can be enhanced
    if (Platform.environment['PROCESSOR_ARCHITECTURE'] == 'AMD64' || Platform.environment['PROCESSOR_ARCHITEW6432'] == 'AMD64') {
      return 'x64';
    }
    return 'x64'; // Default assumption
  }

  List<String> getExpectedLibraryNames() {
    switch (platform) {
      case 'windows':
        return ['avformat-62.dll', 'avcodec-62.dll', 'avutil-60.dll', 'swresample-6.dll'];
      case 'macos':
        return ['libavformat.dylib', 'libavcodec.dylib', 'libavutil.dylib', 'libswresample.dylib'];
      case 'linux':
        // Include both generic names (for CMake) and versioned names (for runtime)
        return [
          'libavformat.so', 'libavcodec.so', 'libavutil.so', 'libswresample.so',
          'libavformat.so.62', 'libavcodec.so.62', 'libavutil.so.60', 'libswresample.so.6'
        ];
      default:
        return [];
    }
  }
}

/// Validates FFMPEG binaries for compatibility and completeness
class FFMPEGBinaryValidator {
  final PlatformInfo platformInfo;

  FFMPEGBinaryValidator({PlatformInfo? platformInfo}) : platformInfo = platformInfo ?? PlatformInfo.detect();

  /// Validates a single binary file
  Future<BinaryValidationResult> validateBinary(String binaryPath) async {
    try {
      final file = File(binaryPath);
      if (!await file.exists()) {
        return BinaryValidationResult(isValid: false, errorMessage: 'Binary file does not exist: $binaryPath');
      }

      // Check if file is readable and has appropriate size
      final stat = await file.stat();
      if (stat.size == 0) {
        return BinaryValidationResult(isValid: false, errorMessage: 'Binary file is empty: $binaryPath');
      }

      // Validate architecture (optional - warn if fails but don't block)
      final archValidation = await _validateArchitecture(binaryPath);
      if (!archValidation.isValid) {
        print('Warning: Architecture validation failed: ${archValidation.errorMessage}');
        // Don't fail completely - just warn
      }

      // Check required symbols
      final requiredSymbols = await getRequiredSymbols();
      final symbolsPresent = await checkSymbolsPresent(binaryPath, requiredSymbols);

      if (!symbolsPresent) {
        final missingSymbols = await _getMissingSymbols(binaryPath, requiredSymbols);
        print('Warning: Some symbols may be missing from $binaryPath: ${missingSymbols.take(3).join(', ')}${missingSymbols.length > 3 ? '...' : ''}');
        // Don't fail completely - just warn
      }

      // Get version information
      final version = await getBinaryVersion(binaryPath);

      return BinaryValidationResult(
        isValid: true,
        detectedVersion: version,
        metadata: {
          'fileSize': stat.size,
          'lastModified': stat.modified.toIso8601String(),
          'platform': platformInfo.platform,
          'architecture': platformInfo.architecture,
        },
      );
    } catch (e) {
      return BinaryValidationResult(isValid: false, errorMessage: 'Validation failed: $e');
    }
  }

  /// Gets the list of required symbols for FFMPEG libraries
  Future<List<String>> getRequiredSymbols() async {
    // Core FFMPEG symbols that must be present
    return [
      'avformat_open_input',
      'avformat_find_stream_info',
      'avformat_close_input',
      'avcodec_find_decoder',
      'avcodec_alloc_context3',
      'avcodec_open2',
      'avcodec_receive_frame',
      'avcodec_send_packet',
      'av_read_frame',
      'av_packet_alloc',
      'av_packet_free',
      'av_frame_alloc',
      'av_frame_free',
      'swr_alloc',
      'swr_init',
      'swr_convert',
      'swr_free',
    ];
  }

  /// Checks if required symbols are present in the binary
  Future<bool> checkSymbolsPresent(String binaryPath, List<String> symbols) async {
    try {
      final missingSymbols = await _getMissingSymbols(binaryPath, symbols);
      return missingSymbols.isEmpty;
    } catch (e) {
      print('Error checking symbols: $e');
      return false;
    }
  }

  /// Gets the version of the binary
  Future<String?> getBinaryVersion(String binaryPath) async {
    try {
      ProcessResult result;

      switch (platformInfo.platform) {
        case 'windows':
          // Use PowerShell to get file version on Windows
          result = await Process.run('powershell', ['-Command', '(Get-Item "$binaryPath").VersionInfo.FileVersion']);
          break;
        case 'macos':
          // Use otool to get version info on macOS
          result = await Process.run('otool', ['-L', binaryPath]);
          break;
        case 'linux':
          // Use readelf to get version info on Linux
          result = await Process.run('readelf', ['-V', binaryPath]);
          break;
        default:
          return null;
      }

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        return _extractVersionFromOutput(output);
      }
    } catch (e) {
      print('Error getting binary version: $e');
    }
    return null;
  }

  /// Validates the architecture of the binary
  Future<BinaryValidationResult> _validateArchitecture(String binaryPath) async {
    try {
      ProcessResult result;

      switch (platformInfo.platform) {
        case 'windows':
          result = await Process.run('powershell', ['-Command', 'dumpbin /headers "$binaryPath" | Select-String "machine"']);
          break;
        case 'macos':
          result = await Process.run('file', [binaryPath]);
          break;
        case 'linux':
          result = await Process.run('file', [binaryPath]);
          break;
        default:
          return BinaryValidationResult(isValid: false, errorMessage: 'Architecture validation not supported on ${platformInfo.platform}');
      }

      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        if (_isCompatibleArchitecture(output)) {
          return BinaryValidationResult(isValid: true);
        } else {
          return BinaryValidationResult(isValid: false, errorMessage: 'Incompatible architecture detected in binary');
        }
      } else {
        return BinaryValidationResult(isValid: false, errorMessage: 'Failed to check binary architecture: ${result.stderr}');
      }
    } catch (e) {
      return BinaryValidationResult(isValid: false, errorMessage: 'Architecture validation failed: $e');
    }
  }

  /// Gets missing symbols from the binary
  Future<List<String>> _getMissingSymbols(String binaryPath, List<String> requiredSymbols) async {
    try {
      final presentSymbols = await _getSymbolsFromBinary(binaryPath);
      return requiredSymbols.where((symbol) => !presentSymbols.contains(symbol)).toList();
    } catch (e) {
      print('Error getting missing symbols: $e');
      return requiredSymbols; // Assume all are missing if we can't check
    }
  }

  /// Extracts symbols from binary using platform-specific tools
  Future<Set<String>> _getSymbolsFromBinary(String binaryPath) async {
    ProcessResult result;

    switch (platformInfo.platform) {
      case 'windows':
        // Use dumpbin to get symbols on Windows
        result = await Process.run('dumpbin', ['/exports', binaryPath]);
        break;
      case 'macos':
        // Use nm to get symbols on macOS
        result = await Process.run('nm', ['-D', binaryPath]);
        break;
      case 'linux':
        // Use readelf to get symbols on Linux
        result = await Process.run('readelf', ['-Ws', binaryPath]);
        break;
      default:
        throw UnsupportedError('Symbol extraction not supported on ${platformInfo.platform}');
    }

    if (result.exitCode == 0) {
      return _parseSymbolsFromOutput(result.stdout.toString());
    } else {
      throw Exception('Failed to extract symbols: ${result.stderr}');
    }
  }

  /// Parses symbols from tool output
  Set<String> _parseSymbolsFromOutput(String output) {
    final symbols = <String>{};
    final lines = output.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Extract symbol names based on platform-specific output format
      switch (platformInfo.platform) {
        case 'windows':
          // dumpbin output format: ordinal hint RVA name
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            symbols.add(parts.last);
          }
          break;
        case 'macos':
        case 'linux':
          // nm/readelf output format varies, but symbol name is typically last
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) {
            final symbolName = parts.last;
            if (symbolName.isNotEmpty && !symbolName.startsWith('0x')) {
              symbols.add(symbolName);
            }
          }
          break;
      }
    }

    return symbols;
  }

  /// Checks if the detected architecture is compatible
  bool _isCompatibleArchitecture(String output) {
    switch (platformInfo.architecture.toLowerCase()) {
      case 'x64':
      case 'amd64':
        return output.contains('x86-64') || output.contains('x86_64') || output.contains('amd64') || output.contains('x64');
      case 'x86':
        return output.contains('i386') || output.contains('x86') || output.contains('i686');
      case 'arm64':
        return output.contains('arm64') || output.contains('aarch64');
      default:
        return false;
    }
  }

  /// Extracts version information from tool output
  String? _extractVersionFromOutput(String output) {
    // Simple version extraction - can be enhanced
    final versionRegex = RegExp(r'(\d+\.\d+(?:\.\d+)?)');
    final match = versionRegex.firstMatch(output);
    return match?.group(1);
  }

  /// Validates all FFMPEG binaries for the current platform
  Future<Map<String, BinaryValidationResult>> validateAllBinaries(String basePath) async {
    final results = <String, BinaryValidationResult>{};
    final expectedLibraries = platformInfo.getExpectedLibraryNames();

    for (final libraryName in expectedLibraries) {
      // Try lib/ subdirectory first (new structure), then direct path (legacy)
      String binaryPath = '$basePath/lib/$libraryName';
      if (!await File(binaryPath).exists()) {
        binaryPath = '$basePath/$libraryName';
      }
      
      results[libraryName] = await validateBinary(binaryPath);
    }

    return results;
  }
}
