import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../admin/providers/admin_provider.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../services/api/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../services/backend/backend_health_service.dart';
import 'screens/scraper_jobs_screen.dart';

enum ScraperType { asurascanz, asuracomic, hotcomics }

class AdminScraperScreen extends ConsumerStatefulWidget {
  const AdminScraperScreen({super.key});

  @override
  ConsumerState<AdminScraperScreen> createState() => _AdminScraperScreenState();
}

class _AdminScraperScreenState extends ConsumerState<AdminScraperScreen>
    with SingleTickerProviderStateMixin {
  ScraperType? _selectedScraper;
  int _selectedTab = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backendHealth = ref.watch(backendHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scraper Management'),
        actions: [
          // Backend status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    backendHealth.isOnline ? Icons.cloud_done : Icons.cloud_off,
                    color: backendHealth.isOnline ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    backendHealth.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: backendHealth.isOnline ? Colors.green : Colors.red,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Jobs icon
          IconButton(
            icon: const Icon(Icons.work_outline),
            tooltip: 'View All Jobs',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ScraperJobsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _selectedScraper == null
          ? _buildScraperList()
          : _buildScraperDetail(),
    );
  }

  Widget _buildScraperList() {
    final scrapers = [
      {
        'type': ScraperType.asurascanz,
        'name': 'AsuraScanz',
        'icon': Icons.menu_book,
        'color': Colors.blue,
      },
      {
        'type': ScraperType.asuracomic,
        'name': 'AsuraComic',
        'icon': Icons.menu_book,
        'color': Colors.purple,
      },
      {
        'type': ScraperType.hotcomics,
        'name': 'HotComics',
        'icon': Icons.warning_amber_rounded,
        'color': Colors.orange,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scrapers.length,
      itemBuilder: (context, index) {
        final scraper = scrapers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scraper['color'] as Color,
              child: Icon(scraper['icon'] as IconData, color: Colors.white),
            ),
            title: Text(
              scraper['name'] as String,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Tap to manage this scraper'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedScraper = scraper['type'] as ScraperType;
                _selectedTab = 0;
                _tabController.animateTo(0);
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildScraperDetail() {
    return Column(
      children: [
        // Back button and title
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedScraper = null;
                  });
                },
              ),
              Text(
                _getScraperName(_selectedScraper!),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Tabs
        Container(
          color: AppTheme.cardBackground,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.search), text: 'Search'),
              Tab(icon: Icon(Icons.monitor_heart), text: 'Monitoring'),
              Tab(icon: Icon(Icons.download_done), text: 'Imported'),
              Tab(icon: Icon(Icons.update), text: 'Updates'),
              Tab(icon: Icon(Icons.list), text: 'Results'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildSearchTab(),
              _buildMonitoringTab(),
              _buildImportedTab(),
              _buildUpdatesTab(),
              _buildResultsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return _ScraperSearchTab(scraperType: _selectedScraper!);
  }

  Widget _buildMonitoringTab() {
    return _ScraperMonitoringTab(scraperType: _selectedScraper!);
  }

  Widget _buildImportedTab() {
    return _ScraperImportedTab(scraperType: _selectedScraper!);
  }

  Widget _buildUpdatesTab() {
    return _ScraperUpdatesTab(scraperType: _selectedScraper!);
  }

  Widget _buildResultsTab() {
    return _ScraperResultsTab(scraperType: _selectedScraper!);
  }

  String _getScraperName(ScraperType type) {
    switch (type) {
      case ScraperType.asurascanz:
        return 'AsuraScanz';
      case ScraperType.asuracomic:
        return 'AsuraComic';
      case ScraperType.hotcomics:
        return 'HotComics';
    }
  }
}

// Search Tab
class _ScraperSearchTab extends ConsumerStatefulWidget {
  final ScraperType scraperType;

  const _ScraperSearchTab({required this.scraperType});

  @override
  ConsumerState<_ScraperSearchTab> createState() => _ScraperSearchTabState();
}

class _ScraperSearchTabState extends ConsumerState<_ScraperSearchTab> {
  final _searchController = TextEditingController();
  final _urlController = TextEditingController();
  String _searchQuery = '';
  bool _isUrlMode = false;
  bool _isScrapingUrl = false;

  @override
  void dispose() {
    _searchController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _scrapeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      CustomSnackbar.error(context, 'Please enter a URL');
      return;
    }

    // Validate URL format
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      CustomSnackbar.error(context, 'Please enter a valid URL (e.g., https://example.com)');
      return;
    }

    setState(() {
      _isScrapingUrl = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final scraperName = _getScraperName(widget.scraperType).toLowerCase();

      // Determine job type based on scraper
      String jobType;
      switch (widget.scraperType) {
        case ScraperType.asurascanz:
          jobType = 'asurascanz_import';
          break;
        case ScraperType.asuracomic:
          jobType = 'asuracomic_import';
          break;
        case ScraperType.hotcomics:
          jobType = 'hotcomics_import';
          break;
      }

      final response = await apiService.post(
        '${ApiConstants.adminScraper}/jobs',
        data: {'scraper': scraperName, 'url': url, 'jobType': jobType},
      );

      // Show success with job details
      final jobId = response.data['_id']?.toString() ?? '';
      final jobIdDisplay = jobId.isNotEmpty && jobId.length > 8
          ? jobId.substring(0, 8)
          : jobId;
      CustomSnackbar.show(
        context,
        message:
            'Scraping job created${jobId.isNotEmpty ? ' (ID: $jobIdDisplay...)' : ''}',
        type: SnackbarType.success,
        duration: const Duration(seconds: 3),
      );

      // Invalidate jobs provider to show new job immediately
      ref.invalidate(scrapingJobsProvider);

      _urlController.clear();

      // Navigate to jobs screen after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScraperJobsScreen()),
          );
        }
      });
    } catch (e) {
      CustomSnackbar.error(
        context,
        'Failed to create scraping job: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScrapingUrl = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    FutureProviderFamily<List<Map<String, dynamic>>, String>? searchProvider;
    if (_searchQuery.isNotEmpty && !_isUrlMode) {
      searchProvider = _getSearchProvider(widget.scraperType, _searchQuery);
    }
    final searchResults = searchProvider != null
        ? ref.watch(searchProvider(_searchQuery))
        : null;

    return Column(
      children: [
        // Toggle between search and URL mode
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Search'),
                icon: Icon(Icons.search),
              ),
              ButtonSegment(
                value: true,
                label: Text('URL Scrape'),
                icon: Icon(Icons.link),
              ),
            ],
            selected: {_isUrlMode},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                _isUrlMode = newSelection.first;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
        ),
        // Search mode
        if (!_isUrlMode) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search ${_getScraperName(widget.scraperType)}...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = _searchController.text;
                    });
                  },
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
        ] else ...[
          // URL scraping mode
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText:
                        'Enter ${_getScraperName(widget.scraperType)} manga URL...',
                    prefixIcon: const Icon(Icons.link),
                    helperText: 'Paste the full URL of the manga page',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _scrapeUrl(),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isScrapingUrl ? null : _scrapeUrl,
                  icon: _isScrapingUrl
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.scatter_plot),
                  label: Text(
                    _isScrapingUrl ? 'Creating Job...' : 'Scrape URL',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: _isUrlMode
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Enter a URL to scrape',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _searchQuery.isEmpty
              ? const Center(child: Text('Enter a search query to find manga'))
              : searchResults!.when(
                  data: (results) {
                    if (results.isEmpty) {
                      return const EmptyState(
                        title: 'No Results',
                        message: 'No manga found matching your search',
                        icon: Icons.search_off,
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final manga = results[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: manga['cover'] != null
                                ? CachedNetworkImage(
                                    imageUrl: manga['cover'].toString(),
                                    width: 50,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 50,
                                      height: 70,
                                      color: AppTheme.cardBackground,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.image),
                                  )
                                : const Icon(Icons.image),
                            title: Text(manga['title']?.toString() ?? ''),
                            subtitle: Text(
                              manga['url']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              // Create scraping job from search result
                              try {
                                final apiService = ref.read(apiServiceProvider);
                                final scraperName = _getScraperName(
                                  widget.scraperType,
                                ).toLowerCase();
                                final mangaUrl = manga['url']?.toString() ?? '';

                                if (mangaUrl.isEmpty) {
                                  CustomSnackbar.error(context, 'Invalid URL');
                                  return;
                                }

                                // Determine job type based on scraper
                                String jobType;
                                switch (widget.scraperType) {
                                  case ScraperType.asurascanz:
                                    jobType = 'asurascanz_import';
                                    break;
                                  case ScraperType.asuracomic:
                                    jobType = 'asuracomic_import';
                                    break;
                                  case ScraperType.hotcomics:
                                    jobType = 'hotcomics_import';
                                    break;
                                }

                                final response = await apiService.post(
                                  '${ApiConstants.adminScraper}/jobs',
                                  data: {
                                    'scraper': scraperName,
                                    'url': mangaUrl,
                                    'jobType': jobType,
                                    'mangaTitle': manga['title']?.toString(),
                                  },
                                );

                                // Show success with job details
                                final jobId =
                                    response.data['_id']?.toString() ?? '';
                                final jobIdDisplay = jobId.isNotEmpty && jobId.length > 8
                                    ? jobId.substring(0, 8)
                                    : jobId;
                                final mangaTitle =
                                    manga['title']?.toString() ?? 'Unknown';
                                CustomSnackbar.show(
                                  context,
                                  message:
                                      'Job created for "$mangaTitle"${jobId.isNotEmpty ? ' (ID: $jobIdDisplay...)' : ''}',
                                  type: SnackbarType.success,
                                  duration: const Duration(seconds: 3),
                                );

                                // Invalidate jobs provider to show new job immediately
                                ref.invalidate(scrapingJobsProvider);
                              } catch (e) {
                                CustomSnackbar.error(
                                  context,
                                  'Failed to create job: ${e.toString()}',
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => EmptyState(
                    title: 'Search Error',
                    message: error.toString(),
                    icon: Icons.error_outline,
                  ),
                ),
        ),
      ],
    );
  }

  String _getScraperName(ScraperType type) {
    switch (type) {
      case ScraperType.asurascanz:
        return 'AsuraScanz';
      case ScraperType.asuracomic:
        return 'AsuraComic';
      case ScraperType.hotcomics:
        return 'HotComics';
    }
  }

  FutureProviderFamily<List<Map<String, dynamic>>, String> _getSearchProvider(
    ScraperType type,
    String query,
  ) {
    switch (type) {
      case ScraperType.asurascanz:
        return asurascanzSearchProvider;
      case ScraperType.asuracomic:
        return asuracomicSearchProvider;
      case ScraperType.hotcomics:
        return hotcomicsSearchProvider;
    }
  }
}

// Monitoring Tab
class _ScraperMonitoringTab extends ConsumerWidget {
  final ScraperType scraperType;

  const _ScraperMonitoringTab({required this.scraperType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoringAsync = ref.watch(chapterMonitoringStatusProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chapter Monitoring',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  monitoringAsync.when(
                    data: (status) => Switch(
                      value: status['enabled'] == true,
                      onChanged: (value) async {
                        try {
                          final apiService = ref.read(apiServiceProvider);
                          await apiService.post(
                            '${ApiConstants.adminScraper}/monitoring/enable',
                            data: {'enabled': value},
                          );
                          ref.invalidate(chapterMonitoringStatusProvider);
                          CustomSnackbar.success(
                            context,
                            value
                                ? 'Monitoring enabled'
                                : 'Monitoring disabled',
                          );
                        } catch (e) {
                          CustomSnackbar.error(
                            context,
                            'Failed to update monitoring',
                          );
                        }
                      },
                    ),
                    loading: () => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const Icon(Icons.error, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              monitoringAsync.when(
                data: (status) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Status',
                      status['enabled'] == true ? 'Enabled' : 'Disabled',
                    ),
                    _buildInfoRow(
                      'Interval',
                      status['interval']?.toString() ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Running',
                      status['running'] == true ? 'Yes' : 'No',
                    ),
                  ],
                ),
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => Text('Error: $error'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final apiService = ref.read(apiServiceProvider);
                    await apiService.post(
                      '${ApiConstants.adminScraper}/monitoring/check',
                    );
                    CustomSnackbar.success(context, 'Manual check triggered');
                  } catch (e) {
                    CustomSnackbar.error(context, 'Failed to trigger check');
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Imported Tab
class _ScraperImportedTab extends ConsumerWidget {
  final ScraperType scraperType;

  const _ScraperImportedTab({required this.scraperType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importedManga = ref.watch(
      adminMangaListProvider(AdminMangaQueryParams(search: null)),
    );

    final sourceName = _getSourceName(scraperType);

    return importedManga.when(
      data: (mangaList) {
        // Filter by source - only show manga from the selected scraper
        final filteredManga = mangaList.where((manga) {
          return manga.source == sourceName;
        }).toList();

        if (filteredManga.isEmpty) {
          return const EmptyState(
            title: 'No Imported Manga',
            message: 'No manga imported from this scraper yet',
            icon: Icons.menu_book_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
              adminMangaListProvider(AdminMangaQueryParams(search: null)),
            );
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredManga.length,
            itemBuilder: (context, index) {
              final item = filteredManga[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: item.cover != null
                      ? CachedNetworkImage(
                          imageUrl: item.cover!,
                          width: 50,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 50,
                            height: 70,
                            color: AppTheme.cardBackground,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(Icons.image),
                        )
                      : const Icon(Icons.image),
                  title: Text(item.title),
                  subtitle: Text('Chapters: ${item.totalChapters ?? 0}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to manga detail or edit
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => EmptyState(
        title: 'Error',
        message: error.toString(),
        icon: Icons.error_outline,
      ),
    );
  }

  String _getSourceName(ScraperType type) {
    switch (type) {
      case ScraperType.asurascanz:
        return 'asurascanz';
      case ScraperType.asuracomic:
        return 'asuracomic';
      case ScraperType.hotcomics:
        return 'hotcomics';
    }
  }
}

// Updates Tab
class _ScraperUpdatesTab extends ConsumerStatefulWidget {
  final ScraperType scraperType;

  const _ScraperUpdatesTab({required this.scraperType});

  @override
  ConsumerState<_ScraperUpdatesTab> createState() => _ScraperUpdatesTabState();
}

class _ScraperUpdatesTabState extends ConsumerState<_ScraperUpdatesTab> {
  final Map<String, bool> _importingManga = {};
  final Map<String, String> _progressStatus = {}; // mangaId -> status message
  List<Map<String, dynamic>> _allMangaList = [];
  int _currentCheckingIndex = -1;
  bool _isChecking = false;

  void _refreshUpdates() {
    setState(() {
      _progressStatus.clear();
      _allMangaList.clear();
      _currentCheckingIndex = -1;
      _isChecking = false;
    });

    switch (widget.scraperType) {
      case ScraperType.asurascanz:
        ref.invalidate(asurascanzUpdatesProvider);
        break;
      case ScraperType.asuracomic:
        ref.invalidate(asuracomicUpdatesProvider);
        break;
      case ScraperType.hotcomics:
        ref.invalidate(hotcomicsUpdatesProvider);
        break;
    }
  }

  Future<void> _checkUpdatesWithProgress() async {
    if (_isChecking) return;

    if (mounted) {
      setState(() {
        _isChecking = true;
        _progressStatus.clear();
        _currentCheckingIndex = -1;
      });
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      String endpoint;
      switch (widget.scraperType) {
        case ScraperType.asurascanz:
          endpoint = '${ApiConstants.adminScraper}/asurascanz/updates';
          break;
        case ScraperType.asuracomic:
          endpoint = '${ApiConstants.adminScraper}/asuracomic/updates';
          break;
        case ScraperType.hotcomics:
          endpoint = '${ApiConstants.adminScraper}/hotcomics/updates';
          break;
      }

      // First, get the list of all imported manga
      final scraperName = _getScraperName(widget.scraperType).toLowerCase();
      final allMangaResponse = await apiService.get(
        ApiConstants.adminManga,
        queryParameters: {'source': scraperName, 'limit': '1000'},
      );

      List<dynamic> mangaData = [];
      if (allMangaResponse.data is Map &&
          allMangaResponse.data['manga'] != null) {
        mangaData = allMangaResponse.data['manga'] as List<dynamic>;
      } else if (allMangaResponse.data is List) {
        mangaData = allMangaResponse.data as List<dynamic>;
      }

      _allMangaList = mangaData.map((m) => m as Map<String, dynamic>).toList();

      if (mounted) {
        setState(() {
          _progressStatus['_total'] =
              'Found ${_allMangaList.length} $scraperName manga';
        });
      }

      // Now check updates for each manga
      final results = <Map<String, dynamic>>[];

      for (int i = 0; i < _allMangaList.length; i++) {
        final manga = _allMangaList[i];
        final mangaId = manga['_id']?.toString() ?? '';
        final mangaTitle = manga['title']?.toString() ?? 'Unknown';

        setState(() {
          _currentCheckingIndex = i;
          _progressStatus[mangaId] = 'Checking "$mangaTitle"...';
        });

        // Small delay to show progress
        await Future.delayed(const Duration(milliseconds: 100));

        try {
          // Check this specific manga for updates
          final updateResponse = await apiService.get(
            endpoint,
            queryParameters: {'mangaId': mangaId},
          );

          final updateData = updateResponse.data;
          if (updateData is Map && updateData['hasUpdates'] != null) {
            final hasUpdates = updateData['hasUpdates'] == true;
            // Try to get newChaptersCount, fallback to counting newChapters array
            final newChaptersCount = updateData['newChaptersCount'] ??
                (updateData['newChapters'] as List?)?.length ??
                0;

            if (hasUpdates && newChaptersCount > 0) {
              if (mounted) {
                setState(() {
                  _progressStatus[mangaId] =
                      'Found $newChaptersCount new chapters';
                });
              }
              results.add(updateData as Map<String, dynamic>);
            } else {
              if (mounted) {
                setState(() {
                  _progressStatus[mangaId] = 'No new chapters';
                });
              }
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _progressStatus[mangaId] = 'Error: ${e.toString()}';
            });
          }
        }

        // Small delay between checks
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (mounted) {
        setState(() {
          _isChecking = false;
          _currentCheckingIndex = -1;
          _progressStatus['_complete'] =
              'Checked ${_allMangaList.length} manga. ${results.length} have updates.';
        });
      }

      // Refresh the provider to show final results
      _refreshUpdates();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _progressStatus['_error'] = 'Error: ${e.toString()}';
        });
      }
    }
  }

  String _getScraperName(ScraperType type) {
    switch (type) {
      case ScraperType.asurascanz:
        return 'AsuraScanz';
      case ScraperType.asuracomic:
        return 'AsuraComic';
      case ScraperType.hotcomics:
        return 'HotComics';
    }
  }

  Future<void> _importUpdates(String mangaId, String mangaTitle) async {
    setState(() {
      _importingManga[mangaId] = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);

      String endpoint;
      switch (widget.scraperType) {
        case ScraperType.asurascanz:
          endpoint = '${ApiConstants.adminScraper}/asurascanz/import-updates';
          break;
        case ScraperType.asuracomic:
          endpoint = '${ApiConstants.adminScraper}/asuracomic/import-updates';
          break;
        case ScraperType.hotcomics:
          // For hotcomics, we need to fetch the manga to get its sourceUrl
          // since the backend requires a URL for HotComics jobs
          try {
            final mangaResponse = await apiService.get(
              '${ApiConstants.adminManga}/$mangaId',
            );
            final mangaData = mangaResponse.data is Map<String, dynamic>
                ? mangaResponse.data
                : <String, dynamic>{};
            final sourceUrl = mangaData['sourceUrl']?.toString() ?? '';
            
            if (sourceUrl.isEmpty) {
              throw Exception('Manga source URL not found');
            }
            
            // Create an update job with the URL
            await apiService.post(
              '${ApiConstants.adminScraper}/jobs',
              data: {
                'jobType': 'hotcomics_updates',
                'mangaId': mangaId,
                'url': sourceUrl,
                'mangaTitle': mangaTitle,
              },
            );
            CustomSnackbar.show(
              context,
              message: 'Update job created for "$mangaTitle"',
              type: SnackbarType.success,
            );
          } catch (e) {
            CustomSnackbar.error(
              context,
              'Failed to create update job: ${e.toString()}',
            );
            rethrow;
          }
          _refreshUpdates();
          return;
      }

      await apiService.post(endpoint, data: {'mangaId': mangaId});

      CustomSnackbar.show(
        context,
        message: 'New chapters imported for "$mangaTitle"',
        type: SnackbarType.success,
      );

      _refreshUpdates();
    } catch (e) {
      CustomSnackbar.error(
        context,
        'Failed to import updates: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _importingManga[mangaId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show progress view if checking
    if (_isChecking) {
      return _buildProgressView();
    }

    AsyncValue<List<Map<String, dynamic>>> updatesAsync;
    switch (widget.scraperType) {
      case ScraperType.asurascanz:
        updatesAsync = ref.watch(asurascanzUpdatesProvider);
        break;
      case ScraperType.asuracomic:
        updatesAsync = ref.watch(asuracomicUpdatesProvider);
        break;
      case ScraperType.hotcomics:
        updatesAsync = ref.watch(hotcomicsUpdatesProvider);
        break;
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshUpdates();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: updatesAsync.when(
        data: (updateList) {
          // Filter to only show manga with updates
          final updatesWithChanges = updateList
              .where((update) => update['hasUpdates'] == true)
              .toList();

          final allManga = updateList;
          final mangaWithErrors = updateList
              .where((update) => update['error'] != null)
              .toList();

          if (updateList.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EmptyState(
                  title: 'No Imported Manga',
                  message:
                      'No manga imported from this scraper yet. Import manga from the Search or Imported tab first.',
                  icon: Icons.menu_book_outlined,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _checkUpdatesWithProgress,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check for Imported Manga'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            );
          }

          // Summary header
          final totalManga = allManga.length;
          final mangaWithUpdates = updatesWithChanges.length;
          final totalNewChapters = updatesWithChanges.fold<int>(
            0,
            (sum, update) => sum + (update['newChaptersCount'] as int? ?? 0),
          );

          return Column(
            children: [
              // Summary card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: mangaWithUpdates > 0
                        ? Colors.orange.withOpacity(0.5)
                        : Colors.green.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mangaWithUpdates > 0
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        mangaWithUpdates > 0
                            ? Icons.update
                            : Icons.check_circle,
                        color: mangaWithUpdates > 0
                            ? Colors.orange
                            : Colors.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mangaWithUpdates > 0
                                ? '$mangaWithUpdates manga with new chapters'
                                : 'All up to date!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalManga total imported • $totalNewChapters new chapters available',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _checkUpdatesWithProgress,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Updates'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (mangaWithUpdates > 0) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Batch import all
                              int successCount = 0;
                              int failCount = 0;
                              for (final update in updatesWithChanges) {
                                final mangaId = update['mangaId']?.toString();
                                final mangaTitle =
                                    update['title']?.toString() ?? 'Unknown';
                                if (mangaId != null) {
                                  try {
                                    await _importUpdates(mangaId, mangaTitle);
                                    successCount++;
                                    await Future.delayed(
                                      const Duration(milliseconds: 500),
                                    );
                                  } catch (e) {
                                    failCount++;
                                    // Continue with next item even if one fails
                                  }
                                }
                              }
                              if (mounted) {
                                CustomSnackbar.show(
                                  context,
                                  message:
                                      'Batch import completed: $successCount succeeded, $failCount failed',
                                  type: failCount > 0
                                      ? SnackbarType.warning
                                      : SnackbarType.success,
                                );
                              }
                            },
                            icon: const Icon(Icons.file_download),
                            label: const Text('Import All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Show error manga if any
              if (mangaWithErrors.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${mangaWithErrors.length} manga had errors checking for updates',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (updatesWithChanges.isEmpty)
                Expanded(
                  child: Column(
                    children: [
                      const EmptyState(
                        title: 'All Up to Date',
                        message: 'All imported manga are up to date',
                        icon: Icons.check_circle_outline,
                      ),
                      // Show all imported manga count
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Total imported: ${allManga.length} manga',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: updatesWithChanges.length,
                    itemBuilder: (context, index) {
                      final update = updatesWithChanges[index];
                      final newChaptersCount =
                          update['newChaptersCount'] ??
                          (update['newChapters'] as List?)?.length ??
                          0;
                      final mangaId = update['mangaId']?.toString() ?? '';
                      final mangaTitle =
                          update['title']?.toString() ?? 'Unknown';
                      final localMax = update['localMaxChapter'] as int? ?? 0;
                      final remoteMax = update['remoteMaxChapter'] as int? ?? 0;
                      final newChapters =
                          update['newChapters'] as List<dynamic>? ?? [];
                      final isImporting = _importingManga[mangaId] ?? false;

                      return _buildUpdateCard(
                        context,
                        update: update,
                        mangaTitle: mangaTitle,
                        newChaptersCount: newChaptersCount,
                        localMax: localMax,
                        remoteMax: remoteMax,
                        newChapters: newChapters,
                        isImporting: isImporting,
                        onImport: () => _importUpdates(mangaId, mangaTitle),
                      );
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Checking ${_getScraperName(widget.scraperType)} manga for updates...',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _checkUpdatesWithProgress,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Updates with Progress'),
              ),
            ],
          ),
        ),
        error: (error, stack) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyState(
              title: 'Error',
              message: error.toString(),
              icon: Icons.error_outline,
              onRetry: () => _refreshUpdates(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _checkUpdatesWithProgress,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Updates with Progress'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressView() {
    final scraperName = _getScraperName(widget.scraperType);
    final totalManga = _allMangaList.length;
    final checkedCount = _currentCheckingIndex + 1;
    final progress = totalManga > 0 ? (checkedCount / totalManga) : 0.0;

    return Column(
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checking all $scraperName manga...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _progressStatus['_total'] ?? 'Initializing...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.cardBackground,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: $checkedCount / $totalManga',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Manga list with progress
        Expanded(
          child: _allMangaList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allMangaList.length,
                  itemBuilder: (context, index) {
                    final manga = _allMangaList[index];
                    final mangaId = manga['_id']?.toString() ?? '';
                    final mangaTitle = manga['title']?.toString() ?? 'Unknown';
                    final isCurrent = index == _currentCheckingIndex;
                    final isChecked = index < _currentCheckingIndex;
                    final status = _progressStatus[mangaId] ?? 'Pending...';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isCurrent
                          ? Colors.orange.withOpacity(0.1)
                          : isChecked
                          ? AppTheme.cardBackground
                          : Colors.grey.withOpacity(0.05),
                      child: ListTile(
                        leading: isCurrent
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : isChecked
                            ? Icon(
                                status.contains('Found')
                                    ? Icons.update
                                    : status.contains('Error')
                                    ? Icons.error
                                    : Icons.check_circle,
                                color: status.contains('Found')
                                    ? Colors.orange
                                    : status.contains('Error')
                                    ? Colors.red
                                    : Colors.green,
                              )
                            : const Icon(Icons.pending),
                        title: Text(
                          mangaTitle,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color: status.contains('Found')
                                ? Colors.orange
                                : status.contains('Error')
                                ? Colors.red
                                : AppTheme.textSecondary,
                            fontWeight: isCurrent
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Checking...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
        // Complete message
        if (_progressStatus['_complete'] != null ||
            _progressStatus['_error'] != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _progressStatus['_error'] != null
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              border: Border(
                top: BorderSide(
                  color: _progressStatus['_error'] != null
                      ? Colors.red.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _progressStatus['_error'] != null
                      ? Icons.error
                      : Icons.check_circle,
                  color: _progressStatus['_error'] != null
                      ? Colors.red
                      : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _progressStatus['_complete'] ??
                        _progressStatus['_error'] ??
                        '',
                    style: TextStyle(
                      color: _progressStatus['_error'] != null
                          ? Colors.red
                          : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_progressStatus['_error'] == null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isChecking = false;
                      });
                      _refreshUpdates();
                    },
                    child: const Text('View Results'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUpdateCard(
    BuildContext context, {
    required Map<String, dynamic> update,
    required String mangaTitle,
    required int newChaptersCount,
    required int localMax,
    required int remoteMax,
    required List<dynamic> newChapters,
    required bool isImporting,
    required VoidCallback onImport,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Show chapter details
          showDialog(
            context: context,
            builder: (context) => _ChapterDetailsDialog(
              mangaTitle: mangaTitle,
              newChapters: newChapters,
              localMax: localMax,
              remoteMax: remoteMax,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // New chapters badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$newChaptersCount NEW',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.update, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Updates Available',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Manga title
              Text(
                mangaTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Chapter range info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Chapters',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chapter $localMax',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.orange),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Available Chapters',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chapter $remoteMax',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => _ChapterDetailsDialog(
                            mangaTitle: mangaTitle,
                            newChapters: newChapters,
                            localMax: localMax,
                            remoteMax: remoteMax,
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Chapters'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isImporting ? null : onImport,
                      icon: isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        isImporting ? 'Importing...' : 'Import New Chapters',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterDetailsDialog extends StatelessWidget {
  final String mangaTitle;
  final List<dynamic> newChapters;
  final int localMax;
  final int remoteMax;

  const _ChapterDetailsDialog({
    required this.mangaTitle,
    required this.newChapters,
    required this.localMax,
    required this.remoteMax,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mangaTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${newChapters.length} new chapters available',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Chapters list
            Flexible(
              child: newChapters.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No chapter details available'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: newChapters.length,
                      itemBuilder: (context, index) {
                        final chapter = newChapters[index];
                        final chapterNum = chapter['number'] as int? ?? 0;
                        final chapterName =
                            chapter['name']?.toString() ??
                            'Chapter $chapterNum';
                        final chapterDate = chapter['date']?.toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '$chapterNum',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(chapterName),
                            subtitle: chapterDate != null
                                ? Text(
                                    'Released: $chapterDate',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Results Tab (Show scraping job results for this scraper)
class _ScraperResultsTab extends ConsumerWidget {
  final ScraperType scraperType;

  const _ScraperResultsTab({required this.scraperType});

  String _getScraperName(ScraperType type) {
    switch (type) {
      case ScraperType.asurascanz:
        return 'AsuraScanz';
      case ScraperType.asuracomic:
        return 'AsuraComic';
      case ScraperType.hotcomics:
        return 'HotComics';
    }
  }

  String _getScraperKey(ScraperType type) {
    switch (type) {
      case ScraperType.asurascanz:
        return 'asurascanz';
      case ScraperType.asuracomic:
        return 'asuracomic';
      case ScraperType.hotcomics:
        return 'hotcomics';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(scrapingJobsProvider);
    final scraperKey = _getScraperKey(scraperType);
    final scraperName = _getScraperName(scraperType);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(scrapingJobsProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: jobsAsync.when(
        data: (jobs) {
          // Filter jobs to only show jobs for this scraper
          final filteredJobs = jobs.where((job) {
            final jobType = job['jobType']?.toString().toLowerCase() ?? '';
            // Check if jobType contains the scraper key
            return jobType.contains(scraperKey);
          }).toList();

          if (filteredJobs.isEmpty) {
            return EmptyState(
              title: 'No Jobs',
              message: 'No scraping jobs found for $scraperName',
              icon: Icons.work_off,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              return _buildJobCard(context, ref, job);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          title: 'Error',
          message: error.toString(),
          icon: Icons.error_outline,
          onRetry: () => ref.invalidate(scrapingJobsProvider),
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, WidgetRef ref, Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'unknown';
    final progress = job['progress'] as Map<String, dynamic>? ?? {};
    final percentage = (progress['percentage'] as num?)?.toDouble() ?? 0.0;
    final mangaTitle = job['mangaTitle']?.toString() ?? 'Unknown';
    final error = job['error']?.toString();
    final current = progress['current'] as num? ?? 0;
    final total = progress['total'] as num? ?? 0;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'running':
        statusColor = Colors.blue;
        statusIcon = Icons.refresh;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(mangaTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (job['updatedAt'] != null)
                  Text(
                    _getTimeAgo(DateTime.parse(job['updatedAt'])),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            if (status == 'running' || status == 'pending') ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? (current / total) : (percentage / 100),
                  backgroundColor: AppTheme.cardBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                total > 0
                    ? '$current / $total (${((current / total) * 100).toStringAsFixed(1)}%)'
                    : '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: status == 'running'
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
