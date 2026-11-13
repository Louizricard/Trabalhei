enum ProposalStatus { pending, accepted, rejected, counterOffered }

class ProposedMilestone {
  final String title;
  final double amount;
  final int days;

  const ProposedMilestone({
    required this.title,
    required this.amount,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount,
    'days': days,
  };

  factory ProposedMilestone.fromJson(Map<String, dynamic> json) =>
      ProposedMilestone(
        title: json['title'] as String? ?? 'Marco',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        days: (json['days'] as num?)?.toInt() ?? 7,
      );
}

class Proposal {
  final String id;
  final String jobId;
  final String freelancerId;
  final String freelancerName;
  final double freelancerRating;
  final double bidAmount;
  final int estimatedDays;
  final String coverLetter;
  final List<ProposedMilestone> proposedMilestones;

  /// Links de trabalhos anteriores (até 10).
  final List<String> portfolioLinks;

  /// Amostras no bucket privado `proposal_attachments` (até 5), no mesmo
  /// formato de `Job.attachments`.
  final List<Map<String, dynamic>> attachments;
  final ProposalStatus status;
  final double? counterPrice;
  final int? counterEstimatedDays;
  final String? counterMessage;
  final String? counterByUserId;
  final DateTime? counterCreatedAt;
  final DateTime createdAt;

  const Proposal({
    required this.id,
    required this.jobId,
    required this.freelancerId,
    required this.freelancerName,
    this.freelancerRating = 0.0,
    required this.bidAmount,
    required this.estimatedDays,
    required this.coverLetter,
    this.proposedMilestones = const [],
    this.portfolioLinks = const [],
    this.attachments = const [],
    this.status = ProposalStatus.pending,
    this.counterPrice,
    this.counterEstimatedDays,
    this.counterMessage,
    this.counterByUserId,
    this.counterCreatedAt,
    required this.createdAt,
  });

  bool get hasActiveCounterOffer =>
      status == ProposalStatus.counterOffered && counterPrice != null;

  Proposal copyWith({
    String? id,
    String? jobId,
    String? freelancerId,
    String? freelancerName,
    double? freelancerRating,
    double? bidAmount,
    int? estimatedDays,
    String? coverLetter,
    List<ProposedMilestone>? proposedMilestones,
    List<String>? portfolioLinks,
    List<Map<String, dynamic>>? attachments,
    ProposalStatus? status,
    double? counterPrice,
    int? counterEstimatedDays,
    String? counterMessage,
    String? counterByUserId,
    DateTime? counterCreatedAt,
    DateTime? createdAt,
    bool clearCounterOffer = false,
  }) {
    return Proposal(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      freelancerRating: freelancerRating ?? this.freelancerRating,
      bidAmount: bidAmount ?? this.bidAmount,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      coverLetter: coverLetter ?? this.coverLetter,
      proposedMilestones: proposedMilestones ?? this.proposedMilestones,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      counterPrice: clearCounterOffer
          ? null
          : counterPrice ?? this.counterPrice,
      counterEstimatedDays: clearCounterOffer
          ? null
          : counterEstimatedDays ?? this.counterEstimatedDays,
      counterMessage: clearCounterOffer
          ? null
          : counterMessage ?? this.counterMessage,
      counterByUserId: clearCounterOffer
          ? null
          : counterByUserId ?? this.counterByUserId,
      counterCreatedAt: clearCounterOffer
          ? null
          : counterCreatedAt ?? this.counterCreatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Proposal.fromJson(Map<String, dynamic> json) {
    String freelancerName = 'Freelancer';
    double freelancerRating = 0.0;

    if (json['profiles'] != null && json['profiles'] is Map) {
      final p = json['profiles'] as Map<String, dynamic>;
      freelancerName = p['full_name'] as String? ?? 'Freelancer';
      freelancerRating = (p['rating'] as num?)?.toDouble() ?? 0.0;
    }

    return Proposal(
      id: json['id'] as String,
      jobId: json['job_id'] as String? ?? '',
      freelancerId: json['freelancer_id'] as String? ?? '',
      freelancerName: freelancerName,
      freelancerRating: freelancerRating,
      bidAmount: (json['bid_amount'] as num?)?.toDouble() ?? 0.0,
      estimatedDays: (json['estimated_days'] as num?)?.toInt() ?? 14,
      coverLetter: json['cover_letter'] as String? ?? '',
      proposedMilestones:
          (json['proposed_milestones'] as List<dynamic>?)
              ?.map(
                (e) => ProposedMilestone.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      portfolioLinks: [
        for (final link in json['portfolio_links'] as List<dynamic>? ?? [])
          if (link is String) link,
      ],
      attachments: [
        for (final item in json['attachments'] as List<dynamic>? ?? [])
          if (item is Map) Map<String, dynamic>.from(item),
      ],
      status: parseStatus(json['status'] as String?),
      counterPrice: (json['counter_price'] as num?)?.toDouble(),
      counterEstimatedDays: (json['counter_estimated_days'] as num?)?.toInt(),
      counterMessage: json['counter_message'] as String?,
      counterByUserId: json['counter_by_user_id'] as String?,
      counterCreatedAt: json['counter_created_at'] != null
          ? DateTime.tryParse(json['counter_created_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static String statusToString(ProposalStatus s) {
    switch (s) {
      case ProposalStatus.accepted:
        return 'accepted';
      case ProposalStatus.rejected:
        return 'rejected';
      case ProposalStatus.counterOffered:
        return 'counter_offered';
      case ProposalStatus.pending:
        return 'pending';
    }
  }

  static ProposalStatus parseStatus(String? status) {
    switch (status) {
      case 'accepted':
        return ProposalStatus.accepted;
      case 'rejected':
        return ProposalStatus.rejected;
      case 'counter_offered':
      case 'counterOffered':
        return ProposalStatus.counterOffered;
      default:
        return ProposalStatus.pending;
    }
  }
}
