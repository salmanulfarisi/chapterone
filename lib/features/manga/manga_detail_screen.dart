import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../manga/providers/manga_provider.dart';
import '../bookmarks/providers/bookmarks_provider.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../features/profile/reading_lists_screen.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/ads/ad_service.dart';
import '../../models/chapter_model.dart';
import '../../core/utils/logger.dart';

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String mangaId;

  const MangaDetailScreen({super.key, required this.mangaId});

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  final TextEditingController _chapterSearchController =
      TextEditingController();
  final ScrollController _chapterScrollController = ScrollController();
  int? _searchedChapterNumber;
  bool _chaptersAscending = true; // true = oldest first, false = newest first

  @override
  void dispose() {
    _chapterSearchController.dispose();
    _chapterScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh chapters and read chapters when screen is focused (e.g., returning from reader)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(mangaChaptersProvider(widget.mangaId));
        ref.invalidate(readChaptersProvider(widget.mangaId));
      }
    });
  }

  String _formatFollowers(int? count) {
    if (count == null || count <= 0) return 'Followed by 0 people';
    if (count < 1000) return 'Followed by $count people';
    if (count < 1000000) {
      final k = (count / 1000).toStringAsFixed(1);
      return 'Followed by ${k}K people';
    }
    final m = (count / 1000000).toStringAsFixed(1);
    return 'Followed by ${m}M people';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatChapterUpdated(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays <= 0) {
      return 'Updated now';
    } else if (diff.inDays == 1) {
      return 'Updated 1 day ago';
    } else if (diff.inDays < 7) {
      return 'Updated ${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return weeks <= 1 ? 'Updated 1 week ago' : 'Updated $weeks weeks ago';
    } else {
      return 'Updated ${_formatDate(date)}';
    }
  }

  void _showRatingDialog(BuildContext parentContext, dynamic manga) {
    double selectedRating = manga.userRating ?? 5.0;
    final scaffoldMessenger = ScaffoldMessenger.of(parentContext);

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBackground,
              title: const Text('Rate this manga'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedRating.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '/10',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: selectedRating,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: Colors.amber,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRating = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    final success = await ref.read(
                      rateMangaProvider((
                        mangaId: widget.mangaId,
                        rating: selectedRating,
                      )).future,
                    );
                    if (success && mounted) {
                      ref.invalidate(mangaDetailProvider(widget.mangaId));
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Rating submitted!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showUnlockDialog(
    BuildContext context,
    ChapterModel chapter,
    dynamic manga,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Unlock Chapter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48, color: AppTheme.primaryRed),
            const SizedBox(height: 16),
            Text(
              'Chapter ${chapter.chapterNumber} is locked',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Watch an ad to unlock this chapter',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Show rewarded ad and unlock
      _unlockChapter(context, chapter, manga);
    }
  }

  Future<void> _unlockChapter(
    BuildContext context,
    ChapterModel chapter,
    dynamic manga,
  ) async {
    try {
      Logger.debug(
        'Starting unlock process - Chapter ID: ${chapter.id}, Chapter Number: ${chapter.chapterNumber}, Manga ID: ${widget.mangaId}',
        'MangaDetailScreen',
      );

      // Show rewarded ad and wait for reward
      final adService = AdService.instance;

      Logger.debug('Showing rewarded ad...', 'MangaDetailScreen');
      final rewardEarned = await adService.showRewardedAd(
        onRewarded: (reward) {
          Logger.debug(
            'Ad reward received! Reward: ${reward.amount} ${reward.type}',
            'MangaDetailScreen',
          );
        },
      );

      Logger.debug(
        'Reward earned: $rewardEarned, Mounted: $mounted',
        'MangaDetailScreen',
      );

      if (rewardEarned && mounted) {
        // Unlock chapter via API
        final apiService = ref.read(apiServiceProvider);
        try {
          final unlockUrl =
              '${ApiConstants.chapterUnlock}/${chapter.id}/unlock';
          Logger.debug(
            'Attempting to unlock chapter: ${chapter.id} at URL: $unlockUrl',
            'MangaDetailScreen',
          );

          final response = await apiService.post(unlockUrl);
          Logger.debug(
            'Unlock response status: ${response.statusCode}',
            'MangaDetailScreen',
          );

          if (mounted) {
            // Check if unlock was successful
            if (response.statusCode == 200 || response.statusCode == 201) {
              Logger.info('Chapter unlock successful!', 'MangaDetailScreen');
              if (mounted) {
                CustomSnackbar.success(
                  context,
                  'Chapter unlocked successfully!',
                );
              }

              // Force refresh chapters by invalidating and waiting for new data
              ref.invalidate(mangaChaptersProvider(widget.mangaId));
              ref.invalidate(readChaptersProvider(widget.mangaId));

              // Wait for the provider to fetch fresh data
              try {
                await ref.read(mangaChaptersProvider(widget.mangaId).future);
                Logger.debug(
                  'Chapters refreshed after unlock',
                  'MangaDetailScreen',
                );
              } catch (e) {
                // If refresh fails, still try to navigate
                Logger.warning(
                  'Error refreshing chapters: $e',
                  'MangaDetailScreen',
                );
              }

              // Small delay to ensure UI updates
              await Future.delayed(const Duration(milliseconds: 300));

              // Navigate to reader
              if (mounted) {
                context.push('/reader/${chapter.id}');
              }
            } else {
              Logger.warning(
                'Unlock failed with status: ${response.statusCode}',
                'MangaDetailScreen',
              );
              if (mounted) {
                CustomSnackbar.error(
                  context,
                  'Failed to unlock chapter. Please try again.',
                );
              }
            }
          }
        } catch (e, stackTrace) {
          Logger.error(
            'Error unlocking chapter: ${e.toString()}',
            e,
            stackTrace,
            'MangaDetailScreen',
          );
          if (mounted) {
            final errorMessage = e.toString();
            CustomSnackbar.error(
              context,
              'Failed to unlock chapter: ${errorMessage.length > 50 ? "${errorMessage.substring(0, 50)}..." : errorMessage}',
            );
          }
        }
      } else if (mounted && !rewardEarned) {
        CustomSnackbar.error(
          context,
          'Please watch the ad completely to unlock the chapter.',
        );
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to unlock chapter: ${e.toString()}',
        e,
        stackTrace,
        'MangaDetailScreen',
      );
      if (mounted) {
        CustomSnackbar.error(
          context,
          'Failed to unlock chapter: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mangaAsync = ref.watch(mangaDetailProvider(widget.mangaId));
    final chaptersAsync = ref.watch(mangaChaptersProvider(widget.mangaId));
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final readChaptersAsync = ref.watch(readChaptersProvider(widget.mangaId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: mangaAsync.maybeWhen(
          data: (manga) => Text(
            manga?.title ?? 'Manga Detail',
            overflow: TextOverflow.ellipsis,
          ),
          orElse: () => const Text('Manga Detail'),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.comment),
            onPressed: () {
              context.push('/manga/${widget.mangaId}/discussion');
            },
            tooltip: 'Discussion',
          ),
        ],
      ),
      body: mangaAsync.when(
        data: (manga) {
          if (manga == null) {
            return const Center(child: Text('Manga not found'));
          }

          // Check age verification for adult content
          final authState = ref.watch(authProvider);
          if (manga.isAdult == true &&
              !(authState.user?.ageVerified ?? false)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: AppTheme.primaryRed,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Age Verification Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This content is restricted to users who are 18 years or older.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await context.push<bool>(
                          '/age-verification?mangaId=${widget.mangaId}',
                        );
                        if (result == true && mounted) {
                          ref.invalidate(mangaDetailProvider(widget.mangaId));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Verify Age'),
                    ),
                  ],
                ),
              ),
            );
          }

          final isBookmarked = bookmarksAsync.maybeWhen(
            data: (list) => list.any((b) => b.id == manga.id),
            orElse: () => false,
          );

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image card with shadow
                      if (manga.cover != null && manga.cover!.isNotEmpty) ...[
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.6),
                                  blurRadius: 18,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: manga.cover!,
                                height: 220,
                                width: 160,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 220,
                                  width: 160,
                                  color: AppTheme.cardBackground,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    height: 220,
                                    width: 160,
                                    color: AppTheme.cardBackground,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 40,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Title
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            manga.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bookmark button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            bool success = false;
                            if (isBookmarked) {
                              success = await ref.read(
                                removeBookmarkProvider(manga.id).future,
                              );
                            } else {
                              success = await ref.read(
                                addBookmarkProvider(manga.id).future,
                              );
                            }

                            if (!mounted) return;
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isBookmarked
                                        ? 'Removed from bookmarks'
                                        : 'Added to bookmarks',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update bookmarks'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.bookmark),
                          label: Text(isBookmarked ? 'Bookmarked' : 'Bookmark'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            foregroundColor: AppTheme.textPrimary,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Add to List button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showAddToListDialog(context, ref, manga.id),
                          icon: const Icon(Icons.list),
                          label: const Text('Add to List'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cardBackground,
                            foregroundColor: AppTheme.textPrimary,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Followers count
                      Center(
                        child: Text(
                          _formatFollowers(manga.followersCount),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rating row (out of 10)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            // stars (convert 10-scale to 5 stars)
                            Row(
                              children: List.generate(5, (index) {
                                final rating =
                                    (manga.rating ?? 0) /
                                    2; // Convert to 5-star scale
                                final starValue = index + 1;
                                return Icon(
                                  rating >= starValue
                                      ? Icons.star
                                      : rating >= starValue - 0.5
                                      ? Icons.star_half
                                      : Icons.star_border,
                                  size: 18,
                                  color: Colors.amber,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (manga.rating ?? 0).toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (manga.ratingCount != null &&
                                manga.ratingCount! > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${manga.ratingCount})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Rate button
                            TextButton.icon(
                              onPressed: () =>
                                  _showRatingDialog(context, manga),
                              icon: Icon(
                                manga.userRating != null
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: Colors.amber,
                              ),
                              label: Text(
                                manga.userRating != null
                                    ? 'Rated ${manga.userRating!.toStringAsFixed(0)}'
                                    : 'Rate',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info card (status, type, posted, updated)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              manga.status.isNotEmpty
                                  ? '${manga.status[0].toUpperCase()}${manga.status.substring(1)}'
                                  : '-',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Type',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              manga.type.isNotEmpty
                                  ? '${manga.type[0].toUpperCase()}${manga.type.substring(1)}'
                                  : 'Manhwa',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Posted On',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(manga.releaseDate ?? manga.createdAt),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Updated On',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(_formatDate(manga.updatedAt)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Genres / tags
                      if (manga.genres.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: manga.genres.map((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                genre,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Synopsis
                      if (manga.description != null &&
                          manga.description!.trim().isNotEmpty) ...[
                        Text(
                          'Synopsis ${manga.title}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            manga.description!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Chapters section header + sort toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Chapters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _chaptersAscending = !_chaptersAscending;
                              });
                            },
                            icon: Icon(
                              _chaptersAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 20,
                            ),
                            tooltip: _chaptersAscending
                                ? 'Oldest first'
                                : 'Newest first',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      chaptersAsync.when(
                        data: (chapters) {
                          if (chapters.isEmpty) {
                            return const Text(
                              'No chapters available',
                              style: TextStyle(color: AppTheme.textSecondary),
                            );
                          }

                          final firstChapter = chapters.first;
                          final lastChapter = chapters.last;

                          var filteredChapters = _searchedChapterNumber == null
                              ? chapters
                              : chapters
                                    .where(
                                      (c) =>
                                          c.chapterNumber ==
                                          _searchedChapterNumber,
                                    )
                                    .toList();

                          // Apply sort order
                          if (!_chaptersAscending) {
                            filteredChapters = filteredChapters.reversed
                                .toList();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final freeChapters =
                                            manga.freeChapters ?? 3;
                                        final shouldBeLocked =
                                            manga.isAdult == true &&
                                            firstChapter.chapterNumber >
                                                freeChapters;
                                        // If isLocked is explicitly false, chapter is unlocked
                                        final isLocked =
                                            firstChapter.isLocked == false
                                            ? false
                                            : (firstChapter.isLocked == true ||
                                                  shouldBeLocked);

                                        if (isLocked) {
                                          _showUnlockDialog(
                                            context,
                                            firstChapter,
                                            manga,
                                          );
                                        } else {
                                          context.push(
                                            '/reader/${firstChapter.id}',
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.cardBackground,
                                        foregroundColor: AppTheme.textPrimary,
                                        minimumSize: const Size.fromHeight(44),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text('First Chapter'),
                                          Builder(
                                            builder: (context) {
                                              final freeChapters =
                                                  manga.freeChapters ?? 3;
                                              final shouldBeLocked =
                                                  manga.isAdult == true &&
                                                  firstChapter.chapterNumber >
                                                      freeChapters;
                                              // If isLocked is explicitly false, chapter is unlocked
                                              final isLocked =
                                                  firstChapter.isLocked == false
                                                  ? false
                                                  : (firstChapter.isLocked ==
                                                            true ||
                                                        shouldBeLocked);

                                              if (isLocked) {
                                                return const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SizedBox(width: 4),
                                                    Icon(
                                                      Icons.lock,
                                                      size: 16,
                                                      color:
                                                          AppTheme.primaryRed,
                                                    ),
                                                  ],
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final freeChapters =
                                            manga.freeChapters ?? 3;
                                        final shouldBeLocked =
                                            manga.isAdult == true &&
                                            lastChapter.chapterNumber >
                                                freeChapters;
                                        final isLocked =
                                            lastChapter.isLocked == true ||
                                            shouldBeLocked;

                                        if (isLocked) {
                                          _showUnlockDialog(
                                            context,
                                            lastChapter,
                                            manga,
                                          );
                                        } else {
                                          context.push(
                                            '/reader/${lastChapter.id}',
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryRed,
                                        foregroundColor: AppTheme.textPrimary,
                                        minimumSize: const Size.fromHeight(44),
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          final freeChapters =
                                              manga.freeChapters ?? 3;
                                          final shouldBeLocked =
                                              manga.isAdult == true &&
                                              lastChapter.chapterNumber >
                                                  freeChapters;
                                          // If isLocked is explicitly false, chapter is unlocked
                                          final isLocked =
                                              lastChapter.isLocked == false
                                              ? false
                                              : (lastChapter.isLocked == true ||
                                                    shouldBeLocked);

                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text('New Chapter'),
                                              if (isLocked) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.lock,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _chapterSearchController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search Chapter. Example: 25 or 178',
                                ),
                                onSubmitted: (value) {
                                  final number = int.tryParse(value.trim());
                                  setState(() {
                                    _searchedChapterNumber = number;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              // Scrollable chapter list with red scrollbar
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 400,
                                ),
                                child: RawScrollbar(
                                  controller: _chapterScrollController,
                                  thumbColor: AppTheme.primaryRed,
                                  radius: const Radius.circular(4),
                                  thickness: 6,
                                  thumbVisibility: true,
                                  child: ListView.separated(
                                    controller: _chapterScrollController,
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.only(right: 12),
                                    itemCount: filteredChapters.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final chapter = filteredChapters[index];

                                      // Backend now handles unlock status
                                      // If isLocked is explicitly false, chapter is unlocked
                                      // Otherwise, check if it should be locked based on chapter number
                                      final freeChapters =
                                          manga.freeChapters ?? 3;
                                      final shouldBeLocked =
                                          manga.isAdult == true &&
                                          chapter.chapterNumber > freeChapters;
                                      // Priority: if backend says unlocked (false), trust it
                                      // Otherwise, use backend's isLocked or fallback to shouldBeLocked
                                      final isChapterLocked =
                                          chapter.isLocked == false
                                          ? false
                                          : (chapter.isLocked ??
                                                shouldBeLocked);

                                      // Check if this is the latest chapter (last in original list)
                                      final isLatest =
                                          chapter.id == lastChapter.id;
                                      // Check if chapter is new (within 3 days)
                                      final isNew =
                                          chapter.releaseDate != null &&
                                          DateTime.now()
                                                  .difference(
                                                    chapter.releaseDate!,
                                                  )
                                                  .inDays <=
                                              3;
                                      // Check if chapter is read
                                      final readChapters = readChaptersAsync
                                          .maybeWhen(
                                            data: (set) => set,
                                            orElse: () => <String>{},
                                          );
                                      final isRead = readChapters.contains(
                                        chapter.id,
                                      );

                                      return InkWell(
                                        onTap: () async {
                                          if (isChapterLocked) {
                                            // Show unlock dialog
                                            _showUnlockDialog(
                                              context,
                                              chapter,
                                              manga,
                                            );
                                          } else {
                                            context.push(
                                              '/reader/${chapter.id}',
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.cardBackground,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: isLatest
                                                    ? Border.all(
                                                        color: AppTheme
                                                            .primaryRed
                                                            .withOpacity(0.5),
                                                        width: 1,
                                                      )
                                                    : null,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              'Chapter ${chapter.chapterNumber}',
                                                              style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                            if (isChapterLocked) ...[
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              const Icon(
                                                                Icons.lock,
                                                                size: 14,
                                                                color: AppTheme
                                                                    .primaryRed,
                                                              ),
                                                            ],
                                                            if (isNew &&
                                                                !isChapterLocked) ...[
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme
                                                                      .primaryRed,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                                child: const Text(
                                                                  'NEW',
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        Text(
                                                          _formatChapterUpdated(
                                                            chapter.releaseDate,
                                                          ),
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: AppTheme
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    isChapterLocked
                                                        ? Icons.lock
                                                        : Icons.chevron_right,
                                                    size: 20,
                                                    color: isChapterLocked
                                                        ? AppTheme.primaryRed
                                                        : AppTheme
                                                              .textSecondary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Latest ribbon
                                            if (isLatest)
                                              Positioned(
                                                top: -2,
                                                right: 30,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryRed,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppTheme
                                                            .primaryRed
                                                            .withOpacity(0.4),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text(
                                                    'LATEST',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            // Read ribbon (show on left side if not latest)
                                            if (isRead && !isLatest)
                                              Positioned(
                                                top: -2,
                                                left: -2,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.green
                                                            .withOpacity(0.4),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text(
                                                    'READ',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            // Read ribbon (show on right side if latest, below LATEST)
                                            if (isRead && isLatest)
                                              Positioned(
                                                top: 18,
                                                right: 30,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.green
                                                            .withOpacity(0.4),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text(
                                                    'READ',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, stack) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Error loading chapters',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),

                      // Related Manga section
                      if (manga.relatedManga != null &&
                          manga.relatedManga!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Related Manga',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: manga.relatedManga!.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final related = manga.relatedManga![index];
                              return GestureDetector(
                                onTap: () =>
                                    context.push('/manga/${related.id}'),
                                child: SizedBox(
                                  width: 100,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: related.cover != null
                                            ? CachedNetworkImage(
                                                imageUrl: related.cover!,
                                                height: 130,
                                                width: 100,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    Container(
                                                      height: 130,
                                                      width: 100,
                                                      color: AppTheme
                                                          .cardBackground,
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                    ),
                                                errorWidget: (_, __, ___) =>
                                                    Container(
                                                      height: 130,
                                                      width: 100,
                                                      color: AppTheme
                                                          .cardBackground,
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        color: AppTheme
                                                            .textSecondary,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                height: 130,
                                                width: 100,
                                                color: AppTheme.cardBackground,
                                                child: const Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        related.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Banner Ad at bottom
              const BannerAdWidget(),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, stack) => const Center(
          child: Text(
            'Error loading manga',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  void _showAddToListDialog(
    BuildContext context,
    WidgetRef ref,
    String mangaId,
  ) {
    final listsAsync = ref.watch(readingListsProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Add to Reading List'),
        content: SizedBox(
          width: double.maxFinite,
          child: listsAsync.when(
            data: (lists) {
              if (lists.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No reading lists. Create one first.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context.push('/reading-lists');
                      },
                      child: const Text('Create List'),
                    ),
                  ],
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  final mangaIds = list['mangaIds'] as List<dynamic>? ?? [];
                  final isInList = mangaIds.any(
                    (id) => id.toString() == mangaId,
                  );

                  return ListTile(
                    title: Text(list['name'] ?? 'Untitled'),
                    subtitle: Text('${mangaIds.length} manga'),
                    trailing: isInList
                        ? const Icon(Icons.check, color: AppTheme.primaryRed)
                        : const Icon(Icons.add),
                    onTap: () async {
                      try {
                        final apiService = ref.read(apiServiceProvider);
                        if (isInList) {
                          await apiService.delete(
                            '${ApiConstants.readingLists}/${list['_id']}/manga/$mangaId',
                          );
                        } else {
                          await apiService.post(
                            '${ApiConstants.readingLists}/${list['_id']}/manga',
                            data: {'mangaId': mangaId},
                          );
                        }
                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          ref.invalidate(readingListsProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isInList
                                    ? 'Removed from list'
                                    : 'Added to list',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error loading lists'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/reading-lists');
            },
            child: const Text('New List'),
          ),
        ],
      ),
    );
  }
}
