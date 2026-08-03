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

  Map<String, dynamic> toJson() => {'title': title, 'amount': amount, 'days': days};

  factory ProposedMilestone.fromJson(Map<String, dynamic> json) => ProposedMilestone(
        title: json['title'] as String? ?? 'Marco',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        days: json['days'] as int? ?? 7,
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
  final ProposalStatus status;
  final DateTime createdAt;

  const Proposal({
    required this.id,
    required this.jobId,
    required this.freelancerId,
    required this.freelancerName,
    this.freelancerRating = 5.0,
    required this.bidAmount,
    required this.estimatedDays,
    required this.coverLetter,
    this.proposedMilestones = const [],
    this.status = ProposalStatus.pending,
    required this.createdAt,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    String freelancerName = 'Freelancer';
    double freelancerRating = 5.0;

    if (json['profiles'] != null && json['profiles'] is Map) {
      final p = json['profiles'] as Map<String, dynamic>;
      freelancerName = p['full_name'] as String? ?? 'Freelancer';
      freelancerRating = (p['rating'] as num?)?.toDouble() ?? 5.0;
    } else if (json['freelancer_name'] != null) {
      freelancerName = json['freelancer_name'] as String;
      freelancerRating = (json['freelancer_rating'] as num?)?.toDouble() ?? 5.0;
    }

    final rawAmount = json['bid_amount'] ?? json['amount'];
    final rawLetter = json['cover_letter'] ?? json['message'] ?? '';

    return Proposal(
      id: json['id'] as String,
      jobId: json['job_id'] as String? ?? '',
      freelancerId: json['freelancer_id'] as String? ?? '',
      freelancerName: freelancerName,
      freelancerRating: freelancerRating,
      bidAmount: (rawAmount as num?)?.toDouble() ?? 0.0,
      estimatedDays: json['estimated_days'] as int? ?? 14,
      coverLetter: rawLetter as String,
      proposedMilestones: (json['proposed_milestones'] as List<dynamic>?)
              ?.map((e) => ProposedMilestone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: _parseStatus(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'freelancer_id': freelancerId,
      'bid_amount': bidAmount,
      'estimated_days': estimatedDays,
      'cover_letter': coverLetter,
      'proposed_milestones': proposedMilestones.map((m) => m.toJson()).toList(),
      'status': status.name,
    };
  }

  static ProposalStatus _parseStatus(String? status) {
    switch (status) {
      case 'accepted':
        return ProposalStatus.accepted;
      case 'rejected':
        return ProposalStatus.rejected;
      case 'counter_offered':
        return ProposalStatus.counterOffered;
      default:
        return ProposalStatus.pending;
    }
  }
}
