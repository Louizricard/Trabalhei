enum UserRole {
  client,
  freelancer,
  admin;

  static UserRole fromString(String? role) {
    switch (role) {
      case 'client':
        return UserRole.client;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.freelancer;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.client:
        return 'client';
      case UserRole.admin:
        return 'admin';
      case UserRole.freelancer:
        return 'freelancer';
    }
  }

  String get label {
    switch (this) {
      case UserRole.client:
        return 'Cliente';
      case UserRole.freelancer:
        return 'Freelancer';
      case UserRole.admin:
        return 'Administrador';
    }
  }
}

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? avatarUrl;
  final String? companyName;
  final String? bio;
  final double hourlyRate;
  final List<String> skills;
  final double rating;
  final int reviewsCount;
  final int completedJobsCount;
  final String availabilityStatus;
  final bool isVerified;
  final String plan;
  final DateTime? planExpiresAt;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.companyName,
    this.bio,
    this.hourlyRate = 0.0,
    this.skills = const [],
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.completedJobsCount = 0,
    this.availabilityStatus = 'available',
    this.isVerified = false,
    this.plan = 'free',
    this.planExpiresAt,
    required this.createdAt,
  });

  /// Plano Pro ativo (a assinatura é gerenciada exclusivamente pelo servidor).
  bool get isPro =>
      plan == 'pro' &&
      (planExpiresAt == null || planExpiresAt!.isAfter(DateTime.now()));

  UserProfile copyWith({
    String? fullName,
    UserRole? role,
    String? avatarUrl,
    String? companyName,
    String? bio,
    double? hourlyRate,
    List<String>? skills,
    double? rating,
    int? reviewsCount,
    int? completedJobsCount,
    String? availabilityStatus,
    bool? isVerified,
    String? plan,
    DateTime? planExpiresAt,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      companyName: companyName ?? this.companyName,
      bio: bio ?? this.bio,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      skills: skills ?? this.skills,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      completedJobsCount: completedJobsCount ?? this.completedJobsCount,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isVerified: isVerified ?? this.isVerified,
      plan: plan ?? this.plan,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      createdAt: createdAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Usuário',
      role: UserRole.fromString(json['role'] as String?),
      avatarUrl: json['avatar_url'] as String?,
      companyName: json['company_name'] as String?,
      bio: json['bio'] as String?,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      skills:
          (json['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      completedJobsCount: (json['completed_jobs_count'] as num?)?.toInt() ?? 0,
      availabilityStatus: json['availability_status'] as String? ?? 'available',
      isVerified: json['is_verified'] as bool? ?? false,
      plan: json['plan'] as String? ?? 'free',
      planExpiresAt: json['plan_expires_at'] != null
          ? DateTime.tryParse(json['plan_expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Serializa exclusivamente os campos cadastrais editáveis pelo usuário.
  /// Campos administrativos, de plano e métricas (plan, role, rating, etc.)
  /// são deliberadamente omitidos para proteger a integridade do RLS.
  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'company_name': companyName,
      'bio': bio,
      'hourly_rate': hourlyRate,
      'skills': skills,
      'availability_status': availabilityStatus,
    };
  }
}
