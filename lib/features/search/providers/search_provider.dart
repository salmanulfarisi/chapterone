import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';
import '../../auth/providers/auth_provider.dart';

// Search history model
class SearchHistoryItem {
  final String id;
  final String query;
  final Map<String, dynamic>? filters;
  final int resultCount;
  final DateTime searchedAt;

  SearchHistoryItem({
    required this.id,
    required this.query,
    this.filters,
    required this.resultCount,
    required this.searchedAt,
  });

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      query: json['query']?.toString() ?? '',
      filters: json['filters'] != null
          ? Map<String, dynamic>.from(json['filters'])
          : null,
      resultCount: json['resultCount'] as int? ?? 0,
      searchedAt: json['searchedAt'] != null
          ? (json['searchedAt'] is DateTime
              ? json['searchedAt'] as DateTime
              : DateTime.parse(json['searchedAt'].toString()))
          : DateTime.now(),
    );
  }
}

// Saved search model
class SavedSearchItem {
  final String id;
  final String name;
  final String? query;
  final Map<String, dynamic>? filters;
  final DateTime createdAt;

  SavedSearchItem({
    required this.id,
    required this.name,
    this.query,
    this.filters,
    required this.createdAt,
  });

  factory SavedSearchItem.fromJson(Map<String, dynamic> json) {
    return SavedSearchItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      query: json['query']?.toString(),
      filters: json['filters'] != null
          ? Map<String, dynamic>.from(json['filters'])
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
              ? json['createdAt'] as DateTime
              : DateTime.parse(json['createdAt'].toString()))
          : DateTime.now(),
    );
  }
}

// Trending search model
class TrendingSearch {
  final String query;
  final int count;
  final DateTime lastSearched;

  TrendingSearch({
    required this.query,
    required this.count,
    required this.lastSearched,
  });

  factory TrendingSearch.fromJson(Map<String, dynamic> json) {
    return TrendingSearch(
      query: json['query']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      lastSearched: json['lastSearched'] != null
          ? (json['lastSearched'] is DateTime
              ? json['lastSearched'] as DateTime
              : DateTime.parse(json['lastSearched'].toString()))
          : DateTime.now(),
    );
  }
}

// Search history provider
final searchHistoryProvider = FutureProvider<List<SearchHistoryItem>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return [];
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.searchHistory);
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => SearchHistoryItem.fromJson(json as Map<String, dynamic>)).toList();
  } catch (e) {
    Logger.error('Failed to fetch search history', e, null, 'SearchProvider');
    return [];
  }
});

// Saved searches provider
final savedSearchesProvider = FutureProvider<List<SavedSearchItem>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return [];
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.savedSearches);
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => SavedSearchItem.fromJson(json as Map<String, dynamic>)).toList();
  } catch (e) {
    Logger.error('Failed to fetch saved searches', e, null, 'SearchProvider');
    return [];
  }
});

// Trending searches provider
final trendingSearchesProvider = FutureProvider<List<TrendingSearch>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(
      ApiConstants.trendingSearches,
      queryParameters: {'limit': '10', 'days': '7'},
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => TrendingSearch.fromJson(json as Map<String, dynamic>)).toList();
  } catch (e) {
    Logger.error('Failed to fetch trending searches', e, null, 'SearchProvider');
    return [];
  }
});

