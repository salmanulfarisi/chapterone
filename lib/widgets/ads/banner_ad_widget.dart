import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ad_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage/storage_service.dart';

class BannerAdWidget extends ConsumerStatefulWidget {
  final AdSize? adSize;
  final EdgeInsets? margin;

  const BannerAdWidget({
    super.key,
    this.adSize,
    this.margin,
  });

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdConstants.getBannerAdUnitId(),
      size: widget.adSize ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // Retry after delay
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadAd();
            }
          });
        },
        onAdOpened: (_) {},
        onAdClosed: (_) {
          // Reload ad after it's closed
          _loadAd();
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  bool _areAdsRemoved() {
    final expiryStr = StorageService.getSetting<String>('ads_removed_until');
    if (expiryStr == null) return false;
    
    try {
      final expiryTime = DateTime.parse(expiryStr);
      final isActive = expiryTime.isAfter(DateTime.now());
      if (!isActive) {
        // Clear expired setting
        StorageService.saveSetting('ads_removed_until', null);
      }
      return isActive;
    } catch (e) {
      // Invalid date, clear it
      StorageService.saveSetting('ads_removed_until', null);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if ads are removed
    if (_areAdsRemoved()) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.only(bottom: 8),
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

