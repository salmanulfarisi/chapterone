import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_preferences_model.dart';
import '../../services/notifications/smart_notification_service.dart';
import 'providers/notification_provider.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: preferencesAsync.when(
        data: (preferences) => _buildPreferencesContent(preferences),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load preferences',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(notificationPreferencesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesContent(NotificationPreferences preferences) {
    final service = ref.read(smartNotificationServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Global toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Turn off all notifications'),
            value: preferences.enabled,
            activeThumbColor: AppTheme.primaryRed,
            onChanged: (value) async {
              final updated = preferences.copyWith(enabled: value);
              await service.updatePreferences(updated);
              ref.invalidate(notificationPreferencesProvider);
            },
          ),
        ),

        const SizedBox(height: 24),

        // Active hours
        _buildSectionHeader('Active Hours'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'When do you usually read manga?',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(24, (hour) {
                  final isSelected = preferences.activeHours.contains(hour);
                  return FilterChip(
                    label: Text('${hour.toString().padLeft(2, '0')}:00'),
                    selected: isSelected,
                    onSelected: (selected) async {
                      final newHours = List<int>.from(preferences.activeHours);
                      if (selected) {
                        newHours.add(hour);
                        newHours.sort();
                      } else {
                        newHours.remove(hour);
                      }
                      final updated = preferences.copyWith(
                        activeHours: newHours,
                      );
                      await service.updatePreferences(updated);
                      ref.invalidate(notificationPreferencesProvider);
                    },
                    selectedColor: AppTheme.primaryRed.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryRed,
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Notification types
        _buildSectionHeader('Notification Types'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('New Chapters'),
                subtitle: const Text(
                  'Get notified when new chapters are released',
                ),
                value: preferences.newChaptersEnabled,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: preferences.enabled
                    ? (value) async {
                        final updated = preferences.copyWith(
                          newChaptersEnabled: value,
                        );
                        await service.updatePreferences(updated);
                        ref.invalidate(notificationPreferencesProvider);
                      }
                    : null,
              ),
              const Divider(height: 1, indent: 16),
              SwitchListTile(
                title: const Text('Engagement'),
                subtitle: const Text(
                  'Comments, likes, and social interactions',
                ),
                value: preferences.engagementEnabled,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: preferences.enabled
                    ? (value) async {
                        final updated = preferences.copyWith(
                          engagementEnabled: value,
                        );
                        await service.updatePreferences(updated);
                        ref.invalidate(notificationPreferencesProvider);
                      }
                    : null,
              ),
              const Divider(height: 1, indent: 16),
              SwitchListTile(
                title: const Text('Recommendations'),
                subtitle: const Text('Personalized manga recommendations'),
                value: preferences.recommendationsEnabled,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: preferences.enabled
                    ? (value) async {
                        final updated = preferences.copyWith(
                          recommendationsEnabled: value,
                        );
                        await service.updatePreferences(updated);
                        ref.invalidate(notificationPreferencesProvider);
                      }
                    : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Digest settings
        _buildSectionHeader('Digest Notifications'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Digest'),
                subtitle: const Text('Receive a summary of updates'),
                value: preferences.digestEnabled,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: preferences.enabled
                    ? (value) async {
                        final updated = preferences.copyWith(
                          digestEnabled: value,
                        );
                        await service.updatePreferences(updated);
                        if (value) {
                          await service.scheduleDigest(updated);
                        }
                        ref.invalidate(notificationPreferencesProvider);
                      }
                    : null,
              ),
              if (preferences.digestEnabled) ...[
                const Divider(height: 1, indent: 16),
                ListTile(
                  title: const Text('Frequency'),
                  subtitle: Text(
                    preferences.digestFrequency == 'daily' ? 'Daily' : 'Weekly',
                  ),
                  trailing: DropdownButton<String>(
                    value: preferences.digestFrequency,
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    ],
                    onChanged: preferences.enabled
                        ? (value) async {
                            if (value != null) {
                              final updated = preferences.copyWith(
                                digestFrequency: value,
                              );
                              await service.updatePreferences(updated);
                              await service.scheduleDigest(updated);
                              ref.invalidate(notificationPreferencesProvider);
                            }
                          }
                        : null,
                  ),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  title: const Text('Digest Time'),
                  subtitle: Text(
                    '${preferences.digestTime.toString().padLeft(2, '0')}:00',
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: Slider(
                      value: preferences.digestTime.toDouble(),
                      min: 0,
                      max: 23,
                      divisions: 23,
                      label:
                          '${preferences.digestTime.toString().padLeft(2, '0')}:00',
                      activeColor: AppTheme.primaryRed,
                      onChanged: preferences.enabled
                          ? (value) async {
                              final updated = preferences.copyWith(
                                digestTime: value.toInt(),
                              );
                              await service.updatePreferences(updated);
                              await service.scheduleDigest(updated);
                              ref.invalidate(notificationPreferencesProvider);
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Smart scheduling info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryRed.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.primaryRed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Scheduling',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Notifications are automatically scheduled during your active hours for better engagement.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
}
