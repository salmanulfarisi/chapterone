import 'package:flutter/foundation.dart';

class AdConstants {
  // Test Ad Unit IDs - Google's test ad unit IDs for development/testing
  // These are safe to use during development and testing
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  // Production Ad Unit IDs
  // IMPORTANT: Replace these with your actual AdMob Ad Unit IDs from your AdMob account
  // Get your Ad Unit IDs from: https://apps.admob.com/
  // Format: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
  static const String bannerAdUnitId =
      'ca-app-pub-8735945956674523/5118090495'; // TODO: Replace with your production banner ad unit ID
  static const String interstitialAdUnitId =
      'ca-app-pub-8735945956674523/9615399390'; // TODO: Replace with your production interstitial ad unit ID
  static const String rewardedAdUnitId =
      'ca-app-pub-8735945956674523/2491927150'; // TODO: Replace with your production rewarded ad unit ID
  static const String nativeAdUnitId =
      'ca-app-pub-8735945956674523/1520275199'; // TODO: Replace with your production native ad unit ID

  // Ad Configuration
  // Set to false when deploying to production with real ad unit IDs
  // When true, uses Google's test ad unit IDs (safe for development)
  static const bool isTestMode =
      kDebugMode; // Automatically uses test mode in debug, production in release

  // Ad display intervals
  static const int interstitialAdInterval =
      3; // Show interstitial every N chapters
  static const int nativeAdInterval = 5; // Show native ad every N items in feed

  /// Get the appropriate ad unit ID based on test mode
  static String getBannerAdUnitId() {
    return isTestMode ? testBannerAdUnitId : bannerAdUnitId;
  }

  static String getInterstitialAdUnitId() {
    return isTestMode ? testInterstitialAdUnitId : interstitialAdUnitId;
  }

  static String getRewardedAdUnitId() {
    return isTestMode ? testRewardedAdUnitId : rewardedAdUnitId;
  }

  static String getNativeAdUnitId() {
    return isTestMode ? testNativeAdUnitId : nativeAdUnitId;
  }
}
