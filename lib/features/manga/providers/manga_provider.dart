import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/manga_model.dart';
import '../../../models/chapter_model.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';

// Helper class to create stable keys for manga list queries
class MangaListParams {
  final String? limit;
  final String? sort;
  final String? sortBy;
  final String? status;
  final String? genre;
  final String? search;
  final String? source;
  final String? minRating;
  final String? maxRating;
  final String? dateFrom;
  final String? dateTo;
  final String? dateField;

  MangaListParams({
    this.limit,
    this.sort,
    this.sortBy,
    this.status,
    this.genre,
    this.search,
    this.source,
    this.minRating,
    this.maxRating,
    this.dateFrom,
    this.dateTo,
    this.dateField,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (limit != null) map['limit'] = limit;
    if (sort != null) map['sort'] = sort;
    if (sortBy != null) map['sortBy'] = sortBy;
    if (status != null) map['status'] = status;
    if (genre != null) map['genre'] = genre;
    if (search != null) map['q'] = search; // Use 'q' for search query parameter
    if (source != null) map['source'] = source;
    if (minRating != null) map['minRating'] = minRating;
    if (maxRating != null) map['maxRating'] = maxRating;
    if (dateFrom != null) map['dateFrom'] = dateFrom;
    if (dateTo != null) map['dateTo'] = dateTo;
    if (dateField != null) map['dateField'] = dateField;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaListParams &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          sort == other.sort &&
          sortBy == other.sortBy &&
          status == other.status &&
          genre == other.genre &&
          search == other.search &&
          source == other.source &&
          minRating == other.minRating &&
          maxRating == other.maxRating &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo &&
          dateField == other.dateField;

  @override
  int get hashCode =>
      limit.hashCode ^
      sort.hashCode ^
      sortBy.hashCode ^
      status.hashCode ^
      genre.hashCode ^
      search.hashCode ^
      source.hashCode ^
      minRating.hashCode ^
      maxRating.hashCode ^
      dateFrom.hashCode ^
      dateTo.hashCode ^
      dateField.hashCode;
}

final mangaListProvider =
    FutureProvider.family<List<MangaModel>, MangaListParams>((
      ref,
      params,
    ) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        final response = await apiService.get(
          ApiConstants.mangaList,
          queryParameters: params.toMap(),
        );

        // Handle both response formats: { manga: [...] } or direct array
        List<dynamic> data;
        if (response.data is Map && response.data['manga'] != null) {
          data = response.data['manga'] as List<dynamic>;
        } else if (response.data is List) {
          data = response.data as List<dynamic>;
        } else {
          data = [];
        }
        
        return data.map((json) => MangaModel.fromJson(json)).toList();
      } catch (e) {
        Logger.error('Failed to fetch manga list', e, null, 'MangaProvider');
        return [];
      }
    });

final mangaDetailProvider = FutureProvider.family<MangaModel?, String>((
  ref,
  mangaId,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(
      '${ApiConstants.mangaDetail}/$mangaId',
    );
    return MangaModel.fromJson(response.data);
  } catch (e) {
    Logger.error('Failed to fetch manga detail', e, null, 'MangaProvider');
    return null;
  }
});

final mangaChaptersProvider = FutureProvider.family<List<ChapterModel>, String>(
  (ref, mangaId) async {
    final apiService = ref.watch(apiServiceProvider);

    try {
      final response = await apiService.get(
        '${ApiConstants.mangaChapters}/$mangaId/chapters',
      );
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((json) => ChapterModel.fromJson(json)).toList();
    } catch (e) {
      Logger.error('Failed to fetch chapters', e, null, 'MangaProvider');
      return [];
    }
  },
);

final chapterProvider = FutureProvider.family<ChapterModel?, String>((
  ref,
  chapterId,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(
      '${ApiConstants.chapterPages}/$chapterId',
    );
    if (response.data == null) {
      Logger.error('Chapter response is null', null, null, 'MangaProvider');
      return null;
    }
    return ChapterModel.fromJson(response.data);
  } catch (e) {
    Logger.error('Failed to fetch chapter', e, null, 'MangaProvider');
    // If chapter not found and ID is in new format, try to extract mangaId and fetch chapters
    if (chapterId.contains('_ch')) {
      try {
        final parts = chapterId.split('_ch');
        if (parts.length == 2) {
          final mangaId = parts[0];
          final chapterNum = int.tryParse(parts[1]);
          if (chapterNum != null) {
            // Fetch all chapters for this manga
            final chapters = await ref.read(
              mangaChaptersProvider(mangaId).future,
            );
            // Find the chapter by number
            final chapter = chapters.firstWhere(
              (ch) => ch.chapterNumber == chapterNum,
              orElse: () =>
                  throw StateError('Chapter not found in manga chapters'),
            );
            return chapter;
          }
        }
      } catch (fallbackError) {
        Logger.error(
          'Fallback chapter fetch failed',
          fallbackError,
          null,
          'MangaProvider',
        );
      }
    }
    return null;
  }
});

final rateMangaProvider =
    FutureProvider.family<bool, ({String mangaId, double rating})>((
      ref,
      params,
    ) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        await apiService.post(
          '${ApiConstants.mangaDetail}/${params.mangaId}/rate',
          data: {'rating': params.rating},
        );
        // Invalidate manga detail to get updated rating
        ref.invalidate(mangaDetailProvider(params.mangaId));
        // Also invalidate manga list to update ratings in lists
        ref.invalidate(mangaListProvider);
        return true;
      } catch (e) {
        Logger.error('Failed to rate manga', e, null, 'MangaProvider');
        return false;
      }
    });

// Provider to get read chapter IDs for a specific manga
final readChaptersProvider = FutureProvider.family<Set<String>, String>((
  ref,
  mangaId,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.readingHistory);
    final List<dynamic> history = response.data is List ? response.data : [];

    // Filter history for this manga and extract chapter IDs
    final readChapterIds = <String>{};
    for (final item in history) {
      if (item is Map<String, dynamic>) {
        final mangaIdFromHistory = item['mangaId'];
        String? mangaIdStr;

        // Handle both object and string formats
        if (mangaIdFromHistory is String) {
          mangaIdStr = mangaIdFromHistory;
        } else if (mangaIdFromHistory is Map) {
          mangaIdStr = mangaIdFromHistory['_id']?.toString();
        }

        if (mangaIdStr == mangaId) {
          final chapterId = item['chapterId'];
          if (chapterId != null) {
            // Handle both object and string formats
            if (chapterId is String) {
              readChapterIds.add(chapterId);
            } else if (chapterId is Map) {
              final chapterIdStr = chapterId['_id']?.toString();
              if (chapterIdStr != null) {
                readChapterIds.add(chapterIdStr);
              }
            }
          }
        }
      }
    }

    return readChapterIds;
  } catch (e) {
    Logger.error('Failed to fetch read chapters', e, null, 'MangaProvider');
    return <String>{};
  }
});
