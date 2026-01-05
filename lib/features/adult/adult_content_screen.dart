import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/manga_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../features/manga/providers/manga_provider.dart';
import '../../models/manga_model.dart';
import '../../features/auth/providers/auth_provider.dart';

class AdultContentScreen extends ConsumerWidget {
  const AdultContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.isAuthenticated;
    final isAgeVerified = authState.user?.ageVerified ?? false;

    // Redirect to age verification if not verified
    if (!isAuthenticated || !isAgeVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.push('/age-verification?mangaId=');
        }
      });
      return Scaffold(
        appBar: AppBar(
          title: const Text('Adult Content'),
          backgroundColor: AppTheme.darkBackground,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final trendingAdult = ref.watch(
      mangaListProvider(
        MangaListParams(
          limit: '20',
          sortBy: 'totalViews',
          source: 'hotcomics',
        ),
      ),
    );
    final newAdult = ref.watch(
      mangaListProvider(
        MangaListParams(
          limit: '20',
          sortBy: 'createdAt',
          source: 'hotcomics',
        ),
      ),
    );
    final popularAdult = ref.watch(
      mangaListProvider(
        MangaListParams(
          limit: '20',
          sortBy: 'rating',
          source: 'hotcomics',
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: AppTheme.primaryRed,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Adult Content',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mangaListProvider);
        },
        child: _buildContent(
          context,
          trendingAdult,
          newAdult,
          popularAdult,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AsyncValue<List<MangaModel>> trendingAdult,
    AsyncValue<List<MangaModel>> newAdult,
    AsyncValue<List<MangaModel>> popularAdult,
  ) {
    // Check if all sections are loaded and empty
    final allLoaded =
        trendingAdult.hasValue && newAdult.hasValue && popularAdult.hasValue;

    final allEmpty =
        allLoaded &&
        trendingAdult.value!.isEmpty &&
        newAdult.value!.isEmpty &&
        popularAdult.value!.isEmpty;

    if (allEmpty) {
      return EmptyState(
        title: 'No Adult Content Available',
        message: 'There are no adult manga in the database yet.',
        icon: Icons.warning_amber_rounded,
        onRetry: () {
          // Retry logic handled by RefreshIndicator
        },
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Warning banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryRed.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.primaryRed,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This section contains adult content. You must be 18+ to access.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Trending Adult Section
          _buildSection(
            context,
            title: 'Trending Adult',
            mangaList: trendingAdult,
          ),
          const SizedBox(height: 24),

          // New Adult Releases Section
          _buildSection(
            context,
            title: 'New Adult Releases',
            mangaList: newAdult,
          ),
          const SizedBox(height: 24),

          // Popular Adult Section
          _buildSection(
            context,
            title: 'Popular Adult',
            mangaList: popularAdult,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required AsyncValue<List<MangaModel>> mangaList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: mangaList.when(
            data: (manga) {
              if (manga.isEmpty) {
                return const SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'No adult manga available',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: manga.length,
                itemBuilder: (context, index) {
                  final item = manga[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        MangaCard(
                          title: item.title,
                          cover: item.cover,
                          genre: item.genres.isNotEmpty ? item.genres.first : null,
                          latestChapter: item.totalChapters,
                          onTap: () {
                            context.push('/manga/${item.id}');
                          },
                        ),
                        // 18+ badge
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '18+',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const ShimmerMangaList(),
            error: (error, stack) => SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Error loading adult manga',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

