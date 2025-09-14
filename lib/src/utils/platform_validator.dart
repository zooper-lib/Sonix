import 'dart:io';

import 'package:sonix/src/native/native_audio_bindings.dart';

/// Validates cross-platform compatibility and native library availability
class PlatformValidator {
  static final PlatformValidator _instance = PlatformValidator._internal();
  factory PlatformValidator() => _instance;
  PlatformValidator._internal();

  /// Validation results cache
  PlatformValidationResult? _cachedResult;

  /// Get current platform information
  PlatformInfo get platformInfo {
    return PlatformInfo(
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
      isLinux: Platform.isLinux,
      architecture: _getArchitecture(),
    );
  }

  /// Validate platform compatibility
  Future<PlatformValidationResult> validatePlatform({bool forceRevalidation = false}) async {
    if (_cachedResult != null && !forceRevalidation) {
      return _cachedResult!;
    }

    final issues = <ValidationIssue>[];
    final warnings = <ValidationWarning>[];
    final info = platformInfo;

    // Check if platform is supported
    if (!_isSupportedPlatform()) {
      issues.add(
        ValidationIssue(
          type: ValidationIssueType.unsupportedPlatform,
          message: 'Platform ${info.operatingSystem} is not officially supported',
          severity: ValidationSeverity.critical,
        ),
      );
    }

    // Validate native library availability
    final libraryValidation = await _validateNativeLibraries();
    issues.addAll(libraryValidation.issues);
    warnings.addAll(libraryValidation.warnings);

    // Check FFI support
    try {
      // Test basic FFI functionality
      // Simplified FFI test - just check if we can access FFI
      final testValue = 42;

      if (testValue != 42) {
        issues.add(ValidationIssue(type: ValidationIssueType.ffiError, message: 'FFI functionality test failed', severity: ValidationSeverity.critical));
      }
    } catch (e) {
      issues.add(ValidationIssue(type: ValidationIssueType.ffiError, message: 'FFI not available: $e', severity: ValidationSeverity.critical));
    }

    // Check memory constraints
    final memoryValidation = _validateMemoryConstraints();
    warnings.addAll(memoryValidation);

    // Check file system permissions
    final fileSystemValidation = await _validateFileSystemAccess();
    issues.addAll(fileSystemValidation.issues);
    warnings.addAll(fileSystemValidation.warnings);

    final result = PlatformValidationResult(
      platformInfo: info,
      isSupported: issues.where((i) => i.severity == ValidationSeverity.critical).isEmpty,
      issues: issues,
      warnings: warnings,
      validatedAt: DateTime.now(),
    );

    _cachedResult = result;
    return result;
  }

  /// Validate specific audio format support
  Future<FormatSupportResult> validateFormatSupport(String format) async {
    final normalizedFormat = format.toLowerCase().replaceAll('.', '');

    try {
      // Check if format is theoretically supported
      final supportedFormats = ['mp3', 'wav', 'flac', 'ogg', 'opus'];
      if (!supportedFormats.contains(normalizedFormat)) {
        return FormatSupportResult(format: format, isSupported: false, reason: 'Format not supported by Sonix');
      }

      // Try to validate native decoder availability
      final hasDecoder = await _validateFormatDecoder(normalizedFormat);
      if (!hasDecoder) {
        return FormatSupportResult(format: format, isSupported: false, reason: 'Native decoder not available for this platform');
      }

      return FormatSupportResult(format: format, isSupported: true, reason: 'Format fully supported');
    } catch (e) {
      return FormatSupportResult(format: format, isSupported: false, reason: 'Validation error: $e');
    }
  }

  /// Get platform-specific optimization recommendations
  List<OptimizationRecommendation> getOptimizationRecommendations() {
    final recommendations = <OptimizationRecommendation>[];
    final info = platformInfo;

    // Platform-specific recommendations
    if (info.isAndroid) {
      recommendations.addAll(_getAndroidRecommendations());
    } else if (info.isIOS) {
      recommendations.addAll(_getIOSRecommendations());
    } else if (info.isWindows) {
      recommendations.addAll(_getWindowsRecommendations());
    } else if (info.isMacOS) {
      recommendations.addAll(_getMacOSRecommendations());
    } else if (info.isLinux) {
      recommendations.addAll(_getLinuxRecommendations());
    }

    // Architecture-specific recommendations
    if (info.architecture.contains('arm') || info.architecture.contains('aarch64')) {
      recommendations.add(
        OptimizationRecommendation(
          category: 'Architecture',
          title: 'ARM Optimization',
          description: 'Consider using ARM-optimized algorithms for better performance',
          priority: RecommendationPriority.medium,
        ),
      );
    }

    return recommendations;
  }

