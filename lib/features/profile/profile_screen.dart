import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api/api_service.dart';
import '../../core/constants/api_constants.dart';
import 'providers/achievements_provider.dart';

// User stats provider
final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.userStats);
    return response.data as Map<String, dynamic>;
  } catch (e) {
    return {};
  }
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh stats when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(userStatsProvider);
    });

    // Auto-refresh every 30 seconds for instant updates
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        ref.invalidate(userStatsProvider);
        _startAutoRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        ref.invalidate(userStatsProvider);
        _startAutoRefresh();
      }
    });
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: AppTheme.primaryRed),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout? You will need to login again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final statsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userStatsProvider);
              },
              child: CustomScrollView(
                slivers: [
                  // Custom App Bar with gradient
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryRed,
                              AppTheme.primaryRed.withOpacity(0.7),
                              AppTheme.darkBackground,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              // Avatar with border
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundColor: AppTheme.cardBackground,
                                  child: user.avatar != null
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: user.avatar!,
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                                  width: 90,
                                                  height: 90,
                                                  color:
                                                      AppTheme.cardBackground,
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                            errorWidget: (_, __, ___) => Text(
                                              user.username?[0].toUpperCase() ??
                                                  user.email[0].toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          user.username?[0].toUpperCase() ??
                                              user.email[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                user.username ?? user.email.split('@')[0],
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  if (user.isAdmin) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Admin',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (user.ageVerified ?? false) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.orange.shade400,
                                            Colors.orange.shade600,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '18+',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Stats Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Cards
                          statsAsync.when(
                            data: (stats) => Column(
                              children: [
                                // Main Stats Row
                                Row(
                                  children: [
                                    _buildStatCard(
                                      icon: Icons.menu_book,
                                      label: 'Manga Read',
                                      value: '${stats['mangaRead'] ?? 0}',
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 12),
                                    _buildStatCard(
                                      icon: Icons.auto_stories,
                                      label: 'Chapters',
                                      value: '${stats['chaptersRead'] ?? 0}',
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildStatCard(
                                      icon: Icons.bookmark,
                                      label: 'Bookmarks',
                                      value: '${stats['bookmarksCount'] ?? 0}',
                                      color: AppTheme.primaryRed,
                                    ),
                                    const SizedBox(width: 12),
                                    _buildStatCard(
                                      icon: Icons.star,
                                      label: 'Ratings',
                                      value: '${stats['ratingsCount'] ?? 0}',
                                      color: Colors.amber,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Reading Streak Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryRed.withOpacity(
                                        0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryRed
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.local_fire_department,
                                          color: AppTheme.primaryRed,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Reading Streak',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '${stats['readingStreak'] ?? 0}',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.primaryRed,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'days',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (stats['longestStreak'] !=
                                                    null &&
                                                stats['longestStreak'] > 0)
                                              Text(
                                                'Best: ${stats['longestStreak']} days',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Achievements Card
                                Consumer(
                                  builder: (context, ref, child) {
                                    final progress = ref.watch(
                                      achievementProgressProvider,
                                    );
                                    return GestureDetector(
                                      onTap: () =>
                                          context.push('/achievements'),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cardBackground,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primaryRed
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryRed
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.emoji_events,
                                                color: AppTheme.primaryRed,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Achievements',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${progress['unlocked']}/${progress['total']}',
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppTheme
                                                              .primaryRed,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          child: LinearProgressIndicator(
                                                            value:
                                                                progress['progress']
                                                                    as double,
                                                            minHeight: 6,
                                                            backgroundColor:
                                                                AppTheme
                                                                    .darkBackground,
                                                            valueColor:
                                                                const AlwaysStoppedAnimation<
                                                                  Color
                                                                >(
                                                                  AppTheme
                                                                      .primaryRed,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Additional Info Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildInfoRow(
                                        Icons.trending_up,
                                        'Avg Rating Given',
                                        stats['avgRatingGiven'] != null
                                            ? (stats['avgRatingGiven'] as num)
                                                  .toStringAsFixed(1)
                                            : '0.0',
                                      ),
                                      const Divider(height: 24),
                                      _buildInfoRow(
                                        Icons.calendar_today,
                                        'Member Since',
                                        _formatDate(stats['memberSince']),
                                      ),
                                    ],
                                  ),
                                ),

                                // Recently Read Section
                                if (stats['recentlyRead'] != null &&
                                    (stats['recentlyRead'] as List)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Recently Read',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 140,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: (stats['recentlyRead'] as List)
                                          .length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final item =
                                            (stats['recentlyRead']
                                                as List)[index];
                                        final manga = item['mangaId'];
                                        if (manga == null) {
                                          return const SizedBox();
                                        }

                                        return GestureDetector(
                                          onTap: () => context.push(
                                            '/manga/${manga['_id']}',
                                          ),
                                          child: SizedBox(
                                            width: 90,
                                            child: Column(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: manga['cover'] != null
                                                      ? CachedNetworkImage(
                                                          imageUrl:
                                                              manga['cover'],
                                                          width: 90,
                                                          height: 110,
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (
                                                                context,
                                                                url,
                                                              ) => Container(
                                                                width: 90,
                                                                height: 110,
                                                                color: AppTheme
                                                                    .cardBackground,
                                                                child: const Center(
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                ),
                                                              ),
                                                          errorWidget:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => Container(
                                                                width: 90,
                                                                height: 110,
                                                                color: AppTheme
                                                                    .cardBackground,
                                                                child: const Icon(
                                                                  Icons.book,
                                                                  color: AppTheme
                                                                      .textSecondary,
                                                                ),
                                                              ),
                                                        )
                                                      : Container(
                                                          width: 90,
                                                          height: 110,
                                                          color: AppTheme
                                                              .cardBackground,
                                                          child: const Icon(
                                                            Icons.book,
                                                            color: AppTheme
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  manga['title'] ?? '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
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
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (_, __) => const SizedBox(),
                          ),

                          const SizedBox(height: 24),

                          // Menu Items
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                if (user.isAdmin)
                                  _buildMenuItem(
                                    icon: Icons.admin_panel_settings,
                                    title: 'Admin Panel',
                                    onTap: () => context.push('/admin'),
                                  ),
                                _buildMenuItem(
                                  icon: Icons.bookmark_outline,
                                  title: 'My Bookmarks',
                                  onTap: () => context.push('/bookmarks'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.emoji_events,
                                  title: 'Achievements',
                                  onTap: () => context.push('/achievements'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.analytics,
                                  title: 'Reading Analytics',
                                  onTap: () => context.push('/analytics'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.history,
                                  title: 'Reading History',
                                  onTap: () => context.push('/reading-history'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.list_alt,
                                  title: 'Reading Lists',
                                  onTap: () => context.push('/reading-lists'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.notifications_outlined,
                                  title: 'Notifications',
                                  onTap: () => context.push('/notifications'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.notification_important_outlined,
                                  title: 'Notification Preferences',
                                  onTap: () => context.push(
                                    '/notifications/preferences',
                                  ),
                                ),
                                _buildMenuItem(
                                  icon: Icons.settings,
                                  title: 'Settings',
                                  onTap: () => context.push('/settings'),
                                  showDivider: false,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Logout Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showLogoutDialog(context, ref),
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppTheme.textSecondary),
          title: Text(title),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1, indent: 56, endIndent: 16),
      ],
    );
  }
}
