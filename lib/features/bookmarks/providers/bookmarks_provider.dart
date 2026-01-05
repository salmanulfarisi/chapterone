import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/manga_model.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';
import '../../manga/providers/manga_provider.dart';
import '../../profile/profile_screen.dart';

final bookmarksProvider = FutureProvider<List<MangaModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(ApiConstants.bookmarks);
    final List<dynamic> data = response.data is List ? response.data : [];
    return data
        .map((json) => MangaModel.fromJson(json['mangaId'] ?? json))
        .toList();
  } catch (e) {
    Logger.error('Failed to fetch bookmarks', e, null, 'BookmarksProvider');
    return [];
  }
});

final addBookmarkProvider = FutureProvider.family<bool, String>((
  ref,
  mangaId,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    await apiService.post(ApiConstants.bookmarks, data: {'mangaId': mangaId});
    ref.invalidate(bookmarksProvider);
    // Invalidate manga detail to refresh followers count
    ref.invalidate(mangaDetailProvider(mangaId));
    // Invalidate user stats to update bookmark count
    ref.invalidate(userStatsProvider);
    return true;
  } catch (e) {
    Logger.error('Failed to add bookmark', e, null, 'BookmarksProvider');
    return false;
  }
});

final removeBookmarkProvider = FutureProvider.family<bool, String>((
  ref,
  mangaId,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    await apiService.delete('${ApiConstants.bookmarks}/$mangaId');
    ref.invalidate(bookmarksProvider);
    // Invalidate manga detail to refresh followers count
    ref.invalidate(mangaDetailProvider(mangaId));
    // Invalidate user stats to update bookmark count
    ref.invalidate(userStatsProvider);
    return true;
  } catch (e) {
    Logger.error('Failed to remove bookmark', e, null, 'BookmarksProvider');
    return false;
  }
});
