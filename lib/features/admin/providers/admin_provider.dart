import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../models/manga_model.dart';

// Stable parameter class for admin manga queries
class AdminMangaQueryParams {
  final String? search;

  AdminMangaQueryParams({this.search});

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (search != null && search!.isNotEmpty) {
      map['search'] = search;
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminMangaQueryParams &&
          runtimeType == other.runtimeType &&
          search == other.search;

  @override
  int get hashCode => search.hashCode;
}

// Admin manga list provider - includes all manga including adult content
final adminMangaListProvider =
    FutureProvider.family<List<MangaModel>, AdminMangaQueryParams>((
      ref,
      params,
    ) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        Response response;
        try {
          response = await apiService.get(
            ApiConstants.adminManga,
            queryParameters: params.toMap(),
            options: Options(
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
            ),
          ).timeout(
            const Duration(seconds: 35), // Slightly longer than receiveTimeout
          );
        } on DioException catch (e) {
          // Handle 504 Gateway Timeout specifically
          if (e.response?.statusCode == 504 || e.type == DioExceptionType.receiveTimeout) {
            Logger.debug('Admin manga request timed out (504)', 'AdminProvider');
            return [];
          }
          rethrow;
        } on TimeoutException catch (e) {
          Logger.debug('Admin manga request timed out: ${e.message}', 'AdminProvider');
          return [];
        }

        // Handle 504 timeout responses gracefully (if validateStatus allowed it through)
        if (response.statusCode == 504) {
          Logger.debug('Received 504 timeout from server', 'AdminProvider');
          return [];
        }

        // Debug logging
        Logger.debug('Admin manga response type: ${response.data.runtimeType}');
        if (response.data is Map) {
          Logger.debug(
            'Admin manga response keys: ${(response.data as Map).keys.toList()}',
          );
          Logger.debug(
            'Admin manga count: ${(response.data as Map)['manga']?.length ?? 0}',
          );
        }

        // Handle both response formats: { manga: [...] } or direct array
        List<dynamic> data;
        if (response.data is Map && response.data['manga'] != null) {
          data = response.data['manga'] as List<dynamic>;
          Logger.debug('Extracted ${data.length} manga from response.manga');
        } else if (response.data is List) {
          data = response.data as List<dynamic>;
          Logger.debug('Extracted ${data.length} manga from direct array');
        } else {
          Logger.debug(
            'No manga found in response. Response data: $response.data',
          );
          data = [];
        }

        if (data.isEmpty) {
          Logger.debug('No manga data to parse');
          return [];
        }

        // Parse manga models
        try {
          final mangaList = data
              .map((json) {
                try {
                  return MangaModel.fromJson(json);
                } catch (e) {
                  Logger.error(
                    'Failed to parse manga item: $json',
                    e,
                    null,
                    'AdminProvider',
                  );
                  return null;
                }
              })
              .whereType<MangaModel>()
              .toList();

          Logger.debug('Successfully parsed ${mangaList.length} manga models');
          return mangaList;
        } catch (e) {
          Logger.error('Failed to parse manga list', e, null, 'AdminProvider');
          rethrow;
        }
      } on TimeoutException catch (e) {
        Logger.debug(
          'Admin manga request timed out: ${e.message}',
          'AdminProvider',
        );
        // Return empty list on timeout instead of throwing
        return [];
      } on DioException catch (e) {
        // Handle 504 Gateway Timeout specifically
        if (e.response?.statusCode == 504) {
          Logger.debug(
            'Server timeout (504) - returning empty list',
            'AdminProvider',
          );
          return [];
        }
        Logger.error(
          'Failed to fetch admin manga list: ${e.message}',
          e,
          e.stackTrace,
          'AdminProvider',
        );
        rethrow; // Re-throw other errors to show error state
      } catch (e, stackTrace) {
        Logger.error(
          'Failed to fetch admin manga list',
          e,
          stackTrace,
          'AdminProvider',
        );
        rethrow; // Re-throw to show error state instead of empty list
      }
    });

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(
      '${ApiConstants.adminStats}/overview',
    );
    return response.data;
  } catch (e) {
    Logger.error('Failed to fetch admin stats', e, null, 'AdminProvider');
    return {};
  }
});

final scraperSourcesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(
      '${ApiConstants.adminScraper}/sources',
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => json as Map<String, dynamic>).toList();
  } catch (e) {
    Logger.error('Failed to fetch scraper sources', e, null, 'AdminProvider');
    return [];
  }
});

final scrapingJobsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) async* {
  final apiService = ref.watch(apiServiceProvider);
  List<Map<String, dynamic>> lastJobs = [];

  while (true) {
    try {
      // Use a longer timeout for jobs endpoint (2 minutes)
      final response = await apiService
          .get(
            '${ApiConstants.adminScraper}/jobs',
            options: Options(
              receiveTimeout: const Duration(minutes: 2),
              sendTimeout: const Duration(minutes: 2),
            ),
          )
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              throw TimeoutException(
                'Request timeout',
                const Duration(minutes: 2),
              );
            },
          );

      final List<dynamic> data = response.data is List ? response.data : [];
      final jobs = data.map((json) => json as Map<String, dynamic>).toList();
      lastJobs = jobs;

      yield jobs;

      // Check if there are any running jobs
      final hasRunningJobs = jobs.any(
        (job) => job['status'] == 'running' || job['status'] == 'pending',
      );

      if (hasRunningJobs) {
        // Wait 2 seconds before next poll
        await Future.delayed(const Duration(seconds: 2));
      } else {
        // No running jobs, wait longer before checking again
        await Future.delayed(const Duration(seconds: 5));
      }
    } on TimeoutException catch (e) {
      Logger.error('Timeout fetching scraping jobs', e, null, 'AdminProvider');
      // Yield last known jobs on timeout instead of empty list
      yield lastJobs;
      // Wait longer before retrying after timeout
      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      Logger.error('Failed to fetch scraping jobs', e, null, 'AdminProvider');
      // Yield last known jobs on error instead of empty list
      yield lastJobs;
      // Wait before retrying on error
      await Future.delayed(const Duration(seconds: 5));
    }
  }
});

// AsuraScanz-specific scraper providers

// Search AsuraScanz by query
final asurascanzSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      query,
    ) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        if (query.trim().isEmpty) return [];
        // Fetch all pages by default to get complete results
        final response = await apiService.get(
          '${ApiConstants.adminScraper}/asurascanz/search',
          queryParameters: {'q': query, 'fetchAll': 'true'},
        );
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => json as Map<String, dynamic>).toList();
      } catch (e) {
        Logger.error('Failed to search AsuraScanz', e, null, 'AdminProvider');
        return [];
      }
    });

// Preview AsuraScanz manga (details + chapter list + local import info)
final asurascanzPreviewProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, url) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        final response = await apiService.post(
          '${ApiConstants.adminScraper}/asurascanz/preview',
          data: {'url': url},
        );
        return response.data as Map<String, dynamic>;
      } catch (e) {
        Logger.error(
          'Failed to preview AsuraScanz manga',
          e,
          null,
          'AdminProvider',
        );
        return {};
      }
    });

// Get update status for all imported AsuraScanz manga
final asurascanzUpdatesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(
      '${ApiConstants.adminScraper}/asurascanz/updates',
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => json as Map<String, dynamic>).toList();
  } catch (e) {
    Logger.error(
      'Failed to fetch AsuraScanz updates',
      e,
      null,
      'AdminProvider',
    );
    return [];
  }
});

final adminUsersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(ApiConstants.adminUsers);
    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      final List<dynamic> data = map['users'] as List<dynamic>? ?? [];
      // Filter out inactive users on client side
      return data
          .map((json) => json as Map<String, dynamic>)
          .where((user) => user['isActive'] != false)
          .toList();
    } else if (response.data is List) {
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => json as Map<String, dynamic>)
          .where((user) => user['isActive'] != false)
          .toList();
    }
    return [];
  } catch (e) {
    Logger.error('Failed to fetch users', e, null, 'AdminProvider');
    return [];
  }
});

final adminAnalyticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    // Backend has /admin/stats/overview, not /analytics
    // Add timeout to prevent hanging
    final response = await apiService.get(
      '${ApiConstants.adminStats}/overview',
      options: Options(
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Request timeout', const Duration(seconds: 30));
      },
    );
    return response.data is Map<String, dynamic>
        ? response.data
        : <String, dynamic>{};
  } catch (e) {
    Logger.error('Failed to fetch analytics', e, null, 'AdminProvider');
    // Return empty map with error flag
    return {'error': e.toString()};
  }
});

// Real-time user activity monitoring
final adminUserActivityProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  timeframe,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(
      ApiConstants.adminUserActivity,
      queryParameters: {'timeframe': timeframe},
    );
    return response.data is Map<String, dynamic>
        ? response.data
        : <String, dynamic>{};
  } catch (e) {
    Logger.error('Failed to fetch user activity', e, null, 'AdminProvider');
    return {};
  }
});

