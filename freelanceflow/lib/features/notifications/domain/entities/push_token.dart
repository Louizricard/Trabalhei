/// Pure Dart entity representing a registered FCM Push Notification Token
class PushToken {
  final String id;
  final String userId;
  final String token;
  final String platform;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PushToken({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PushToken.fromJson(Map<String, dynamic> json) {
    return PushToken(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      token: json['token'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'token': token,
      'platform': platform,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PushToken copyWith({
    String? id,
    String? userId,
    String? token,
    String? platform,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PushToken(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PushToken &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          token == other.token &&
          platform == other.platform;

  @override
  int get hashCode =>
      id.hashCode ^ userId.hashCode ^ token.hashCode ^ platform.hashCode;
}
