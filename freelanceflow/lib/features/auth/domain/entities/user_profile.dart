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
  final String? phone;
  final String? companyName;
  final String? bio;
  final double hourlyRate;
  final List<String> skills;
  final double rating;
  final int completedJobsCount;
  final String availabilityStatus;
  final bool isVerified;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.companyName,
    this.bio,
    this.hourlyRate = 0.0,
    this.skills = const [],
    this.rating = 5.0,
    this.completedJobsCount = 0,
    this.availabilityStatus = 'available',
    this.isVerified = false,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? fullName,
    UserRole? role,
    String? avatarUrl,
    String? phone,
    String? companyName,
    String? bio,
    double? hourlyRate,
    List<String>? skills,
    double? rating,
    int? completedJobsCount,
    String? availabilityStatus,
    bool? isVerified,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      companyName: companyName ?? this.companyName,
      bio: bio ?? this.bio,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      skills: skills ?? this.skills,
      rating: rating ?? this.rating,
      completedJobsCount: completedJobsCount ?? this.completedJobsCount,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isVerified: isVerified ?? this.isVerified,
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
      phone: json['phone'] as String?,
      companyName: json['company_name'] as String?,
      bio: json['bio'] as String?,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobsCount: json['completed_jobs_count'] as int? ?? 0,
      availabilityStatus: json['availability_status'] as String? ?? 'available',
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.toDbString(),
      'avatar_url': avatarUrl,
      'phone': phone,
      'company_name': companyName,
      'bio': bio,
      'hourly_rate': hourlyRate,
      'skills': skills,
      'rating': rating,
      'completed_jobs_count': completedJobsCount,
      'availability_status': availabilityStatus,
      'is_verified': isVerified,
    };
  }
}