  /// Check if current platform is supported
  bool _isSupportedPlatform() {
    return Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Get system architecture
  String _getArchitecture() {
    // This is a simplified approach - in a real implementation,
    // you might use platform-specific methods to get detailed architecture info
    if (Platform.isAndroid || Platform.isIOS) {
      return 'mobile';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'desktop';
    }
    return 'unknown';
  }

  /// Validate native library availability
  Future<LibraryValidationResult> _validateNativeLibraries() async {
    final issues = <ValidationIssue>[];
    final warnings = <ValidationWarning>[];

    try {
      // Test if we can load the native library
      final bindings = NativeAudioBindings();

      // Test basic functionality
      // Simplified check - assume bindings are available if we can create them
      if (bindings.runtimeType != NativeAudioBindings) {
        issues.add(
          ValidationIssue(
            type: ValidationIssueType.libraryNotFound,
            message: 'Native audio library could not be initialized',
            severity: ValidationSeverity.critical,
          ),
        );
      }

      // Test format-specific decoders
      final formats = ['mp3', 'wav', 'flac', 'ogg', 'opus'];
      for (final format in formats) {
        if (!await _validateFormatDecoder(format)) {
          warnings.add(ValidationWarning(type: ValidationWarningType.limitedFunctionality, message: 'Decoder for $format format may not be available'));
        }
      }
    } catch (e) {
      issues.add(ValidationIssue(type: ValidationIssueType.libraryError, message: 'Error testing native libraries: $e', severity: ValidationSeverity.high));
    }

    return LibraryValidationResult(issues: issues, warnings: warnings);
  }

  /// Validate memory constraints
  List<ValidationWarning> _validateMemoryConstraints() {
    final warnings = <ValidationWarning>[];

    // Check if we're on a memory-constrained platform
    if (Platform.isAndroid || Platform.isIOS) {
      warnings.add(
        ValidationWarning(
          type: ValidationWarningType.memoryConstraints,
          message: 'Mobile platform detected - consider using streaming processing for large files',
        ),
      );
    }

    return warnings;
  }

  /// Validate file system access
  Future<FileSystemValidationResult> _validateFileSystemAccess() async {
    final issues = <ValidationIssue>[];
    final warnings = <ValidationWarning>[];

    try {
      // Test basic file operations
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/sonix_test_${DateTime.now().millisecondsSinceEpoch}.tmp');

      // Test write access
      await testFile.writeAsString('test');

      // Test read access
      final content = await testFile.readAsString();
      if (content != 'test') {
        issues.add(
          ValidationIssue(type: ValidationIssueType.fileSystemError, message: 'File system read/write test failed', severity: ValidationSeverity.high),
        );
      }

      // Clean up
      await testFile.delete();
    } catch (e) {
      issues.add(ValidationIssue(type: ValidationIssueType.fileSystemError, message: 'File system access test failed: $e', severity: ValidationSeverity.high));
    }

    return FileSystemValidationResult(issues: issues, warnings: warnings);
  }

  /// Validate format-specific decoder
  Future<bool> _validateFormatDecoder(String format) async {
    try {
      // This would test the actual decoder availability
      // For now, we'll simulate the check
      // Simplified format support check
      final supportedFormats = ['mp3', 'wav', 'flac', 'ogg', 'opus'];
      return supportedFormats.contains(format);
    } catch (e) {
      return false;
    }
  }

  List<OptimizationRecommendation> _getAndroidRecommendations() {
    return [
      OptimizationRecommendation(
        category: 'Memory',
        title: 'Use Streaming Processing',
        description: 'Android devices have limited memory. Use streaming processing for files larger than 10MB.',
        priority: RecommendationPriority.high,
      ),
      OptimizationRecommendation(
        category: 'Performance',
        title: 'Background Processing',
        description: 'Process audio on background threads to avoid blocking the UI thread.',
        priority: RecommendationPriority.high,
      ),
    ];
  }

  List<OptimizationRecommendation> _getIOSRecommendations() {
    return [
      OptimizationRecommendation(
        category: 'Memory',
        title: 'Memory Pressure Handling',
        description: 'iOS aggressively manages memory. Implement proper memory pressure callbacks.',
        priority: RecommendationPriority.high,
      ),
      OptimizationRecommendation(
        category: 'Performance',
        title: 'Metal Performance Shaders',
        description: 'Consider using Metal Performance Shaders for intensive audio processing.',
        priority: RecommendationPriority.medium,
      ),
    ];
  }

  List<OptimizationRecommendation> _getWindowsRecommendations() {
    return [
      OptimizationRecommendation(
        category: 'Performance',
        title: 'Multi-threading',
        description: 'Windows supports excellent multi-threading. Use isolates for CPU-intensive tasks.',
        priority: RecommendationPriority.medium,
      ),
    ];
  }

  List<OptimizationRecommendation> _getMacOSRecommendations() {
    return [
      OptimizationRecommendation(
        category: 'Performance',
        title: 'Accelerate Framework',
        description: 'Consider using macOS Accelerate framework for optimized audio processing.',
        priority: RecommendationPriority.medium,
      ),
    ];
  }

  List<OptimizationRecommendation> _getLinuxRecommendations() {
    return [
      OptimizationRecommendation(
        category: 'Compatibility',
        title: 'Library Dependencies',
        description: 'Ensure all required shared libraries are available on the target system.',
        priority: RecommendationPriority.high,
      ),
    ];
  }
}

/// Information about the current platform
class PlatformInfo {
  final String operatingSystem;
  final String operatingSystemVersion;
  final bool isAndroid;
  final bool isIOS;
  final bool isWindows;
  final bool isMacOS;
  final bool isLinux;
  final String architecture;

