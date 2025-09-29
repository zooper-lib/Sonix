import 'package:sonix/src/isolate/isolate_config.dart';

/// Configuration class for Sonix instances
///
/// Provides configuration options for isolate management and memory usage.
class SonixConfig implements IsolateConfig {
  /// Maximum number of concurrent operations
  @override
  final int maxConcurrentOperations;

  /// Size of the isolate pool for background processing
  @override
  final int isolatePoolSize;

  /// Timeout for idle isolates before cleanup
  @override
  final Duration isolateIdleTimeout;

  /// Maximum memory usage in bytes
  @override
  final int maxMemoryUsage;

  /// Whether to enable progress reporting
  final bool enableProgressReporting;

  /// FFmpeg log level configuration
  ///
  /// Controls the verbosity of FFmpeg logging output:
  /// * -1 = QUIET (no output)
  /// * 0 = PANIC (only critical errors)
  /// * 1 = FATAL
  /// * 2 = ERROR (recommended default - suppresses MP3 warnings)
  /// * 3 = WARNING (shows all warnings including MP3 format detection)
  /// * 4 = INFO
  /// * 5 = VERBOSE
  /// * 6 = DEBUG (maximum verbosity)
  ///
  /// For production apps, level 2 (ERROR) is recommended to suppress
  /// noisy MP3 format detection warnings while still showing actual errors.
  final int logLevel;

  /// Global flag to enable debug logging
  ///
  /// When true, debug messages will be logged even in release builds.
  /// This is useful for package developers or when debugging issues.
  /// End users typically should leave this false.
  static bool enableDebugLogging = false;

  const SonixConfig({
    this.maxConcurrentOperations = 3,
    this.isolatePoolSize = 2,
    this.isolateIdleTimeout = const Duration(minutes: 5),
    this.maxMemoryUsage = 100 * 1024 * 1024, // 100MB
    this.logLevel = 2, // ERROR level - suppresses MP3 warnings
    this.enableProgressReporting = true,
  });

  /// Create a default configuration
  factory SonixConfig.defaultConfig() => const SonixConfig();

  /// Create a configuration optimized for mobile devices
  factory SonixConfig.mobile() => const SonixConfig(
    maxConcurrentOperations: 2,
    isolatePoolSize: 1,
    maxMemoryUsage: 50 * 1024 * 1024, // 50MB
    logLevel: 2, // ERROR level - suppress MP3 warnings
  );

  /// Create a configuration optimized for desktop devices
  factory SonixConfig.desktop() => const SonixConfig(
    maxConcurrentOperations: 4,
    isolatePoolSize: 3,
    maxMemoryUsage: 200 * 1024 * 1024, // 200MB
    logLevel: 2, // ERROR level - suppress MP3 warnings for desktop
  );

  /// Enable debug logging for the entire package
  ///
  /// This will cause debug messages to be logged even in release builds.
  /// Useful for debugging issues or package development.
  static void enableDebugLogs() {
    enableDebugLogging = true;
  }

  /// Disable debug logging for the entire package
  ///
  /// This is the default state. Only error messages will be logged.
  static void disableDebugLogs() {
    enableDebugLogging = false;
  }

  @override
  String toString() {
    return 'SonixConfig('
        'maxConcurrentOperations: $maxConcurrentOperations, '
        'isolatePoolSize: $isolatePoolSize, '
        'isolateIdleTimeout: $isolateIdleTimeout, '
        'maxMemoryUsage: ${(maxMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB'
        ')';
  }
}
