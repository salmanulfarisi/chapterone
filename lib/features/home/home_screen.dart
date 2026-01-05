import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/manga_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../features/manga/providers/manga_provider.dart';
import '../../features/manga/providers/recommendations_provider.dart';
import '../../models/manga_model.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/api/api_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../widgets/ads/native_ad_widget.dart';
import '../../widgets/animated_refresh_indicator.dart';

// Featured carousel provider
final featuredCarouselProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get('${ApiConstants.mangaList}/featured');
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    return [];
  }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _carouselController = PageController();
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds for instant updates
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        ref.invalidate(mangaListProvider);
        ref.invalidate(featuredCarouselProvider);
        final authState = ref.read(authProvider);
        if (authState.isAuthenticated) {
          ref.invalidate(recommendationsProvider);
          ref.invalidate(continueReadingProvider);
        }
        _startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselAutoScroll(int itemCount) {
    if (itemCount <= 1) return; // Only animate if more than one item

    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_carouselController.hasClients) {
        timer.cancel();
        return;
      }

      final nextIndex = (_currentCarouselIndex + 1) % itemCount;
      _carouselController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopCarouselAutoScroll() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        ref.invalidate(mangaListProvider);
        ref.invalidate(featuredCarouselProvider);
        final authState = ref.read(authProvider);
        if (authState.isAuthenticated) {
          ref.invalidate(recommendationsProvider);
          ref.invalidate(continueReadingProvider);
        }
        _startAutoRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.isAuthenticated;

    final trendingManga = ref.watch(
      mangaListProvider(MangaListParams(limit: '10', sortBy: 'totalViews')),
    );
    final newReleases = ref.watch(
      mangaListProvider(MangaListParams(limit: '10', sortBy: 'createdAt')),
    );
    final popularManga = ref.watch(
      mangaListProvider(MangaListParams(limit: '10', sortBy: 'rating')),
    );

    // Personalized recommendations (only for authenticated users)
    final recommendationsAsync = isAuthenticated
        ? ref.watch(recommendationsProvider)
        : const AsyncValue<List<MangaModel>>.data([]);
    final youMightLikeAsync = isAuthenticated
        ? ref.watch(youMightLikeProvider)
        : const AsyncValue<List<MangaModel>>.data([]);
    final continueReadingAsync = isAuthenticated
        ? ref.watch(continueReadingProvider)
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'ChapterOne',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Adult content icon (only for age-verified users)
          if (isAuthenticated && (authState.user?.ageVerified ?? false))
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryRed.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.primaryRed,
                  size: 20,
                ),
              ),
              tooltip: 'Adult Content',
              onPressed: () {
                context.push('/adult-content');
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.push('/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedRefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mangaListProvider);
                ref.invalidate(featuredCarouselProvider);
                if (isAuthenticated) {
                  ref.invalidate(recommendationsProvider);
                  ref.invalidate(continueReadingProvider);
                }
              },
              child: _buildContent(
                context,
                trendingManga,
                newReleases,
                popularManga,
                recommendationsAsync,
                youMightLikeAsync,
                continueReadingAsync,
                isAuthenticated,
                authState,
              ),
            ),
          ),
          // Banner Ad at bottom
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required AsyncValue<List<MangaModel>> mangaList,
    String? sortBy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {
                  context.push(
                    '/search?sort=${sortBy ?? 'createdAt'}&title=$title',
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'See all',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppTheme.primaryRed,
                    ),
                  ],
                ),
              ),
            ],
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
                      'No manga available',
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
                    child: MangaCard(
                      title: item.title,
                      cover: item.cover,
                      genre: item.genres.isNotEmpty ? item.genres.first : null,
                      latestChapter: item.totalChapters,
                      onTap: () {
                        context.push('/manga/${item.id}');
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const ShimmerMangaList(),
            error: (error, stack) => const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Error loading manga',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    AsyncValue<List<MangaModel>> trendingManga,
    AsyncValue<List<MangaModel>> newReleases,
    AsyncValue<List<MangaModel>> popularManga,
    AsyncValue<List<MangaModel>> recommendationsAsync,
    AsyncValue<List<MangaModel>> youMightLikeAsync,
    AsyncValue<List<Map<String, dynamic>>> continueReadingAsync,
    bool isAuthenticated,
    dynamic authState,
  ) {
    // Check if all sections are loaded and empty
    final allLoaded =
        trendingManga.hasValue && newReleases.hasValue && popularManga.hasValue;

    final allEmpty =
        allLoaded &&
        trendingManga.value!.isEmpty &&
        newReleases.value!.isEmpty &&
        popularManga.value!.isEmpty;

    if (allEmpty) {
      return EmptyState(
        title: 'No Manga Available',
        message: 'There are no manga in the database yet. Check back later!',
        icon: Icons.menu_book_outlined,
        onRetry: () {
          ref.invalidate(mangaListProvider);
        },
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner Section
          _buildHeroBanner(context),
          const SizedBox(height: 24),

          // Continue Reading Section (for authenticated users)
          if (isAuthenticated)
            continueReadingAsync.when(
              data: (continueList) {
                if (continueList.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Continue Reading',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/reading-history'),
                              child: Row(
                                children: [
                                  Text(
                                    'See all',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppTheme.primaryRed),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: AppTheme.primaryRed,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: continueList.length,
                          itemBuilder: (context, index) {
                            final item = continueList[index];
                            try {
                              final manga = MangaModel.fromJson(item);
                              final lastChapter =
                                  item['lastChapterNumber'] as int?;
                              final totalChapters =
                                  item['totalChapters'] as int? ??
                                  manga.totalChapters ??
                                  0;
                              final chaptersRead =
                                  item['chaptersRead'] as int? ?? 0;

                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    MangaCard(
                                      title: manga.title,
                                      cover: manga.cover,
                                      genre: manga.genres.isNotEmpty
                                          ? manga.genres.first
                                          : null,
                                      latestChapter:
                                          lastChapter ?? manga.totalChapters,
                                      onTap: () {
                                        if (lastChapter != null) {
                                          context.push(
                                            '/reader/${manga.id}_ch$lastChapter',
                                          );
                                        } else {
                                          context.push('/manga/${manga.id}');
                                        }
                                      },
                                    ),
                                    // Progress indicator
                                    if (totalChapters > 0 && chaptersRead > 0)
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: AppTheme.cardBackground,
                                            borderRadius: BorderRadius.only(
                                              bottomLeft: Radius.circular(8),
                                              bottomRight: Radius.circular(8),
                                            ),
                                          ),
                                          child: FractionallySizedBox(
                                            widthFactor:
                                                chaptersRead / totalChapters,
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: AppTheme.primaryRed,
                                                borderRadius: BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    8,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // Recommendations Section (for authenticated users)
          if (isAuthenticated)
            recommendationsAsync.when(
              data: (recommendations) {
                if (recommendations.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Recommended For You',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: recommendations.length,
                          itemBuilder: (context, index) {
                            final item = recommendations[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: MangaCard(
                                title: item.title,
                                cover: item.cover,
                                genre: item.genres.isNotEmpty
                                    ? item.genres.first
                                    : null,
                                latestChapter: item.totalChapters,
                                onTap: () {
                                  context.push('/manga/${item.id}');
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // "You might also like" Section (enhanced personalized recommendations)
          if (isAuthenticated)
            youMightLikeAsync.when(
              data: (youMightLike) {
                if (youMightLike.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 20,
                                  color: AppTheme.primaryRed,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'You Might Also Like',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: youMightLike.length,
                          itemBuilder: (context, index) {
                            final item = youMightLike[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: MangaCard(
                                title: item.title,
                                cover: item.cover,
                                genre: item.genres.isNotEmpty
                                    ? item.genres.first
                                    : null,
                                latestChapter: item.totalChapters,
                                onTap: () {
                                  context.push('/manga/${item.id}');
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // Trending Section
          _buildSection(
            context,
            title: 'Trending Now',
            mangaList: trendingManga,
            sortBy: 'totalViews',
          ),
          const SizedBox(height: 24),

          // New Releases Section
          _buildSection(
            context,
            title: 'New Releases',
            mangaList: newReleases,
            sortBy: 'createdAt',
          ),
          const SizedBox(height: 24),

          // Popular Section
          _buildSection(
            context,
            title: 'Popular',
            mangaList: popularManga,
            sortBy: 'rating',
          ),
          const SizedBox(height: 24),

          // Native Ad (with unique key to prevent duplicate GlobalKey errors)
          const NativeAdWidget(key: ValueKey('home_native_ad'), height: 300),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    // Use featured carousel from admin, fallback to trending
    final featuredAsync = ref.watch(featuredCarouselProvider);

    return featuredAsync.when(
      data: (featuredList) {
        if (featuredList.isEmpty) {
          // Fallback to trending manga
          return _buildFallbackHero(context);
        }
        return _buildCarouselBanner(context, featuredList);
      },
      loading: () => const ShimmerBanner(),
      error: (_, __) => _buildFallbackHero(context),
    );
  }

  Widget _buildCarouselBanner(
    BuildContext context,
    List<Map<String, dynamic>> featuredList,
  ) {
    // Start auto-scroll if more than one item
    if (featuredList.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startCarouselAutoScroll(featuredList.length);
        }
      });
    } else {
      _stopCarouselAutoScroll();
    }

    return SizedBox(
      height: 420,
      child: PageView.builder(
        controller: _carouselController,
        onPageChanged: (index) {
          setState(() {
            _currentCarouselIndex = index;
          });
          // Restart auto-scroll after user interaction
          if (featuredList.length > 1) {
            _stopCarouselAutoScroll();
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                _startCarouselAutoScroll(featuredList.length);
              }
            });
          }
        },
        itemCount: featuredList.length,
        itemBuilder: (context, index) {
          final featured = featuredList[index];
          final title = featured['title'] ?? '';
          final cover = featured['cover'];
          final genres = List<String>.from(featured['genres'] ?? []);
          final id = featured['_id'];

          return Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.darkerBackground, AppTheme.darkBackground],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null)
                  CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.cardBackground,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.cardBackground,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 100,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
                // Page indicator
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${index + 1}/${featuredList.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
                // Dot indicators (only show if more than one item)
                if (featuredList.length > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        featuredList.length,
                        (dotIndex) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentCarouselIndex == dotIndex
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Featured badge
                if (featured['isManual'] == true)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FEATURED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 32,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (genres.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: genres.take(3).map((g) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                g,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  final chapters = await ref.read(
                                    mangaChaptersProvider(id).future,
                                  );
                                  if (chapters.isNotEmpty) {
                                    if (!mounted) return;
                                    context.push(
                                      '/reader/${chapters.first.id}',
                                    );
                                  } else {
                                    if (!mounted) return;
                                    CustomSnackbar.warning(
                                      context,
                                      'No chapters available for this manga yet.',
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  CustomSnackbar.error(
                                    context,
                                    'Failed to open reader: ${e.toString()}',
                                  );
                                }
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Read Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.push('/manga/$id');
                              },
                              icon: const Icon(Icons.info_outline),
                              label: const Text('Details'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackHero(BuildContext context) {
    final trendingManga = ref.watch(
      mangaListProvider(MangaListParams(limit: '1', sort: 'totalViews')),
    );

    return trendingManga.when(
      data: (manga) {
        if (manga.isEmpty) {
          return const ShimmerBanner();
        }
        final featured = manga.first;
        return Container(
          height: 420,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.darkerBackground, AppTheme.darkBackground],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (featured.cover != null)
                CachedNetworkImage(
                  imageUrl: featured.cover!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppTheme.cardBackground,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.cardBackground,
                    child: const Icon(
                      Icons.image_outlined,
                      size: 100,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featured.title,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (featured.genres.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: featured.genres.take(3).map((g) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              g,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final chapters = await ref.read(
                                  mangaChaptersProvider(featured.id).future,
                                );
                                if (chapters.isNotEmpty) {
                                  if (!mounted) return;
                                  context.push('/reader/${chapters.first.id}');
                                } else {
                                  if (!mounted) return;
                                  CustomSnackbar.warning(
                                    context,
                                    'No chapters available for this manga yet.',
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                CustomSnackbar.error(
                                  context,
                                  'Failed to open reader: ${e.toString()}',
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Read Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.push('/manga/${featured.id}');
                            },
                            icon: const Icon(Icons.info_outline),
                            label: const Text('Details'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const ShimmerBanner(),
      error: (_, __) => Container(
        height: 400,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryRed.withOpacity(0.3), Colors.transparent],
          ),
        ),
        child: const Center(
          child: Text(
            'Featured Manga',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
