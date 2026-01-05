class NotificationModel {
  final String id;
  final String type; // 'new_chapter', 'digest', 'engagement', 'recommendation'
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool read;
  final String? mangaId;
  final String? chapterId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.createdAt,
    this.read = false,
    this.mangaId,
    this.chapterId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'new_chapter',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      read: json['read'] ?? false,
      mangaId: json['mangaId'] ?? json['data']?['mangaId'],
      chapterId: json['chapterId'] ?? json['data']?['chapterId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'read': read,
      'mangaId': mangaId,
      'chapterId': chapterId,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? read,
    String? mangaId,
    String? chapterId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      mangaId: mangaId ?? this.mangaId,
      chapterId: chapterId ?? this.chapterId,
    );
  }
}

