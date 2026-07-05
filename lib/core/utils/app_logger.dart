// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';

/// Log categories/tags to track processes in Orbit.
enum LogTag {
  AUTH('[AUTH]'),
  CRYPTO('[CRYPTO]'),
  FIRESTORE('[FIRESTORE]'),
  LOCAL_DB('[LOCAL_DB]'),
  SYNC('[SYNC]'),
  UI('[UI]');

  final String value;
  const LogTag(this.value);
}

/// Centralized logging utility for Orbit.
///
/// Automatically suppresses output in production/release mode.
class AppLogger {
  AppLogger._();

  /// Logs a fine-grained development/diagnostic message.
  static void debug(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    LogTag? tag,
  ]) {
    if (kDebugMode) {
      _log('DEBUG', message, error, stackTrace, tag);
    }
  }

  /// Logs general informational messages tracking application lifecycle or state changes.
  static void info(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    LogTag? tag,
  ]) {
    if (kDebugMode) {
      _log('INFO', message, error, stackTrace, tag);
    }
  }

  /// Logs warnings about recoverable issues or odd/non-fatal behaviors.
  static void warning(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    LogTag? tag,
  ]) {
    if (kDebugMode) {
      _log('WARNING', message, error, stackTrace, tag);
    }
  }

  /// Logs exceptions, errors, or fatal failures.
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    LogTag? tag,
  ]) {
    if (kDebugMode) {
      _log('ERROR', message, error, stackTrace, tag);
    }
  }

  static void _log(
    String level,
    String message,
    Object? error,
    StackTrace? stackTrace, [
    LogTag? tag,
  ]) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 12);

    final resolvedTag = tag ?? _detectTag(message);
    final tagStr = resolvedTag != null ? ' ${resolvedTag.value}' : '';

    final logMessage = '[ORBIT] [$timestamp] [$level]$tagStr $message';
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('[ORBIT] Error details: $error');
    }
    if (stackTrace != null) {
      debugPrint('[ORBIT] StackTrace:\n$stackTrace');
    }
  }

  static LogTag? _detectTag(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('sync') ||
        lower.contains('queue') ||
        lower.contains('upload') ||
        lower.contains('worker')) {
      return LogTag.SYNC;
    }
    if (lower.contains('auth') ||
        lower.contains('recovery') ||
        lower.contains('login') ||
        lower.contains('signup') ||
        lower.contains('sign-in') ||
        lower.contains('sign-out') ||
        lower.contains('passphrase')) {
      return LogTag.AUTH;
    }
    if (lower.contains('crypto') ||
        lower.contains('encrypt') ||
        lower.contains('decrypt') ||
        lower.contains('envelope') ||
        lower.contains('masterkey') ||
        lower.contains('dek') ||
        lower.contains('hkdf') ||
        lower.contains('keymanager')) {
      return LogTag.CRYPTO;
    }
    if (lower.contains('firestore') ||
        lower.contains('cloud_firestore') ||
        lower.contains('remote doc') ||
        lower.contains('col(')) {
      return LogTag.FIRESTORE;
    }
    if (lower.contains('drift') ||
        lower.contains('database') ||
        lower.contains('sqlite') ||
        lower.contains('local db') ||
        lower.contains('table') ||
        lower.contains('local_database')) {
      return LogTag.LOCAL_DB;
    }
    if (lower.contains('view') ||
        lower.contains('widget') ||
        lower.contains('page') ||
        lower.contains('ui') ||
        lower.contains('controller') ||
        lower.contains('dialog')) {
      return LogTag.UI;
    }
    return null;
  }
}
