import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../models/notification_preferences_model.dart';
import '../api/api_service.dart';
import '../../core/constants/api_constants.dart';

final smartNotificationServiceProvider = Provider<SmartNotificationService>((ref) {
  return SmartNotificationService(ref.read(apiServiceProvider));
});

class SmartNotificationService {
  final ApiService _apiService;

  SmartNotificationService(this._apiService);

  /// Get user's notification preferences
  Future<NotificationPreferences> getPreferences() async {
    try {
      final response = await _apiService.get(ApiConstants.notificationPreferences);
      return NotificationPreferences.fromJson(response.data);
    } catch (e) {
      Logger.warning('Failed to get notification preferences, using defaults', 'SmartNotificationService');
      return NotificationPreferences();
    }
  }

  /// Update user's notification preferences
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    try {
      await _apiService.put(
        ApiConstants.notificationPreferences,
        data: preferences.toJson(),
      );
      Logger.info('Notification preferences updated', 'SmartNotificationService');
    } catch (e) {
      Logger.error('Failed to update notification preferences', e, null, 'SmartNotificationService');
      rethrow;
    }
  }

  /// Get notification preferences for a specific manga
  Future<MangaNotificationSettings> getMangaSettings(String mangaId) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.notificationMangaSettings}/$mangaId',
      );
      return MangaNotificationSettings.fromJson(response.data);
    } catch (e) {
      Logger.warning('Failed to get manga notification settings, using defaults', 'SmartNotificationService');
      return MangaNotificationSettings();
    }
  }

  /// Update notification preferences for a specific manga
  Future<void> updateMangaSettings(
    String mangaId,
    MangaNotificationSettings settings,
  ) async {
    try {
      await _apiService.put(
        '${ApiConstants.notificationMangaSettings}/$mangaId',
        data: settings.toJson(),
      );
      Logger.info('Manga notification settings updated', 'SmartNotificationService');
    } catch (e) {
      Logger.error('Failed to update manga notification settings', e, null, 'SmartNotificationService');
      rethrow;
    }
  }

  /// Check if current time is within user's active hours
  bool isWithinActiveHours(NotificationPreferences preferences) {
    if (!preferences.enabled) return false;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    return preferences.activeHours.contains(currentHour);
  }

  /// Get next optimal notification time based on active hours
  DateTime? getNextOptimalTime(NotificationPreferences preferences) {
    if (!preferences.enabled || preferences.activeHours.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Find next active hour
    for (final hour in preferences.activeHours) {
      if (hour > currentHour) {
        return DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          0,
        );
      }
    }
    
    // If no active hour found today, use first active hour tomorrow
    final firstActiveHour = preferences.activeHours.first;
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      firstActiveHour,
      0,
    );
  }

  /// Schedule digest notification
  Future<void> scheduleDigest(NotificationPreferences preferences) async {
    if (!preferences.digestEnabled || !preferences.enabled) {
      return;
    }

    try {
      var digestTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        preferences.digestTime,
        0,
      );

      // If digest time has passed today, schedule for tomorrow
      if (digestTime.isBefore(DateTime.now())) {
        digestTime = digestTime.add(const Duration(days: 1));
      }

      await _apiService.post(
        '${ApiConstants.notifications}/schedule-digest',
        data: {
          'scheduledTime': digestTime.toIso8601String(),
          'frequency': preferences.digestFrequency,
        },
      );

      Logger.info('Digest notification scheduled', 'SmartNotificationService');
    } catch (e) {
      Logger.error('Failed to schedule digest notification', e, null, 'SmartNotificationService');
    }
  }

  /// Update active hours based on user's reading patterns
  Future<void> updateActiveHoursFromPatterns(List<int> activeHours) async {
    try {
      final preferences = await getPreferences();
      final updated = preferences.copyWith(activeHours: activeHours);
      await updatePreferences(updated);
      Logger.info('Active hours updated from reading patterns', 'SmartNotificationService');
    } catch (e) {
      Logger.error('Failed to update active hours', e, null, 'SmartNotificationService');
    }
  }
}

