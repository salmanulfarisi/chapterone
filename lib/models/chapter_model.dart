class ChapterModel {
  final String id;
  final String mangaId;
  final int chapterNumber;
  final String? title;
  final List<String> pages;
  final DateTime? releaseDate;
  final int? views;
  final bool? isLocked;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChapterModel({
    required this.id,
    required this.mangaId,
    required this.chapterNumber,
    this.title,
    this.pages = const [],
    this.releaseDate,
    this.views,
    this.isLocked,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    // Normalize mangaId to a string, even if backend sends a populated object
    String normalizeMangaId(dynamic raw) {
      if (raw is String) return raw;
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final nestedId = map['_id'];
        if (nestedId is String) return nestedId;
      }
      return '';
    }

    // Normalize pages to a pure List<String>, even if backend sends objects
    List<String> normalizePages(dynamic raw) {
      if (raw is List) {
        return raw.map<String>((item) {
          if (item is String) return item;
          if (item is Map<String, dynamic>) {
            // Common keys from scrapers
            if (item['imageUrl'] is String) return item['imageUrl'] as String;
            if (item['url'] is String) return item['url'] as String;
          }
          return item.toString();
        }).toList();
      }
      return const [];
    }

    // Helper to safely convert to int (handles both int and double)
    int safeInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    }

    // Helper to safely convert to nullable int
    int? safeIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    return ChapterModel(
      id: json['_id'] ?? json['id'] ?? '',
      mangaId: normalizeMangaId(json['mangaId']),
      chapterNumber: safeInt(json['chapterNumber'], 0),
      title: json['title'],
      pages: normalizePages(json['pages']),
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'])
          : null,
      views: safeIntOrNull(json['views']),
      isLocked: json['isLocked'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mangaId': mangaId,
      'chapterNumber': chapterNumber,
      'title': title,
      'pages': pages,
      'releaseDate': releaseDate?.toIso8601String(),
      'views': views,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
