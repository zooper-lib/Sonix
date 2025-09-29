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

    this.enableProgressReporting = true,
  });

  /// Create a default configuration
  factory SonixConfig.defaultConfig() => const SonixConfig();

  /// Create a configuration optimized for mobile devices
  factory SonixConfig.mobile() => const SonixConfig(
    maxConcurrentOperations: 2,
    isolatePoolSize: 1,
    maxMemoryUsage: 50 * 1024 * 1024, // 50MB
  );

  /// Create a configuration optimized for desktop devices
  factory SonixConfig.desktop() => const SonixConfig(
    maxConcurrentOperations: 4,
    isolatePoolSize: 3,
    maxMemoryUsage: 200 * 1024 * 1024, // 200MB
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
