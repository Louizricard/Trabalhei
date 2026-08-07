enum ContractType { fixed, hourly }

enum JobStatus { open, inProgress, completed, cancelled }

enum ExperienceLevel { all, junior, pleno, senior }

class Job {
  final String id;
  final String clientId;
  final String clientName;
  final double clientRating;
  final String title;
  final String category;
  final String description;
  final ContractType contractType;
  final double budgetMin;
  final double budgetMax;
  final int deadlineDays;
  final ExperienceLevel experienceLevel;
  final JobStatus status;
  final bool isFeatured;
  final bool isUrgent;
  final List<String> skillsRequired;
  final List<String> screeningQuestions;
  final List<Map<String, dynamic>> attachments;
  final int proposalsCount;
  final DateTime createdAt;

  const Job({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientRating = 5.0,
    required this.title,
    required this.category,
    required this.description,
    this.contractType = ContractType.fixed,
    required this.budgetMin,
    required this.budgetMax,
    this.deadlineDays = 30,
    this.experienceLevel = ExperienceLevel.all,
    this.status = JobStatus.open,
    this.isFeatured = false,
    this.isUrgent = false,
    this.skillsRequired = const [],
    this.screeningQuestions = const [],
    this.attachments = const [],
    this.proposalsCount = 0,
    required this.createdAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    String clientName = 'Cliente';
    double clientRating = 5.0;
    int proposalsCount = 0;

    if (json['profiles'] != null && json['profiles'] is Map) {
      final p = json['profiles'] as Map<String, dynamic>;
      clientName = p['full_name'] as String? ?? 'Cliente';
      clientRating = (p['rating'] as num?)?.toDouble() ?? 5.0;
    } else if (json['client_name'] != null) {
      clientName = json['client_name'] as String;
      clientRating = (json['client_rating'] as num?)?.toDouble() ?? 5.0;
    }

    if (json['proposals'] != null &&
        json['proposals'] is List &&
        (json['proposals'] as List).isNotEmpty) {
      final first = (json['proposals'] as List).first;
      if (first is Map && first.containsKey('count')) {
        proposalsCount = (first['count'] as num?)?.toInt() ?? 0;
      }
    } else if (json['proposals_count'] != null) {
      proposalsCount = (json['proposals_count'] as num).toInt();
    }

    final rawAttachments = json['attachments'];
    List<Map<String, dynamic>> parsedAttachments = [];
    if (rawAttachments is List) {
      parsedAttachments = rawAttachments
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return Job(
      id: json['id'] as String,
      clientId: json['client_id'] as String? ?? '',
      clientName: clientName,
      clientRating: clientRating,
      title: json['title'] as String? ?? 'Sem título',
      category: json['category'] as String? ?? 'Mobile',
      description: json['description'] as String? ?? '',
      contractType: json['contract_type'] == 'hourly'
          ? ContractType.hourly
          : ContractType.fixed,
      budgetMin: (json['budget_min'] as num?)?.toDouble() ?? 0.0,
      budgetMax: (json['budget_max'] as num?)?.toDouble() ?? 0.0,
      deadlineDays: (json['deadline_days'] as num?)?.toInt() ?? 30,
      experienceLevel: _parseExpLevel(json['experience_level'] as String?),
      status: _parseJobStatus(json['status'] as String?),
      isFeatured: json['is_featured'] as bool? ?? false,
      isUrgent: json['is_urgent'] as bool? ?? false,
      skillsRequired:
          (json['skills_required'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      screeningQuestions:
          (json['screening_questions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      attachments: parsedAttachments,
      proposalsCount: proposalsCount,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'title': title,
      'category': category,
      'description': description,
      'contract_type': contractType == ContractType.hourly ? 'hourly' : 'fixed',
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'deadline_days': deadlineDays,
      'experience_level': experienceLevel.name,
      'status': _jobStatusToString(status),
      'is_featured': isFeatured,
      'is_urgent': isUrgent,
      'skills_required': skillsRequired,
      'screening_questions': screeningQuestions,
      'attachments': attachments,
    };
  }

  static String _jobStatusToString(JobStatus s) {
    switch (s) {
      case JobStatus.inProgress:
        return 'in_progress';
      case JobStatus.completed:
        return 'completed';
      case JobStatus.cancelled:
        return 'cancelled';
      case JobStatus.open:
        return 'open';
    }
  }

  static ExperienceLevel _parseExpLevel(String? level) {
    switch (level) {
      case 'junior':
        return ExperienceLevel.junior;
      case 'pleno':
        return ExperienceLevel.pleno;
      case 'senior':
        return ExperienceLevel.senior;
      default:
        return ExperienceLevel.all;
    }
  }

  static JobStatus _parseJobStatus(String? status) {
    switch (status) {
      case 'in_progress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.open;
    }
  }
}
