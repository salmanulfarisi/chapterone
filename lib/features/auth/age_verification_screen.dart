import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/ads/ad_service.dart';
import '../auth/providers/auth_provider.dart';

class AgeVerificationScreen extends ConsumerStatefulWidget {
  final String? mangaId;
  final VoidCallback? onVerified;
  final bool showAd;

  const AgeVerificationScreen({
    super.key,
    this.mangaId,
    this.onVerified,
    this.showAd = true,
  });

  @override
  ConsumerState<AgeVerificationScreen> createState() =>
      _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends ConsumerState<AgeVerificationScreen> {
  bool _isVerifying = false;
  bool _adShown = false;
  bool _showingAd = false;

  @override
  void initState() {
    super.initState();
    // Show rewarded ad on init if needed
    if (widget.showAd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRewardedAd();
      });
    } else {
      _adShown = true; // Skip ad if already shown
    }
  }

  Future<void> _showRewardedAd() async {
    if (_showingAd || _adShown) return;

    setState(() => _showingAd = true);

    try {
      final adService = AdService.instance;
      bool adWatched = false;

      final adShown = await adService.showRewardedAd(
        onRewarded: (reward) {
          adWatched = true;
        },
        onAdDismissed: () {
          // Ad was dismissed
        },
      );

      if (adShown && adWatched) {
        setState(() {
          _adShown = true;
          _showingAd = false;
        });
      } else if (adShown && !adWatched) {
        // Ad was shown but not watched fully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please watch the ad to proceed with age verification',
              ),
            ),
          );
        }
        setState(() => _showingAd = false);
      } else {
        // Ad not available, proceed without ad
        setState(() {
          _adShown = true;
          _showingAd = false;
        });
      }
    } catch (e) {
      // If ad fails, proceed without ad
      setState(() {
        _adShown = true;
        _showingAd = false;
      });
    }
  }

  Future<void> _verifyAge() async {
    // If ad is required and not shown yet, show it first
    if (widget.showAd && !_adShown && !_showingAd) {
      await _showRewardedAd();
      if (!_adShown) {
        // Ad not watched, don't proceed
        return;
      }
    }
    if (_isVerifying) return;

    setState(() => _isVerifying = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post(ApiConstants.userVerifyAge);

      // Refresh auth state by fetching updated user data
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        CustomSnackbar.success(
          context,
          'Age verification completed successfully',
        );

        // Call callback if provided
        widget.onVerified?.call();

        // Navigate back
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to verify age: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: AppTheme.primaryRed,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'Age Verification Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                const Text(
                  'This content is restricted to users who are 18 years or older.',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'By continuing, you confirm that you are at least 18 years old.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Ad status indicator
                if (widget.showAd && !_adShown && !_showingAd)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryRed.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.primaryRed,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Watch an ad to proceed',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_showingAd)
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryRed,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading ad...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.showAd && _adShown)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Ad watched successfully',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isVerifying || (widget.showAd && !_adShown))
                        ? null
                        : _verifyAge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: AppTheme.primaryRed.withOpacity(
                        0.5,
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            widget.showAd && !_adShown
                                ? 'Watch Ad to Verify'
                                : 'I am 18+',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                TextButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop(false);
                    } else {
                      context.go('/home');
                    }
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
