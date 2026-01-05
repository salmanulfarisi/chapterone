import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'services/storage/storage_service.dart';
import 'services/ads/ad_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/logging/crashlytics_service.dart';
import 'services/offline/offline_service.dart';
import 'widgets/connectivity_wrapper.dart';
import 'core/utils/logger.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with firebase_options.dart
  try {
    if (Firebase.apps.isEmpty) {
      Logger.info('Initializing Firebase with firebase_options.dart...', 'Main');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Logger.info('Firebase initialized successfully', 'Main');

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } else {
      Logger.info('Firebase already initialized', 'Main');
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e, stackTrace) {
    Logger.error(
      'Firebase initialization failed. Notifications will not work.',
      e,
      stackTrace,
      'Main',
    );
  }

  // Initialize storage
  await StorageService.init();

  // Initialize crashlytics/error logging
  try {
    await CrashlyticsService.instance.initialize();
    Logger.info('Crashlytics service initialized', 'Main');
  } catch (e) {
    Logger.warning('Failed to initialize Crashlytics: $e', 'Main');
    // Continue without crashlytics if initialization fails
  }

  // Initialize offline service
  try {
    await OfflineService.instance.initialize();
    Logger.info('Offline service initialized', 'Main');
  } catch (e) {
    Logger.warning('Failed to initialize offline service: $e', 'Main');
    // Continue without offline support if initialization fails
  }

  // Initialize ads (main revenue source)
  try {
    await AdService.instance.initialize();
    Logger.info('Ads initialized successfully', 'Main');
  } catch (e) {
    Logger.warning('Failed to initialize ads: $e', 'Main');
    // Continue without ads if initialization fails
  }


  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ChapterOne - Manga Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        // Ensure connectivity handling is inside MaterialApp so Directionality exists
        return ConnectivityWrapper(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
