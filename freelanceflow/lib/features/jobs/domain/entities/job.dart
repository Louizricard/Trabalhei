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
  final DateTime? featuredUntil;
  final bool isUrgent;
  final List<String> skillsRequired;
  final List<Map<String, dynamic>> attachments;
  final int proposalsCount;
  final String? imageUrl;
  final DateTime createdAt;

  const Job({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientRating = 0.0,
    required this.title,
    required this.category,
    required this.description,
    this.contractType = ContractType.fixed,
    required this.budgetMin,
    required this.budgetMax,
    this.deadlineDays = 30,
    this.experienceLevel = ExperienceLevel.all,
    this.status = JobStatus.open,
    this.featuredUntil,
    this.isUrgent = false,
    this.skillsRequired = const [],
    this.attachments = const [],
    this.proposalsCount = 0,
    this.imageUrl,
    required this.createdAt,
  });

  /// Vaga em destaque (pago) enquanto `featured_until` estiver no futuro.
  bool get isFeatured =>
      featuredUntil != null && featuredUntil!.isAfter(DateTime.now());

  factory Job.fromJson(Map<String, dynamic> json) {
    String clientName = 'Cliente';
    double clientRating = 0.0;
    int proposalsCount = 0;

    if (json['profiles'] != null && json['profiles'] is Map) {
      final p = json['profiles'] as Map<String, dynamic>;
      clientName = p['full_name'] as String? ?? 'Cliente';
      clientRating = (p['rating'] as num?)?.toDouble() ?? 0.0;
    }

    // Campo calculado no banco (conta todas as propostas, não só as visíveis
    // pela RLS); o embed `proposals(count)` fica como alternativa.
    if (json['proposals_count'] is num) {
      proposalsCount = (json['proposals_count'] as num).toInt();
    } else if (json['proposals'] != null &&
        json['proposals'] is List &&
        (json['proposals'] as List).isNotEmpty) {
      final first = (json['proposals'] as List).first;
      if (first is Map && first.containsKey('count')) {
        proposalsCount = (first['count'] as num?)?.toInt() ?? 0;
      }
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
      featuredUntil: json['featured_until'] != null
          ? DateTime.tryParse(json['featured_until'] as String)
          : null,
      isUrgent: json['is_urgent'] as bool? ?? false,
      skillsRequired:
          (json['skills_required'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      attachments: parsedAttachments,
      proposalsCount: proposalsCount,
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Apenas colunas editáveis pelo cliente (status, destaque e dono são do servidor).
  Map<String, dynamic> toWriteJson() {
    return {
      'title': title,
      'category': category,
      'description': description,
      'contract_type': contractType == ContractType.hourly ? 'hourly' : 'fixed',
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'deadline_days': deadlineDays,
      'experience_level': experienceLevel.name,
      'is_urgent': isUrgent,
      'skills_required': skillsRequired,
      'attachments': attachments,
      'image_url': imageUrl,
    };
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
