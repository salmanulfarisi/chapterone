import 'package:flutter/foundation.dart';
import '../../core/utils/logger.dart';
import '../logging/crashlytics_service.dart';

/// Service for monitoring app performance and metrics
class PerformanceMonitor {
  static PerformanceMonitor? _instance;
  static PerformanceMonitor get instance {
    _instance ??= PerformanceMonitor._();
    return _instance!;
  }

  PerformanceMonitor._();

  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};

  /// Start tracking an operation
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
  }

  /// End tracking an operation and record the duration
  Duration? endOperation(String operationName) {
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);
    
    // Store duration for analytics
    _operationDurations.putIfAbsent(operationName, () => []);
    _operationDurations[operationName]!.add(duration);

    // Log slow operations
    if (duration.inMilliseconds > 1000) {
      Logger.warning(
        'Slow operation detected: $operationName took ${duration.inMilliseconds}ms',
        'PerformanceMonitor',
      );
      
      // Record to crashlytics in production
      if (!kDebugMode) {
        CrashlyticsService.instance.log(
          'Slow operation: $operationName (${duration.inMilliseconds}ms)',
        );
      }
    }

    return duration;
  }

  /// Get average duration for an operation
  Duration? getAverageDuration(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) return null;

    final total = durations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    return Duration(milliseconds: total ~/ durations.length);
  }

  /// Track memory usage (approximate)
  void trackMemoryUsage() {
    // In production, this could integrate with Firebase Performance Monitoring
    if (kDebugMode) {
      Logger.debug('Memory tracking not implemented in debug mode', 'PerformanceMonitor');
    }
  }

  /// Record a custom metric
  void recordMetric(String metricName, double value, {Map<String, dynamic>? attributes}) {
    if (kDebugMode) {
      Logger.debug('Metric: $metricName = $value', 'PerformanceMonitor');
    }
    
    // In production, send to analytics service
    // FirebaseAnalytics.instance.logEvent(...)
  }

  /// Clear all stored metrics
  void clearMetrics() {
    _operationDurations.clear();
    _operationStartTimes.clear();
  }
}

