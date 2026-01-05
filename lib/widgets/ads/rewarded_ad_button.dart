import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ads/ad_service.dart';
import '../../services/storage/storage_service.dart';
import '../../core/utils/logger.dart';

class RewardedAdButton extends ConsumerStatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onRewardEarned;
  final String? rewardMessage;
  final Color? backgroundColor;
  final Color? textColor;
  final int? requiredAdCount;
  final String? storageKey;

  const RewardedAdButton({
    super.key,
    required this.title,
    required this.icon,
    this.onRewardEarned,
    this.rewardMessage,
    this.backgroundColor,
    this.textColor,
    this.requiredAdCount,
    this.storageKey,
  });

  @override
  ConsumerState<RewardedAdButton> createState() => _RewardedAdButtonState();
}

class _RewardedAdButtonState extends ConsumerState<RewardedAdButton> {
  bool _isLoading = false;

  int _getAdsWatched() {
    if (widget.storageKey == null) return 0;
    return StorageService.getSetting<int>(
      widget.storageKey!,
      defaultValue: 0,
    ) ?? 0;
  }

  void _incrementAdsWatched() {
    if (widget.storageKey == null) return;
    final current = _getAdsWatched();
    StorageService.saveSetting(widget.storageKey!, current + 1);
  }

  Future<void> _showRewardedAd() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final adService = AdService.instance;
      final adShown = await adService.showRewardedAd(
        onRewarded: (RewardItem reward) {
          Logger.debug(
            'User earned reward: ${reward.amount} ${reward.type}',
            'RewardedAdButton',
          );
          
          // Increment ads watched count if storage key is provided
          if (widget.storageKey != null) {
            _incrementAdsWatched();
          }

          if (mounted) {
            final adsWatched = _getAdsWatched();
            final required = widget.requiredAdCount ?? 1;
            final remaining = required - adsWatched;
            
            String message = widget.rewardMessage ?? 
                'Reward earned! ${reward.amount} ${reward.type}';
            
            if (widget.requiredAdCount != null && remaining > 0) {
              message = 'Progress: $adsWatched / $required ads watched!';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          // Call the callback if provided (only when requirement is met)
          if (widget.onRewardEarned != null) {
            final adsWatched = _getAdsWatched();
            final required = widget.requiredAdCount ?? 1;
            if (adsWatched >= required) {
              widget.onRewardEarned!();
            }
          }
        },
        onAdDismissed: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );

      if (!adShown && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad is not ready yet. Please try again in a moment.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to show rewarded ad', e, null, 'RewardedAdButton');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ad: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _showRewardedAd,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(widget.icon),
      label: Text(widget.title),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor ?? AppTheme.primaryRed,
        foregroundColor: widget.textColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

