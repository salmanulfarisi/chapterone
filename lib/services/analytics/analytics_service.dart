import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/analytics/providers/analytics_provider.dart';
import '../../features/profile/providers/achievements_provider.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Track reading session
  static Future<void> trackReadingSession({
    required WidgetRef ref,
    required String mangaId,
    required String chapterId,
    required int chapterNumber,
    required int totalChapters,
    required DateTime sessionStart,
    DateTime? sessionEnd,
    int? timeSpent,
    int? pagesRead,
    bool? isCompleted,
    double? completionPercentage,
    int? lastPageRead,
    int? totalPages,
    List<String>? genres,
  }) async {
    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        return; // Don't track for anonymous users
      }

      final apiService = ref.read(apiServiceProvider);
      final endTime = sessionEnd ?? DateTime.now();
      final spent = timeSpent ??
          (endTime.difference(sessionStart).inSeconds);

      await apiService.post(
        ApiConstants.analyticsTrack,
        data: {
          'mangaId': mangaId,
          'chapterId': chapterId,
          'chapterNumber': chapterNumber,
          'totalChapters': totalChapters,
          'sessionStart': sessionStart.toIso8601String(),
          'sessionEnd': endTime.toIso8601String(),
          'timeSpent': spent,
          'pagesRead': pagesRead ?? 0,
          'isCompleted': isCompleted ?? false,
          'completionPercentage': completionPercentage ?? 0.0,
          'lastPageRead': lastPageRead ?? 0,
          'totalPages': totalPages ?? 0,
          'genres': genres ?? [],
        },
      );

      // Invalidate all analytics providers to refresh immediately
      Future.microtask(() {
        try {
          ref.invalidate(analyticsDashboardProvider);
          ref.invalidate(genrePreferencesProvider);
          ref.invalidate(readingPatternsProvider);
          ref.invalidate(completionDataProvider);
          ref.invalidate(dropoffAnalysisProvider);
          
          // Check for new achievements after tracking analytics
          _checkAchievements(ref);
        } catch (e) {
          // Ignore invalidation errors
        }
      });
    } catch (e) {
      Logger.error('Failed to track reading session', e, null, 'AnalyticsService');
      // Don't throw - analytics tracking should not break the app
    }
  }

  // Check for new achievements
  static Future<void> _checkAchievements(WidgetRef ref) async {
    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        return;
      }

      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(ApiConstants.achievementsCheck);
      
      if (response.data['newlyAwarded'] != null) {
        final List<dynamic> newlyAwarded = response.data['newlyAwarded'] as List;
        if (newlyAwarded.isNotEmpty) {
          // Invalidate achievements provider to refresh
          ref.invalidate(userAchievementsProvider);
          Logger.info('New achievements unlocked: ${newlyAwarded.join(", ")}', 'AnalyticsService');
        }
      }
    } catch (e) {
      // Silently fail - achievement checking should not break the app
      Logger.debug('Failed to check achievements: $e', 'AnalyticsService');
    }
  }
}

