import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ad_constants.dart';
import '../../core/theme/app_theme.dart';

class NativeAdWidget extends ConsumerStatefulWidget {
  final double? height;
  final EdgeInsets? margin;
  final Key? adKey;

  const NativeAdWidget({
    super.key,
    this.height,
    this.margin,
    this.adKey,
  });

  @override
  ConsumerState<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends ConsumerState<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Native ads require either nativeTemplateStyle or factoryId
    // For simplicity, we'll use a template style
    _nativeAd = NativeAd(
      adUnitId: AdConstants.getNativeAdUnitId(),
      request: const AdRequest(),
      listener: NativeAdListener(
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
      nativeAdOptions: NativeAdOptions(
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
        mediaAspectRatio: MediaAspectRatio.landscape,
      ),
      // Provide a native template style for AdWidget
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: AppTheme.cardBackground,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: AppTheme.textPrimary,
          backgroundColor: AppTheme.primaryRed,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: AppTheme.textPrimary,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppTheme.textSecondary,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: AppTheme.textTertiary,
        ),
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      key: widget.adKey,
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      height: widget.height ?? 300,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textTertiary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}

