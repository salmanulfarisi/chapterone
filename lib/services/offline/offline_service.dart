import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/logger.dart';
import '../../models/chapter_model.dart';

/// Service for managing offline content caching
class OfflineService {
  static const String offlineBoxName = 'offline_content';
  static const String cachedChaptersKey = 'cached_chapters';
  static const String cachedMangaKey = 'cached_manga';
  
  static OfflineService? _instance;
  static OfflineService get instance {
    _instance ??= OfflineService._();
    return _instance!;
  }

  OfflineService._();

  Box? _offlineBox;
  bool _isInitialized = false;

  /// Initialize offline service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _offlineBox = await Hive.openBox(offlineBoxName);
      _isInitialized = true;
      Logger.info('Offline service initialized', 'OfflineService');
    } catch (e) {
      Logger.error('Failed to initialize offline service', e, null, 'OfflineService');
      rethrow;
    }
  }

  /// Check if a chapter is cached offline
  bool isChapterCached(String chapterId) {
    if (!_isInitialized || _offlineBox == null) return false;
    return _offlineBox!.containsKey('chapter_$chapterId');
  }

  /// Cache a chapter for offline reading
  Future<void> cacheChapter(ChapterModel chapter, List<String> pageUrls) async {
    if (!_isInitialized || _offlineBox == null) {
      await initialize();
    }

    try {
      final chapterData = {
        'id': chapter.id,
        'mangaId': chapter.mangaId,
        'chapterNumber': chapter.chapterNumber,
        'title': chapter.title,
        'pageUrls': pageUrls,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await _offlineBox!.put('chapter_${chapter.id}', chapterData);
      
      // Update cached chapters list
      final cachedChapters = getCachedChapters();
      if (!cachedChapters.contains(chapter.id)) {
        cachedChapters.add(chapter.id);
        await _offlineBox!.put(cachedChaptersKey, cachedChapters);
      }

      Logger.info('Chapter ${chapter.id} cached offline', 'OfflineService');
    } catch (e) {
      Logger.error('Failed to cache chapter', e, null, 'OfflineService');
      rethrow;
    }
  }

  /// Get cached chapter data
  Map<String, dynamic>? getCachedChapter(String chapterId) {
    if (!_isInitialized || _offlineBox == null) return null;
    
    try {
      final data = _offlineBox!.get('chapter_$chapterId');
      return data as Map<String, dynamic>?;
    } catch (e) {
      Logger.error('Failed to get cached chapter', e, null, 'OfflineService');
      return null;
    }
  }

  /// Get list of cached chapter IDs
  List<String> getCachedChapters() {
    if (!_isInitialized || _offlineBox == null) return [];
    
    try {
      final data = _offlineBox!.get(cachedChaptersKey);
      if (data is List) {
        return data.cast<String>().toList();
      }
      return [];
    } catch (e) {
      Logger.error('Failed to get cached chapters list', e, null, 'OfflineService');
      return [];
    }
  }

  /// Remove a cached chapter
  Future<void> removeCachedChapter(String chapterId) async {
    if (!_isInitialized || _offlineBox == null) return;

    try {
      await _offlineBox!.delete('chapter_$chapterId');
      
      // Update cached chapters list
      final cachedChapters = getCachedChapters();
      cachedChapters.remove(chapterId);
      await _offlineBox!.put(cachedChaptersKey, cachedChapters);

      Logger.info('Chapter $chapterId removed from cache', 'OfflineService');
    } catch (e) {
      Logger.error('Failed to remove cached chapter', e, null, 'OfflineService');
    }
  }

  /// Get total cached size (approximate)
  Future<int> getCachedSize() async {
    if (!_isInitialized || _offlineBox == null) return 0;
    
    try {
      // This is an approximation - Hive doesn't provide exact size
      final keys = _offlineBox!.keys.toList();
      return keys.length; // Return count as approximation
    } catch (e) {
      Logger.error('Failed to get cached size', e, null, 'OfflineService');
      return 0;
    }
  }

  /// Clear all offline content
  Future<void> clearAll() async {
    if (!_isInitialized || _offlineBox == null) return;

    try {
      await _offlineBox!.clear();
      Logger.info('All offline content cleared', 'OfflineService');
    } catch (e) {
      Logger.error('Failed to clear offline content', e, null, 'OfflineService');
    }
  }
}

