import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../widgets/manga_card.dart';
import '../../models/manga_model.dart';

// Reading list detail provider
final readingListDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, listId) async {
      final apiService = ref.watch(apiServiceProvider);
      try {
        final response = await apiService.get(
          '${ApiConstants.readingLists}/$listId',
        );
        return Map<String, dynamic>.from(response.data);
      } catch (e) {
        return null;
      }
    });

class ReadingListDetailScreen extends ConsumerWidget {
  final String listId;

  const ReadingListDetailScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(readingListDetailProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: listAsync.when(
          data: (list) => Text(list?['name'] ?? 'Reading List'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Reading List'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMangaDialog(context, ref),
          ),
        ],
      ),
      body: listAsync.when(
        data: (list) {
          if (list == null) {
            return const Center(child: Text('List not found'));
          }

          final mangaList = list['mangaIds'] as List<dynamic>? ?? [];

          if (mangaList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 80,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No manga in this list',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add manga to organize your reading',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: mangaList.length,
            itemBuilder: (context, index) {
              final manga = mangaList[index];
              try {
                final mangaModel = MangaModel.fromJson(manga);
                return Stack(
                  children: [
                    MangaCard(
                      title: mangaModel.title,
                      cover: mangaModel.cover,
                      genre: mangaModel.genres.isNotEmpty
                          ? mangaModel.genres.first
                          : null,
                      latestChapter: mangaModel.totalChapters,
                      onTap: () => context.push('/manga/${mangaModel.id}'),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.white,
                        onPressed: () =>
                            _removeMangaFromList(context, ref, mangaModel.id),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(4),
                          minimumSize: const Size(24, 24),
                        ),
                      ),
                    ),
                  ],
                );
              } catch (e) {
                return const SizedBox.shrink();
              }
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading list')),
      ),
    );
  }

  void _showAddMangaDialog(BuildContext context, WidgetRef ref) {
    // Navigate to search with a callback to add to list
    context.push('/search?addToList=$listId');
  }

  void _removeMangaFromList(
    BuildContext context,
    WidgetRef ref,
    String mangaId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Remove from List?'),
        content: const Text('This manga will be removed from this list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.delete(
                  '${ApiConstants.readingLists}/$listId/manga/$mangaId',
                );
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ref.invalidate(readingListDetailProvider(listId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Removed from list')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
