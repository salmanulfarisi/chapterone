import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api/api_service.dart';
import '../../widgets/custom_snackbar.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _userIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _sendTestNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      CustomSnackbar.error(context, 'Please fill in title and body');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final userId = _userIdController.text.trim();

      if (userId.isEmpty) {
        // Send to all users (bulk notification)
        final response = await apiService.post(
          '/admin/notifications/send-bulk',
          data: {'title': _titleController.text, 'body': _bodyController.text},
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          CustomSnackbar.success(
            context,
            'Notification sent to all users successfully!',
          );
          _titleController.clear();
          _bodyController.clear();
        }
      } else {
        // Send to specific user
        final response = await apiService.post(
          '/admin/notifications/send',
          data: {
            'userId': userId,
            'title': _titleController.text,
            'body': _bodyController.text,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          CustomSnackbar.success(context, 'Notification sent successfully!');
          _titleController.clear();
          _bodyController.clear();
          _userIdController.clear();
        }
      }
    } catch (e) {
      CustomSnackbar.error(
        context,
        'Failed to send notification: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Manager')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryRed,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send push notifications to users. Leave User ID empty to send to all users.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Notification Form
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
                    'Send Notification',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User ID (Optional)
                  TextField(
                    controller: _userIdController,
                    decoration: InputDecoration(
                      labelText:
                          'User ID (Optional - leave empty for all users)',
                      hintText: 'Enter user ID or leave empty',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBackground,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Enter notification title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBackground,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Body
                  TextField(
                    controller: _bodyController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Message *',
                      hintText: 'Enter notification message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBackground,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Send Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendTestNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send),
                                SizedBox(width: 8),
                                Text(
                                  'Send Notification',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.new_releases),
                    title: const Text('New Chapter Template'),
                    subtitle: const Text(
                      'Template for new chapter notifications',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _titleController.text = 'New Chapter Available!';
                      _bodyController.text =
                          'A new chapter has been added to your bookmarked manga';
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.book),
                    title: const Text('New Manga Template'),
                    subtitle: const Text(
                      'Template for new manga notifications',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _titleController.text = 'New Manga Added!';
                      _bodyController.text =
                          'A new manga has been added to the library';
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.campaign),
                    title: const Text('Announcement Template'),
                    subtitle: const Text('Template for general announcements'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _titleController.text = 'Announcement';
                      _bodyController.text =
                          'We have an important announcement for you';
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
