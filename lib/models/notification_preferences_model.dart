class NotificationPreferences {
  final bool enabled;
  final List<int> activeHours; // Hours of day when user is active (0-23)
  final bool digestEnabled;
  final String digestFrequency; // 'daily' or 'weekly'
  final int digestTime; // Hour of day for digest (0-23)
  final bool newChaptersEnabled;
  final bool engagementEnabled;
  final bool recommendationsEnabled;
  final Map<String, MangaNotificationSettings> mangaSettings; // mangaId -> settings

  NotificationPreferences({
    this.enabled = true,
    this.activeHours = const [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
    this.digestEnabled = true,
    this.digestFrequency = 'daily',
    this.digestTime = 18, // 6 PM default
    this.newChaptersEnabled = true,
    this.engagementEnabled = true,
    this.recommendationsEnabled = true,
    this.mangaSettings = const {},
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] ?? true,
      activeHours: json['activeHours'] != null
          ? List<int>.from(json['activeHours'])
          : [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
      digestEnabled: json['digestEnabled'] ?? true,
      digestFrequency: json['digestFrequency'] ?? 'daily',
      digestTime: json['digestTime'] ?? 18,
      newChaptersEnabled: json['newChaptersEnabled'] ?? true,
      engagementEnabled: json['engagementEnabled'] ?? true,
      recommendationsEnabled: json['recommendationsEnabled'] ?? true,
      mangaSettings: json['mangaSettings'] != null
          ? (json['mangaSettings'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                MangaNotificationSettings.fromJson(value),
              ),
            )
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'activeHours': activeHours,
      'digestEnabled': digestEnabled,
      'digestFrequency': digestFrequency,
      'digestTime': digestTime,
      'newChaptersEnabled': newChaptersEnabled,
      'engagementEnabled': engagementEnabled,
      'recommendationsEnabled': recommendationsEnabled,
      'mangaSettings': mangaSettings.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  NotificationPreferences copyWith({
    bool? enabled,
    List<int>? activeHours,
    bool? digestEnabled,
    String? digestFrequency,
    int? digestTime,
    bool? newChaptersEnabled,
    bool? engagementEnabled,
    bool? recommendationsEnabled,
    Map<String, MangaNotificationSettings>? mangaSettings,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      activeHours: activeHours ?? this.activeHours,
      digestEnabled: digestEnabled ?? this.digestEnabled,
      digestFrequency: digestFrequency ?? this.digestFrequency,
      digestTime: digestTime ?? this.digestTime,
      newChaptersEnabled: newChaptersEnabled ?? this.newChaptersEnabled,
      engagementEnabled: engagementEnabled ?? this.engagementEnabled,
      recommendationsEnabled: recommendationsEnabled ?? this.recommendationsEnabled,
      mangaSettings: mangaSettings ?? this.mangaSettings,
    );
  }
}

class MangaNotificationSettings {
  final bool enabled;
  final bool immediate; // Send immediately or wait for digest
  final bool onlyNewChapters; // Only notify for new chapters, not updates

  MangaNotificationSettings({
    this.enabled = true,
    this.immediate = true,
    this.onlyNewChapters = true,
  });

  factory MangaNotificationSettings.fromJson(Map<String, dynamic> json) {
    return MangaNotificationSettings(
      enabled: json['enabled'] ?? true,
      immediate: json['immediate'] ?? true,
      onlyNewChapters: json['onlyNewChapters'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'immediate': immediate,
      'onlyNewChapters': onlyNewChapters,
    };
  }

  MangaNotificationSettings copyWith({
    bool? enabled,
    bool? immediate,
    bool? onlyNewChapters,
  }) {
    return MangaNotificationSettings(
      enabled: enabled ?? this.enabled,
      immediate: immediate ?? this.immediate,
      onlyNewChapters: onlyNewChapters ?? this.onlyNewChapters,
    );
  }
}

