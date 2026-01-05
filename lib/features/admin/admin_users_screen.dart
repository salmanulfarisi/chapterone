import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../services/api/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../admin/providers/admin_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _filterRole = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.put(
        '${ApiConstants.adminUsers}/$userId',
        data: {'role': newRole},
      );
      CustomSnackbar.success(context, 'User role updated');
      ref.invalidate(adminUsersProvider);
    } catch (e) {
      CustomSnackbar.error(context, 'Failed to update role: ${e.toString()}');
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.put(
          '${ApiConstants.adminUsers}/$userId',
          data: {'isActive': false},
        );
        CustomSnackbar.success(context, 'User deactivated');
        ref.invalidate(adminUsersProvider);
      } catch (e) {
        CustomSnackbar.error(context, 'Failed to delete user: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final query = _searchController.text.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Filter: '),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'user', label: Text('Users')),
                          ButtonSegment(value: 'admin', label: Text('Admins')),
                          ButtonSegment(value: 'moderator', label: Text('Mods')),
                        ],
                        selected: {_filterRole},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _filterRole = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: usersAsync.when(
        data: (users) {
          final filteredUsers = users.where((user) {
            final matchesSearch = query.isEmpty ||
                (user['email']?.toString().toLowerCase().contains(query) ?? false) ||
                (user['username']?.toString().toLowerCase().contains(query) ?? false);
            final matchesRole = _filterRole == 'all' || user['role'] == _filterRole;
            return matchesSearch && matchesRole;
          }).toList();

          if (filteredUsers.isEmpty) {
            return EmptyState(
              title: 'No Users Found',
              message: query.isNotEmpty || _filterRole != 'all'
                  ? 'No users match your filters'
                  : 'No users in database',
              icon: Icons.people_outline,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final role = user['role'] ?? 'user';
              
              Color roleColor;
              switch (role) {
                case 'admin':
                  roleColor = Colors.red;
                  break;
                case 'moderator':
                  roleColor = Colors.orange;
                  break;
                default:
                  roleColor = Colors.blue;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: roleColor,
                    child: Text(
                      (user['username'] ?? user['email'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(user['username'] ?? 'No username'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['email'] ?? ''),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Chip(
                            label: Text(
                              role.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: roleColor.withOpacity(0.2),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          if (user['createdAt'] != null)
                            Text(
                              'Joined: ${DateTime.parse(user['createdAt']).toString().split(' ')[0]}',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      if (role != 'admin')
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.admin_panel_settings, size: 18),
                              SizedBox(width: 8),
                              Text('Make Admin'),
                            ],
                          ),
                          onTap: () => _updateUserRole(user['_id'], 'admin'),
                        ),
                      if (role != 'moderator')
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.shield, size: 18),
                              SizedBox(width: 8),
                              Text('Make Moderator'),
                            ],
                          ),
                          onTap: () => _updateUserRole(user['_id'], 'moderator'),
                        ),
                      if (role != 'user')
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.person, size: 18),
                              SizedBox(width: 8),
                              Text('Make User'),
                            ],
                          ),
                          onTap: () => _updateUserRole(user['_id'], 'user'),
                        ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: AppTheme.primaryRed),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppTheme.primaryRed)),
                          ],
                        ),
                        onTap: () => _deleteUser(user['_id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (context, index) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(),
              title: Container(
                height: 16,
                width: 100,
                color: AppTheme.cardBackground,
              ),
              subtitle: Container(
                height: 12,
                width: 200,
                margin: const EdgeInsets.only(top: 8),
                color: AppTheme.cardBackground,
              ),
            ),
          ),
        ),
        error: (error, stack) => EmptyState(
          title: 'Error Loading Users',
          message: error.toString(),
          icon: Icons.error_outline,
          onRetry: () => ref.invalidate(adminUsersProvider),
        ),
      ),
    );
  }
}
