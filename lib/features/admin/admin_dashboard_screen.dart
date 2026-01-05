import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../admin/providers/admin_provider.dart';
import '../../services/backend/backend_health_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds for instant updates
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        ref.invalidate(adminStatsProvider);
        _startAutoRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        ref.invalidate(adminStatsProvider);
        _startAutoRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminStatsProvider);
    final backendHealth = ref.watch(backendHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          // Backend status indicator in app bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    backendHealth.isOnline ? Icons.cloud_done : Icons.cloud_off,
                    color: backendHealth.isOnline ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    backendHealth.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: backendHealth.isOnline ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backend status banner
              if (!backendHealth.isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backend is Offline',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (backendHealth.error != null)
                              Text(
                                backendHealth.error!,
                                style: TextStyle(
                                  color: Colors.red.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ref
                              .read(backendHealthProvider.notifier)
                              .checkHealth();
                        },
                        icon: Icon(Icons.refresh, size: 16),
                        label: Text('Retry'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              // Stats Cards
              statsAsync.when(
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Users',
                        value: stats['totalUsers']?.toString() ?? '0',
                        icon: Icons.people,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Manga',
                        value: stats['totalManga']?.toString() ?? '0',
                        icon: Icons.book,
                      ),
                    ),
                  ],
                ),
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => const Text('Error loading stats'),
              ),
              const SizedBox(height: 24),
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2,
                children: [
                  _ActionCard(
                    title: 'Featured Carousel',
                    icon: Icons.featured_play_list,
                    onTap: () {
                      context.push('/admin/featured');
                    },
                  ),
                  _ActionCard(
                    title: 'Content Management',
                    icon: Icons.library_books,
                    onTap: () {
                      context.push('/admin/content');
                    },
                  ),
                  _ActionCard(
                    title: 'Scraper',
                    icon: Icons.settings_ethernet,
                    onTap: () {
                      context.push('/admin/scraper');
                    },
                  ),
                  _ActionCard(
                    title: 'Users',
                    icon: Icons.people,
                    onTap: () {
                      context.push('/admin/users');
                    },
                  ),
                  _ActionCard(
                    title: 'Analytics',
                    icon: Icons.analytics,
                    onTap: () {
                      context.push('/admin/analytics');
                    },
                  ),
                  _ActionCard(
                    title: 'Activity Logs',
                    icon: Icons.history,
                    onTap: () {
                      context.push('/admin/logs');
                    },
                  ),
                  _ActionCard(
                    title: 'Bulk Operations',
                    icon: Icons.select_all,
                    onTap: () {
                      context.push('/admin/bulk-operations');
                    },
                  ),
                  _ActionCard(
                    title: 'Notifications',
                    icon: Icons.notifications_active,
                    onTap: () {
                      context.push('/admin/notifications');
                    },
                  ),
                  _ActionCard(
                    title: 'Feedback & Requests',
                    icon: Icons.feedback,
                    onTap: () {
                      context.push('/admin/feedback');
                    },
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryRed),
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

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryRed),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
