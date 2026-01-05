import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import 'providers/analytics_provider.dart';
import '../../widgets/empty_state.dart';

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState
    extends ConsumerState<AnalyticsDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh analytics when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(analyticsDashboardProvider);
      ref.invalidate(genrePreferencesProvider);
      ref.invalidate(readingPatternsProvider);
      ref.invalidate(completionDataProvider);
      ref.invalidate(dropoffAnalysisProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reading Analytics'),
          backgroundColor: AppTheme.darkBackground,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(analyticsDashboardProvider);
                ref.invalidate(genrePreferencesProvider);
                ref.invalidate(readingPatternsProvider);
                ref.invalidate(completionDataProvider);
                ref.invalidate(dropoffAnalysisProvider);
              },
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Genres'),
              Tab(text: 'Patterns'),
              Tab(text: 'Completion'),
              Tab(text: 'Drop-off'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.darkerBackground, AppTheme.darkBackground],
            ),
          ),
          child: const TabBarView(
            children: [
              _OverviewTab(),
              _GenresTab(),
              _PatternsTab(),
              _CompletionTab(),
              _DropoffTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// Overview Tab
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(analyticsDashboardProvider);

    return dashboardAsync.when(
      data: (dashboard) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _StatCard(
                  title: 'Time Spent',
                  value: dashboard.formattedTimeSpent,
                  icon: Icons.access_time,
                  color: Colors.blue,
                ),
                _StatCard(
                  title: 'Chapters Read',
                  value: '${dashboard.totalChaptersRead}',
                  icon: Icons.menu_book,
                  color: Colors.green,
                ),
                _StatCard(
                  title: 'Pages Read',
                  value: '${dashboard.totalPagesRead}',
                  icon: Icons.pages,
                  color: Colors.orange,
                ),
                _StatCard(
                  title: 'Manga Read',
                  value: '${dashboard.uniqueMangaRead}',
                  icon: Icons.library_books,
                  color: Colors.purple,
                ),
                _StatCard(
                  title: 'Avg Session',
                  value: dashboard.formattedAvgSessionTime,
                  icon: Icons.timer,
                  color: Colors.teal,
                ),
                _StatCard(
                  title: 'Completion Rate',
                  value: '${dashboard.completionRate.toStringAsFixed(1)}%',
                  icon: Icons.check_circle,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Completion Summary
            Card(
              color: AppTheme.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completion Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: 'Started',
                          value: '${dashboard.totalMangaStarted}',
                          color: Colors.blue,
                        ),
                        _SummaryItem(
                          label: 'Completed',
                          value: '${dashboard.totalMangaCompleted}',
                          color: Colors.green,
                        ),
                        _SummaryItem(
                          label: 'In Progress',
                          value:
                              '${dashboard.totalMangaStarted - dashboard.totalMangaCompleted}',
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        title: 'Error',
        message: 'Failed to load analytics',
        icon: Icons.error_outline,
      ),
    );
  }
}

// Genres Tab
class _GenresTab extends ConsumerWidget {
  const _GenresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genrePreferencesProvider);

    return genresAsync.when(
      data: (genres) {
        if (genres.isEmpty) {
          return const EmptyState(
            title: 'No Data',
            message: 'No genre data available',
            icon: Icons.category_outlined,
          );
        }

        final maxCount = genres.isNotEmpty
            ? genres.map((g) => g.count).reduce((a, b) => a > b ? a : b)
            : 1;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final genre = genres[index];
            final percentage = (genre.count / maxCount) * 100;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppTheme.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          genre.genre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${genre.count} sessions',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 8,
                        backgroundColor: AppTheme.cardBackground.withOpacity(
                          0.3,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(genre.totalTime),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${genre.totalChapters} chapters',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        title: 'Error',
        message: 'Failed to load genre preferences',
        icon: Icons.error_outline,
      ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

// Patterns Tab
class _PatternsTab extends ConsumerWidget {
  const _PatternsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(readingPatternsProvider);

    return patternsAsync.when(
      data: (patterns) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day of Week
            const Text(
              'Reading by Day of Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppTheme.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: patterns.dayOfWeek.map((day) {
                    final maxCount = patterns.dayOfWeek.isNotEmpty
                        ? patterns.dayOfWeek
                              .map((d) => d.count)
                              .reduce((a, b) => a > b ? a : b)
                        : 1;
                    final percentage = (day.count / maxCount) * 100;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                day.dayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${day.count} sessions',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              minHeight: 6,
                              backgroundColor: AppTheme.cardBackground
                                  .withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Hour of Day
            const Text(
              'Reading by Hour of Day',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppTheme.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: patterns.hourOfDay.map((hour) {
                    final maxCount = patterns.hourOfDay.isNotEmpty
                        ? patterns.hourOfDay
                              .map((h) => h.count)
                              .reduce((a, b) => a > b ? a : b)
                        : 1;
                    final percentage = (hour.count / maxCount) * 100;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${hour.hour}:00',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 6,
                                backgroundColor: AppTheme.cardBackground
                                    .withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryRed,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${hour.count}',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        title: 'Error',
        message: 'Failed to load reading patterns',
        icon: Icons.error_outline,
      ),
    );
  }
}

// Completion Tab
class _CompletionTab extends ConsumerWidget {
  const _CompletionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionAsync = ref.watch(completionDataProvider);

    return completionAsync.when(
      data: (completions) {
        if (completions.isEmpty) {
          return const EmptyState(
            title: 'No Data',
            message: 'No completion data available',
            icon: Icons.check_circle_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completions.length,
          itemBuilder: (context, index) {
            final completion = completions[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppTheme.cardBackground,
              child: ListTile(
                leading: completion.mangaCover != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: completion.mangaCover!,
                          width: 50,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 50,
                            height: 70,
                            color: AppTheme.cardBackground,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 50,
                            height: 70,
                            color: AppTheme.cardBackground,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 70,
                        color: AppTheme.cardBackground,
                        child: const Icon(Icons.book),
                      ),
                title: Text(
                  completion.mangaTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${completion.chaptersRead} / ${completion.totalChapters} chapters',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completion.completionPercentage / 100,
                        minHeight: 6,
                        backgroundColor: AppTheme.cardBackground.withOpacity(
                          0.3,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completion.isCompleted
                              ? Colors.green
                              : AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${completion.completionPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                trailing: completion.isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        title: 'Error',
        message: 'Failed to load completion data',
        icon: Icons.error_outline,
      ),
    );
  }
}

// Drop-off Tab
class _DropoffTab extends ConsumerWidget {
  const _DropoffTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dropoffAsync = ref.watch(dropoffAnalysisProvider);

    return dropoffAsync.when(
      data: (dropoff) {
        if (dropoff.dropoffPoints.isEmpty) {
          return const EmptyState(
            title: 'No Data',
            message: 'No drop-off data available',
            icon: Icons.trending_down_outlined,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Stats
              Card(
                color: AppTheme.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Drop-off Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SummaryItem(
                            label: 'Total Drop-offs',
                            value: '${dropoff.overall.totalDropoffs}',
                            color: Colors.red,
                          ),
                          _SummaryItem(
                            label: 'Avg Chapter',
                            value: dropoff.overall.avgChapterNumber
                                .toStringAsFixed(1),
                            color: Colors.orange,
                          ),
                          _SummaryItem(
                            label: 'Avg Completion',
                            value:
                                '${dropoff.overall.avgCompletionPercentage.toStringAsFixed(1)}%',
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Top Drop-off Points',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...dropoff.dropoffPoints.map((point) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppTheme.cardBackground,
                  child: ListTile(
                    leading: point.mangaCover != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: point.mangaCover!,
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 50,
                                height: 70,
                                color: AppTheme.cardBackground,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 50,
                                height: 70,
                                color: AppTheme.cardBackground,
                                child: const Icon(Icons.image_not_supported),
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 70,
                            color: AppTheme.cardBackground,
                            child: const Icon(Icons.book),
                          ),
                    title: Text(
                      point.mangaTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Chapter ${point.chapterNumber}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${point.dropoffCount} drop-offs • ${point.avgCompletionPercentage.toStringAsFixed(1)}% avg completion',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_down, color: AppTheme.primaryRed),
                        Text(
                          '${point.dropoffCount}',
                          style: TextStyle(
                            color: AppTheme.primaryRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(
        title: 'Error',
        message: 'Failed to load drop-off analysis',
        icon: Icons.error_outline,
      ),
    );
  }
}

// Helper Widgets
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
