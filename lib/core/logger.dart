import 'package:flutter/foundation.dart';
import '../services/error_log.dart';

/// Central application logger.
///
/// In debug mode ([kDebugMode]), messages are printed to the console using [debugPrint].
/// In profile/release mode, debug and info messages are silenced, while warnings
/// and errors are recorded into the persistent [ErrorLog] ring buffer.
class AppLog {
  AppLog._();

  /// Logs a debug/diagnostic message. Only printed in [kDebugMode].
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Alias for [d]. Only printed in [kDebugMode].
  static void debug(String message) => d(message);

  /// Logs an informational message. Only printed in [kDebugMode].
  static void i(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Alias for [i]. Only printed in [kDebugMode].
  static void info(String message) => i(message);

  /// Logs a warning.
  /// - In debug mode: prints to console.
  /// - In release mode: records into [ErrorLog].
  static void w(String message, [dynamic error, StackTrace? stack]) {
    if (kDebugMode) {
      final detail = error != null ? ': $error' : '';
      debugPrint('[WARN] $message$detail');
      if (stack != null) debugPrint(stack.toString());
    } else {
      ErrorLog.record(error ?? message, stack, 'warn');
    }
  }

  /// Alias for [w].
  static void warning(String message, [dynamic error, StackTrace? stack]) =>
      w(message, error, stack);

  /// Logs an error.
  /// - In debug mode: prints to console.
  /// - In release mode: records into [ErrorLog].
  static void e(
    String message, [
    dynamic error,
    StackTrace? stack,
    String context = 'error',
  ]) {
    if (kDebugMode) {
      final detail = error != null ? ': $error' : '';
      debugPrint('[ERROR] $message$detail');
      if (stack != null) debugPrint(stack.toString());
    } else {
      ErrorLog.record(error ?? message, stack, context);
    }
  }

  /// Alias for [e].
  static void error(
    String message, [
    dynamic error,
    StackTrace? stack,
    String context = 'error',
  ]) =>
      e(message, error, stack, context);
}
