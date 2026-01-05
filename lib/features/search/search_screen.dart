import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../features/manga/providers/manga_provider.dart';
import '../../features/manga/providers/genres_provider.dart';
import '../../widgets/manga_card.dart';
import '../../services/api/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/custom_snackbar.dart';
import '../../core/utils/logger.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'providers/search_provider.dart';
import '../../models/manga_model.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchFiltersProvider = StateProvider<Map<String, dynamic>>((ref) => {});

// Search params class for proper equality comparison
class SearchParams {
  final String query;
  final Map<String, dynamic> filters;

  SearchParams({required this.query, required this.filters});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchParams &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          _mapEquals(filters, other.filters);

  @override
  int get hashCode => query.hashCode ^ _mapHashCode(filters);

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  int _mapHashCode(Map<String, dynamic> map) {
    return map.entries
        .map((e) => e.key.hashCode ^ e.value.hashCode)
        .fold(0, (a, b) => a ^ b);
  }
}

// Search provider that uses the search endpoint
final _searchProvider = FutureProvider.family<List<MangaModel>, SearchParams>((
  ref,
  params,
) async {
  final query = params.query.trim();
  if (query.isEmpty) return [];

  final filters = params.filters;
  final apiService = ref.watch(apiServiceProvider);

  try {
    final queryParams = <String, dynamic>{
      'q': query,
      'limit': '50',
      if (filters['genre'] != null) 'genre': filters['genre'],
      if (filters['status'] != null) 'status': filters['status'],
      if (filters['minRating'] != null)
        'minRating': filters['minRating'].toString(),
      if (filters['maxRating'] != null)
        'maxRating': filters['maxRating'].toString(),
      if (filters['dateFrom'] != null)
        'dateFrom': filters['dateFrom'] is DateTime
            ? (filters['dateFrom'] as DateTime).toIso8601String()
            : filters['dateFrom'].toString(),
      if (filters['dateTo'] != null)
        'dateTo': filters['dateTo'] is DateTime
            ? (filters['dateTo'] as DateTime).toIso8601String()
            : filters['dateTo'].toString(),
      if (filters['dateField'] != null) 'dateField': filters['dateField'],
    };

    final response = await apiService.get(
      ApiConstants.search,
      queryParameters: queryParams,
    );

    final List<dynamic> data = response.data is List ? response.data : [];
    final results = data.map((json) => MangaModel.fromJson(json)).toList();

    // Invalidate search history provider to refresh it immediately after search
    Future.microtask(() {
      try {
        ref.invalidate(searchHistoryProvider);
      } catch (e) {
        // Ignore errors during invalidation
      }
    });

    return results;
  } catch (e) {
    Logger.error('Failed to search', e, null, 'SearchScreen');
    return [];
  }
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String? _sortBy;
  String? _title;
  bool _initialized = false;
  int _currentTab = 0; // 0: Search, 1: History, 2: Saved, 3: Trending

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final uri = GoRouterState.of(context).uri;
      _sortBy = uri.queryParameters['sort'];
      _title = uri.queryParameters['title'];
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    ref.read(searchQueryProvider.notifier).state = query;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final filters = ref.watch(searchFiltersProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.isAuthenticated;

    final showSortedResults = _sortBy != null && query.isEmpty;
    final hasFilters = filters.isNotEmpty;

    // Use search endpoint when there's a query, otherwise use manga list
    final searchResults = query.isNotEmpty
        ? ref.watch(
            _searchProvider(
              SearchParams(query: query.trim(), filters: filters),
            ),
          )
        : ref.watch(
            mangaListProvider(
              MangaListParams(
                limit: '50',
                status: filters['status'] as String?,
                genre: filters['genre'] as String?,
                sortBy: showSortedResults
                    ? _sortBy
                    : (filters['sortBy'] as String?),
                minRating: filters['minRating']?.toString(),
                maxRating: filters['maxRating']?.toString(),
                dateFrom: filters['dateFrom']?.toString(),
                dateTo: filters['dateTo']?.toString(),
                dateField: filters['dateField'] as String?,
              ),
            ),
          );

    return DefaultTabController(
      length: isAuthenticated ? 4 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: _title != null && query.isEmpty
              ? Text(_title!)
              : TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search manga...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
          actions: [
            if (query.isNotEmpty && authState.isAuthenticated)
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                tooltip: 'Save Search',
                onPressed: () =>
                    _showSaveSearchDialog(context, ref, query, filters),
              ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _performSearch,
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showAdvancedFilterDialog(context, ref),
            ),
          ],
          bottom: isAuthenticated
              ? TabBar(
                  tabs: const [
                    Tab(text: 'Search'),
                    Tab(text: 'History'),
                    Tab(text: 'Saved'),
                    Tab(text: 'Trending'),
                  ],
                  onTap: (index) {
                    setState(() {
                      _currentTab = index;
                    });
                  },
                )
              : null,
        ),
        body: isAuthenticated && _currentTab != 0
            ? _buildTabContent(context, _currentTab)
            : _buildSearchResults(
                context,
                query,
                showSortedResults,
                searchResults,
                hasFilters,
              ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _buildSearchHistory(context);
      case 2:
        return _buildSavedSearches(context);
      case 3:
        return _buildTrendingSearches(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSearchHistory(BuildContext context) {
    final historyAsync = ref.watch(searchHistoryProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No search history',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppTheme.cardBackground,
              child: ListTile(
                leading: const Icon(Icons.history, color: AppTheme.primaryRed),
                title: Text(item.query),
                subtitle: Text(
                  '${item.resultCount} results • ${DateFormat('MMM d, y').format(item.searchedAt)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _deleteSearchHistory(context, item.id),
                ),
                onTap: () {
                  _searchController.text = item.query;
                  ref.read(searchQueryProvider.notifier).state = item.query;
                  if (item.filters != null) {
                    ref.read(searchFiltersProvider.notifier).state =
                        Map<String, dynamic>.from(item.filters!);
                  }
                  setState(() {
                    _currentTab = 0;
                  });
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Failed to load search history',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSavedSearches(BuildContext context) {
    final savedAsync = ref.watch(savedSearchesProvider);

    return savedAsync.when(
      data: (saved) {
        if (saved.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 64,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No saved searches',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save your favorite searches for quick access',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: saved.length,
          itemBuilder: (context, index) {
            final item = saved[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppTheme.cardBackground,
              child: ListTile(
                leading: const Icon(Icons.bookmark, color: AppTheme.primaryRed),
                title: Text(item.name),
                subtitle: item.query != null && item.query!.isNotEmpty
                    ? Text(
                        item.query!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteSavedSearch(context, item.id),
                ),
                onTap: () {
                  if (item.query != null) {
                    _searchController.text = item.query!;
                    ref.read(searchQueryProvider.notifier).state = item.query!;
                  }
                  if (item.filters != null) {
                    ref.read(searchFiltersProvider.notifier).state =
                        Map<String, dynamic>.from(item.filters!);
                  }
                  setState(() {
                    _currentTab = 0;
                  });
                  _performSearch();
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Failed to load saved searches',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildTrendingSearches(BuildContext context) {
    final trendingAsync = ref.watch(trendingSearchesProvider);

    return trendingAsync.when(
      data: (trending) {
        if (trending.isEmpty) {
          return Center(
            child: Text(
              'No trending searches',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trending.length,
          itemBuilder: (context, index) {
            final item = trending[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppTheme.cardBackground,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(item.query),
                subtitle: Text(
                  '${item.count} searches',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.trending_up,
                  color: AppTheme.primaryRed,
                ),
                onTap: () {
                  _searchController.text = item.query;
                  ref.read(searchQueryProvider.notifier).state = item.query;
                  setState(() {
                    _currentTab = 0;
                  });
                  _performSearch();
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          'Failed to load trending searches',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    String query,
    bool showSortedResults,
    AsyncValue<List<MangaModel>> searchResults,
    bool hasFilters,
  ) {
    // Show empty state only if no query, no filters, and no sorted results
    if (!showSortedResults && query.isEmpty && !hasFilters) {
      return _buildEmptySearchState(context);
    }

    return searchResults.when(
      data: (manga) {
        if (manga.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No results found',
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
          itemCount: manga.length,
          itemBuilder: (context, index) {
            final item = manga[index];
            return MangaCard(
              title: item.title,
              cover: item.cover,
              genre: item.genres.isNotEmpty ? item.genres.first : null,
              latestChapter: item.totalChapters,
              onTap: () {
                context.push('/manga/${item.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error searching',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    final authState = ref.watch(authProvider);
    final trendingAsync = ref.watch(trendingSearchesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (authState.isAuthenticated) ...[
            // Trending Searches Section
            const Text(
              'Trending Searches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            trendingAsync.when(
              data: (trending) {
                if (trending.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: trending.take(10).map((item) {
                    return ActionChip(
                      avatar: Icon(
                        Icons.trending_up,
                        size: 16,
                        color: AppTheme.primaryRed,
                      ),
                      label: Text(item.query),
                      onPressed: () {
                        _searchController.text = item.query;
                        ref.read(searchQueryProvider.notifier).state =
                            item.query;
                        _performSearch();
                      },
                      backgroundColor: AppTheme.cardBackground,
                      side: BorderSide(
                        color: AppTheme.primaryRed.withOpacity(0.3),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
          ],

          // Quick Filters
          const Text(
            'Quick Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Ongoing'),
                onSelected: (selected) {
                  if (selected) {
                    // Clear any existing query to use manga list provider
                    ref.read(searchQueryProvider.notifier).state = '';
                    ref.read(searchFiltersProvider.notifier).state = {
                      'status': 'ongoing',
                    };
                  }
                },
                selected: false,
              ),
              FilterChip(
                label: const Text('Completed'),
                onSelected: (selected) {
                  if (selected) {
                    // Clear any existing query to use manga list provider
                    ref.read(searchQueryProvider.notifier).state = '';
                    ref.read(searchFiltersProvider.notifier).state = {
                      'status': 'completed',
                    };
                  }
                },
                selected: false,
              ),
              FilterChip(
                label: const Text('High Rating'),
                onSelected: (selected) {
                  if (selected) {
                    // Clear any existing query to use manga list provider
                    ref.read(searchQueryProvider.notifier).state = '';
                    ref.read(searchFiltersProvider.notifier).state = {
                      'minRating': 8.0,
                    };
                  }
                },
                selected: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAdvancedFilterDialog(BuildContext context, WidgetRef ref) {
    final filters = ref.read(searchFiltersProvider);
    final genresAsync = ref.watch(genresProvider);

    String? selectedGenre = filters['genre'] as String?;
    String? selectedStatus = filters['status'] as String?;
    String? selectedSort = filters['sortBy'] as String?;
    double? minRating = filters['minRating'] != null
        ? (filters['minRating'] is double
              ? filters['minRating'] as double
              : double.tryParse(filters['minRating'].toString()))
        : null;
    double? maxRating = filters['maxRating'] != null
        ? (filters['maxRating'] is double
              ? filters['maxRating'] as double
              : double.tryParse(filters['maxRating'].toString()))
        : null;
    DateTime? dateFrom = filters['dateFrom'] != null
        ? (filters['dateFrom'] is DateTime
              ? filters['dateFrom'] as DateTime
              : DateTime.tryParse(filters['dateFrom'].toString()))
        : null;
    DateTime? dateTo = filters['dateTo'] != null
        ? (filters['dateTo'] is DateTime
              ? filters['dateTo'] as DateTime
              : DateTime.tryParse(filters['dateTo'].toString()))
        : null;
    String? dateField = filters['dateField'] as String? ?? 'createdAt';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: const Text('Advanced Filters'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Genre Filter
                  const Text(
                    'Genre',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  genresAsync.when(
                    data: (genres) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: selectedGenre == null,
                          onSelected: (selected) {
                            setDialogState(() {
                              selectedGenre = null;
                            });
                          },
                          selectedColor: AppTheme.primaryRed,
                        ),
                        ...genres.map(
                          (genre) => ChoiceChip(
                            label: Text(genre),
                            selected: selectedGenre == genre,
                            onSelected: (selected) {
                              setDialogState(() {
                                selectedGenre = selected ? genre : null;
                              });
                            },
                            selectedColor: AppTheme.primaryRed,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('Failed to load genres'),
                  ),
                  const SizedBox(height: 24),

                  // Status Filter
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: selectedStatus == null,
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedStatus = null;
                          });
                        },
                        selectedColor: AppTheme.primaryRed,
                      ),
                      ChoiceChip(
                        label: const Text('Ongoing'),
                        selected: selectedStatus == 'ongoing',
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedStatus = selected ? 'ongoing' : null;
                          });
                        },
                        selectedColor: AppTheme.primaryRed,
                      ),
                      ChoiceChip(
                        label: const Text('Completed'),
                        selected: selectedStatus == 'completed',
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedStatus = selected ? 'completed' : null;
                          });
                        },
                        selectedColor: AppTheme.primaryRed,
                      ),
                      ChoiceChip(
                        label: const Text('Hiatus'),
                        selected: selectedStatus == 'hiatus',
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedStatus = selected ? 'hiatus' : null;
                          });
                        },
                        selectedColor: AppTheme.primaryRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Rating Range
                  const Text(
                    'Rating Range',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Min Rating',
                            hintText: '0.0',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: minRating?.toString() ?? '',
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              minRating = double.tryParse(value);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Max Rating',
                            hintText: '10.0',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: maxRating?.toString() ?? '',
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              maxRating = double.tryParse(value);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date Range
                  const Text(
                    'Date Range',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: dateField,
                    decoration: const InputDecoration(
                      labelText: 'Date Field',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'createdAt',
                        child: Text('Created Date'),
                      ),
                      DropdownMenuItem(
                        value: 'updatedAt',
                        child: Text('Updated Date'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        dateField = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            dateFrom != null
                                ? DateFormat('MMM d, y').format(dateFrom!)
                                : 'From Date',
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dateFrom ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                dateFrom = picked;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            dateTo != null
                                ? DateFormat('MMM d, y').format(dateTo!)
                                : 'To Date',
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  dateTo ?? (dateFrom ?? DateTime.now()),
                              firstDate: dateFrom ?? DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                dateTo = picked;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sort By
                  const Text(
                    'Sort By',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSort ?? 'createdAt',
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'createdAt',
                        child: Text('Newest First'),
                      ),
                      DropdownMenuItem(
                        value: 'updatedAt',
                        child: Text('Recently Updated'),
                      ),
                      DropdownMenuItem(
                        value: 'totalViews',
                        child: Text('Most Views'),
                      ),
                      DropdownMenuItem(
                        value: 'rating',
                        child: Text('Highest Rated'),
                      ),
                      DropdownMenuItem(
                        value: 'title',
                        child: Text('Title A-Z'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSort = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(searchFiltersProvider.notifier).state = {};
                Navigator.pop(dialogContext);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newFilters = <String, dynamic>{};
                if (selectedGenre != null) newFilters['genre'] = selectedGenre;
                if (selectedStatus != null) {
                  newFilters['status'] = selectedStatus;
                }
                if (selectedSort != null) newFilters['sortBy'] = selectedSort;
                if (minRating != null) newFilters['minRating'] = minRating;
                if (maxRating != null) newFilters['maxRating'] = maxRating;
                if (dateFrom != null) {
                  newFilters['dateFrom'] = dateFrom!.toIso8601String();
                }
                if (dateTo != null) {
                  newFilters['dateTo'] = dateTo!.toIso8601String();
                }
                if (dateField != null) newFilters['dateField'] = dateField;

                ref.read(searchFiltersProvider.notifier).state = newFilters;
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSearchHistory(BuildContext context, String id) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      await apiService.delete('${ApiConstants.searchHistory}/$id');
      ref.invalidate(searchHistoryProvider);
      if (mounted) {
        CustomSnackbar.success(context, 'Search history deleted');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to delete search history');
      }
    }
  }

  Future<void> _deleteSavedSearch(BuildContext context, String id) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      await apiService.delete('${ApiConstants.savedSearches}/$id');
      ref.invalidate(savedSearchesProvider);
      if (mounted) {
        CustomSnackbar.success(context, 'Saved search deleted');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to delete saved search');
      }
    }
  }

  Future<void> _showSaveSearchDialog(
    BuildContext context,
    WidgetRef ref,
    String query,
    Map<String, dynamic> filters,
  ) async {
    final nameController = TextEditingController(text: query);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Save Search'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Search Name',
            hintText: 'Enter a name for this search',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final apiService = ref.read(apiServiceProvider);
      try {
        await apiService.post(
          ApiConstants.savedSearches,
          data: {'name': result, 'query': query, 'filters': filters},
        );
        ref.invalidate(savedSearchesProvider);
        if (mounted) {
          CustomSnackbar.success(context, 'Search saved successfully');
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.error(context, 'Failed to save search');
        }
      }
    }
  }
}
