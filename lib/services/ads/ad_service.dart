import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ad_constants.dart';
import '../../core/utils/logger.dart';
import '../storage/storage_service.dart';

class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _interstitialLoadAttempts = 0;
  int _rewardedLoadAttempts = 0;
  int _chapterReadCount = 0;

  // Maximum number of attempts to load an ad
  static const int maxLoadAttempts = 3;

  /// Initialize Google Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      Logger.debug('AdService initialized successfully', 'AdService');
      
      // Pre-load ads
      loadInterstitialAd();
      loadRewardedAd();
    } catch (e) {
      Logger.error('Failed to initialize AdService', e, null, 'AdService');
    }
  }

  /// Load an interstitial ad
  void loadInterstitialAd() {
    if (!_isInitialized) return;

    if (_interstitialAd != null) {
      _interstitialAd!.dispose();
      _interstitialAd = null;
    }

    InterstitialAd.load(
      adUnitId: AdConstants.getInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoadAttempts = 0;
          _interstitialAd = ad;
          _setInterstitialAdListeners(ad);
          Logger.debug('Interstitial ad loaded', 'AdService');
        },
        onAdFailedToLoad: (error) {
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          Logger.warning(
            'Failed to load interstitial ad: ${error.message}',
            'AdService',
          );
          
          // Retry loading after a delay
          if (_interstitialLoadAttempts < maxLoadAttempts) {
            Future.delayed(
              Duration(seconds: _interstitialLoadAttempts * 2),
              () => loadInterstitialAd(),
            );
          }
        },
      ),
    );
  }

  /// Set listeners for interstitial ad
  void _setInterstitialAdListeners(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        // Pre-load next ad
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        Logger.warning(
          'Failed to show interstitial ad: ${error.message}',
          'AdService',
        );
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
    );
  }

  /// Show interstitial ad if available
  Future<bool> showInterstitialAd() async {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      return true;
    }
    // Pre-load next ad
    loadInterstitialAd();
    return false;
  }

  /// Check if should show interstitial ad (based on chapter count)
  bool shouldShowInterstitialAd() {
    // Check if user has skip ads count
    final skipCount = StorageService.getSetting<int>('skip_ads_count') ?? 0;
    if (skipCount > 0) {
      // Decrement skip count
      StorageService.saveSetting('skip_ads_count', skipCount - 1);
      return false;
    }
    
    _chapterReadCount++;
    return _chapterReadCount >= AdConstants.interstitialAdInterval;
  }

  /// Reset chapter read count (call after showing ad)
  void resetChapterReadCount() {
    _chapterReadCount = 0;
  }

  /// Load a rewarded ad
  void loadRewardedAd() {
    if (!_isInitialized) return;

    if (_rewardedAd != null) {
      _rewardedAd!.dispose();
      _rewardedAd = null;
    }

    RewardedAd.load(
      adUnitId: AdConstants.getRewardedAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoadAttempts = 0;
          _rewardedAd = ad;
          _setRewardedAdListeners(ad);
          Logger.debug('Rewarded ad loaded', 'AdService');
        },
        onAdFailedToLoad: (error) {
          _rewardedLoadAttempts++;
          _rewardedAd = null;
          Logger.warning(
            'Failed to load rewarded ad: ${error.message}',
            'AdService',
          );
          
          // Retry loading after a delay
          if (_rewardedLoadAttempts < maxLoadAttempts) {
            Future.delayed(
              Duration(seconds: _rewardedLoadAttempts * 2),
              () => loadRewardedAd(),
            );
          }
        },
      ),
    );
  }

  /// Set listeners for rewarded ad
  void _setRewardedAdListeners(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        // Pre-load next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        Logger.warning(
          'Failed to show rewarded ad: ${error.message}',
          'AdService',
        );
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );
  }

  /// Show rewarded ad if available
  Future<bool> showRewardedAd({
    required Function(RewardItem) onRewarded,
    Function()? onAdDismissed,
  }) async {
    if (_rewardedAd == null) {
      // Pre-load next ad
      loadRewardedAd();
      return false;
    }

    // Use Completer to wait for reward callback
    final completer = Completer<bool>();
    bool rewardEarned = false;
    
    // Store the callback temporarily
    final currentAd = _rewardedAd!;
    
    // Override the dismiss callback if provided
    if (onAdDismissed != null) {
      final originalCallback = currentAd.fullScreenContentCallback;
      currentAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          onAdDismissed();
          if (!rewardEarned && !completer.isCompleted) {
            completer.complete(false);
          }
          if (originalCallback != null) {
            originalCallback.onAdDismissedFullScreenContent?.call(ad);
          } else {
            ad.dispose();
            _rewardedAd = null;
            loadRewardedAd();
          }
        },
        onAdFailedToShowFullScreenContent: originalCallback?.onAdFailedToShowFullScreenContent,
      );
    } else {
      // Set up dismiss callback to complete if ad is dismissed without reward
      final originalCallback = currentAd.fullScreenContentCallback;
      currentAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          if (!rewardEarned && !completer.isCompleted) {
            completer.complete(false);
          }
          if (originalCallback != null) {
            originalCallback.onAdDismissedFullScreenContent?.call(ad);
          } else {
            ad.dispose();
            _rewardedAd = null;
            loadRewardedAd();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          originalCallback?.onAdFailedToShowFullScreenContent?.call(ad, error);
        },
      );
    }
    
    currentAd.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        onRewarded(reward);
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );
    
    // Wait for either reward or dismiss (with timeout)
    try {
      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          Logger.warning('Rewarded ad timeout - assuming reward not earned', 'AdService');
          return false;
        },
      );
    } catch (e) {
      Logger.error('Error waiting for rewarded ad', e, null, 'AdService');
      return false;
    }
  }

  /// Dispose all ads
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}

// Provider for AdService
final adServiceProvider = Provider<AdService>((ref) {
  return AdService.instance;
});

