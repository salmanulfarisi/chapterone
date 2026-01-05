import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_model.dart';
import '../../../models/notification_preferences_model.dart';
import '../../../services/notifications/smart_notification_service.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';

/// Provider for notification preferences
final notificationPreferencesProvider = FutureProvider<NotificationPreferences>((ref) async {
  final service = ref.watch(smartNotificationServiceProvider);
  return await service.getPreferences();
});

/// Provider for notifications list
final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.notifications);
    final List<dynamic> data = response.data['notifications'] ?? response.data ?? [];
    return data.map((json) => NotificationModel.fromJson(json)).toList();
  } catch (e) {
    return [];
  }
});

/// Provider for unread notifications count
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get('${ApiConstants.notifications}/unread-count');
    return response.data['count'] ?? 0;
  } catch (e) {
    return 0;
  }
});

/// Provider for manga notification settings
final mangaNotificationSettingsProvider = FutureProvider.family<MangaNotificationSettings, String>((ref, mangaId) async {
  final service = ref.watch(smartNotificationServiceProvider);
  return await service.getMangaSettings(mangaId);
});

