import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage/storage_service.dart';
import '../../widgets/ads/rewarded_ad_button.dart';
import '../bookmarks/providers/bookmarks_provider.dart';
import '../../widgets/manga_card.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      body: Column(
        children: [
          // Premium Unlock Banner
          Consumer(
            builder: (context, ref, child) {
              final adsWatched = StorageService.getSetting<int>(
                'premium_reader_ads_watched',
                defaultValue: 0,
              ) ?? 0;
              final isUnlocked = StorageService.getSetting<String>(
                'premium_unlocked_until',
              ) != null;

              // Check if premium is still valid
              bool isPremiumActive = false;
              if (isUnlocked) {
                final expiryStr = StorageService.getSetting<String>(
                  'premium_unlocked_until',
                );
                if (expiryStr != null) {
                  try {
                    final expiryTime = DateTime.parse(expiryStr);
                    isPremiumActive = expiryTime.isAfter(DateTime.now());
                    if (!isPremiumActive) {
                      StorageService.saveSetting('premium_unlocked_until', null);
                    }
                  } catch (e) {
                    StorageService.saveSetting('premium_unlocked_until', null);
                  }
                }
              }

              final remainingAds = 6 - adsWatched;

              if (isPremiumActive) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryRed.withOpacity(0.2),
                      AppTheme.primaryRed.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryRed.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: AppTheme.primaryRed,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Unlock Premium Reader',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Watch 6 ads to unlock premium features',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: $adsWatched / 6 ads',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${((adsWatched / 6) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: adsWatched / 6,
                        minHeight: 6,
                        backgroundColor: AppTheme.textTertiary.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: RewardedAdButton(
                        title: remainingAds > 0
                            ? 'Watch Ad ($adsWatched/6)'
                            : 'Unlock Premium',
                        icon: Icons.diamond_outlined,
                        rewardMessage: remainingAds > 1
                            ? 'Progress: ${adsWatched + 1}/6 ads watched!'
                            : 'Premium Reader unlocked!',
                        backgroundColor: AppTheme.primaryRed,
                        textColor: Colors.white,
                        onRewardEarned: () {
                          final newCount = adsWatched + 1;
                          StorageService.saveSetting(
                            'premium_reader_ads_watched',
                            newCount,
                          );

                          if (newCount >= 6) {
                            final expiryTime = DateTime.now().add(
                              const Duration(days: 3),
                            );
                            StorageService.saveSetting(
                              'premium_unlocked_until',
                              expiryTime.toIso8601String(),
                            );
                            StorageService.saveSetting(
                              'premium_reader_ads_watched',
                              0,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Bookmarks List
          Expanded(
            child: bookmarksAsync.when(
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return const Center(
              child: Text(
                'No bookmarks yet',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final manga = bookmarks[index];
              return MangaCard(
                title: manga.title,
                cover: manga.cover,
                subtitle: manga.genres.isNotEmpty ? manga.genres.first : null,
                onTap: () {
                  context.push('/manga/${manga.id}');
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text(
            'Error loading bookmarks',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
            ),
          ),
        ],
      ),
    );
  }
}

