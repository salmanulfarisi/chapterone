import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../models/manga_model.dart';
import '../../auth/providers/auth_provider.dart';

// Recommendations provider
final recommendationsProvider = FutureProvider<List<MangaModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    // Recommendations endpoint can take longer due to complex queries
    // Use a longer timeout (60 seconds) for this endpoint
    final response = await apiService.get(
      ApiConstants.recommendations,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => MangaModel.fromJson(json)).toList();
  } catch (e) {
    Logger.error(
      'Failed to fetch recommendations',
      e,
      null,
      'RecommendationsProvider',
    );
    return [];
  }
});

// Continue reading provider
final continueReadingProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.continueReading);
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => Map<String, dynamic>.from(json)).toList();
  } catch (e) {
    Logger.error(
      'Failed to fetch continue reading',
      e,
      null,
      'RecommendationsProvider',
    );
    return [];
  }
});

// Similar manga provider (for a specific manga)
final similarMangaProvider = FutureProvider.family<List<MangaModel>, String>(
  (ref, mangaId) async {
    final apiService = ref.watch(apiServiceProvider);
    try {
      final response = await apiService.get(
        '${ApiConstants.similarManga}/$mangaId',
      );
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((json) => MangaModel.fromJson(json)).toList();
    } catch (e) {
      Logger.error(
        'Failed to fetch similar manga',
        e,
        null,
        'RecommendationsProvider',
      );
      return [];
    }
  },
);

// Trending by genre provider
final trendingByGenreProvider = FutureProvider.family<List<MangaModel>, String>(
  (ref, genre) async {
    final apiService = ref.watch(apiServiceProvider);
    try {
      final response = await apiService.get(
        ApiConstants.trendingByGenre,
        queryParameters: {'genre': genre, 'limit': '10'},
      );
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((json) => MangaModel.fromJson(json)).toList();
    } catch (e) {
      Logger.error(
        'Failed to fetch trending by genre',
        e,
        null,
        'RecommendationsProvider',
      );
      return [];
    }
  },
);

// "You might also like" provider (enhanced personalized recommendations)
final youMightLikeProvider = FutureProvider<List<MangaModel>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return [];
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    // This endpoint can also take longer due to complex queries
    // Use a longer timeout (60 seconds) for this endpoint
    final response = await apiService.get(
      ApiConstants.youMightLike,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => MangaModel.fromJson(json)).toList();
  } catch (e) {
    Logger.error(
      'Failed to fetch you might like',
      e,
      null,
      'RecommendationsProvider',
    );
    return [];
  }
});
