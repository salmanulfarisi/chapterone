import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../core/utils/logger.dart';

// Provider for statistics
final statisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.userStatistics);
    return Map<String, dynamic>.from(response.data);
  } catch (e) {
    Logger.error(
      'Error fetching statistics: ${e.toString()}',
      e,
      null,
      'StatisticsProvider',
    );
    rethrow;
  }
});

class DetailedStatisticsScreen extends ConsumerWidget {
  const DetailedStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsAsync = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Statistics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: statisticsAsync.when(
        data: (stats) => _buildStatisticsContent(context, stats),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryRed),
              const SizedBox(height: 16),
              Text(
                'Loading your reading statistics...',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(statisticsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsContent(BuildContext context, Map<String, dynamic> stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          _buildHeaderCard(context, stats),
          const SizedBox(height: 24),

          // Time Spent Reading
          _buildTimeSpentSection(context, stats),
          const SizedBox(height: 24),

          // Chapters Read
          _buildChaptersReadSection(context, stats),
          const SizedBox(height: 24),

          // Genre Breakdown
          _buildGenreBreakdownSection(context, stats),
          const SizedBox(height: 24),

          // Reading Streak
          _buildReadingStreakSection(context, stats),
          const SizedBox(height: 24),

          // Most Read Manga
          _buildMostReadMangaSection(context, stats),
          const SizedBox(height: 24),

          // Daily Activity Chart
          _buildDailyActivitySection(context, stats),
          const SizedBox(height: 24),

          // Favorite Genres
          _buildFavoriteGenresSection(context, stats),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Map<String, dynamic> stats) {
    final weeklyHours = stats['timeSpent']?['weekly']?['hours'] ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryRed,
            AppTheme.primaryRed.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_stories,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Your Reading Wrapped',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You read for ${weeklyHours.toStringAsFixed(1)} hours this week',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSpentSection(BuildContext context, Map<String, dynamic> stats) {
    final timeSpent = stats['timeSpent'] ?? {};
    final weekly = timeSpent['weekly'] ?? {};
    final monthly = timeSpent['monthly'] ?? {};
    final total = timeSpent['total'] ?? {};

    return _buildSectionCard(
      title: 'Time Spent Reading',
      icon: Icons.access_time,
      child: Column(
        children: [
          _buildStatCard(
            'This Week',
            '${(weekly['hours'] ?? 0.0).toStringAsFixed(1)} hours',
            Icons.calendar_today,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'This Month',
            '${(monthly['hours'] ?? 0.0).toStringAsFixed(1)} hours',
            Icons.calendar_month,
            Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'All Time',
            '${(total['hours'] ?? 0.0).toStringAsFixed(1)} hours',
            Icons.history,
            AppTheme.primaryRed,
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersReadSection(BuildContext context, Map<String, dynamic> stats) {
    final chaptersRead = stats['chaptersRead'] ?? {};
    final total = chaptersRead['total'] ?? 0;
    final unique = chaptersRead['unique'] ?? 0;

    return _buildSectionCard(
      title: 'Chapters Read',
      icon: Icons.menu_book,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Chapters',
              '$total',
              Icons.library_books,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Unique Chapters',
              '$unique',
              Icons.bookmark,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreBreakdownSection(BuildContext context, Map<String, dynamic> stats) {
    final genreBreakdown = (stats['genreBreakdown'] as List<dynamic>?) ?? [];
    
    if (genreBreakdown.isEmpty) {
      return _buildSectionCard(
        title: 'Genre Breakdown',
        icon: Icons.pie_chart,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No genre data available',
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _buildSectionCard(
      title: 'Genre Breakdown',
      icon: Icons.pie_chart,
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: genreBreakdown.asMap().entries.map((entry) {
                  final index = entry.key;
                  final genre = entry.value;
                  final percentage = genre['percentage'] ?? 0;
                  final colors = [
                    AppTheme.primaryRed,
                    Colors.blue,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                    Colors.pink,
                    Colors.teal,
                    Colors.amber,
                    Colors.indigo,
                    Colors.cyan,
                  ];
                  
                  return PieChartSectionData(
                    value: percentage.toDouble(),
                    title: '$percentage%',
                    color: colors[index % colors.length],
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 60,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...genreBreakdown.map((genre) {
            final percentage = genre['percentage'] ?? 0;
            final genreName = genre['genre'] ?? 'Unknown';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      genreName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReadingStreakSection(BuildContext context, Map<String, dynamic> stats) {
    final streak = stats['readingStreak'] ?? {};
    final current = streak['current'] ?? 0;
    final longest = streak['longest'] ?? 0;

    return _buildSectionCard(
      title: 'Reading Streak',
      icon: Icons.local_fire_department,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Current Streak',
              '$current days',
              Icons.whatshot,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Longest Streak',
              '$longest days',
              Icons.emoji_events,
              Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostReadMangaSection(BuildContext context, Map<String, dynamic> stats) {
    final mostRead = (stats['mostReadManga'] as List<dynamic>?) ?? [];
    
    if (mostRead.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      title: 'Most Read Manga',
      icon: Icons.star,
      child: Column(
        children: mostRead.take(5).map((manga) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: manga['cover'] ?? '',
                    width: 60,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 80,
                      color: AppTheme.darkBackground,
                      child: const Icon(Icons.image),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 80,
                      color: AppTheme.darkBackground,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manga['title'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${manga['chaptersRead'] ?? 0} chapters • ${(manga['readingTimeHours'] ?? 0.0).toStringAsFixed(1)} hours',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyActivitySection(BuildContext context, Map<String, dynamic> stats) {
    final dailyActivity = (stats['dailyActivity'] as List<dynamic>?) ?? [];
    
    if (dailyActivity.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxChapters = dailyActivity.fold<double>(
      0,
      (max, day) => (day['chaptersRead'] ?? 0).toDouble() > max
          ? (day['chaptersRead'] ?? 0).toDouble()
          : max,
    );

    return _buildSectionCard(
      title: 'Daily Activity (Last 30 Days)',
      icon: Icons.show_chart,
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxChapters > 0 ? maxChapters + 2 : 10,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() % 5 == 0 && value.toInt() < dailyActivity.length) {
                      final date = dailyActivity[value.toInt()]['date'];
                      return Text(
                        date.split('-')[2],
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      );
                    }
                    return const Text('');
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            barGroups: dailyActivity.asMap().entries.map((entry) {
              final index = entry.key;
              final day = entry.value;
              final chapters = (day['chaptersRead'] ?? 0).toDouble();
              
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: chapters,
                    color: AppTheme.primaryRed,
                    width: 4,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteGenresSection(BuildContext context, Map<String, dynamic> stats) {
    final favoriteGenres = (stats['favoriteGenres'] as List<dynamic>?) ?? [];
    
    if (favoriteGenres.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      title: 'Favorite Genres by Reading Time',
      icon: Icons.favorite,
      child: Column(
        children: favoriteGenres.map((genre) {
          final genreName = genre['genre'] ?? 'Unknown';
          final hours = (genre['hours'] ?? 0.0).toStringAsFixed(1);
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.category,
                    size: 20,
                    color: AppTheme.primaryRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    genreName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$hours hours',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryRed,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryRed, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

