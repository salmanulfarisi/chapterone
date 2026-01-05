import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';
import '../../auth/providers/auth_provider.dart';

// Analytics dashboard model
class AnalyticsDashboard {
  final int totalTimeSpent; // in seconds
  final int totalChaptersRead;
  final int totalPagesRead;
  final int uniqueMangaRead;
  final int avgSessionTime; // in seconds
  final double completionRate; // percentage
  final int totalMangaStarted;
  final int totalMangaCompleted;

  AnalyticsDashboard({
    required this.totalTimeSpent,
    required this.totalChaptersRead,
    required this.totalPagesRead,
    required this.uniqueMangaRead,
    required this.avgSessionTime,
    required this.completionRate,
    required this.totalMangaStarted,
    required this.totalMangaCompleted,
  });

  factory AnalyticsDashboard.fromJson(Map<String, dynamic> json) {
    return AnalyticsDashboard(
      totalTimeSpent: json['totalTimeSpent'] as int? ?? 0,
      totalChaptersRead: json['totalChaptersRead'] as int? ?? 0,
      totalPagesRead: json['totalPagesRead'] as int? ?? 0,
      uniqueMangaRead: json['uniqueMangaRead'] as int? ?? 0,
      avgSessionTime: json['avgSessionTime'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
      totalMangaStarted: json['totalMangaStarted'] as int? ?? 0,
      totalMangaCompleted: json['totalMangaCompleted'] as int? ?? 0,
    );
  }

  String get formattedTimeSpent {
    final hours = totalTimeSpent ~/ 3600;
    final minutes = (totalTimeSpent % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedAvgSessionTime {
    final minutes = avgSessionTime ~/ 60;
    final seconds = avgSessionTime % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

// Genre preference model
class GenrePreference {
  final String genre;
  final int count;
  final int totalTime;
  final int totalChapters;

  GenrePreference({
    required this.genre,
    required this.count,
    required this.totalTime,
    required this.totalChapters,
  });

  factory GenrePreference.fromJson(Map<String, dynamic> json) {
    return GenrePreference(
      genre: json['genre']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      totalTime: json['totalTime'] as int? ?? 0,
      totalChapters: json['totalChapters'] as int? ?? 0,
    );
  }
}

// Reading pattern model
class ReadingPattern {
  final List<DayOfWeekPattern> dayOfWeek;
  final List<HourOfDayPattern> hourOfDay;

  ReadingPattern({
    required this.dayOfWeek,
    required this.hourOfDay,
  });

  factory ReadingPattern.fromJson(Map<String, dynamic> json) {
    return ReadingPattern(
      dayOfWeek: (json['dayOfWeek'] as List<dynamic>?)
              ?.map((e) => DayOfWeekPattern.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hourOfDay: (json['hourOfDay'] as List<dynamic>?)
              ?.map((e) => HourOfDayPattern.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DayOfWeekPattern {
  final int day;
  final String dayName;
  final int count;
  final int totalTime;

  DayOfWeekPattern({
    required this.day,
    required this.dayName,
    required this.count,
    required this.totalTime,
  });

  factory DayOfWeekPattern.fromJson(Map<String, dynamic> json) {
    return DayOfWeekPattern(
      day: json['day'] as int? ?? 0,
      dayName: json['dayName']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      totalTime: json['totalTime'] as int? ?? 0,
    );
  }
}

class HourOfDayPattern {
  final int hour;
  final int count;
  final int totalTime;

  HourOfDayPattern({
    required this.hour,
    required this.count,
    required this.totalTime,
  });

  factory HourOfDayPattern.fromJson(Map<String, dynamic> json) {
    return HourOfDayPattern(
      hour: json['hour'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
      totalTime: json['totalTime'] as int? ?? 0,
    );
  }
}

// Completion data model
class CompletionData {
  final String mangaId;
  final String mangaTitle;
  final String? mangaCover;
  final int totalChapters;
  final int chaptersRead;
  final double completionPercentage;
  final bool isCompleted;
  final DateTime? lastRead;

  CompletionData({
    required this.mangaId,
    required this.mangaTitle,
    this.mangaCover,
    required this.totalChapters,
    required this.chaptersRead,
    required this.completionPercentage,
    required this.isCompleted,
    this.lastRead,
  });

  factory CompletionData.fromJson(Map<String, dynamic> json) {
    return CompletionData(
      mangaId: json['mangaId']?.toString() ?? '',
      mangaTitle: json['mangaTitle']?.toString() ?? '',
      mangaCover: json['mangaCover']?.toString(),
      totalChapters: json['totalChapters'] as int? ?? 0,
      chaptersRead: json['chaptersRead'] as int? ?? 0,
      completionPercentage: (json['completionPercentage'] as num?)?.toDouble() ?? 0.0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      lastRead: json['lastRead'] != null
          ? DateTime.parse(json['lastRead'].toString())
          : null,
    );
  }
}

// Drop-off analysis model
class DropoffAnalysis {
  final List<DropoffPoint> dropoffPoints;
  final OverallDropoff overall;

  DropoffAnalysis({
    required this.dropoffPoints,
    required this.overall,
  });

  factory DropoffAnalysis.fromJson(Map<String, dynamic> json) {
    return DropoffAnalysis(
      dropoffPoints: (json['dropoffPoints'] as List<dynamic>?)
              ?.map((e) => DropoffPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      overall: OverallDropoff.fromJson(
        json['overall'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class DropoffPoint {
  final String mangaId;
  final String mangaTitle;
  final String? mangaCover;
  final int chapterNumber;
  final int dropoffCount;
  final double avgCompletionPercentage;
  final int avgLastPage;

  DropoffPoint({
    required this.mangaId,
    required this.mangaTitle,
    this.mangaCover,
    required this.chapterNumber,
    required this.dropoffCount,
    required this.avgCompletionPercentage,
    required this.avgLastPage,
  });

  factory DropoffPoint.fromJson(Map<String, dynamic> json) {
    return DropoffPoint(
      mangaId: json['mangaId']?.toString() ?? '',
      mangaTitle: json['mangaTitle']?.toString() ?? '',
      mangaCover: json['mangaCover']?.toString(),
      chapterNumber: json['chapterNumber'] as int? ?? 0,
      dropoffCount: json['dropoffCount'] as int? ?? 0,
      avgCompletionPercentage:
          (json['avgCompletionPercentage'] as num?)?.toDouble() ?? 0.0,
      avgLastPage: json['avgLastPage'] as int? ?? 0,
    );
  }
}

class OverallDropoff {
  final int totalDropoffs;
  final double avgChapterNumber;
  final double avgCompletionPercentage;

  OverallDropoff({
    required this.totalDropoffs,
    required this.avgChapterNumber,
    required this.avgCompletionPercentage,
  });

  factory OverallDropoff.fromJson(Map<String, dynamic> json) {
    return OverallDropoff(
      totalDropoffs: json['totalDropoffs'] as int? ?? 0,
      avgChapterNumber: (json['avgChapterNumber'] as num?)?.toDouble() ?? 0.0,
      avgCompletionPercentage:
          (json['avgCompletionPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Providers
final analyticsDashboardProvider =
    FutureProvider<AnalyticsDashboard>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    throw Exception('Not authenticated');
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.analyticsDashboard);
    return AnalyticsDashboard.fromJson(response.data);
  } catch (e) {
    Logger.error('Failed to fetch analytics dashboard', e, null, 'AnalyticsProvider');
    rethrow;
  }
});

final genrePreferencesProvider = FutureProvider<List<GenrePreference>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return [];
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.analyticsGenres);
    final List<dynamic> data = response.data is List ? response.data : [];
    return data
        .map((json) => GenrePreference.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    Logger.error('Failed to fetch genre preferences', e, null, 'AnalyticsProvider');
    return [];
  }
});

final readingPatternsProvider = FutureProvider<ReadingPattern>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return ReadingPattern(dayOfWeek: [], hourOfDay: []);
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.analyticsPatterns);
    return ReadingPattern.fromJson(response.data);
  } catch (e) {
    Logger.error('Failed to fetch reading patterns', e, null, 'AnalyticsProvider');
    return ReadingPattern(dayOfWeek: [], hourOfDay: []);
  }
});

final completionDataProvider =
    FutureProvider<List<CompletionData>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return [];
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.analyticsCompletion);
    final List<dynamic> data = response.data is List ? response.data : [];
    return data
        .map((json) => CompletionData.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    Logger.error('Failed to fetch completion data', e, null, 'AnalyticsProvider');
    return [];
  }
});

final dropoffAnalysisProvider = FutureProvider<DropoffAnalysis>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return DropoffAnalysis(
      dropoffPoints: [],
      overall: OverallDropoff(
        totalDropoffs: 0,
        avgChapterNumber: 0,
        avgCompletionPercentage: 0,
      ),
    );
  }

  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get(ApiConstants.analyticsDropoff);
    return DropoffAnalysis.fromJson(response.data);
  } catch (e) {
    Logger.error('Failed to fetch drop-off analysis', e, null, 'AnalyticsProvider');
    return DropoffAnalysis(
      dropoffPoints: [],
      overall: OverallDropoff(
        totalDropoffs: 0,
        avgChapterNumber: 0,
        avgCompletionPercentage: 0,
      ),
    );
  }
});

