import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage/storage_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../widgets/ads/rewarded_ad_button.dart';
import '../../widgets/feedback_modal.dart';
import '../../services/ads/ad_service.dart';
import '../../features/auth/providers/auth_provider.dart';

// Settings state provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);

class SettingsState {
  final String readingMode; // 'webtoon', 'page', 'double'
  final bool autoScroll;
  final double scrollSpeed;
  final bool darkMode;

  SettingsState({
    this.readingMode = 'webtoon',
    this.autoScroll = false,
    this.scrollSpeed = 1.0,
    this.darkMode = true,
  });

  SettingsState copyWith({
    String? readingMode,
    bool? autoScroll,
    double? scrollSpeed,
    bool? darkMode,
  }) {
    return SettingsState(
      readingMode: readingMode ?? this.readingMode,
      autoScroll: autoScroll ?? this.autoScroll,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = StorageService.getPreferences();
    if (prefs != null) {
      state = SettingsState(
        readingMode: prefs['readingMode'] ?? 'webtoon',
        autoScroll: prefs['autoScroll'] ?? false,
        scrollSpeed: (prefs['scrollSpeed'] ?? 1.0).toDouble(),
        darkMode: prefs['darkMode'] ?? true,
      );
    }
  }

  Future<void> setReadingMode(String mode) async {
    state = state.copyWith(readingMode: mode);
    await _saveSettings();
  }

  Future<void> setAutoScroll(bool value) async {
    state = state.copyWith(autoScroll: value);
    await _saveSettings();
  }

  Future<void> setScrollSpeed(double value) async {
    state = state.copyWith(scrollSpeed: value);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    await StorageService.savePreferences({
      'readingMode': state.readingMode,
      'autoScroll': state.autoScroll,
      'scrollSpeed': state.scrollSpeed,
      'darkMode': state.darkMode,
    });
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  final bool isSetup;

  const SettingsScreen({super.key, this.isSetup = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh every second to update ad progress
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {});
        _startPeriodicRefresh();
      }
    });
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {});
        _startPeriodicRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSetup ? 'Setup' : 'Settings'),
        leading: widget.isSetup
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  // Mark setup as completed and go to home
                  StorageService.saveSetting('setup_completed', true);
                  final authState = ref.read(authProvider);
                  if (authState.isAuthenticated) {
                    context.go('/home');
                  } else {
                    context.go('/login');
                  }
                },
              )
            : null,
      ),
      body: widget.isSetup
          ? _buildSetupContent(context, settings, settingsNotifier)
          : _buildSettingsContent(context, settings, settingsNotifier),
    );
  }

  Widget _buildSetupContent(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier settingsNotifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryRed.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.waving_hand,
                      color: AppTheme.primaryRed,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Welcome to ChapterOne!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Let\'s set up your reading preferences to get the best experience.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Setup sections - reuse existing settings widgets
          _buildSectionHeader('Reading Preferences'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Reading Mode
                ListTile(
                  leading: const Icon(Icons.view_carousel),
                  title: const Text('Reading Mode'),
                  subtitle: Text(_getReadingModeLabel(settings.readingMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showReadingModeDialog(
                    context,
                    settings.readingMode,
                    settingsNotifier,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                // Auto Scroll
                SwitchListTile(
                  secondary: const Icon(Icons.speed),
                  title: const Text('Auto Scroll'),
                  subtitle: const Text('Automatically scroll while reading'),
                  value: settings.autoScroll,
                  activeThumbColor: AppTheme.primaryRed,
                  onChanged: (value) => settingsNotifier.setAutoScroll(value),
                ),
                if (settings.autoScroll) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: const Text('Scroll Speed'),
                    subtitle: Slider(
                      value: settings.scrollSpeed,
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      activeColor: AppTheme.primaryRed,
                      label: '${settings.scrollSpeed.toStringAsFixed(1)}x',
                      onChanged: (value) =>
                          settingsNotifier.setScrollSpeed(value),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Complete setup button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                StorageService.saveSetting('setup_completed', true);
                final authState = ref.read(authProvider);
                if (authState.isAuthenticated) {
                  context.go('/home');
                } else {
                  context.go('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Complete Setup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier settingsNotifier,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      children: [
        // Reading Settings Section
        _buildSectionHeader('Reading Settings'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Reading Mode
              ListTile(
                leading: const Icon(Icons.view_carousel),
                title: const Text('Reading Mode'),
                subtitle: Text(_getReadingModeLabel(settings.readingMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showReadingModeDialog(
                  context,
                  settings.readingMode,
                  settingsNotifier,
                ),
              ),
              const Divider(height: 1, indent: 56),
              // Auto Scroll
              SwitchListTile(
                secondary: const Icon(Icons.speed),
                title: const Text('Auto Scroll'),
                subtitle: const Text('Automatically scroll while reading'),
                value: settings.autoScroll,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: (value) => settingsNotifier.setAutoScroll(value),
              ),
              if (settings.autoScroll) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('Scroll Speed'),
                  subtitle: Slider(
                    value: settings.scrollSpeed,
                    min: 0.5,
                    max: 3.0,
                    divisions: 5,
                    activeColor: AppTheme.primaryRed,
                    label: '${settings.scrollSpeed.toStringAsFixed(1)}x',
                    onChanged: (value) =>
                        settingsNotifier.setScrollSpeed(value),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Notification Settings Section
        _buildSectionHeader('Notifications'),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, child) {
            final notificationService = ref.watch(notificationServiceProvider);
            return FutureBuilder<AuthorizationStatus>(
              future: notificationService.getPermissionStatus(),
              builder: (context, snapshot) {
                final isEnabled =
                    snapshot.data == AuthorizationStatus.authorized ||
                    snapshot.data == AuthorizationStatus.provisional;
                final status =
                    snapshot.data ?? AuthorizationStatus.notDetermined;

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          isEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: isEnabled
                              ? Colors.green
                              : AppTheme.textSecondary,
                        ),
                        title: const Text('Push Notifications'),
                        subtitle: Text(
                          _getNotificationStatusText(status),
                          style: TextStyle(
                            color: isEnabled
                                ? Colors.green
                                : AppTheme.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEnabled)
                              IconButton(
                                icon: const Icon(Icons.notifications_active),
                                color: Colors.green,
                                tooltip: 'Test notification',
                                onPressed: () async {
                                  await notificationService
                                      .testLocalNotification();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Test notification sent! Check your notification tray.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                            isEnabled
                                ? Icon(Icons.check_circle, color: Colors.green)
                                : IconButton(
                                    icon: const Icon(Icons.settings),
                                    onPressed: () async {
                                      final success = await notificationService
                                          .requestPermission();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? 'Notifications enabled successfully!'
                                                  : 'Failed to enable notifications. Please check app settings.',
                                            ),
                                            backgroundColor: success
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        );
                                        // Refresh the UI
                                        setState(() {});
                                      }
                                    },
                                  ),
                          ],
                        ),
                      ),
                      if (!isEnabled) ...[
                        const Divider(height: 1, indent: 56),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable notifications to get updates about:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildNotificationFeature(
                                'New chapters for your bookmarked manga',
                              ),
                              _buildNotificationFeature('New manga releases'),
                              _buildNotificationFeature(
                                'Comments and engagement',
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final success = await notificationService
                                  .requestPermission();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Notifications enabled successfully!'
                                          : 'Failed to enable notifications. Please enable from device settings.',
                                    ),
                                    backgroundColor: success
                                        ? Colors.green
                                        : Colors.orange,
                                    action: success
                                        ? null
                                        : SnackBarAction(
                                            label: 'Open Settings',
                                            onPressed: () {
                                              // On some platforms, you might want to open app settings
                                              // This is a placeholder - implement platform-specific code if needed
                                            },
                                          ),
                                  ),
                                );
                                setState(() {});
                              }
                            },
                            icon: const Icon(Icons.notifications),
                            label: const Text('Enable Notifications'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 24),

        // Feedback & Support Section
        _buildSectionHeader('Feedback & Support'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.book_outlined),
                title: const Text('Request Manga'),
                subtitle: const Text('Request a new manga to be added'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showFeedbackDialog(context, 'request');
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Send Feedback'),
                subtitle: const Text('Share your thoughts and suggestions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showFeedbackDialog(context, 'feedback');
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.contact_support_outlined),
                title: const Text('Contact Us'),
                subtitle: const Text('Get in touch with us'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showFeedbackDialog(context, 'contact');
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Statistics Section
        _buildSectionHeader('Statistics'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Detailed Statistics'),
            subtitle: const Text('View your reading insights and analytics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/profile/statistics');
            },
          ),
        ),

        const SizedBox(height: 24),

        // Account Section (Age Verification)
        _buildSectionHeader('Account'),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, child) {
            final authState = ref.watch(authProvider);
            final isAgeVerified = authState.user?.ageVerified ?? false;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAgeVerified
                            ? Colors.green.withOpacity(0.2)
                            : AppTheme.primaryRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isAgeVerified
                            ? Icons.verified
                            : Icons.warning_amber_rounded,
                        color: isAgeVerified
                            ? Colors.green
                            : AppTheme.primaryRed,
                        size: 20,
                      ),
                    ),
                    title: const Text('Age Verification'),
                    subtitle: Text(
                      isAgeVerified
                          ? 'You are verified to access adult content'
                          : 'Verify your age to access adult content',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: isAgeVerified
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.chevron_right),
                    onTap: isAgeVerified
                        ? null
                        : () => _navigateToAgeVerification(context, ref),
                  ),
                ),
                // Verification Ribbon
                if (isAgeVerified)
                  Positioned(
                    top: -8,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'VERIFIED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // App Info Section
        _buildSectionHeader('About'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Version'),
                trailing: const Text(
                  '1.0.0',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/terms-of-service');
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/privacy-policy');
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Premium Features Section
        _buildSectionHeader('Premium Features'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Watch Ad to Remove Ads',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final adsWatched =
                            StorageService.getSetting<int>(
                              'remove_ads_ads_watched',
                              defaultValue: 0,
                            ) ??
                            0;
                        final isRemoved =
                            StorageService.getSetting<String>(
                              'ads_removed_until',
                            ) !=
                            null;

                        // Check if ads removal is still valid
                        bool isAdsRemoved = false;
                        if (isRemoved) {
                          final expiryStr = StorageService.getSetting<String>(
                            'ads_removed_until',
                          );
                          if (expiryStr != null) {
                            try {
                              final expiryTime = DateTime.parse(expiryStr);
                              isAdsRemoved = expiryTime.isAfter(DateTime.now());
                              if (!isAdsRemoved) {
                                StorageService.saveSetting(
                                  'ads_removed_until',
                                  null,
                                );
                                StorageService.saveSetting(
                                  'remove_ads_ads_watched',
                                  0,
                                );
                              }
                            } catch (e) {
                              StorageService.saveSetting(
                                'ads_removed_until',
                                null,
                              );
                              StorageService.saveSetting(
                                'remove_ads_ads_watched',
                                0,
                              );
                            }
                          }
                        }

                        final remainingAds = 3 - adsWatched;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdsRemoved
                                  ? 'Banner ads removed for 24 hours!'
                                  : 'Watch 3 ads to remove banner ads for 24 hours',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (!isAdsRemoved && remainingAds > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBackground.withOpacity(
                                    0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Progress: $adsWatched / 3 ads',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${((adsWatched / 3) * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.amber,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: adsWatched / 3,
                                        minHeight: 6,
                                        backgroundColor: AppTheme.textTertiary
                                            .withOpacity(0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.amber,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            RewardedAdButton(
                              title: isAdsRemoved
                                  ? 'Ads Removed'
                                  : remainingAds > 0
                                  ? 'Watch Ad ($adsWatched/3)'
                                  : 'Remove Ads',
                              icon: isAdsRemoved
                                  ? Icons.check_circle
                                  : Icons.play_circle_outline,
                              rewardMessage: remainingAds > 1
                                  ? 'Progress: ${adsWatched + 1}/3 ads watched!'
                                  : 'Banner ads removed for 24 hours!',
                              backgroundColor: isAdsRemoved
                                  ? Colors.green
                                  : Colors.amber,
                              textColor: Colors.white,
                              requiredAdCount: 3,
                              storageKey: 'remove_ads_ads_watched',
                              onRewardEarned: () {
                                final expiryTime = DateTime.now().add(
                                  const Duration(hours: 24),
                                );
                                StorageService.saveSetting(
                                  'ads_removed_until',
                                  expiryTime.toIso8601String(),
                                );
                                StorageService.saveSetting(
                                  'remove_ads_ads_watched',
                                  0,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: AppTheme.primaryRed,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Unlock Premium Reader',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final adsWatched =
                            StorageService.getSetting<int>(
                              'premium_reader_ads_watched',
                              defaultValue: 0,
                            ) ??
                            0;
                        final isUnlocked =
                            StorageService.getSetting<String>(
                              'premium_unlocked_until',
                            ) !=
                            null;

                        // Check if premium is still valid
                        bool isPremiumActive = false;
                        if (isUnlocked) {
                          final expiryStr = StorageService.getSetting<String>(
                            'premium_unlocked_until',
                          );
                          if (expiryStr != null) {
                            try {
                              final expiryTime = DateTime.parse(expiryStr);
                              isPremiumActive = expiryTime.isAfter(
                                DateTime.now(),
                              );
                              if (!isPremiumActive) {
                                // Clear expired premium
                                StorageService.saveSetting(
                                  'premium_unlocked_until',
                                  null,
                                );
                              }
                            } catch (e) {
                              // Invalid date, clear it
                              StorageService.saveSetting(
                                'premium_unlocked_until',
                                null,
                              );
                            }
                          }
                        }

                        final remainingAds = 6 - adsWatched;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPremiumActive)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Premium Reader is active!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              Text(
                                'Watch 6 ads to unlock premium reader features',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Progress indicator
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBackground.withOpacity(
                                    0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Progress: $adsWatched / 6 ads',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${((adsWatched / 6) * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.primaryRed,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: adsWatched / 6,
                                        minHeight: 6,
                                        backgroundColor: AppTheme.textTertiary
                                            .withOpacity(0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppTheme.primaryRed,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            RewardedAdButton(
                              title: isPremiumActive
                                  ? 'Premium Active'
                                  : remainingAds > 0
                                  ? 'Watch Ad ($adsWatched/6)'
                                  : 'Unlock Premium',
                              icon: isPremiumActive
                                  ? Icons.check_circle
                                  : Icons.diamond_outlined,
                              rewardMessage: remainingAds > 1
                                  ? 'Progress: ${adsWatched + 1}/6 ads watched!'
                                  : 'Premium Reader unlocked for 3 days!',
                              backgroundColor: isPremiumActive
                                  ? Colors.green
                                  : AppTheme.cardBackground,
                              textColor: isPremiumActive
                                  ? Colors.white
                                  : AppTheme.primaryRed,
                              requiredAdCount: 6,
                              storageKey: 'premium_reader_ads_watched',
                              onRewardEarned: () {
                                final expiryTime = DateTime.now().add(
                                  const Duration(days: 3),
                                );
                                StorageService.saveSetting(
                                  'premium_unlocked_until',
                                  expiryTime.toIso8601String(),
                                );
                                StorageService.saveSetting(
                                  'premium_reader_ads_watched',
                                  0,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Cache Section
        _buildSectionHeader('Storage'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearCacheDialog(context),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  String _getReadingModeLabel(String mode) {
    switch (mode) {
      case 'webtoon':
        return 'Webtoon (Vertical Scroll)';
      case 'page':
        return 'Page by Page';
      case 'double':
        return 'Double Page';
      default:
        return 'Webtoon';
    }
  }

  void _showReadingModeDialog(
    BuildContext context,
    String currentMode,
    SettingsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Reading Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeOption(
              context,
              'Webtoon (Vertical Scroll)',
              'webtoon',
              currentMode,
              notifier,
            ),
            _buildModeOption(
              context,
              'Page by Page',
              'page',
              currentMode,
              notifier,
            ),
            _buildModeOption(
              context,
              'Double Page',
              'double',
              currentMode,
              notifier,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    String label,
    String value,
    String currentMode,
    SettingsNotifier notifier,
  ) {
    final isSelected = currentMode == value;
    return ListTile(
      title: Text(label),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppTheme.primaryRed : AppTheme.textSecondary,
      ),
      onTap: () {
        notifier.setReadingMode(value);
        Navigator.pop(context);
      },
    );
  }

  String _getNotificationStatusText(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'Enabled';
      case AuthorizationStatus.provisional:
        return 'Enabled (Provisional)';
      case AuthorizationStatus.denied:
        return 'Disabled - Tap to enable';
      case AuthorizationStatus.notDetermined:
        return 'Not set - Tap to enable';
    }
  }

  Widget _buildNotificationFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppTheme.primaryRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will clear all cached images and data. You may need to re-download content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (dialogContext) => FeedbackModal(type: type),
    );
  }

  Future<void> _navigateToAgeVerification(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Show rewarded ad first
    final adService = AdService.instance;
    bool adWatched = false;

    try {
      final adShown = await adService.showRewardedAd(
        onRewarded: (reward) {
          adWatched = true;
        },
        onAdDismissed: () {
          // Ad was dismissed
        },
      );

      if (adShown && adWatched) {
        // Ad was watched successfully, navigate to age verification
        if (context.mounted) {
          final result = await context.push<bool>(
            '/age-verification?showAd=false',
          );

          if (result == true && context.mounted) {
            // Age verification successful, refresh auth state
            await ref.read(authProvider.notifier).refreshUser();
          }
        }
      } else if (adShown && !adWatched) {
        // Ad was shown but not watched
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please watch the ad to proceed with age verification',
              ),
            ),
          );
        }
      } else {
        // Ad not available, proceed directly to age verification
        if (context.mounted) {
          final result = await context.push<bool>(
            '/age-verification?showAd=false',
          );

          if (result == true && context.mounted) {
            // Age verification successful, refresh auth state
            await ref.read(authProvider.notifier).refreshUser();
          }
        }
      }
    } catch (e) {
      // If ad fails, still allow age verification
      if (context.mounted) {
        final result = await context.push<bool>(
          '/age-verification?showAd=false',
        );

        if (result == true && context.mounted) {
          // Age verification successful, refresh auth state
          ref.invalidate(authProvider);
        }
      }
    }
  }
}
