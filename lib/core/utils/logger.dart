import 'package:flutter/foundation.dart';
import '../../services/logging/crashlytics_service.dart';

class Logger {
  /// Enhanced logger that also sends errors to Crashlytics in production
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      print('[DEBUG]${tag != null ? ' [$tag]' : ''}: $message');
    }
  }

  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      print('[INFO]${tag != null ? ' [$tag]' : ''}: $message');
    }
  }

  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      print('[WARNING]${tag != null ? ' [$tag]' : ''}: $message');
    }
    
    // Log warnings to Crashlytics in production
    if (!kDebugMode) {
      CrashlyticsService.instance.log('WARNING${tag != null ? ' [$tag]' : ''}: $message');
    }
  }

  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    if (kDebugMode) {
      print('[ERROR]${tag != null ? ' [$tag]' : ''}: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // Always record errors to Crashlytics (even in debug mode for testing)
    CrashlyticsService.instance.recordError(
      error ?? message,
      stackTrace,
      reason: message,
      information: {'tag': tag},
      fatal: false,
    );
  }

  /// Log a fatal error (app-crashing error)
  static void fatal(
    String message,
    Object error,
    StackTrace stackTrace, [
    String? tag,
    Map<String, dynamic>? context,
  ]) {
    Logger.error(message, error, stackTrace, tag);
    
    // Mark as fatal in Crashlytics
    CrashlyticsService.instance.recordError(
      error,
      stackTrace,
      reason: message,
      information: {
        'tag': tag,
        if (context != null) ...context,
      },
      fatal: true,
    );
  }
}

