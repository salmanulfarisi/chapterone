import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';

class AddEditScraperSourceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? source;

  const AddEditScraperSourceScreen({super.key, this.source});

  @override
  ConsumerState<AddEditScraperSourceScreen> createState() => _AddEditScraperSourceScreenState();
}

class _AddEditScraperSourceScreenState extends ConsumerState<AddEditScraperSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _mangaListSelectorController = TextEditingController();
  final _mangaItemSelectorController = TextEditingController();
  final _mangaTitleSelectorController = TextEditingController();
  final _mangaCoverSelectorController = TextEditingController();
  final _chapterListSelectorController = TextEditingController();
  final _pageImageSelectorController = TextEditingController();
  bool _requiresJS = false;
  int _rateLimit = 60;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.source != null) {
      _nameController.text = widget.source!['name'] ?? '';
      _baseUrlController.text = widget.source!['baseUrl'] ?? '';
      final selectors = widget.source!['selectors'] ?? {};
      _mangaListSelectorController.text = selectors['mangaList'] ?? '';
      _mangaItemSelectorController.text = selectors['mangaItem'] ?? '';
      _mangaTitleSelectorController.text = selectors['mangaTitle'] ?? '';
      _mangaCoverSelectorController.text = selectors['mangaCover'] ?? '';
      _chapterListSelectorController.text = selectors['chapterList'] ?? '';
      _pageImageSelectorController.text = selectors['pageImage'] ?? '';
      _requiresJS = widget.source!['config']?['requiresJS'] ?? false;
      _rateLimit = widget.source!['config']?['rateLimit'] ?? 60;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _mangaListSelectorController.dispose();
    _mangaItemSelectorController.dispose();
    _mangaTitleSelectorController.dispose();
    _mangaCoverSelectorController.dispose();
    _chapterListSelectorController.dispose();
    _pageImageSelectorController.dispose();
    super.dispose();
  }

  Future<void> _saveSource() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final data = {
        'name': _nameController.text.trim(),
        'baseUrl': _baseUrlController.text.trim(),
        'selectors': {
          'mangaList': _mangaListSelectorController.text.trim(),
          'mangaItem': _mangaItemSelectorController.text.trim(),
          'mangaTitle': _mangaTitleSelectorController.text.trim(),
          'mangaCover': _mangaCoverSelectorController.text.trim(),
          'chapterList': _chapterListSelectorController.text.trim(),
          'pageImage': _pageImageSelectorController.text.trim(),
        },
        'config': {
          'requiresJS': _requiresJS,
          'rateLimit': _rateLimit,
        },
      };

      final sourceId = widget.source?['_id']?.toString();
      if (sourceId != null) {
        // Editing existing source
        await apiService.put('${ApiConstants.adminScraper}/sources/$sourceId', data: data);
      } else {
        // Creating new source
        await apiService.post('${ApiConstants.adminScraper}/sources', data: data);
      }
      CustomSnackbar.success(context, 'Scraper source saved successfully!');
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      CustomSnackbar.error(context, 'Failed to save source: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testSource() async {
    if (_baseUrlController.text.isEmpty) {
      CustomSnackbar.warning(context, 'Please enter a base URL first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final sourceId = widget.source?['_id'];
      
      if (sourceId == null) {
        // Save first, then test
        await _saveSource();
        return;
      }

      await apiService.post(
        '${ApiConstants.adminScraper}/sources/$sourceId/test',
        data: {'url': _baseUrlController.text},
      );
      
      CustomSnackbar.success(context, 'Source test completed! Check results.');
    } catch (e) {
      CustomSnackbar.error(context, 'Test failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source != null ? 'Edit Source' : 'Add Scraper Source'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _testSource,
              tooltip: 'Test Source',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSource,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Info
              Text(
                'Basic Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Source Name *',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL *',
                  prefixIcon: Icon(Icons.link),
                  hintText: 'https://example.com',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a base URL';
                  }
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    return 'Please enter a valid URL (e.g., https://example.com)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Selectors
              Text(
                'CSS Selectors',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter CSS selectors to locate elements on the page',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _mangaListSelectorController,
                decoration: const InputDecoration(
                  labelText: 'Manga List Container',
                  prefixIcon: Icon(Icons.list),
                  hintText: '.manga-list',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _mangaItemSelectorController,
                decoration: const InputDecoration(
                  labelText: 'Manga Item',
                  prefixIcon: Icon(Icons.book),
                  hintText: '.manga-item',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _mangaTitleSelectorController,
                decoration: const InputDecoration(
                  labelText: 'Manga Title',
                  prefixIcon: Icon(Icons.title),
                  hintText: 'h2.title',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _mangaCoverSelectorController,
                decoration: const InputDecoration(
                  labelText: 'Manga Cover Image',
                  prefixIcon: Icon(Icons.image),
                  hintText: 'img.cover',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _chapterListSelectorController,
                decoration: const InputDecoration(
                  labelText: 'Chapter List',
                  prefixIcon: Icon(Icons.menu_book),
                  hintText: '.chapter-list',
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _pageImageSelectorController,
                decoration: const InputDecoration(
                  labelText: 'Page Image',
                  prefixIcon: Icon(Icons.photo),
                  hintText: 'img.page-image',
                ),
              ),
              const SizedBox(height: 24),

              // Configuration
              Text(
                'Configuration',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Requires JavaScript'),
                subtitle: const Text('Enable if the site uses dynamic content'),
                value: _requiresJS,
                onChanged: (value) => setState(() => _requiresJS = value),
              ),

              ListTile(
                title: const Text('Rate Limit'),
                subtitle: Text('$_rateLimit requests per minute'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if (_rateLimit > 1) {
                          setState(() => _rateLimit--);
                        }
                      },
                    ),
                    Text('$_rateLimit'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() => _rateLimit++);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

