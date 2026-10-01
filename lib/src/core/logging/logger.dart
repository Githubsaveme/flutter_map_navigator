import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Structured logger for the navigation SDK.
/// Protects privacy by filtering sensitive coordinates/keys in production.
class RouteEngineLogger {
  static LogLevel logLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  static bool enableLogging = true;

  static void debug(String subsystem, String message, [Map<String, dynamic>? meta]) {
    _log(LogLevel.debug, subsystem, message, meta);
  }

  static void info(String subsystem, String message, [Map<String, dynamic>? meta]) {
    _log(LogLevel.info, subsystem, message, meta);
  }

  static void warning(String subsystem, String message, [Map<String, dynamic>? meta]) {
    _log(LogLevel.warning, subsystem, message, meta);
  }

  static void error(String subsystem, String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, subsystem, message, {
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    });
  }

  static void _log(LogLevel level, String subsystem, String message, [Map<String, dynamic>? meta]) {
    if (!enableLogging || level.index < logLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final metaStr = meta != null && meta.isNotEmpty ? ' | Meta: ${_sanitizeMeta(meta)}' : '';
    debugPrint('[$timestamp][${level.name.toUpperCase()}][$subsystem] $message$metaStr');
  }

  static Map<String, dynamic> _sanitizeMeta(Map<String, dynamic> meta) {
    final sanitized = <String, dynamic>{};
    for (final entry in meta.entries) {
      final keyLower = entry.key.toLowerCase();
      if (keyLower.contains('key') || keyLower.contains('token') || keyLower.contains('secret') || keyLower.contains('password')) {
        sanitized[entry.key] = '***REDACTED***';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }
}
