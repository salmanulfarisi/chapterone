class ApiConstants {
  // Base URL - should be loaded from .env in production

  // TODO: Replace with your actual API base URL
  static const String baseUrl = 'https://api.chapterone.live/api';

  // static const String baseUrl = String.fromEnvironment(
  //   'API_BASE_URL',
  //   defaultValue: 'http://192.168.1.104:3000/api',
  //   // defaultValue: 'http://localhost:3000/api',
  // );

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Manga endpoints
  static const String mangaList = '/manga';
  static const String mangaDetail = '/manga';
  static const String mangaChapters = '/manga';
  static const String chapterPages = '/chapter';

  // User endpoints
  static const String userProfile = '/user/profile';
  static const String userStats = '/user/stats';
  static const String readingHistory = '/user/reading-history';
  static const String readingLists = '/user/reading-lists';
  static const String userFcmToken = '/user/fcm-token';
  static const String userFeedback = '/user/feedback';
  static const String userStatistics = '/user/statistics';
  static const String userVerifyAge = '/user/verify-age';
  static const String userAgeVerification = '/user/age-verification';
  static const String chapterUnlock = '/chapter';
  static const String chapterUnlocked = '/chapter/unlocked';
  static const String bookmarks = '/bookmarks';

  // Notification endpoints
  static const String notifications = '/notifications';
  static const String notificationPreferences = '/notifications/preferences';
  static const String notificationMangaSettings =
      '/notifications/manga-settings';
  static const String notificationMarkRead = '/notifications/mark-read';
  static const String notificationMarkAllRead = '/notifications/mark-all-read';
  static const String notificationDelete = '/notifications/delete';

  // Search endpoints
  static const String search = '/search';
  static const String searchHistory = '/search/history';
  static const String savedSearches = '/search/saved';
  static const String trendingSearches = '/search/trending';

  // Recommendations endpoints
  static const String recommendations = '/recommendations';
  static const String continueReading = '/recommendations/continue-reading';
  static const String similarManga = '/recommendations/similar';
  static const String trendingByGenre = '/recommendations/trending-by-genre';
  static const String youMightLike = '/recommendations/you-might-like';

  // Comments endpoints
  static const String comments = '/comments';

  // Social endpoints
  static const String social = '/social';

  // Analytics endpoints
  static const String analyticsTrack = '/analytics/track';
  static const String analyticsDashboard = '/analytics/dashboard';
  static const String analyticsGenres = '/analytics/genres';
  static const String analyticsPatterns = '/analytics/patterns';
  static const String analyticsCompletion = '/analytics/completion';
  static const String analyticsDropoff = '/analytics/dropoff';

  // Achievements endpoints
  static const String achievements = '/achievements';
  static const String achievementsCheck = '/achievements/check';
  static const String achievementsProgress = '/achievements/progress';

  // Admin endpoints
  static const String adminManga = '/admin/manga';
  static const String adminUsers = '/admin/users';
  static const String adminStats = '/admin/stats';
  static const String adminScraper = '/admin/scraper';
  static const String adminLogs = '/admin/logs';
  static const String adminNotifications = '/admin/notifications';
  static const String adminFeedback = '/admin/feedback';

  // Admin analytics endpoints
  static const String adminUserActivity = '/admin/analytics/user-activity';
  static const String adminPopularContent = '/admin/analytics/popular-content';
  static const String adminUserRetention = '/admin/analytics/user-retention';
  static const String adminRevenue = '/admin/analytics/revenue';
  static const String adminContentPerformance =
      '/admin/analytics/content-performance';

  // Headers
  static const String authorizationHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';
  static const String contentTypeJson = 'application/json';
}
