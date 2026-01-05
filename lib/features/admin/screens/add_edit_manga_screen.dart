import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/custom_snackbar.dart';

class AddEditMangaScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? manga;

  const AddEditMangaScreen({super.key, this.manga});

  @override
  ConsumerState<AddEditMangaScreen> createState() => _AddEditMangaScreenState();
}

class _AddEditMangaScreenState extends ConsumerState<AddEditMangaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _authorController = TextEditingController();
  final _artistController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  final _newGenreController = TextEditingController();
  List<String> _selectedGenres = [];
  List<String> _availableGenres = [];
  String _status = 'ongoing';
  String _type = 'manhwa';
  bool _isLoading = false;
  bool _isLoadingGenres = true;

  @override
  void initState() {
    super.initState();
    if (widget.manga != null) {
      _titleController.text = widget.manga!['title'] ?? '';
      _descriptionController.text = widget.manga!['description'] ?? '';
      _authorController.text = widget.manga!['author'] ?? '';
      _artistController.text = widget.manga!['artist'] ?? '';
      _coverImageUrlController.text = widget.manga!['cover'] ?? '';
      _selectedGenres = List<String>.from(widget.manga!['genres'] ?? []);
      _status = widget.manga!['status'] ?? 'ongoing';
      _type = widget.manga!['type'] ?? 'manhwa';
    }
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('${ApiConstants.mangaList}/genres');
      final List<dynamic> genres = response.data is List ? response.data : [];
      setState(() {
        _availableGenres = genres.cast<String>();
        // Add any selected genres that might not be in the list
        for (final genre in _selectedGenres) {
          if (!_availableGenres.contains(genre)) {
            _availableGenres.add(genre);
          }
        }
        _availableGenres.sort();
        _isLoadingGenres = false;
      });
    } catch (e) {
      setState(() {
        // Fallback to default genres if API fails
        _availableGenres = [
          'Action',
          'Adventure',
          'Comedy',
          'Drama',
          'Fantasy',
          'Horror',
          'Romance',
          'Sci-Fi',
          'Slice of Life',
          'Supernatural',
          'Mystery',
          'Thriller',
          'Sports',
          'School',
          'Martial Arts',
          'Isekai',
          'Harem',
          'Psychological',
        ];
        _isLoadingGenres = false;
      });
    }
  }

  void _addNewGenre() {
    final newGenre = _newGenreController.text.trim();
    if (newGenre.isNotEmpty) {
      setState(() {
        if (!_availableGenres.contains(newGenre)) {
          _availableGenres.add(newGenre);
          _availableGenres.sort();
        }
        if (!_selectedGenres.contains(newGenre)) {
          _selectedGenres.add(newGenre);
        }
        _newGenreController.clear();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    _artistController.dispose();
    _coverImageUrlController.dispose();
    _newGenreController.dispose();
    super.dispose();
  }

  Future<void> _saveManga() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'author': _authorController.text.trim(),
        'artist': _artistController.text.trim(),
        'genres': _selectedGenres,
        'status': _status,
        'type': _type,
        if (_coverImageUrlController.text.trim().isNotEmpty)
          'cover': _coverImageUrlController.text.trim(),
      };

      if (widget.manga != null) {
        final mangaId = widget.manga!['_id'] ?? widget.manga!['id'];
        if (mangaId == null ||
            mangaId.toString().isEmpty ||
            mangaId.toString() == 'null') {
          CustomSnackbar.error(
            context,
            'Invalid manga ID. Cannot update manga.',
          );
          return;
        }

        await apiService.put('${ApiConstants.adminManga}/$mangaId', data: data);
        CustomSnackbar.success(context, 'Manga updated successfully!');
      } else {
        await apiService.post(ApiConstants.adminManga, data: data);
        CustomSnackbar.success(context, 'Manga created successfully!');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      CustomSnackbar.error(context, 'Failed to save manga: ${e.toString()}');
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
        title: Text(widget.manga != null ? 'Edit Manga' : 'Add Manga'),
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
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _saveManga),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image URL
              TextFormField(
                controller: _coverImageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Cover Image URL',
                  prefixIcon: Icon(Icons.image),
                  hintText: 'https://example.com/cover.jpg',
                  helperText: 'Enter the full URL of the cover image',
                ),
                keyboardType: TextInputType.url,
                onChanged: (value) {
                  setState(() {}); // Rebuild to update preview
                },
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null ||
                        !uri.hasScheme ||
                        (!uri.scheme.startsWith('http'))) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cover Image Preview
              if (_coverImageUrlController.text.trim().isNotEmpty)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _coverImageUrlController.text.trim(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppTheme.cardBackground,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        return Container(
                          color: AppTheme.cardBackground,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),

              // Author
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),

              // Artist
              TextFormField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: 'Artist',
                  prefixIcon: Icon(Icons.brush),
                ),
              ),
              const SizedBox(height: 16),

              // Status
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.info),
                ),
                items: const [
                  DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(value: 'hiatus', child: Text('Hiatus')),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _status = value!);
                },
              ),
              const SizedBox(height: 16),

              // Type
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'manga', child: Text('Manga')),
                  DropdownMenuItem(value: 'manhwa', child: Text('Manhwa')),
                  DropdownMenuItem(value: 'manhua', child: Text('Manhua')),
                  DropdownMenuItem(value: 'comic', child: Text('Comic')),
                  DropdownMenuItem(value: 'webtoon', child: Text('Webtoon')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() => _type = value!);
                },
              ),
              const SizedBox(height: 16),

              // Genres section
              const Text(
                'Genres',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              // Add new genre input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newGenreController,
                      decoration: const InputDecoration(
                        hintText: 'Add new genre',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _addNewGenre(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addNewGenre,
                    icon: const Icon(Icons.add_circle),
                    color: AppTheme.primaryRed,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Genre chips
              if (_isLoadingGenres)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableGenres.map((genre) {
                    final isSelected = _selectedGenres.contains(genre);
                    return FilterChip(
                      label: Text(genre),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryRed.withOpacity(0.3),
                      checkmarkColor: AppTheme.primaryRed,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedGenres.add(genre);
                          } else {
                            _selectedGenres.remove(genre);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
