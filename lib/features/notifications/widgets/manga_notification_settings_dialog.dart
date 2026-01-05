import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/notifications/smart_notification_service.dart';
import '../providers/notification_provider.dart';

class MangaNotificationSettingsDialog extends ConsumerStatefulWidget {
  final String mangaId;
  final String mangaTitle;

  const MangaNotificationSettingsDialog({
    super.key,
    required this.mangaId,
    required this.mangaTitle,
  });

  @override
  ConsumerState<MangaNotificationSettingsDialog> createState() =>
      _MangaNotificationSettingsDialogState();
}

class _MangaNotificationSettingsDialogState
    extends ConsumerState<MangaNotificationSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(
      mangaNotificationSettingsProvider(widget.mangaId),
    );
    final service = ref.read(smartNotificationServiceProvider);

    return Dialog(
      backgroundColor: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: settingsAsync.when(
        data: (settings) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notification Settings',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.mangaTitle,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive notifications for this manga'),
                value: settings.enabled,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: (value) async {
                  final updated = settings.copyWith(enabled: value);
                  await service.updateMangaSettings(widget.mangaId, updated);
                  ref.invalidate(
                    mangaNotificationSettingsProvider(widget.mangaId),
                  );
                },
              ),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text('Immediate Notifications'),
                subtitle: const Text(
                  'Get notified immediately when new chapters are released',
                ),
                value: settings.immediate,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: settings.enabled
                    ? (value) async {
                        final updated = settings.copyWith(immediate: value);
                        await service.updateMangaSettings(
                          widget.mangaId,
                          updated,
                        );
                        ref.invalidate(
                          mangaNotificationSettingsProvider(widget.mangaId),
                        );
                      }
                    : null,
              ),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text('Only New Chapters'),
                subtitle: const Text(
                  'Only notify for new chapters, not updates',
                ),
                value: settings.onlyNewChapters,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: settings.enabled
                    ? (value) async {
                        final updated = settings.copyWith(
                          onlyNewChapters: value,
                        );
                        await service.updateMangaSettings(
                          widget.mangaId,
                          updated,
                        );
                        ref.invalidate(
                          mangaNotificationSettingsProvider(widget.mangaId),
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text('Failed to load settings'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(
                    mangaNotificationSettingsProvider(widget.mangaId),
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
