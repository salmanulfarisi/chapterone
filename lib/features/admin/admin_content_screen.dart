import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'providers/admin_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/manga_card.dart';
import 'screens/add_edit_manga_screen.dart';
import 'screens/chapter_management_screen.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/api/api_service.dart';
import '../../core/constants/api_constants.dart';

class AdminContentScreen extends ConsumerStatefulWidget {
  const AdminContentScreen({super.key});

  @override
  ConsumerState<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends ConsumerState<AdminContentScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteManga(String mangaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Manga'),
        content: const Text(
          'Are you sure you want to delete this manga? This action cannot be undone.',
        ),
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
        await apiService.delete('${ApiConstants.adminManga}/$mangaId');
        CustomSnackbar.success(context, 'Manga deleted successfully');
        ref.invalidate(adminMangaListProvider);
      } catch (e) {
        CustomSnackbar.error(
          context,
          'Failed to delete manga: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text;
    // Use admin manga provider to see all manga including adult content
    final mangaList = ref.watch(
      adminMangaListProvider(
        AdminMangaQueryParams(search: query.isNotEmpty ? query : null),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search manga...',
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
          ),
        ),
      ),
      body: mangaList.when(
        data: (manga) {
          if (manga.isEmpty) {
            return EmptyState(
              title: 'No Manga Found',
              message: query.isNotEmpty
                  ? 'No manga match your search'
                  : 'No manga in database. Add your first manga!',
              icon: Icons.menu_book_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                adminMangaListProvider(
                  AdminMangaQueryParams(
                    search: query.isNotEmpty ? query : null,
                  ),
                ),
              );
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: manga.length,
              itemBuilder: (context, index) {
                final item = manga[index];
                return Stack(
                  children: [
                    MangaCard(
                      title: item.title,
                      cover: item.cover,
                      subtitle: item.status,
                      onTap: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddEditMangaScreen(manga: item.toJson()),
                              ),
                            )
                            .then((_) {
                              ref.invalidate(
                                adminMangaListProvider(
                                  AdminMangaQueryParams(
                                    search: query.isNotEmpty ? query : null,
                                  ),
                                ),
                              );
                            });
                      },
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: PopupMenuButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert, size: 16),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Manga'),
                              ],
                            ),
                            onTap: () {
                              Future.delayed(Duration.zero, () {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddEditMangaScreen(
                                              manga: item.toJson(),
                                            ),
                                      ),
                                    )
                                    .then((_) {
                                      ref.invalidate(
                                        adminMangaListProvider(
                                          AdminMangaQueryParams(
                                            search: query.isNotEmpty
                                                ? query
                                                : null,
                                          ),
                                        ),
                                      );
                                    });
                              });
                            },
                          ),
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.menu_book, size: 18),
                                SizedBox(width: 8),
                                Text('Manage Chapters'),
                              ],
                            ),
                            onTap: () {
                              Future.delayed(Duration.zero, () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChapterManagementScreen(
                                          mangaId: item.id,
                                          mangaTitle: item.title,
                                        ),
                                  ),
                                );
                              });
                            },
                          ),
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: AppTheme.primaryRed,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: AppTheme.primaryRed),
                                ),
                              ],
                            ),
                            onTap: () => _deleteManga(item.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 6,
          itemBuilder: (context, index) => const ShimmerMangaCard(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Manga',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString().contains('timeout')
                    ? 'Connection timeout. Please try again.'
                    : error.toString(),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(
                    adminMangaListProvider(
                      AdminMangaQueryParams(
                        search: _searchController.text.isNotEmpty
                            ? _searchController.text
                            : null,
                      ),
                    ),
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => const AddEditMangaScreen(),
                ),
              )
              .then((_) {
                ref.invalidate(
                  adminMangaListProvider(AdminMangaQueryParams(search: null)),
                );
              });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Manga'),
      ),
    );
  }
}
