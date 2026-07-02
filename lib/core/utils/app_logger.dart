import 'package:flutter/foundation.dart';

/// Centralized logging utility for Orbit.
///
/// Automatically suppresses output in production/release mode.
class AppLogger {
  AppLogger._();

  /// Logs a fine-grained development/diagnostic message.
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log('DEBUG', message, error, stackTrace);
    }
  }

  /// Logs general informational messages tracking application lifecycle or state changes.
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log('INFO', message, error, stackTrace);
    }
  }

  /// Logs warnings about recoverable issues or odd/non-fatal behaviors.
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log('WARNING', message, error, stackTrace);
    }
  }

  /// Logs exceptions, errors, or fatal failures.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log('ERROR', message, error, stackTrace);
    }
  }

  static void _log(
    String level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 12);
    final logMessage = '[$timestamp] [$level] $message';
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('Error details: $error');
    }
    if (stackTrace != null) {
      debugPrint('StackTrace:\n$stackTrace');
    }
  }
}
