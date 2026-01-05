import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/animated_refresh_indicator.dart';
import '../../widgets/skeleton_loaders.dart';
import '../../widgets/empty_state.dart';
import 'providers/notification_provider.dart';
import '../../services/api/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../models/notification_model.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notificationsAsync.when(
            data: (notifications) {
              final unreadCount = notifications.where((n) => !n.read).length;
              if (unreadCount > 0) {
                return TextButton.icon(
                  onPressed: () => _markAllAsRead(),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all read'),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return EmptyState(
              title: 'No Notifications',
              message: 'You\'re all caught up! New notifications will appear here.',
              icon: Icons.notifications_none,
            );
          }

          final unreadNotifications = notifications.where((n) => !n.read).toList();
          final readNotifications = notifications.where((n) => n.read).toList();

          return AnimatedRefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (unreadNotifications.isNotEmpty) ...[
                  const Text(
                    'Unread',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unreadNotifications.map((notification) => _buildNotificationItem(notification)),
                  const SizedBox(height: 24),
                ],
                if (readNotifications.isNotEmpty) ...[
                  const Text(
                    'Read',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...readNotifications.map((notification) => _buildNotificationItem(notification)),
                ],
              ],
            ),
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonSearchResult(),
            ),
          ),
        ),
        error: (error, stack) => EmptyState(
          title: 'Error Loading Notifications',
          message: 'Failed to load notifications. Please try again.',
          icon: Icons.error_outline,
          onRetry: () {
            ref.invalidate(notificationsProvider);
          },
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'new_chapter':
        icon = Icons.menu_book;
        iconColor = AppTheme.primaryRed;
        break;
      case 'digest':
        icon = Icons.summarize;
        iconColor = Colors.blue;
        break;
      case 'engagement':
        icon = Icons.favorite;
        iconColor = Colors.pink;
        break;
      case 'recommendation':
        icon = Icons.star;
        iconColor = Colors.amber;
        break;
      default:
        icon = Icons.notifications;
        iconColor = AppTheme.textSecondary;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.primaryRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteNotification(notification.id),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.read
                ? AppTheme.cardBackground
                : AppTheme.cardBackground.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: notification.read
                ? null
                : Border.all(
                    color: AppTheme.primaryRed.withOpacity(0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.read
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (!notification.read) {
      _markAsRead(notification.id);
    }

    if (notification.mangaId != null) {
      if (notification.chapterId != null) {
        context.push('/reader/${notification.chapterId}');
      } else {
        context.push('/manga/${notification.mangaId}');
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.put('${ApiConstants.notificationMarkRead}/$notificationId');
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.put(ApiConstants.notificationMarkAllRead);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.delete('${ApiConstants.notificationDelete}/$notificationId');
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (e) {
      // Silently fail
    }
  }
}

