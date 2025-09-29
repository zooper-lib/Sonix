/// Internal logging utilities for the Sonix package
///
/// This module provides logging functionality that:
/// - Uses dart:developer for standard Dart/Flutter logging
/// - Respects kDebugMode for automatic filtering in release builds
/// - Allows package-level debug logging control
/// - Can be intercepted by external logging frameworks
/// - Follows Flutter best practices for package logging
library;

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import '../config/sonix_config.dart';

/// Log levels for different types of messages
class SonixLogLevel {
  /// Critical errors that should always be reported
  static const int error = 1000;

  /// Important warnings that users should be aware of
  static const int warning = 800;

  /// General information messages
  static const int info = 500;

  /// Debug information for developers
  static const int debug = 300;

  /// Very detailed trace information
  static const int trace = 100;
}

/// Internal logging helper for the Sonix package
class SonixLogger {
  /// Package name used for logging context
  static const String _packageName = 'Sonix';

  /// Logs a message with the specified level
  ///
  /// Messages are only logged if:
  /// - We're in debug mode (kDebugMode), OR
  /// - Debug logging is explicitly enabled via SonixConfig
  ///
  /// Error level messages are always logged regardless of debug settings
  static void _log(String message, {required int level, String? name, Object? error, StackTrace? stackTrace}) {
    final shouldLog = level >= SonixLogLevel.error || kDebugMode || SonixConfig.enableDebugLogging;

    if (shouldLog) {
      developer.log(message, name: name ?? _packageName, level: level, error: error, stackTrace: stackTrace);
    }
  }

  /// Logs an error message (always visible, can be intercepted)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(message, level: SonixLogLevel.error, error: error, stackTrace: stackTrace);
  }

  /// Logs a warning message (visible in debug mode or when enabled)
  static void warning(String message) {
    _log(message, level: SonixLogLevel.warning);
  }

  /// Logs an info message (visible in debug mode or when enabled)
  static void info(String message) {
    _log(message, level: SonixLogLevel.info);
  }

  /// Logs a debug message (visible in debug mode or when enabled)
  static void debug(String message) {
    _log(message, level: SonixLogLevel.debug);
  }

  /// Logs a trace message (visible in debug mode or when enabled)
  static void trace(String message) {
    _log(message, level: SonixLogLevel.trace);
  }

  /// Logs isolate-specific messages with context
  static void isolate(String isolateId, String message, {int level = SonixLogLevel.debug}) {
    _log('[$isolateId] $message', level: level, name: '$_packageName.Isolate');
  }

  /// Logs native operation messages with context
  static void native(String operation, String message, {int level = SonixLogLevel.debug}) {
    _log('[$operation] $message', level: level, name: '$_packageName.Native');
  }
}
