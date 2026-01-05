import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import 'providers/admin_provider.dart';
import '../../widgets/empty_state.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() =>
      _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userActivityTimeframe = '24h';
  String _popularContentTimeframe = '30d';
  String _retentionPeriod = '30d';
  String _revenueTimeframe = '30d';
  String _contentPerformanceTimeframe = '30d';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    // Only auto-refresh the overview tab, not all tabs (to prevent continuous API calls)
    // Auto-refresh every 60 seconds (increased interval)
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && _tabController.index == 0) {
        ref.invalidate(adminAnalyticsProvider);
        _startAutoRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && _tabController.index == 0) {
        // Only refresh overview tab when it's active
        ref.invalidate(adminAnalyticsProvider);
        _startAutoRefresh();
      }
    });
  }

  void _refreshAll() {
    // Only refresh the currently active tab to prevent continuous API calls
    final currentIndex = _tabController.index;
    switch (currentIndex) {
      case 0:
        ref.invalidate(adminAnalyticsProvider);
        break;
      case 1:
        ref.invalidate(adminUserActivityProvider(_userActivityTimeframe));
        break;
      case 2:
        ref.invalidate(
          adminPopularContentProvider({
            'timeframe': _popularContentTimeframe,
            'limit': '10',
          }),
        );
        break;
      case 3:
        ref.invalidate(adminUserRetentionProvider(_retentionPeriod));
        break;
      case 4:
        ref.invalidate(adminRevenueProvider(_revenueTimeframe));
        break;
      case 5:
        ref.invalidate(
          adminContentPerformanceProvider({
            'timeframe': _contentPerformanceTimeframe,
            'limit': '20',
          }),
        );
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Analytics'),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'User Activity'),
            Tab(text: 'Popular Content'),
            Tab(text: 'User Retention'),
            Tab(text: 'Revenue'),
            Tab(text: 'Content Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUserActivityTab(),
          _buildPopularContentTab(),
          _buildUserRetentionTab(),
          _buildRevenueTab(),
          _buildContentPerformanceTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAnalyticsProvider);
      },
      child: analyticsAsync.when(
        data: (analytics) {
          final totalUsers =
              analytics['totalUsers'] ?? analytics['stats']?['totalUsers'] ?? 0;
          final totalManga =
              analytics['totalManga'] ?? analytics['stats']?['totalManga'] ?? 0;
          final totalChapters =
              analytics['totalChapters'] ??
              analytics['stats']?['totalChapters'] ??
              0;
          final chartData = analytics['chartData'] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Users',
                        value: totalUsers.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Manga',
                        value: totalManga.toString(),
                        icon: Icons.menu_book,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Chapters',
                        value: totalChapters.toString(),
                        icon: Icons.menu_book_outlined,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Avg Chapters/Manga',
                        value: totalManga > 0
                            ? (totalChapters / totalManga).toStringAsFixed(1)
                            : '0',
                        icon: Icons.calculate,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Charts
                if (chartData.isNotEmpty) ...[
                  if (chartData['userGrowth'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'User Growth (Last 7 Days)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: _buildLineChart(
                                chartData['userGrowth'] ?? [],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (chartData['popularGenres'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Popular Genres',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: _buildPieChart(
                                chartData['popularGenres'] ?? {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (chartData['readingActivity'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reading Activity (Last 7 Days)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: _buildBarChart(
                                chartData['readingActivity'] ?? [],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  const EmptyState(
                    title: 'No Chart Data',
                    message: 'Chart data will appear here once available',
                    icon: Icons.bar_chart,
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
              const Text(
                'Error loading analytics',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(adminAnalyticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserActivityTab() {
    final activityAsync = ref.watch(
      adminUserActivityProvider(_userActivityTimeframe),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminUserActivityProvider(_userActivityTimeframe));
      },
      child: activityAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const EmptyState(
              title: 'No Activity Data',
              message: 'User activity data will appear here',
              icon: Icons.people_outline,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeframe selector
                Row(
                  children: [
                    const Text('Timeframe: '),
                    DropdownButton<String>(
                      value: _userActivityTimeframe,
                      items: const [
                        DropdownMenuItem(value: '1h', child: Text('Last Hour')),
                        DropdownMenuItem(
                          value: '24h',
                          child: Text('Last 24 Hours'),
                        ),
                        DropdownMenuItem(
                          value: '7d',
                          child: Text('Last 7 Days'),
                        ),
                        DropdownMenuItem(
                          value: '30d',
                          child: Text('Last 30 Days'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _userActivityTimeframe = value);
                          ref.invalidate(adminUserActivityProvider(value));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Active Users',
                        value: (data['activeUsers'] ?? 0).toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'New Users',
                        value: (data['newUsers'] ?? 0).toString(),
                        icon: Icons.person_add,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Reading Sessions',
                        value: (data['readingSessions'] ?? 0).toString(),
                        icon: Icons.book,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Reading Hours',
                        value: (data['totalReadingHours'] ?? 0).toString(),
                        icon: Icons.access_time,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Hourly activity chart
                if (data['hourlyActivity'] != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hourly Activity (Last 24 Hours)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _buildHourlyBarChart(
                              data['hourlyActivity'] ?? [],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const EmptyState(
          title: 'Error',
          message: 'Failed to load user activity',
          icon: Icons.error_outline,
        ),
      ),
    );
  }

  Widget _buildPopularContentTab() {
    final contentAsync = ref.watch(
      adminPopularContentProvider({
        'timeframe': _popularContentTimeframe,
        'limit': '10',
      }),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          adminPopularContentProvider({
            'timeframe': _popularContentTimeframe,
            'limit': '10',
          }),
        );
      },
      child: contentAsync.when(
        data: (data) {
          // Check if there's an error in the response
          if (data.containsKey('error')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load popular content',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(
                        adminPopularContentProvider({
                          'timeframe': _popularContentTimeframe,
                          'limit': '10',
                        }),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final popularManga = data['popularManga'] as List<dynamic>? ?? [];
          final popularGenres = data['popularGenres'] as List<dynamic>? ?? [];

          if (popularManga.isEmpty && popularGenres.isEmpty) {
            return const EmptyState(
              title: 'No Content Data',
              message: 'Popular content data will appear here',
              icon: Icons.trending_up,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeframe selector
                Row(
                  children: [
                    const Text('Timeframe: '),
                    DropdownButton<String>(
                      value: _popularContentTimeframe,
                      items: const [
                        DropdownMenuItem(
                          value: '7d',
                          child: Text('Last 7 Days'),
                        ),
                        DropdownMenuItem(
                          value: '30d',
                          child: Text('Last 30 Days'),
                        ),
                        DropdownMenuItem(
                          value: '90d',
                          child: Text('Last 90 Days'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _popularContentTimeframe = value);
                          ref.invalidate(
                            adminPopularContentProvider({
                              'timeframe': value,
                              'limit': '10',
                            }),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Popular Manga
                const Text(
                  'Most Read Manga',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...popularManga.map((item) {
                  final manga = item['manga'] as Map<String, dynamic>?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: manga?['cover'] != null
                          ? CachedNetworkImage(
                              imageUrl: manga!['cover'],
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(
                                width: 50,
                                height: 70,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            )
                          : const Icon(Icons.book),
                      title: Text(manga?['title'] ?? 'Unknown'),
                      subtitle: Text(
                        '${item['uniqueReaders']} readers • ${item['readCount']} reads',
                      ),
                      trailing: Text(
                        '${item['avgChaptersRead']?.toStringAsFixed(1) ?? 0} avg chapters',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),
                const Text(
                  'Popular Genres',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: popularGenres.map((item) {
                    return Chip(
                      label: Text('${item['genre']}: ${item['readCount']}'),
                      backgroundColor: AppTheme.primaryRed.withOpacity(0.2),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
              const Text(
                'Failed to load popular content',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(
                    adminPopularContentProvider({
                      'timeframe': _popularContentTimeframe,
                      'limit': '10',
                    }),
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserRetentionTab() {
    final retentionAsync = ref.watch(
      adminUserRetentionProvider(_retentionPeriod),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminUserRetentionProvider(_retentionPeriod));
      },
      child: retentionAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const EmptyState(
              title: 'No Retention Data',
              message: 'User retention data will appear here',
              icon: Icons.timeline,
            );
          }

          final dau = data['dailyActiveUsers'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period selector
                Row(
                  children: [
                    const Text('Period: '),
                    DropdownButton<String>(
                      value: _retentionPeriod,
                      items: const [
                        DropdownMenuItem(
                          value: '7d',
                          child: Text('Last 7 Days'),
                        ),
                        DropdownMenuItem(
                          value: '30d',
                          child: Text('Last 30 Days'),
                        ),
                        DropdownMenuItem(
                          value: '90d',
                          child: Text('Last 90 Days'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _retentionPeriod = value);
                          ref.invalidate(adminUserRetentionProvider(value));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Monthly Active Users',
                        value: (data['monthlyActiveUsers'] ?? 0).toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'New Users',
                        value: (data['newUsers'] ?? 0).toString(),
                        icon: Icons.person_add,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Returning Users',
                        value: (data['returningUsers'] ?? 0).toString(),
                        icon: Icons.repeat,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Retention Rate',
                        value: '${data['retentionRate'] ?? 0}%',
                        icon: Icons.trending_up,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Daily active users chart
                if (dau.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Active Users',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(height: 200, child: _buildDauLineChart(dau)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const EmptyState(
          title: 'Error',
          message: 'Failed to load user retention',
          icon: Icons.error_outline,
        ),
      ),
    );
  }

  Widget _buildRevenueTab() {
    final revenueAsync = ref.watch(adminRevenueProvider(_revenueTimeframe));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminRevenueProvider(_revenueTimeframe));
      },
      child: revenueAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const EmptyState(
              title: 'No Revenue Data',
              message: 'Revenue data will appear here',
              icon: Icons.attach_money,
            );
          }

          final adRevenue = data['adRevenue'] as Map<String, dynamic>? ?? {};
          final premiumRevenue =
              data['premiumRevenue'] as Map<String, dynamic>? ?? {};
          final dailyRevenue = data['dailyRevenue'] as List<dynamic>? ?? [];
          final topRevenueManga =
              data['topRevenueManga'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeframe selector
                Row(
                  children: [
                    const Text('Timeframe: '),
                    DropdownButton<String>(
                      value: _revenueTimeframe,
                      items: const [
                        DropdownMenuItem(
                          value: '7d',
                          child: Text('Last 7 Days'),
                        ),
                        DropdownMenuItem(
                          value: '30d',
                          child: Text('Last 30 Days'),
                        ),
                        DropdownMenuItem(
                          value: '90d',
                          child: Text('Last 90 Days'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _revenueTimeframe = value);
                          ref.invalidate(adminRevenueProvider(value));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Revenue summary
                Card(
                  color: Colors.green.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Revenue',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${data['totalRevenue'] ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Ad revenue
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ad Revenue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${adRevenue['total'] ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${adRevenue['unlocks'] ?? 0} ad unlocks',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Premium revenue
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Premium Revenue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${premiumRevenue['total'] ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${premiumRevenue['subscribers'] ?? 0} subscribers',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Daily revenue chart
                if (dailyRevenue.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Revenue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: _buildRevenueLineChart(dailyRevenue),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Top revenue manga
                const Text(
                  'Top Revenue Generating Manga',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...topRevenueManga.map((item) {
                  final manga = item['manga'] as Map<String, dynamic>?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: manga?['cover'] != null
                          ? CachedNetworkImage(
                              imageUrl: manga!['cover'],
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(
                                width: 50,
                                height: 70,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            )
                          : const Icon(Icons.book),
                      title: Text(manga?['title'] ?? 'Unknown'),
                      subtitle: Text('${item['adUnlocks']} ad unlocks'),
                      trailing: Text(
                        '\$${item['estimatedRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const EmptyState(
          title: 'Error',
          message: 'Failed to load revenue analytics',
          icon: Icons.error_outline,
        ),
      ),
    );
  }

  Widget _buildContentPerformanceTab() {
    final performanceAsync = ref.watch(
      adminContentPerformanceProvider({
        'timeframe': _contentPerformanceTimeframe,
        'limit': '20',
      }),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          adminContentPerformanceProvider({
            'timeframe': _contentPerformanceTimeframe,
            'limit': '20',
          }),
        );
      },
      child: performanceAsync.when(
        data: (data) {
          // Check if there's an error in the response
          if (data.containsKey('error')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load content performance',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(
                        adminContentPerformanceProvider({
                          'timeframe': _contentPerformanceTimeframe,
                          'limit': '20',
                        }),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final contentPerformance =
              data['contentPerformance'] as List<dynamic>? ?? [];
          final avgMetrics =
              data['averageMetrics'] as Map<String, dynamic>? ?? {};

          if (contentPerformance.isEmpty &&
              (avgMetrics.isEmpty || avgMetrics['totalReads'] == 0)) {
            return const EmptyState(
              title: 'No Performance Data',
              message: 'Content performance data will appear here',
              icon: Icons.analytics,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeframe selector
                Row(
                  children: [
                    const Text('Timeframe: '),
                    DropdownButton<String>(
                      value: _contentPerformanceTimeframe,
                      items: const [
                        DropdownMenuItem(
                          value: '7d',
                          child: Text('Last 7 Days'),
                        ),
                        DropdownMenuItem(
                          value: '30d',
                          child: Text('Last 30 Days'),
                        ),
                        DropdownMenuItem(
                          value: '90d',
                          child: Text('Last 90 Days'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _contentPerformanceTimeframe = value);
                          ref.invalidate(
                            adminContentPerformanceProvider({
                              'timeframe': value,
                              'limit': '20',
                            }),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Average metrics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Average Metrics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Avg Chapters Read',
                                value:
                                    avgMetrics['avgChaptersRead']?.toString() ??
                                    '0',
                                icon: Icons.book,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Total Reads',
                                value:
                                    avgMetrics['totalReads']?.toString() ?? '0',
                                icon: Icons.visibility,
                                color: AppTheme.primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Content performance list
                const Text(
                  'Top Performing Content',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...contentPerformance.map((item) {
                  final manga = item['manga'] as Map<String, dynamic>?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: manga?['cover'] != null
                          ? CachedNetworkImage(
                              imageUrl: manga!['cover'],
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(
                                width: 50,
                                height: 70,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            )
                          : const Icon(Icons.book),
                      title: Text(manga?['title'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['uniqueReaders']} readers • ${item['totalReads']} reads',
                          ),
                          if (item['completionRate'] != null)
                            Text(
                              'Completion: ${item['completionRate']?.toStringAsFixed(1) ?? 0}%',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item['avgChaptersRead']?.toStringAsFixed(1) ?? 0} avg',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (item['avgTimeSpent'] != null)
                            Text(
                              '${(item['avgTimeSpent'] / 60).toStringAsFixed(0)} min',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
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
              const Text(
                'Failed to load content performance',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(
                    adminContentPerformanceProvider({
                      'timeframe': _contentPerformanceTimeframe,
                      'limit': '20',
                    }),
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (index) =>
                  FlSpot(index.toDouble(), (data[index] ?? 0).toDouble()),
            ),
            isCurved: true,
            color: AppTheme.primaryRed,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryRed.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final entries = data.entries.toList();
    final colors = [
      AppTheme.primaryRed,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return PieChart(
      PieChartData(
        sections: List.generate(entries.length, (index) {
          final entry = entries[index];
          final value = (entry.value as num).toDouble();
          return PieChartSectionData(
            value: value,
            title: entry.key,
            color: colors[index % colors.length],
            radius: 60,
          );
        }),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildBarChart(List<dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          data.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (data[index] ?? 0).toDouble(),
                color: AppTheme.primaryRed,
                width: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyBarChart(List<dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 6 == 0) {
                  return Text('${value.toInt()}h');
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          data.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (data[index] ?? 0).toDouble(),
                color: Colors.blue,
                width: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDauLineChart(List<dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (index) => FlSpot(
                index.toDouble(),
                (data[index]['count'] ?? 0).toDouble(),
              ),
            ),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueLineChart(List<dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (index) => FlSpot(
                index.toDouble(),
                (data[index]['adRevenue'] ?? 0).toDouble(),
              ),
            ),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