// Popular content analytics
final adminPopularContentProvider = FutureProvider.family<Map<String, dynamic>, Map<String, String>>((
  ref,
  params,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    Response response;
    try {
      response = await apiService.get(
        ApiConstants.adminPopularContent,
        queryParameters: params,
        options: Options(
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 25),
        ),
      ).timeout(
        const Duration(seconds: 25),
      );
    } on DioException catch (e) {
      // Handle 504 Gateway Timeout specifically
      if (e.response?.statusCode == 504 || e.type == DioExceptionType.receiveTimeout) {
        Logger.debug('Popular content request timed out (504)', 'AdminProvider');
        // Return empty data instead of error to prevent continuous retries
        return {'popularManga': [], 'popularGenres': [], 'timeframe': params['timeframe'] ?? '30d'};
      }
      rethrow;
    } on TimeoutException catch (e) {
      Logger.debug('Popular content request timed out: ${e.message}', 'AdminProvider');
      // Return empty data instead of error to prevent continuous retries
      return {'popularManga': [], 'popularGenres': [], 'timeframe': params['timeframe'] ?? '30d'};
    }
    
    // Handle 504 timeout responses gracefully (if validateStatus allowed it through)
    if (response.statusCode == 504) {
      Logger.debug('Received 504 timeout from server', 'AdminProvider');
      return {'popularManga': [], 'popularGenres': [], 'timeframe': params['timeframe'] ?? '30d'};
    }
    
    return response.data is Map<String, dynamic>
        ? response.data
        : <String, dynamic>{'popularManga': [], 'popularGenres': [], 'timeframe': params['timeframe'] ?? '30d'};
  } catch (e) {
    Logger.error('Failed to fetch popular content', e, null, 'AdminProvider');
    // Return empty data structure instead of error to prevent continuous retries
    return {'popularManga': [], 'popularGenres': [], 'timeframe': params['timeframe'] ?? '30d'};
  }
});

// User retention metrics
final adminUserRetentionProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  period,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(
      ApiConstants.adminUserRetention,
      queryParameters: {'period': period},
    );
    return response.data is Map<String, dynamic>
        ? response.data
        : <String, dynamic>{};
  } catch (e) {
    Logger.error('Failed to fetch user retention', e, null, 'AdminProvider');
    return {};
  }
});

// Revenue analytics
final adminRevenueProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  timeframe,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(
      ApiConstants.adminRevenue,
      queryParameters: {'timeframe': timeframe},
    );
    return response.data is Map<String, dynamic>
        ? response.data
        : <String, dynamic>{};
  } catch (e) {
    Logger.error('Failed to fetch revenue analytics', e, null, 'AdminProvider');
    return {};
  }
});

// Content performance metrics
final adminContentPerformanceProvider = FutureProvider.family<Map<String, dynamic>, Map<String, String>>((
  ref,
  params,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(
      ApiConstants.adminContentPerformance,
      queryParameters: params,
      options: Options(
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Request timeout', const Duration(seconds: 30));
      },
    );
    return response.data is Map<String, dynamic>
        ? response.data
        : <String, dynamic>{};
  } catch (e) {
    Logger.error('Failed to fetch content performance', e, null, 'AdminProvider');
    return {'error': e.toString(), 'contentPerformance': [], 'averageMetrics': {}};
  }
});

// AsuraComic-specific scraper providers

// Search AsuraComic by query
final asuracomicSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      query,
    ) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        if (query.trim().isEmpty) return [];
        // Fetch all pages by default to get complete results
        final response = await apiService.get(
          '${ApiConstants.adminScraper}/asuracomic/search',
          queryParameters: {'q': query, 'fetchAll': 'true'},
        );
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => json as Map<String, dynamic>).toList();
      } catch (e) {
        Logger.error('Failed to search AsuraComic', e, null, 'AdminProvider');
        return [];
      }
    });

// Preview AsuraComic manga (details + chapter list + local import info)
final asuracomicPreviewProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, url) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        final response = await apiService.post(
          '${ApiConstants.adminScraper}/asuracomic/preview',
          data: {'url': url},
        );
        return response.data as Map<String, dynamic>;
      } catch (e) {
        Logger.error(
          'Failed to preview AsuraComic manga',
          e,
          null,
          'AdminProvider',
        );
        return {};
      }
    });

// Get update status for all imported AsuraComic manga
final asuracomicUpdatesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(
      '${ApiConstants.adminScraper}/asuracomic/updates',
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => json as Map<String, dynamic>).toList();
  } catch (e) {
    Logger.error(
      'Failed to fetch AsuraComic updates',
      e,
      null,
      'AdminProvider',
    );
    return [];
  }
});

// HotComics-specific scraper providers

// Search HotComics by query
final hotcomicsSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      query,
    ) async {
      final apiService = ref.watch(apiServiceProvider);

      try {
        if (query.trim().isEmpty) return [];
        final response = await apiService.get(
          '${ApiConstants.adminScraper}/hotcomics/search',
          queryParameters: {'q': query},
        );
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => json as Map<String, dynamic>).toList();
      } catch (e) {
        Logger.error('Failed to search HotComics', e, null, 'AdminProvider');
        return [];
      }
    });

// Get update status for all imported HotComics manga
final hotcomicsUpdatesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);

  try {
    final response = await apiService.get(
      '${ApiConstants.adminScraper}/hotcomics/updates',
    );
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.map((json) => json as Map<String, dynamic>).toList();
  } catch (e) {
    Logger.error('Failed to fetch HotComics updates', e, null, 'AdminProvider');
    return [];
  }
});

// Chapter monitoring status provider
final chapterMonitoringStatusProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(
      '${ApiConstants.adminScraper}/monitoring/status',
    );
    return response.data is Map<String, dynamic> ? response.data : {};
  } catch (e) {
    Logger.error('Failed to fetch monitoring status', e, null, 'AdminProvider');
    return {};
  }
});
