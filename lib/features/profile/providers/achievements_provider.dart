import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/achievement_model.dart';
import '../../../core/utils/logger.dart';
import '../../../core/constants/api_constants.dart';
import '../../../services/api/api_service.dart';
import '../../auth/providers/auth_provider.dart';

// All available achievement types
final allAchievementsProvider = Provider<List<AchievementModel>>((ref) {
  return [
    AchievementModel(type: 'first_chapter', unlockedAt: DateTime.now()),
    AchievementModel(type: 'ten_chapters', unlockedAt: DateTime.now()),
    AchievementModel(type: 'hundred_chapters', unlockedAt: DateTime.now()),
    AchievementModel(type: 'week_streak', unlockedAt: DateTime.now()),
    AchievementModel(type: 'month_streak', unlockedAt: DateTime.now()),
    AchievementModel(type: 'year_streak', unlockedAt: DateTime.now()),
    AchievementModel(type: 'bookworm', unlockedAt: DateTime.now()),
    AchievementModel(type: 'speed_reader', unlockedAt: DateTime.now()),
  ];
});

// User achievements provider - fetches from API
final userAchievementsProvider = FutureProvider<List<AchievementModel>>((ref) async {
  try {
    final authState = ref.watch(authProvider);
    if (!authState.isAuthenticated) {
      return [];
    }

    final apiService = ref.watch(apiServiceProvider);
    final response = await apiService.get(ApiConstants.achievements);
    
    if (response.data['achievements'] != null) {
      final List<dynamic> achievementsJson = response.data['achievements'] as List;
      return achievementsJson
          .map((json) => AchievementModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    
    return [];
  } catch (e) {
    Logger.error('Failed to fetch user achievements', e, null, 'AchievementsProvider');
    // Fallback to user model if API fails
    try {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated && authState.user != null) {
        return authState.user!.achievements ?? [];
      }
    } catch (_) {
      // Ignore fallback errors
    }
    return [];
  }
});

// Achievement progress provider
final achievementProgressProvider = Provider<Map<String, dynamic>>((ref) {
  final allAchievements = ref.watch(allAchievementsProvider);
  final userAchievementsAsync = ref.watch(userAchievementsProvider);

  return userAchievementsAsync.when(
    data: (unlocked) {
      final unlockedTypes = unlocked.map((a) => a.type).toSet();
      final total = allAchievements.length;
      final unlockedCount = unlockedTypes.length;
      final locked = allAchievements.where((a) => !unlockedTypes.contains(a.type)).toList();

      return {
        'total': total,
        'unlocked': unlockedCount,
        'locked': total - unlockedCount,
        'progress': total > 0 ? (unlockedCount / total) : 0.0,
        'unlockedAchievements': unlocked,
        'lockedAchievements': locked,
      };
    },
    loading: () => {
      'total': 0,
      'unlocked': 0,
      'locked': 0,
      'progress': 0.0,
      'unlockedAchievements': <AchievementModel>[],
      'lockedAchievements': <AchievementModel>[],
    },
    error: (_, __) => {
      'total': 0,
      'unlocked': 0,
      'locked': 0,
      'progress': 0.0,
      'unlockedAchievements': <AchievementModel>[],
      'lockedAchievements': <AchievementModel>[],
    },
  );
});

