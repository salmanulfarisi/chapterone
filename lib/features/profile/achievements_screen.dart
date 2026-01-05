import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/achievement_model.dart';
import 'providers/achievements_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(achievementProgressProvider);
    final allAchievements = ref.watch(allAchievementsProvider);
    final userAchievementsAsync = ref.watch(userAchievementsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
      ),
      body: userAchievementsAsync.when(
        data: (unlockedAchievements) {
          final unlockedTypes = unlockedAchievements.map((a) => a.type).toSet();
          
          return CustomScrollView(
            slivers: [
              // Progress Header
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryRed.withOpacity(0.2),
                        AppTheme.primaryRed.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryRed.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${progress['unlocked']}/${progress['total']} Achievements',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryRed,
                                  AppTheme.primaryRed.withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${((progress['progress'] as double) * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress['progress'] as double,
                          minHeight: 8,
                          backgroundColor: AppTheme.cardBackground,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Achievements List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final achievement = allAchievements[index];
                      final isUnlocked = unlockedTypes.contains(achievement.type);
                      final unlockedAchievement = isUnlocked
                          ? unlockedAchievements.firstWhere(
                              (a) => a.type == achievement.type,
                            )
                          : null;

                      return _AchievementCard(
                        achievement: achievement,
                        isUnlocked: isUnlocked,
                        unlockedAt: unlockedAchievement?.unlockedAt,
                      );
                    },
                    childCount: allAchievements.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load achievements',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
    this.unlockedAt,
  });

  Color _getRarityColor(int rarity) {
    switch (rarity) {
      case 1: // Common
        return Colors.grey;
      case 2: // Uncommon
        return Colors.blue;
      case 3: // Rare
        return Colors.purple;
      case 4: // Epic
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRarityName(int rarity) {
    switch (rarity) {
      case 1:
        return 'Common';
      case 2:
        return 'Uncommon';
      case 3:
        return 'Rare';
      case 4:
        return 'Epic';
      default:
        return 'Common';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(achievement.rarity);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppTheme.cardBackground
            : AppTheme.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? rarityColor.withOpacity(0.3)
              : AppTheme.cardBackground,
          width: 1.5,
        ),
      ),
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Achievement Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? rarityColor.withOpacity(0.2)
                      : AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnlocked
                        ? rarityColor.withOpacity(0.5)
                        : AppTheme.textTertiary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    achievement.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Achievement Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (isUnlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: rarityColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getRarityName(achievement.rarity),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: rarityColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnlocked
                            ? AppTheme.textSecondary
                            : AppTheme.textTertiary,
                      ),
                    ),
                    if (isUnlocked && unlockedAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Unlocked ${DateFormat('MMM d, y').format(unlockedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ] else if (!isUnlocked) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Locked',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

