import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api/api_service.dart';
import '../../../widgets/custom_snackbar.dart';

// Featured manga provider
final featuredMangaProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get('/admin/featured');
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    return [];
  }
});

// Search manga provider
final searchMangaProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      query,
    ) async {
      if (query.isEmpty) return [];
      final apiService = ref.watch(apiServiceProvider);
      try {
        final response = await apiService.get('/admin/manga/search?q=$query');
        return List<Map<String, dynamic>>.from(response.data);
      } catch (e) {
        return [];
      }
    });

class AdminFeaturedScreen extends ConsumerStatefulWidget {
  const AdminFeaturedScreen({super.key});

  @override
  ConsumerState<AdminFeaturedScreen> createState() =>
      _AdminFeaturedScreenState();
}

class _AdminFeaturedScreenState extends ConsumerState<AdminFeaturedScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAutoUpdating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addToFeatured(Map<String, dynamic> manga) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post(
        '/admin/featured',
        data: {'mangaId': manga['_id'], 'type': 'carousel', 'priority': 10},
      );
      ref.invalidate(featuredMangaProvider);
      if (mounted) {
        CustomSnackbar.success(context, 'Added to featured carousel');
        setState(() {
          _searchQuery = '';
          _searchController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to add to featured');
      }
    }
  }

  Future<void> _removeFromFeatured(String id) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.delete('/admin/featured/$id');
      ref.invalidate(featuredMangaProvider);
      if (mounted) {
        CustomSnackbar.success(context, 'Removed from featured');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to remove');
      }
    }
  }

  Future<void> _updatePriority(String id, int priority) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.put('/admin/featured/$id', data: {'priority': priority});
      ref.invalidate(featuredMangaProvider);
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to update priority');
      }
    }
  }

  Future<void> _autoUpdate() async {
    setState(() => _isAutoUpdating = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/admin/featured/auto-update');
      ref.invalidate(featuredMangaProvider);
      if (mounted) {
        CustomSnackbar.success(
          context,
          response.data['message'] ?? 'Auto-update complete',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to auto-update');
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final featuredAsync = ref.watch(featuredMangaProvider);
    final searchResults = ref.watch(searchMangaProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Featured Carousel'),
        actions: [
          IconButton(
            onPressed: _isAutoUpdating ? null : _autoUpdate,
            icon: _isAutoUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            tooltip: 'Auto-add recent updates',
          ),
          IconButton(
            onPressed: () => ref.invalidate(featuredMangaProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryRed,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Featured manga appears in the home carousel. Auto-added manga expires after 1 week.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search to add manga
            const Text(
              'Add Manga to Carousel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search manga to add...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),

            // Search results
            if (_searchQuery.isNotEmpty)
              searchResults.when(
                data: (results) {
                  if (results.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No results found'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final manga = results[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: manga['cover'] != null
                              ? CachedNetworkImage(
                                  imageUrl: manga['cover'],
                                  width: 40,
                                  height: 55,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 40,
                                    height: 55,
                                    color: AppTheme.cardBackground,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 40,
                                    height: 55,
                                    color: AppTheme.cardBackground,
                                    child: const Icon(Icons.book, size: 20),
                                  ),
                                )
                              : Container(
                                  width: 40,
                                  height: 55,
                                  color: AppTheme.cardBackground,
                                  child: const Icon(Icons.book, size: 20),
                                ),
                        ),
                        title: Text(
                          manga['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          manga['status'] ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: AppTheme.primaryRed,
                          ),
                          onPressed: () => _addToFeatured(manga),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Error searching'),
                ),
              ),

            const SizedBox(height: 24),

            // Current featured manga
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Carousel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                featuredAsync.maybeWhen(
                  data: (list) => Text(
                    '${list.length} items',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  orElse: () => const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            featuredAsync.when(
              data: (featuredList) {
                if (featuredList.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.featured_play_list_outlined,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No featured manga',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Search and add manga above or use auto-update',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: featuredList.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final item = featuredList[oldIndex];
                    final newPriority = featuredList.length - newIndex;
                    await _updatePriority(item['_id'], newPriority);
                  },
                  itemBuilder: (context, index) {
                    final featured = featuredList[index];
                    final manga = featured['mangaId'];
                    if (manga == null) {
                      return const SizedBox(key: ValueKey('empty'));
                    }

                    return Card(
                      key: ValueKey(featured['_id']),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.drag_handle,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: manga['cover'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: manga['cover'],
                                      width: 40,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 40,
                                        height: 55,
                                        color: AppTheme.cardBackground,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 40,
                                        height: 55,
                                        color: AppTheme.cardBackground,
                                        child: const Icon(Icons.book, size: 20),
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 55,
                                      color: AppTheme.cardBackground,
                                      child: const Icon(Icons.book, size: 20),
                                    ),
                            ),
                          ],
                        ),
                        title: Text(
                          manga['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            if (featured['isManual'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryRed.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'MANUAL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.primaryRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AUTO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              'Priority: ${featured['priority'] ?? 0}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeFromFeatured(featured['_id']),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) =>
                  const Center(child: Text('Error loading featured manga')),
            ),
          ],
        ),
      ),
    );
  }
}
