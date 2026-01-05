import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage/storage_service.dart';
import '../../services/ads/ad_service.dart';
import '../../widgets/ads/rewarded_ad_button.dart';
import '../../widgets/ads/native_ad_widget.dart';
import '../manga/providers/manga_provider.dart';
import '../../models/chapter_model.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/analytics/analytics_service.dart';

enum ReaderThemeMode { dark, light, sepia }

class ReaderScreen extends ConsumerStatefulWidget {
  final String chapterId;

  const ReaderScreen({super.key, required this.chapterId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;
  bool _showControls = true;
  bool _initialScrollApplied = false;

  // Reader settings
  ReaderThemeMode _readerTheme = ReaderThemeMode.dark;
  double _imageBrightness = 1.0; // 0.5 - 1.0
  double _imageScale = 1.0; // 1.0 - 1.2 (full width by default)

  // Reading state
  double _savedProgress = 0.0;
  bool _isBookmarked = false;
  Set<int> _highlightedPages = <int>{};

  // Text-to-speech
  FlutterTts? _flutterTts;
  bool _isTtsPlaying = false;

  // Auto scroll
  bool _autoScrollEnabled = false;
  double _autoScrollSpeed = 1.0;

  // Analytics tracking
  DateTime? _sessionStart;
  String? _mangaId;
  int? _totalChapters;
  List<String> _genres = [];

  static const _progressKeyPrefix = 'reader_progress_';
  static const _bookmarkKeyPrefix = 'reader_bookmark_';
  static const _highlightsKeyPrefix = 'reader_highlights_';
  static const _themeKey = 'reader_theme';
  static const _brightnessKey = 'reader_brightness';
  static const _imageScaleKey = 'reader_image_scale';

  @override
  void initState() {
    super.initState();
    _loadReaderPreferences();
    _initTts();
  }

  Future<void> _loadReaderPreferences() async {
    // Load per-chapter scroll progress and bookmark
    final savedProgress =
        StorageService.getSetting<double>(
          '$_progressKeyPrefix${widget.chapterId}',
          defaultValue: 0.0,
        ) ??
        0.0;
    final isBookmarked =
        StorageService.getSetting<bool>(
          '$_bookmarkKeyPrefix${widget.chapterId}',
          defaultValue: false,
        ) ??
        false;
    final rawHighlights =
        StorageService.getSetting<List<dynamic>>(
          '$_highlightsKeyPrefix${widget.chapterId}',
        ) ??
        <dynamic>[];

    // Global reader settings
    final themeIndex =
        StorageService.getSetting<int>(
          _themeKey,
          defaultValue: ReaderThemeMode.dark.index,
        ) ??
        ReaderThemeMode.dark.index;
    final brightness =
        StorageService.getSetting<double>(_brightnessKey, defaultValue: 1.0) ??
        1.0;
    final imageScale =
        StorageService.getSetting<double>(_imageScaleKey, defaultValue: 1.0) ??
        1.0;

    // Load auto scroll settings from global preferences
    final prefs = StorageService.getPreferences();
    final autoScroll = prefs?['autoScroll'] ?? false;
    final scrollSpeed = (prefs?['scrollSpeed'] ?? 1.0).toDouble();

    setState(() {
      _savedProgress = savedProgress.clamp(0.0, 1.0);
      _scrollProgress = _savedProgress;
      _isBookmarked = isBookmarked;
      _highlightedPages = rawHighlights
          .whereType<int>()
          .toSet(); // ensure only ints are used as indices
      _readerTheme = ReaderThemeMode
          .values[themeIndex.clamp(0, ReaderThemeMode.values.length - 1)];
      _imageBrightness = brightness.clamp(0.5, 1.0);
      _imageScale = imageScale.clamp(1.0, 1.2);
      _autoScrollEnabled = autoScroll;
      _autoScrollSpeed = scrollSpeed.clamp(0.5, 3.0);
    });

    // Start auto scroll if enabled
    if (_autoScrollEnabled) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (!_autoScrollEnabled) return;

    Future.doWhile(() async {
      if (!mounted || !_autoScrollEnabled) return false;
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        return _autoScrollEnabled && mounted;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll >= maxScroll) {
        return false;
      }

      // Scroll speed: base 50 pixels per second, multiplied by speed factor
      final pixelsPerFrame = (50 * _autoScrollSpeed) / 60;
      _scrollController.jumpTo(
        (currentScroll + pixelsPerFrame).clamp(0, maxScroll),
      );

      await Future.delayed(const Duration(milliseconds: 16)); // ~60fps
      return _autoScrollEnabled && mounted;
    });
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScrollEnabled = !_autoScrollEnabled;
    });
    if (_autoScrollEnabled) {
      _startAutoScroll();
    }
  }

  Future<void> _initTts() async {
    final tts = FlutterTts();
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.5);
    _flutterTts = tts;
  }

  @override
  void dispose() {
    _flutterTts?.stop();

    // End analytics tracking when reader closes
    if (_sessionStart != null) {
      // Try to get chapter data and track
      final chapterAsync = ref.read(chapterProvider(widget.chapterId));
      chapterAsync.whenData((chapter) {
        if (chapter != null) {
          _endAnalyticsTracking(chapter);
        }
      });
    }

    _scrollController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Color _backgroundColor() {
    switch (_readerTheme) {
      case ReaderThemeMode.light:
        return Colors.white;
      case ReaderThemeMode.sepia:
        return const Color(0xFFF4ECD8);
      case ReaderThemeMode.dark:
        return AppTheme.darkerBackground;
    }
  }

  Color _overlayTextColor() {
    switch (_readerTheme) {
      case ReaderThemeMode.light:
        return Colors.black87;
      case ReaderThemeMode.sepia:
        return const Color(0xFF3D2B1F);
      case ReaderThemeMode.dark:
        return AppTheme.textPrimary;
    }
  }

  void _updateProgress(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped == _scrollProgress) return;
    setState(() {
      _scrollProgress = clamped;
    });
    StorageService.saveSetting(
      '$_progressKeyPrefix${widget.chapterId}',
      _scrollProgress,
    );
  }

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
    StorageService.saveSetting(
      '$_bookmarkKeyPrefix${widget.chapterId}',
      _isBookmarked,
    );
  }

  void _toggleHighlight(int pageIndex) {
    setState(() {
      if (_highlightedPages.contains(pageIndex)) {
        _highlightedPages.remove(pageIndex);
      } else {
        _highlightedPages.add(pageIndex);
      }
    });

    StorageService.saveSetting(
      '$_highlightsKeyPrefix${widget.chapterId}',
      _highlightedPages.toList(),
    );
  }

  void _cycleTheme() {
    setState(() {
      switch (_readerTheme) {
        case ReaderThemeMode.dark:
          _readerTheme = ReaderThemeMode.light;
          break;
        case ReaderThemeMode.light:
          _readerTheme = ReaderThemeMode.sepia;
          break;
        case ReaderThemeMode.sepia:
          _readerTheme = ReaderThemeMode.dark;
          break;
      }
    });

    StorageService.saveSetting(_themeKey, _readerTheme.index);
  }

  void _updateBrightness(double value) {
    setState(() {
      _imageBrightness = value.clamp(0.5, 1.0);
    });
    StorageService.saveSetting(_brightnessKey, _imageBrightness);
  }

  void _updateImageScale(double value) {
    setState(() {
      _imageScale = value.clamp(1.0, 1.2);
    });
    StorageService.saveSetting(_imageScaleKey, _imageScale);
  }

  Future<void> _unlockChapter(
    BuildContext context,
    ChapterModel chapter,
  ) async {
    try {
      // Show rewarded ad
      final adService = AdService.instance;
      bool adWatched = false;

      final adShown = await adService.showRewardedAd(
        onRewarded: (reward) {
          adWatched = true;
        },
      );

      if (adShown && adWatched && mounted) {
        // Unlock chapter via API
        final apiService = ref.read(apiServiceProvider);
        await apiService.post(
          '${ApiConstants.chapterUnlock}/${chapter.id}/unlock',
        );

        CustomSnackbar.success(context, 'Chapter unlocked successfully!');

        // Refresh chapter data
        ref.invalidate(chapterProvider(widget.chapterId));
      } else if (mounted && !adWatched) {
        CustomSnackbar.error(
          context,
          'Please watch the ad to unlock the chapter.',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(
          context,
          'Failed to unlock chapter: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _toggleTts(ChapterModel? chapter) async {
    if (_flutterTts == null) return;

    if (_isTtsPlaying) {
      await _flutterTts!.stop();
      setState(() {
        _isTtsPlaying = false;
      });
      return;
    }

    final title = chapter?.title ?? 'Chapter ${chapter?.chapterNumber ?? ''}';
    final pagesCount = chapter?.pages.length ?? 0;
    final text =
        'You are reading $title. This is an image-based manga chapter with $pagesCount pages. Text-to-speech can only read this summary because pages are images.';

    await _flutterTts!.speak(text);
    setState(() {
      _isTtsPlaying = true;
    });

    // Best-effort: stop flag when done
    _flutterTts!.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPlaying = false;
        });
      }
    });
  }

  Future<void> _startAnalyticsTracking(ChapterModel chapter) async {
    if (_sessionStart != null) return; // Already tracking

    _sessionStart = DateTime.now();

    // Get manga details for analytics
    try {
      final manga = await ref.read(mangaDetailProvider(chapter.mangaId).future);
      if (manga != null) {
        _mangaId = manga.id;
        _totalChapters = manga.totalChapters ?? 0;
        _genres = manga.genres;
      }
    } catch (e) {
      // Use chapter data if manga fetch fails
      _mangaId = chapter.mangaId;
    }
  }

  Future<void> _endAnalyticsTracking(ChapterModel chapter) async {
    if (_sessionStart == null) return;

    final sessionEnd = DateTime.now();
    final timeSpent = sessionEnd.difference(_sessionStart!).inSeconds;

    // Calculate completion percentage based on scroll progress
    final completionPercentage = _scrollProgress * 100;
    final isCompleted = _scrollProgress >= 0.95; // Consider 95%+ as completed
    final pagesRead = (chapter.pages.length * _scrollProgress).round();
    final lastPageRead = (chapter.pages.length * _scrollProgress).round();

    await AnalyticsService.trackReadingSession(
      ref: ref,
      mangaId: _mangaId ?? chapter.mangaId,
      chapterId: chapter.id,
      chapterNumber: chapter.chapterNumber,
      totalChapters: _totalChapters ?? 0,
      sessionStart: _sessionStart!,
      sessionEnd: sessionEnd,
      timeSpent: timeSpent,
      pagesRead: pagesRead,
      isCompleted: isCompleted,
      completionPercentage: completionPercentage,
      lastPageRead: lastPageRead,
      totalPages: chapter.pages.length,
      genres: _genres,
    );

    _sessionStart = null;
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(chapterProvider(widget.chapterId));

    final bgColor = _backgroundColor();
    final overlayTextColor = _overlayTextColor();

    return Scaffold(
      backgroundColor: bgColor,
      body: chapterAsync.when(
        data: (chapter) {
          if (chapter == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chapter not found',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Check if chapter is locked
          if (chapter.isLocked == true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock,
                      size: 64,
                      color: AppTheme.primaryRed,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Chapter Locked',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chapter ${chapter.chapterNumber} is locked',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Watch an ad to unlock this chapter',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _unlockChapter(context, chapter),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Watch Ad to Unlock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (chapter.pages.isEmpty) {
            return const Center(
              child: Text(
                'No pages available',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          // Start analytics tracking when chapter loads (only once)
          if (_sessionStart == null) {
            _startAnalyticsTracking(chapter);
          }

          // Restore initial scroll once we know content size
          if (!_initialScrollApplied && _savedProgress > 0.0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollController.hasClients) return;
              final maxScroll = _scrollController.position.maxScrollExtent;
              _scrollController.jumpTo(maxScroll * _savedProgress);
              if (mounted) {
                setState(() {
                  _initialScrollApplied = true;
                  _scrollProgress = _savedProgress;
                });
              }
            });
          } else if (!_initialScrollApplied) {
            _initialScrollApplied = true;
          }

          return Stack(
            children: [
              // Vertical (webtoon-style) reader
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.maxScrollExtent > 0) {
                    final progress =
                        (notification.metrics.pixels /
                                notification.metrics.maxScrollExtent)
                            .clamp(0.0, 1.0);
                    _updateProgress(progress);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      for (int i = 0; i < chapter.pages.length; i++) ...[
                        GestureDetector(
                          onTap: _toggleControls,
                          onLongPress: () => _toggleHighlight(i),
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.zero,
                                child: ColorFiltered(
                                  // Use a simple modulate filter so images never disappear;
                                  // lower brightness = darker image.
                                  colorFilter: ColorFilter.mode(
                                    Colors.white.withOpacity(_imageBrightness),
                                    BlendMode.modulate,
                                  ),
                                  child: Transform.scale(
                                    scale: _imageScale,
                                    child: CachedNetworkImage(
                                      imageUrl: chapter.pages[i],
                                      fit: BoxFit.fitWidth,
                                      width: MediaQuery.of(context).size.width,
                                      placeholder: (context, url) =>
                                          const AspectRatio(
                                            aspectRatio: 3 / 4,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const SizedBox(
                                            height: 200,
                                            child: Center(
                                              child: Icon(
                                                Icons.error_outline,
                                                size: 48,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_highlightedPages.contains(i))
                                Positioned(
                                  top: 20,
                                  right: 24,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Highlight',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Show native ad every 5 pages (after pages 4, 9, 14, etc.)
                        if ((i + 1) % 5 == 0 && (i + 1) < chapter.pages.length)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: NativeAdWidget(
                              height: 300,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              adKey: ValueKey('reader_ad_$i'),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              // Top bar (positioned so it only captures touches in its own area)
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.pop(),
                        ),
                        title: Text(
                          chapter.title != null && chapter.title!.isNotEmpty
                              ? chapter.title!
                              : 'Chapter ${chapter.chapterNumber}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        actions: [
                          IconButton(
                            tooltip: _isBookmarked
                                ? 'Remove bookmark'
                                : 'Bookmark chapter',
                            icon: Icon(
                              _isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                            onPressed: _toggleBookmark,
                          ),
                          IconButton(
                            tooltip: 'Change theme',
                            icon: const Icon(Icons.color_lens_outlined),
                            onPressed: _cycleTheme,
                          ),
                          IconButton(
                            tooltip: _isTtsPlaying
                                ? 'Stop voice summary'
                                : 'Play voice summary',
                            icon: Icon(
                              _isTtsPlaying
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                            ),
                            onPressed: () => _toggleTts(chapter),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                backgroundColor: Colors.black.withOpacity(0.9),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (context) {
                                  return _ReaderSettingsSheet(
                                    brightness: _imageBrightness,
                                    imageScale: _imageScale,
                                    theme: _readerTheme,
                                    onBrightnessChanged: _updateBrightness,
                                    onImageScaleChanged: _updateImageScale,
                                    onThemeChanged: (mode) {
                                      setState(() {
                                        _readerTheme = mode;
                                      });
                                      StorageService.saveSetting(
                                        _themeKey,
                                        _readerTheme.index,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Bottom progress bar (also positioned just at the bottom)
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Auto scroll and navigation row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Auto scroll toggle
                              GestureDetector(
                                onTap: _toggleAutoScroll,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _autoScrollEnabled
                                        ? AppTheme.primaryRed
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _autoScrollEnabled
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _autoScrollEnabled
                                            ? 'Auto'
                                            : 'Auto Scroll',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Next chapter button
                              GestureDetector(
                                onTap: () => _goToNextChapter(chapter),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRed,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Next Chapter',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Scroll Progress',
                                style: TextStyle(
                                  color: overlayTextColor.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${(_scrollProgress * 100).round()}%',
                                style: TextStyle(
                                  color: overlayTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  _scrollProgress == 0.0 &&
                                      chapter.pages.isNotEmpty
                                  ? 0.01
                                  : _scrollProgress,
                              backgroundColor: AppTheme.cardBackground
                                  .withOpacity(0.5),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text(
            'Error loading chapter',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  void _goToNextChapter(ChapterModel chapter) async {
    if (chapter.mangaId.isEmpty) return;

    // Fetch the manga details to get next chapter
    final mangaId = chapter.mangaId;
    final chapters = await ref.read(mangaChaptersProvider(mangaId).future);

    if (chapters.isEmpty) return;

    // Find current chapter and get the next one
    final currentIndex = chapters.indexWhere((c) => c.id == widget.chapterId);
    if (currentIndex == -1 || currentIndex >= chapters.length - 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No next chapter available')),
        );
      }
      return;
    }

    final nextChapter = chapters[currentIndex + 1];

    // Get manga details to check if it's adult and has freeChapters
    final manga = await ref.read(mangaDetailProvider(chapter.mangaId).future);

    // Check if next chapter should be locked (for adult manga after free chapters)
    final freeChapters = manga?.freeChapters ?? 3;
    final shouldBeLocked =
        manga?.isAdult == true && nextChapter.chapterNumber > freeChapters;
    final isNextChapterLocked = nextChapter.isLocked == true || shouldBeLocked;

    // If next chapter is locked, show rewarded ad to unlock
    if (isNextChapterLocked) {
      final adService = AdService.instance;
      bool adWatched = false;

      final adShown = await adService.showRewardedAd(
        onRewarded: (reward) {
          adWatched = true;
        },
      );

      if (adShown && adWatched && mounted) {
        // Unlock chapter via API
        final apiService = ref.read(apiServiceProvider);
        try {
          await apiService.post(
            '${ApiConstants.chapterUnlock}/${nextChapter.id}/unlock',
          );

          CustomSnackbar.success(context, 'Chapter unlocked!');

          // Refresh chapter data
          ref.invalidate(chapterProvider(nextChapter.id));

          // Wait a moment for the provider to refresh
          await Future.delayed(const Duration(milliseconds: 300));

          // End current session tracking before navigating
          if (_sessionStart != null) {
            await _endAnalyticsTracking(chapter);
          }

          // Navigate to next chapter
          if (mounted) {
            context.pushReplacement('/reader/${nextChapter.id}');
          }
        } catch (e) {
          if (mounted) {
            CustomSnackbar.error(
              context,
              'Failed to unlock chapter: ${e.toString()}',
            );
          }
        }
      } else if (mounted && !adWatched) {
        CustomSnackbar.error(
          context,
          'Please watch the ad to continue to the next chapter.',
        );
      }
      return;
    }

    // End current session tracking before navigating
    if (_sessionStart != null) {
      await _endAnalyticsTracking(chapter);
    }

    // Show interstitial ad if should show (every N chapters)
    final adService = AdService.instance;
    if (adService.shouldShowInterstitialAd()) {
      adService.resetChapterReadCount();
      final adShown = await adService.showInterstitialAd();
      // Small delay to let ad show properly
      if (adShown) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (mounted) {
      context.pushReplacement('/reader/${nextChapter.id}');
    }
  }
}

class _ReaderSettingsSheet extends StatefulWidget {
  final double brightness;
  final double imageScale;
  final ReaderThemeMode theme;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onImageScaleChanged;
  final ValueChanged<ReaderThemeMode> onThemeChanged;

  const _ReaderSettingsSheet({
    required this.brightness,
    required this.imageScale,
    required this.theme,
    required this.onBrightnessChanged,
    required this.onImageScaleChanged,
    required this.onThemeChanged,
  });

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late double _brightness;
  late double _imageScale;
  late ReaderThemeMode _theme;

  @override
  void initState() {
    super.initState();
    _brightness = widget.brightness;
    _imageScale = widget.imageScale;
    _theme = widget.theme;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Reader Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Theme',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ThemeChip(
                    label: 'Dark',
                    icon: Icons.dark_mode,
                    selected: _theme == ReaderThemeMode.dark,
                    onTap: () {
                      setState(() {
                        _theme = ReaderThemeMode.dark;
                      });
                      widget.onThemeChanged(ReaderThemeMode.dark);
                    },
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: 'Light',
                    icon: Icons.light_mode,
                    selected: _theme == ReaderThemeMode.light,
                    onTap: () {
                      setState(() {
                        _theme = ReaderThemeMode.light;
                      });
                      widget.onThemeChanged(ReaderThemeMode.light);
                    },
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: 'Sepia',
                    icon: Icons.auto_awesome,
                    selected: _theme == ReaderThemeMode.sepia,
                    onTap: () {
                      setState(() {
                        _theme = ReaderThemeMode.sepia;
                      });
                      widget.onThemeChanged(ReaderThemeMode.sepia);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Premium Unlock Section
              Consumer(
                builder: (context, ref, child) {
                  final adsWatched =
                      StorageService.getSetting<int>(
                        'premium_reader_ads_watched',
                        defaultValue: 0,
                      ) ??
                      0;
                  final isUnlocked =
                      StorageService.getSetting<String>(
                        'premium_unlocked_until',
                      ) !=
                      null;

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
                          StorageService.saveSetting(
                            'premium_unlocked_until',
                            null,
                          );
                        }
                      } catch (e) {
                        StorageService.saveSetting(
                          'premium_unlocked_until',
                          null,
                        );
                      }
                    }
                  }

                  final remainingAds = 6 - adsWatched;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryRed.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              color: AppTheme.primaryRed,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Unlock Premium Reader',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isPremiumActive)
                          const Text(
                            'Premium Reader is active!',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else ...[
                          Text(
                            'Watch 6 ads to unlock premium features ($adsWatched/6)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: adsWatched / 6,
                              minHeight: 4,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: RewardedAdButton(
                            title: isPremiumActive
                                ? 'Premium Active'
                                : remainingAds > 0
                                ? 'Watch Ad ($adsWatched/6)'
                                : 'Unlock Premium',
                            icon: isPremiumActive
                                ? Icons.check_circle
                                : Icons.diamond_outlined,
                            rewardMessage: remainingAds > 1
                                ? 'Progress: ${adsWatched + 1}/6 ads watched!'
                                : 'Premium Reader unlocked!',
                            backgroundColor: isPremiumActive
                                ? Colors.green
                                : AppTheme.primaryRed,
                            textColor: Colors.white,
                            onRewardEarned: () {
                              if (isPremiumActive) return;

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
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Skip Ads Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Skip Ads',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Watch an ad to skip interstitial ads for next 5 chapters',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: RewardedAdButton(
                        title: 'Watch Ad to Skip Ads',
                        icon: Icons.play_circle_outline,
                        rewardMessage: 'Ads skipped for next 5 chapters!',
                        backgroundColor: Colors.amber,
                        textColor: Colors.black,
                        onRewardEarned: () {
                          StorageService.saveSetting('skip_ads_count', 5);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Brightness',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.brightness_low, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: _brightness,
                      min: 0.5,
                      max: 1.0,
                      onChanged: (value) {
                        setState(() {
                          _brightness = value;
                        });
                        widget.onBrightnessChanged(value);
                      },
                    ),
                  ),
                  const Icon(Icons.brightness_high, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Image Size',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.photo_size_select_small,
                    color: Colors.white70,
                  ),
                  Expanded(
                    child: Slider(
                      value: _imageScale,
                      min: 1.0, // always start at full size, only allow zoom-in
                      max: 1.2,
                      onChanged: (value) {
                        setState(() {
                          _imageScale = value;
                        });
                        widget.onImageScaleChanged(value);
                      },
                    ),
                  ),
                  const Icon(
                    Icons.photo_size_select_large,
                    color: Colors.white70,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.white : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.black : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
