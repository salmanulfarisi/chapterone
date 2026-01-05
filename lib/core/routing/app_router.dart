import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/age_verification_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/manga/manga_detail_screen.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/reading_history_screen.dart';
import '../../features/profile/reading_lists_screen.dart';
import '../../features/profile/reading_list_detail_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/profile/detailed_statistics_screen.dart';
import '../../features/profile/achievements_screen.dart';
import '../../features/analytics/analytics_dashboard_screen.dart';
import '../../features/notifications/notification_center_screen.dart';
import '../../features/notifications/notification_preferences_screen.dart';
import '../../features/profile/terms_of_service_screen.dart';
import '../../features/profile/privacy_policy_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/bookmarks/bookmarks_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_content_screen.dart';
import '../../features/admin/admin_scraper_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_analytics_screen.dart';
import '../../features/admin/admin_logs_screen.dart';
import '../../features/admin/admin_bulk_operations_screen.dart';
import '../../features/admin/admin_notifications_screen.dart';
import '../../features/admin/admin_feedback_screen.dart';
import '../../features/admin/screens/admin_featured_screen.dart';
import '../../features/manga/manga_discussion_screen.dart';
import '../../features/adult/adult_content_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/no_internet/no_internet_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/no-internet',
      builder: (context, state) => const NoInternetScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/age-verification',
      builder: (context, state) {
        final mangaId = state.uri.queryParameters['mangaId'];
        final showAd = state.uri.queryParameters['showAd'] != 'false';
        return AgeVerificationScreen(
          mangaId: mangaId,
          showAd: showAd,
        );
      },
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/adult-content',
      builder: (context, state) => const AdultContentScreen(),
    ),
    GoRoute(
      path: '/manga/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: MangaDetailScreen(mangaId: id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/manga/:id/discussion',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MangaDiscussionScreen(mangaId: id);
      },
    ),
    GoRoute(
      path: '/reader/:chapterId',
      pageBuilder: (context, state) {
        final chapterId = state.pathParameters['chapterId']!;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: ReaderScreen(chapterId: chapterId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/reading-history',
      builder: (context, state) => const ReadingHistoryScreen(),
    ),
    GoRoute(
      path: '/reading-lists',
      builder: (context, state) => const ReadingListsScreen(),
    ),
    GoRoute(
      path: '/reading-list/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ReadingListDetailScreen(listId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        final isSetup = state.uri.queryParameters['setup'] == 'true';
        return SettingsScreen(isSetup: isSetup);
      },
    ),
    GoRoute(
      path: '/profile/statistics',
      builder: (context, state) => const DetailedStatisticsScreen(),
    ),
    GoRoute(
      path: '/achievements',
      builder: (context, state) => const AchievementsScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsDashboardScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterScreen(),
    ),
    GoRoute(
      path: '/notifications/preferences',
      builder: (context, state) => const NotificationPreferencesScreen(),
    ),
    GoRoute(
      path: '/terms-of-service',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/content',
      builder: (context, state) => const AdminContentScreen(),
    ),
    GoRoute(
      path: '/admin/scraper',
      builder: (context, state) => const AdminScraperScreen(),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const AdminUsersScreen(),
    ),
    GoRoute(
      path: '/admin/analytics',
      builder: (context, state) => const AdminAnalyticsScreen(),
    ),
    GoRoute(
      path: '/admin/featured',
      builder: (context, state) => const AdminFeaturedScreen(),
    ),
    GoRoute(
      path: '/admin/logs',
      builder: (context, state) => const AdminLogsScreen(),
    ),
    GoRoute(
      path: '/admin/bulk-operations',
      builder: (context, state) => const AdminBulkOperationsScreen(),
    ),
    GoRoute(
      path: '/admin/notifications',
      builder: (context, state) => const AdminNotificationsScreen(),
    ),
    GoRoute(
      path: '/admin/feedback',
      builder: (context, state) => const AdminFeedbackScreen(),
    ),
  ],
);
