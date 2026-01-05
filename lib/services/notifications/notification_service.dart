import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../../firebase_options.dart';
import '../api/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(apiServiceProvider));
});

class NotificationService {
  final ApiService _apiService;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  NotificationService(this._apiService);

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      Logger.info(
        'Initializing notification service...',
        'NotificationService',
      );

      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        Logger.warning(
          'Firebase not initialized in notification service. Firebase should be initialized in main.dart',
          'NotificationService',
        );
        return;
      } else {
        Logger.debug(
          'Firebase already initialized (${Firebase.apps.length} app(s))',
          'NotificationService',
        );
      }

      // Initialize local notifications (for foreground messages)
      await _initializeLocalNotifications();

      // Request permission
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      Logger.debug(
        'Notification permission status: ${settings.authorizationStatus}',
        'NotificationService',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        Logger.debug('Requesting FCM token...', 'NotificationService');
        _fcmToken = await _messaging.getToken();
        Logger.debug(
          'FCM token received: ${_fcmToken != null ? 'Yes (${_fcmToken!.substring(0, 20)}...)' : 'No'}',
          'NotificationService',
        );

        if (_fcmToken != null) {
          await _saveTokenToServer(_fcmToken!);
        } else {
          Logger.warning('FCM token is null', 'NotificationService');
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          Logger.info('FCM token refreshed', 'NotificationService');
          _fcmToken = newToken;
          _saveTokenToServer(newToken);
        });

        // Handle foreground messages (when app is open)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          Logger.debug(
            'onMessage listener triggered (app in foreground) - Title: ${message.notification?.title}, Body: ${message.notification?.body}',
            'NotificationService',
          );
          _handleForegroundMessage(message);
        });

        // Handle background messages (when user taps notification)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          Logger.debug(
            'onMessageOpenedApp listener triggered (user tapped notification) - Title: ${message.notification?.title}',
            'NotificationService',
          );
          _handleBackgroundMessage(message);
        });

        // Check if app was opened from a notification
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          Logger.debug(
            'App opened from notification: ${initialMessage.notification?.title}',
            'NotificationService',
          );
          _handleBackgroundMessage(initialMessage);
        }

        Logger.info(
          'Notification service initialized successfully',
          'NotificationService',
        );
      } else {
        Logger.warning(
          'Notification permission not granted. Status: ${settings.authorizationStatus}',
          'NotificationService',
        );
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Error initializing notifications: ${e.toString()}',
        e,
        stackTrace,
        'NotificationService',
      );
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return; // Local notifications not supported on web

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        Logger.debug(
          'Local notification tapped: ${response.payload}',
          'NotificationService',
        );
        // Handle notification tap if needed
      },
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createAndroidNotificationChannels();
    }

    Logger.info('Local notifications initialized', 'NotificationService');
  }

  /// Create Android notification channels
  Future<void> _createAndroidNotificationChannels() async {
    // Create 'new_chapters' channel (matches backend)
    const newChaptersChannel = AndroidNotificationChannel(
      'new_chapters', // channel id
      'New Chapters', // channel name
      description:
          'Notifications for new manga chapters', // channel description
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Create 'engagement' channel
    const engagementChannel = AndroidNotificationChannel(
      'engagement', // channel id
      'Engagement', // channel name
      description: 'Engagement notifications', // channel description
      importance: Importance.defaultImportance,
      playSound: true,
    );

    // Create 'admin_notifications' channel for admin notifications
    const adminChannel = AndroidNotificationChannel(
      'admin_notifications', // channel id
      'Admin Notifications', // channel name
      description:
          'Admin notifications for feedback and requests', // channel description
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(newChaptersChannel);
    await androidPlugin?.createNotificationChannel(engagementChannel);
    await androidPlugin?.createNotificationChannel(adminChannel);

    Logger.info(
      'Android notification channels created (new_chapters, engagement, admin_notifications)',
      'NotificationService',
    );
  }

  /// Save FCM token to server
  Future<void> _saveTokenToServer(String token) async {
    try {
      Logger.debug('Saving FCM token to server', 'NotificationService');
      await _apiService.post(ApiConstants.userFcmToken, data: {'token': token});
      Logger.info('FCM token saved successfully', 'NotificationService');
    } catch (e) {
      Logger.error(
        'Error saving FCM token: ${e.toString()}',
        e,
        null,
        'NotificationService',
      );
      rethrow;
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    Logger.debug(
      'Foreground message received - Title: ${message.notification?.title}, Data: ${message.data}, Message ID: ${message.messageId}',
      'NotificationService',
    );

    // Show local notification when app is in foreground
    if (message.notification != null) {
      final notification = message.notification!;
      final androidDetails = message.notification?.android;
      final data = message.data;

      // Determine channel based on notification type
      String channelId = androidDetails?.channelId ?? 'new_chapters';
      String channelName = 'New Chapters';
      String channelDescription = 'Notifications for new manga chapters';

      if (data['notificationType'] == 'feedback' ||
          data['type'] == 'admin_notification') {
        channelId = 'admin_notifications';
        channelName = 'Admin Notifications';
        channelDescription = 'Admin notifications for feedback and requests';
      } else if (data['type'] == 'engagement' ||
          data['type'] == 'comment' ||
          data['type'] == 'reply') {
        channelId = 'engagement';
        channelName = 'Engagement';
        channelDescription = 'Engagement notifications';
      }

      Logger.debug(
        'Showing local notification - Title: ${notification.title}, Body: ${notification.body}, Channel: $channelId',
        'NotificationService',
      );

      try {
        await _localNotifications.show(
          message.hashCode,
          notification.title ?? 'New Notification',
          notification.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelId, // channel id
              channelName, // channel name
              channelDescription: channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
              showWhen: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );

        Logger.debug(
          'Local notification displayed successfully',
          'NotificationService',
        );
      } catch (e, stackTrace) {
        Logger.error(
          'Error showing local notification: ${e.toString()}',
          e,
          stackTrace,
          'NotificationService',
        );
      }
    } else {
      Logger.debug(
        'Message has no notification payload',
        'NotificationService',
      );
    }
  }

  /// Handle background messages (when user taps notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    Logger.debug(
      'Background message opened - Title: ${message.notification?.title}, Data: ${message.data}',
      'NotificationService',
    );
    // Navigate to chapter if needed
    final data = message.data;
    if (data['type'] == 'new_chapter' && data['mangaId'] != null) {
      Logger.debug(
        'Navigating to chapter: ${data['mangaId']}',
        'NotificationService',
      );
      // Navigation will be handled by the app router
    }
  }

  /// Get current FCM token
  String? get token => _fcmToken;

  /// Check current notification permission status
  Future<AuthorizationStatus> getPermissionStatus() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      Logger.error(
        'Error checking notification permission: ${e.toString()}',
        e,
        null,
        'NotificationService',
      );
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Request notification permission manually (for settings)
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token if permission granted
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null) {
          await _saveTokenToServer(_fcmToken!);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _saveTokenToServer(newToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

        return true;
      }
      return false;
    } catch (e) {
      Logger.error(
        'Error requesting notification permission: ${e.toString()}',
        e,
        null,
        'NotificationService',
      );
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> isNotificationEnabled() async {
    final status = await getPermissionStatus();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Test notification - send a local notification to verify setup
  Future<void> testLocalNotification() async {
    try {
      Logger.debug('Testing local notification...', 'NotificationService');
      await _localNotifications.show(
        999999,
        'Test Notification',
        'If you see this, local notifications are working!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'new_chapters',
            'New Chapters',
            channelDescription: 'Notifications for new manga chapters',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test',
      );
      Logger.info('Test notification sent', 'NotificationService');
    } catch (e) {
      Logger.error(
        'Error sending test notification: ${e.toString()}',
        e,
        null,
        'NotificationService',
      );
    }
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Note: Logger may not be available in background isolate, so we use minimal logging
    // In production, these logs won't appear but errors will be caught by Crashlytics

    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // When app is in background, FCM automatically displays notifications
    // We just need to ensure the notification channel exists
    // The notification will be shown by the system automatically

    // Note: For Android, when app is in background, FCM automatically shows
    // the notification using the channelId specified in the message.
    // No manual display needed - FCM handles it automatically.
  } catch (e) {
    // Log error - in background isolate, this will be minimal
    // Errors should be handled by Crashlytics if configured
    // Note: stackTrace not available in background isolate without proper setup
  }
}
