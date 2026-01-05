class AchievementModel {
  final String type;
  final DateTime unlockedAt;

  AchievementModel({
    required this.type,
    required this.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      type: json['type']?.toString() ?? '',
      unlockedAt: json['unlockedAt'] != null
          ? (json['unlockedAt'] is DateTime
              ? json['unlockedAt'] as DateTime
              : DateTime.parse(json['unlockedAt'].toString()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'unlockedAt': unlockedAt.toIso8601String(),
    };
  }

  // Achievement metadata
  String get title {
    switch (type) {
      case 'first_chapter':
        return 'First Steps';
      case 'ten_chapters':
        return 'Getting Started';
      case 'hundred_chapters':
        return 'Century Reader';
      case 'week_streak':
        return 'Week Warrior';
      case 'month_streak':
        return 'Monthly Master';
      case 'year_streak':
        return 'Year Champion';
      case 'bookworm':
        return 'Bookworm';
      case 'speed_reader':
        return 'Speed Reader';
      default:
        return 'Achievement';
    }
  }

  String get description {
    switch (type) {
      case 'first_chapter':
        return 'Read your first chapter';
      case 'ten_chapters':
        return 'Read 10 chapters';
      case 'hundred_chapters':
        return 'Read 100 chapters';
      case 'week_streak':
        return 'Maintain a 7-day reading streak';
      case 'month_streak':
        return 'Maintain a 30-day reading streak';
      case 'year_streak':
        return 'Maintain a 365-day reading streak';
      case 'bookworm':
        return 'Read extensively across multiple manga';
      case 'speed_reader':
        return 'Read chapters at an impressive pace';
      default:
        return 'Unlock this achievement';
    }
  }

  String get icon {
    switch (type) {
      case 'first_chapter':
        return '🎯';
      case 'ten_chapters':
        return '📖';
      case 'hundred_chapters':
        return '📚';
      case 'week_streak':
        return '🔥';
      case 'month_streak':
        return '⭐';
      case 'year_streak':
        return '👑';
      case 'bookworm':
        return '🐛';
      case 'speed_reader':
        return '⚡';
      default:
        return '🏆';
    }
  }

  int get rarity {
    switch (type) {
      case 'first_chapter':
        return 1; // Common
      case 'ten_chapters':
        return 1; // Common
      case 'hundred_chapters':
        return 2; // Uncommon
      case 'week_streak':
        return 2; // Uncommon
      case 'month_streak':
        return 3; // Rare
      case 'year_streak':
        return 4; // Epic
      case 'bookworm':
        return 3; // Rare
      case 'speed_reader':
        return 2; // Uncommon
      default:
        return 1;
    }
  }
}

