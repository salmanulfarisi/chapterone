import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../widgets/custom_snackbar.dart';

class AdminBulkOperationsScreen extends ConsumerStatefulWidget {
  const AdminBulkOperationsScreen({super.key});

  @override
  ConsumerState<AdminBulkOperationsScreen> createState() =>
      _AdminBulkOperationsScreenState();
}

class _AdminBulkOperationsScreenState
    extends ConsumerState<AdminBulkOperationsScreen> {
  final List<String> _selectedMangaIds = [];
  final List<String> _selectedUserIds = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bulk Operations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Manga', icon: Icon(Icons.book)),
              Tab(text: 'Users', icon: Icon(Icons.people)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildMangaBulkOperations(), _buildUserBulkOperations()],
        ),
      ),
    );
  }

  Widget _buildMangaBulkOperations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bulk Manga Operations',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select manga from Content Management, then use these operations',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Bulk Update Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bulk Update Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Manga IDs (comma-separated)',
                      border: OutlineInputBorder(),
                      hintText: 'id1, id2, id3',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedMangaIds.clear();
                        if (value.isNotEmpty) {
                          _selectedMangaIds.addAll(
                            value
                                .split(',')
                                .map((id) => id.trim())
                                .where((id) => id.isNotEmpty),
                          );
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'New Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ongoing',
                        child: Text('Ongoing'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(value: 'hiatus', child: Text('Hiatus')),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value != null && _selectedMangaIds.isNotEmpty) {
                        await _bulkUpdateManga({'status': value});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bulk Delete
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bulk Delete Manga',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This will soft-delete (deactivate) the selected manga',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Manga IDs (comma-separated)',
                      border: OutlineInputBorder(),
                      hintText: 'id1, id2, id3',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedMangaIds.clear();
                        if (value.isNotEmpty) {
                          _selectedMangaIds.addAll(
                            value
                                .split(',')
                                .map((id) => id.trim())
                                .where((id) => id.isNotEmpty),
                          );
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedMangaIds.isEmpty || _isLoading
                          ? null
                          : () => _showBulkDeleteConfirmation(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Delete ${_selectedMangaIds.length} Manga'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBulkOperations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bulk User Operations',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select users from User Management, then use these operations',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Bulk Update Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bulk Update Users',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'User IDs (comma-separated)',
                      border: OutlineInputBorder(),
                      hintText: 'id1, id2, id3',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedUserIds.clear();
                        if (value.isNotEmpty) {
                          _selectedUserIds.addAll(
                            value
                                .split(',')
                                .map((id) => id.trim())
                                .where((id) => id.isNotEmpty),
                          );
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'New Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Activate'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Deactivate'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value != null && _selectedUserIds.isNotEmpty) {
                        await _bulkUpdateUsers({'isActive': value == 'active'});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkUpdateManga(Map<String, dynamic> updateData) async {
    if (_selectedMangaIds.isEmpty) {
      CustomSnackbar.error(context, 'Please select manga IDs');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '${ApiConstants.adminManga}/bulk-update',
        data: {'mangaIds': _selectedMangaIds, 'updateData': updateData},
      );

      if (mounted) {
        CustomSnackbar.success(
          context,
          'Updated ${response.data['modifiedCount'] ?? 0} manga',
        );
        setState(() => _selectedMangaIds.clear());
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to update manga: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _bulkUpdateUsers(Map<String, dynamic> updateData) async {
    if (_selectedUserIds.isEmpty) {
      CustomSnackbar.error(context, 'Please select user IDs');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '${ApiConstants.adminUsers}/bulk-update',
        data: {'userIds': _selectedUserIds, 'updateData': updateData},
      );

      if (mounted) {
        CustomSnackbar.success(
          context,
          'Updated ${response.data['modifiedCount'] ?? 0} users',
        );
        setState(() => _selectedUserIds.clear());
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to update users: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBulkDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Confirm Bulk Delete'),
        content: Text(
          'Are you sure you want to delete ${_selectedMangaIds.length} manga? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _bulkDeleteManga();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkDeleteManga() async {
    if (_selectedMangaIds.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        '${ApiConstants.adminManga}/bulk-delete',
        data: {'mangaIds': _selectedMangaIds},
      );

      if (mounted) {
        CustomSnackbar.success(
          context,
          'Deleted ${response.data['deletedCount'] ?? 0} manga',
        );
        setState(() => _selectedMangaIds.clear());
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to delete manga: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