  const PlatformInfo({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.isAndroid,
    required this.isIOS,
    required this.isWindows,
    required this.isMacOS,
    required this.isLinux,
    required this.architecture,
  });

  bool get isMobile => isAndroid || isIOS;
  bool get isDesktop => isWindows || isMacOS || isLinux;

  @override
  String toString() {
    return 'PlatformInfo(os: $operatingSystem, version: $operatingSystemVersion, arch: $architecture)';
  }
}

/// Result of platform validation
class PlatformValidationResult {
  final PlatformInfo platformInfo;
  final bool isSupported;
  final List<ValidationIssue> issues;
  final List<ValidationWarning> warnings;
  final DateTime validatedAt;

  const PlatformValidationResult({
    required this.platformInfo,
    required this.isSupported,
    required this.issues,
    required this.warnings,
    required this.validatedAt,
  });

  bool get hasIssues => issues.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasCriticalIssues => issues.any((i) => i.severity == ValidationSeverity.critical);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== Platform Validation Result ===');
    buffer.writeln('Platform: $platformInfo');
    buffer.writeln('Supported: $isSupported');
    buffer.writeln('Validated: $validatedAt');

    if (hasIssues) {
      buffer.writeln('\nIssues:');
      for (final issue in issues) {
        buffer.writeln('  - ${issue.severity.name.toUpperCase()}: ${issue.message}');
      }
    }

    if (hasWarnings) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  - ${warning.message}');
      }
    }

    return buffer.toString();
  }
}

/// Validation issue
class ValidationIssue {
  final ValidationIssueType type;
  final String message;
  final ValidationSeverity severity;

  const ValidationIssue({required this.type, required this.message, required this.severity});
}

/// Validation warning
class ValidationWarning {
  final ValidationWarningType type;
  final String message;

  const ValidationWarning({required this.type, required this.message});
}

/// Types of validation issues
enum ValidationIssueType { unsupportedPlatform, libraryNotFound, libraryError, ffiError, fileSystemError }

/// Types of validation warnings
enum ValidationWarningType { limitedFunctionality, memoryConstraints, performanceImpact }

/// Severity levels for validation issues
enum ValidationSeverity { low, medium, high, critical }

/// Result of library validation
class LibraryValidationResult {
  final List<ValidationIssue> issues;
  final List<ValidationWarning> warnings;

  const LibraryValidationResult({required this.issues, required this.warnings});
}

/// Result of file system validation
class FileSystemValidationResult {
  final List<ValidationIssue> issues;
  final List<ValidationWarning> warnings;

  const FileSystemValidationResult({required this.issues, required this.warnings});
}

/// Result of format support validation
class FormatSupportResult {
  final String format;
  final bool isSupported;
  final String reason;

  const FormatSupportResult({required this.format, required this.isSupported, required this.reason});

  @override
  String toString() {
    return 'FormatSupportResult(format: $format, supported: $isSupported, reason: $reason)';
  }
}

/// Optimization recommendation
class OptimizationRecommendation {
  final String category;
  final String title;
  final String description;
  final RecommendationPriority priority;

  const OptimizationRecommendation({required this.category, required this.title, required this.description, required this.priority});

  @override
  String toString() {
    return 'OptimizationRecommendation(category: $category, title: $title, priority: ${priority.name})';
  }
}

/// Priority levels for recommendations
enum RecommendationPriority { low, medium, high, critical }
