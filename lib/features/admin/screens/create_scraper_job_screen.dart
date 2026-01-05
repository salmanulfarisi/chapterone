import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../admin/providers/admin_provider.dart';

class CreateScraperJobScreen extends ConsumerStatefulWidget {
  const CreateScraperJobScreen({super.key});

  @override
  ConsumerState<CreateScraperJobScreen> createState() =>
      _CreateScraperJobScreenState();
}

class _CreateScraperJobScreenState
    extends ConsumerState<CreateScraperJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  String? _selectedScraper;
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Scraping Job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scraper Selection
              Text(
                'Select Scraper',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final sourcesAsync = ref.watch(scraperSourcesProvider);

                  // Default scrapers if API returns empty
                  final defaultScrapers = [
                    {'name': 'asurascanz', 'displayName': 'AsuraScanz'},
                    {'name': 'asuracomic', 'displayName': 'AsuraComic'},
                    {'name': 'hotcomics', 'displayName': 'HotComics.io'},
                  ];

                  return sourcesAsync.when(
                    data: (sources) {
                      // Use default scrapers if API returns empty
                      final availableScrapers = sources.isNotEmpty
                          ? sources
                          : defaultScrapers;

                      // Set default if not set
                      if (_selectedScraper == null &&
                          availableScrapers.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedScraper =
                                availableScrapers.first['name'] ??
                                availableScrapers.first['_id'];
                          });
                        });
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedScraper,
                        decoration: const InputDecoration(
                          labelText: 'Scraper *',
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                        items: availableScrapers.map<DropdownMenuItem<String>>((
                          source,
                        ) {
                          final name =
                              (source['name'] ?? source['_id'] ?? 'Unknown')
                                  .toString();
                          final displayName = (source['displayName'] ?? name)
                              .toString();
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedScraper = value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a scraper';
                          }
                          return null;
                        },
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, stack) {
                      // On error, show default scrapers
                      if (_selectedScraper == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedScraper = defaultScrapers.first['name'];
                          });
                        });
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedScraper,
                        decoration: const InputDecoration(
                          labelText: 'Scraper *',
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                        items: defaultScrapers.map<DropdownMenuItem<String>>((
                          source,
                        ) {
                          final name = source['name']!;
                          final displayName = source['displayName']!;
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedScraper = value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a scraper';
                          }
                          return null;
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // URL Input
              Text('Manga URL', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL *',
                  prefixIcon: const Icon(Icons.link),
                  hintText: _getHintText(_selectedScraper),
                  helperText: _getHelperText(_selectedScraper),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a URL';
                  }
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) {
                    return 'Please enter a valid URL';
                  }
                  // Validate URL matches selected scraper
                  if (_selectedScraper != null) {
                    if (_selectedScraper == 'asurascanz' &&
                        !uri.host.contains('asurascanz') &&
                        !uri.host.contains('asurascans')) {
                      return 'URL must be from AsuraScanz';
                    }
                    if (_selectedScraper == 'asuracomic' &&
                        !uri.host.contains('asuracomic')) {
                      return 'URL must be from AsuraComic';
                    }
                    if (_selectedScraper == 'hotcomics' &&
                        !uri.host.contains('hotcomics.io')) {
                      return 'URL must be from hotcomics.io';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Create Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createJob,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? 'Creating...' : 'Create Job'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Determine job type based on scraper
      String? jobType;
      if (_selectedScraper != null) {
        switch (_selectedScraper!.toLowerCase()) {
          case 'asurascanz':
            jobType = 'asurascanz_import';
            break;
          case 'asuracomic':
            jobType = 'asuracomic_import';
            break;
          case 'hotcomics':
            jobType = 'hotcomics_import';
            break;
        }
      }
      
      await apiService.post(
        '${ApiConstants.adminScraper}/jobs',
        data: {
          'scraper': _selectedScraper,
          'url': _urlController.text.trim(),
          if (jobType != null) 'jobType': jobType,
        },
      );

      CustomSnackbar.success(context, 'Scraping job created successfully!');

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      CustomSnackbar.error(context, 'Failed to create job: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getHintText(String? scraper) {
    switch (scraper) {
      case 'asurascanz':
        return 'https://asurascanz.com/manga/...';
      case 'asuracomic':
        return 'https://asuracomic.net/series/...';
      case 'hotcomics':
        return 'https://hotcomics.io/comics/...';
      default:
        return 'Enter manga URL';
    }
  }

  String _getHelperText(String? scraper) {
    switch (scraper) {
      case 'asurascanz':
        return 'Enter AsuraScanz manga URL';
      case 'asuracomic':
        return 'Enter AsuraComic manga URL';
      case 'hotcomics':
        return 'Enter hotcomics.io manga URL';
      default:
        return 'Enter manga URL';
    }
  }
}
