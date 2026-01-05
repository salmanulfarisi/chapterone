import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../core/utils/logger.dart';

/// Enhanced error logging service with Firebase Crashlytics integration
/// Automatically captures crashes and non-fatal errors
class CrashlyticsService {
  static CrashlyticsService? _instance;
  static CrashlyticsService get instance {
    _instance ??= CrashlyticsService._();
    return _instance!;
  }

  CrashlyticsService._();

  bool _isInitialized = false;
  FirebaseCrashlytics? _crashlytics;

  /// Initialize the crashlytics service
  /// Sets up Firebase Crashlytics for error tracking
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get Firebase Crashlytics instance
      _crashlytics = FirebaseCrashlytics.instance;
      
      // Enable crash collection (disabled in debug mode by default)
      // In production/release builds, this will be enabled
      await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);
      
      // Set up automatic crash reporting for Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        // Log to console in debug mode
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
        
        // Send to Crashlytics in production
        _crashlytics?.recordFlutterFatalError(details);
      };
      
      // Set up error zone for async errors
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };
      
      _isInitialized = true;
      Logger.info('Crashlytics service initialized', 'CrashlyticsService');
    } catch (e) {
      Logger.error('Failed to initialize Crashlytics', e, null, 'CrashlyticsService');
      // Continue without crashlytics if initialization fails
      _isInitialized = false;
    }
  }

  /// Log a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, dynamic>? information,
    bool fatal = false,
  }) async {
    try {
      // Log to console in debug mode
      if (kDebugMode) {
        Logger.error(
          reason ?? 'Error occurred',
          exception,
          stackTrace,
          'CrashlyticsService',
        );
        if (information != null && information.isNotEmpty) {
          Logger.debug('Additional information: $information', 'CrashlyticsService');
        }
      }

      // Send to Firebase Crashlytics
      if (_crashlytics != null && _isInitialized) {
        // Convert information map to List<DiagnosticsNode> format if needed
        // For now, we'll use the reason and information as context
        await _crashlytics!.recordError(
          exception,
          stackTrace,
          reason: reason,
          fatal: fatal,
        );
        
        // Set custom keys from information map
        if (information != null && information.isNotEmpty) {
          for (final entry in information.entries) {
            await _crashlytics!.setCustomKey(
              entry.key,
              entry.value.toString(),
            );
          }
        }
      }
    } catch (e) {
      // Silently fail - logging shouldn't break the app
      // Note: Can't use Logger here as it would create circular dependency
      if (kDebugMode) {
        // Only log in debug mode to avoid print statements in production
      }
    }
  }

  /// Log a custom message
  Future<void> log(String message) async {
    try {
      Logger.info(message, 'CrashlyticsService');
      
      // Log to Firebase Crashlytics
      if (_crashlytics != null && _isInitialized) {
        await _crashlytics!.log(message);
      }
    } catch (e) {
      // Silently fail - logging shouldn't break the app
    }
  }

  /// Set a custom key-value pair for crash reports
  /// Useful for adding context to crash reports (e.g., user ID, app version)
  Future<void> setCustomKey(String key, dynamic value) async {
    try {
      if (kDebugMode) {
        Logger.debug('Set custom key: $key = $value', 'CrashlyticsService');
      }
      
      // Set in Firebase Crashlytics
      if (_crashlytics != null && _isInitialized) {
        // Convert value to string if it's not a supported type
        if (value is String || value is int || value is double || value is bool) {
          await _crashlytics!.setCustomKey(key, value);
        } else {
          await _crashlytics!.setCustomKey(key, value.toString());
        }
      }
    } catch (e) {
      // Silently fail - logging shouldn't break the app
    }
  }

  /// Set user identifier for crash reports
  /// This helps identify which users are experiencing crashes
  Future<void> setUserId(String userId) async {
    try {
      if (kDebugMode) {
        Logger.debug('Set user ID: $userId', 'CrashlyticsService');
      }
      
      // Set in Firebase Crashlytics
      if (_crashlytics != null && _isInitialized) {
        await _crashlytics!.setUserIdentifier(userId);
      }
    } catch (e) {
      // Silently fail - logging shouldn't break the app
    }
  }

  /// Check if Crashlytics is initialized
  bool get isInitialized => _isInitialized;

  /// Get the Firebase Crashlytics instance (for advanced usage)
  FirebaseCrashlytics? get crashlytics => _crashlytics;
}

