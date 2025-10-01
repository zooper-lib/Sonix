/// Internal logging utilities for the Sonix package
///
/// This module provides logging functionality that:
/// - Uses dart:developer for standard Dart/Flutter logging
/// - Allows package-level debug logging control
/// - Can be intercepted by external logging frameworks
/// - Follows Flutter best practices for package logging
library;

import 'dart:developer' as developer;

import '../config/sonix_config.dart';

/// Internal logging helper for the Sonix package
class SonixLogger {
  /// Package name used for logging context
  static const String _packageName = 'Sonix';

  /// Current configured log level from SonixConfig (FFmpeg scale)
  static int _configuredLogLevel = 2; // Default ERROR level

  /// Set the log level from SonixConfig
  static void setLogLevel(int level) {
    _configuredLogLevel = level;
  }

  /// Logs a message with the specified level
  ///
  /// Messages are logged if:
  /// - The message level is at or above the configured log level, OR
  /// - Debug logging is explicitly enabled via SonixConfig.enableDebugLogging
  ///
  /// Uses log level scale:
  /// * 2 = ERROR - Only critical errors
  /// * 3 = WARNING - Warnings and above
  /// * 4 = INFO - Info messages and above
  /// * 6 = DEBUG - Debug messages and above (shows all)
  static void _log(String message, {required int level, String? name, Object? error, StackTrace? stackTrace}) {
    final shouldLog = level <= _configuredLogLevel || SonixConfig.enableDebugLogging;

    if (shouldLog) {
      // Convert level to dart:developer level for proper display
      final dartLevel = level * 100; // Simple conversion for dart:developer
      developer.log(message, name: name ?? _packageName, level: dartLevel, error: error, stackTrace: stackTrace);
    }
  }

  /// Logs an error message (level 2)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(message, level: 2, error: error, stackTrace: stackTrace);
  }

  /// Logs a warning message (level 3)
  static void warning(String message) {
    _log(message, level: 3);
  }

  /// Logs an info message (level 4)
  static void info(String message) {
    _log(message, level: 4);
  }

  /// Logs a debug message (level 6)
  static void debug(String message) {
    _log(message, level: 6);
  }

  /// Logs a trace message (level 6)
  static void trace(String message) {
    _log(message, level: 6);
  }

  /// Logs isolate-specific messages with context
  static void isolate(String isolateId, String message, {int level = 6}) {
    _log('[$isolateId] $message', level: level, name: '$_packageName.Isolate');
  }

  /// Logs native operation messages with context
  static void native(String operation, String message, {int level = 6}) {
    _log('[$operation] $message', level: level, name: '$_packageName.Native');
  }
}
