class MangaModel {
  final String id;
  final String title;
  final String? description;
  final String? cover;
  final List<String> genres;
  final String status; // 'ongoing', 'completed', 'hiatus'
  final String type; // 'manga', 'manhwa', 'manhua'
  final String? author;
  final String? artist;
  final double? rating;
  final int? ratingCount;
  final int? totalChapters;
  final int? totalViews;
  final int? followersCount;
  final double? userRating;
  final List<MangaModel>? relatedManga;
  final DateTime? releaseDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool? isAdult;
  final String? ageRating;
  final int? freeChapters;
  final String? source;

  MangaModel({
    required this.id,
    required this.title,
    this.description,
    this.cover,
    this.genres = const [],
    this.status = 'ongoing',
    this.type = 'manhwa',
    this.author,
    this.artist,
    this.rating,
    this.ratingCount,
    this.totalChapters,
    this.totalViews,
    this.followersCount,
    this.userRating,
    this.relatedManga,
    this.releaseDate,
    required this.createdAt,
    this.updatedAt,
    this.isAdult,
    this.ageRating,
    this.freeChapters,
    this.source,
  });

  factory MangaModel.fromJson(Map<String, dynamic> json) {
    return MangaModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      cover: json['cover'],
      genres: json['genres'] != null ? List<String>.from(json['genres']) : [],
      status: json['status'] ?? 'ongoing',
      type: json['type'] ?? 'manhwa',
      author: json['author'],
      artist: json['artist'],
      rating: json['rating'] != null
          ? (json['rating'] is int
                ? json['rating'].toDouble()
                : json['rating'] as double)
          : null,
      ratingCount: json['ratingCount'],
      totalChapters: json['totalChapters'],
      totalViews: json['totalViews'],
      followersCount: json['followersCount'],
      userRating: json['userRating'] != null
          ? (json['userRating'] is int
                ? json['userRating'].toDouble()
                : json['userRating'] as double)
          : null,
      relatedManga: json['relatedManga'] != null
          ? (json['relatedManga'] as List)
                .map((m) => MangaModel.fromJson(m))
                .toList()
          : null,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isAdult: json['isAdult'],
      ageRating: json['ageRating'],
      freeChapters: json['freeChapters'],
      source: json['source'],
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cover': cover,
      'genres': genres,
      'status': status,
      'type': type,
      'author': author,
      'artist': artist,
      'rating': rating,
      'ratingCount': ratingCount,
      'totalChapters': totalChapters,
      'totalViews': totalViews,
      'followersCount': followersCount,
      'userRating': userRating,
      'releaseDate': releaseDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
