import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../widgets/manga_card.dart';
import '../../models/manga_model.dart';

// Reading lists provider
final readingListsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.readingLists);
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    return [];
  }
});

class ReadingListsScreen extends ConsumerStatefulWidget {
  const ReadingListsScreen({super.key});

  @override
  ConsumerState<ReadingListsScreen> createState() => _ReadingListsScreenState();
}

class _ReadingListsScreenState extends ConsumerState<ReadingListsScreen> {
  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(readingListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateListDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(readingListsProvider),
          ),
        ],
      ),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list_alt,
                    size: 80,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No reading lists',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a list to organize your manga',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateListDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              final mangaList = list['mangaIds'] as List<dynamic>? ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => context.push('/reading-list/${list['_id']}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        list['name'] ?? 'Untitled List',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (list['isPublic'] == true) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.public,
                                          size: 16,
                                          color: AppTheme.primaryRed,
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (list['description'] != null &&
                                      list['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        list['description'],
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Text('Edit'),
                                  onTap: () =>
                                      _showEditListDialog(context, ref, list),
                                ),
                                PopupMenuItem(
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onTap: () => _showDeleteDialog(
                                    context,
                                    ref,
                                    list['_id'],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${mangaList.length} manga',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (mangaList.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: mangaList.length > 5
                                  ? 5
                                  : mangaList.length,
                              itemBuilder: (context, idx) {
                                final manga = mangaList[idx];
                                try {
                                  final mangaModel = MangaModel.fromJson(manga);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: MangaCard(
                                      title: mangaModel.title,
                                      cover: mangaModel.cover,
                                      genre: mangaModel.genres.isNotEmpty
                                          ? mangaModel.genres.first
                                          : null,
                                      latestChapter: mangaModel.totalChapters,
                                      onTap: () => context.push(
                                        '/manga/${mangaModel.id}',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                          ),
                          if (mangaList.length > 5)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () => context.push(
                                  '/reading-list/${list['_id']}',
                                ),
                                child: Text(
                                  'View all ${mangaList.length} manga',
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading lists')),
      ),
    );
  }

  void _showCreateListDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: const Text('Create Reading List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'List Name *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Make Public'),
                subtitle: const Text('Others can view this list'),
                value: isPublic,
                onChanged: (value) => setDialogState(() => isPublic = value),
                activeThumbColor: AppTheme.primaryRed,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('List name is required')),
                  );
                  return;
                }

                try {
                  final apiService = ref.read(apiServiceProvider);
                  await apiService.post(
                    ApiConstants.readingLists,
                    data: {
                      'name': nameController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'isPublic': isPublic,
                    },
                  );
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ref.invalidate(readingListsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('List created')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create list: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditListDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> list,
  ) {
    final nameController = TextEditingController(text: list['name'] ?? '');
    final descriptionController = TextEditingController(
      text: list['description'] ?? '',
    );
    bool isPublic = list['isPublic'] == true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: const Text('Edit Reading List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'List Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Make Public'),
                value: isPublic,
                onChanged: (value) => setDialogState(() => isPublic = value),
                activeThumbColor: AppTheme.primaryRed,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('List name is required')),
                  );
                  return;
                }

                try {
                  final apiService = ref.read(apiServiceProvider);
                  await apiService.put(
                    '${ApiConstants.readingLists}/${list['_id']}',
                    data: {
                      'name': nameController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'isPublic': isPublic,
                    },
                  );
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ref.invalidate(readingListsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('List updated')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update list: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String listId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Delete List?'),
        content: const Text('This will permanently delete this reading list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.delete('${ApiConstants.readingLists}/$listId');
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ref.invalidate(readingListsProvider);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('List deleted')));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete list: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
