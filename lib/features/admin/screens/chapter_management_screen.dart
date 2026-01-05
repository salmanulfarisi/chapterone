import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/api/api_service.dart';
import '../../../features/manga/providers/manga_provider.dart';

class ChapterManagementScreen extends ConsumerStatefulWidget {
  final String mangaId;
  final String mangaTitle;

  const ChapterManagementScreen({
    super.key,
    required this.mangaId,
    required this.mangaTitle,
  });

  @override
  ConsumerState<ChapterManagementScreen> createState() =>
      _ChapterManagementScreenState();
}

class _ChapterManagementScreenState
    extends ConsumerState<ChapterManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  Future<void> _deleteChapter(String chapterId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: const Text(
          'Are you sure you want to delete this chapter? This action cannot be undone.',
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
        await apiService.delete('/admin/chapters/$chapterId');
        CustomSnackbar.success(context, 'Chapter deleted successfully');
        ref.invalidate(mangaChaptersProvider(widget.mangaId));
      } catch (e) {
        CustomSnackbar.error(
          context,
          'Failed to delete chapter: ${e.toString()}',
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text;
    final chaptersAsync = ref.watch(mangaChaptersProvider(widget.mangaId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chapter Management'),
            Text(
              widget.mangaTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by chapter number...',
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
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: chaptersAsync.when(
        data: (chapters) {
          // Filter chapters by search query
          final filteredChapters = query.isNotEmpty
              ? chapters.where((ch) {
                  final number = ch.chapterNumber.toString();
                  return number.contains(query);
                }).toList()
              : chapters;

          // Sort by chapter number (descending - newest first)
          filteredChapters.sort(
            (a, b) => b.chapterNumber.compareTo(a.chapterNumber),
          );

          if (filteredChapters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    query.isNotEmpty
                        ? Icons.search_off
                        : Icons.menu_book_outlined,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    query.isNotEmpty
                        ? 'No chapters found matching "$query"'
                        : 'No chapters available for this manga',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredChapters.length,
            itemBuilder: (context, index) {
              final chapter = filteredChapters[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryRed.withOpacity(0.2),
                    child: Text(
                      '${chapter.chapterNumber}',
                      style: const TextStyle(
                        color: AppTheme.primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title ?? 'Chapter ${chapter.chapterNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.image,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${chapter.pages.length} pages',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (chapter.views != null) ...[
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.visibility,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${chapter.views} views',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      if (chapter.releaseDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(chapter.releaseDate),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
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
                        onTap: () => _deleteChapter(chapter.id),
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
                'Error loading chapters',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(mangaChaptersProvider(widget.mangaId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
