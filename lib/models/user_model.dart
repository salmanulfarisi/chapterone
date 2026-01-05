import 'achievement_model.dart';

class UserModel {
  final String id;
  final String email;
  final String? username;
  final String? avatar;
  final String role; // 'user', 'admin', 'moderator'
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? preferences;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool? ageVerified;
  final DateTime? ageVerifiedAt;
  final List<AchievementModel>? achievements;

  UserModel({
    required this.id,
    required this.email,
    this.username,
    this.avatar,
    this.role = 'user',
    this.profile,
    this.preferences,
    required this.createdAt,
    this.updatedAt,
    this.ageVerified,
    this.ageVerifiedAt,
    this.achievements,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert nested maps
    Map<String, dynamic>? convertNestedMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    }

    return UserModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString(),
      avatar: json['avatar']?.toString(),
      role: json['role']?.toString() ?? 'user',
      profile: convertNestedMap(json['profile']),
      preferences: convertNestedMap(json['preferences']),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
                ? json['createdAt'] as DateTime
                : DateTime.parse(json['createdAt'].toString()))
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is DateTime
                ? json['updatedAt'] as DateTime
                : DateTime.parse(json['updatedAt'].toString()))
          : null,
      ageVerified: json['ageVerified'] as bool?,
      ageVerifiedAt: json['ageVerifiedAt'] != null
          ? (json['ageVerifiedAt'] is DateTime
                ? json['ageVerifiedAt'] as DateTime
                : DateTime.parse(json['ageVerifiedAt'].toString()))
          : null,
      achievements: json['achievements'] != null
          ? (json['achievements'] as List)
              .map((a) => AchievementModel.fromJson(a as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatar': avatar,
      'role': role,
      'profile': profile,
      'preferences': preferences,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isModerator => role == 'moderator' || isAdmin;
}
