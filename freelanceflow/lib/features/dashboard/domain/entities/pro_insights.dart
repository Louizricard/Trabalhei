/// Dados das ferramentas Pro do freelancer (funções `proposal_stats` e
/// `freelancer_clients` do banco, que exigem o plano Pro).
library;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double? _double(Object? v) => (v as num?)?.toDouble();

class CategoryStat {
  final String category;
  final int sent;
  final int accepted;

  const CategoryStat(this.category, this.sent, this.accepted);

  double get acceptanceRate => sent == 0 ? 0 : accepted / sent;
}

class MonthStat {
  /// `AAAA-MM`.
  final String month;
  final int sent;
  final int accepted;

  const MonthStat(this.month, this.sent, this.accepted);
}

class ProposalStats {
  final int days;
  final int sent;
  final int accepted;
  final int rejected;
  final int pending;
  final int negotiated;
  final double? avgBid;

  /// Valor proposto em relação ao teto do orçamento (1,0 = igual ao teto).
  final double? avgBidVsBudget;

  /// Horas, em média, até o cliente aceitar ou recusar.
  final double? avgDecisionHours;
  final List<CategoryStat> byCategory;
  final List<MonthStat> byMonth;

  const ProposalStats({
    required this.days,
    required this.sent,
    required this.accepted,
    required this.rejected,
    required this.pending,
    required this.negotiated,
    this.avgBid,
    this.avgBidVsBudget,
    this.avgDecisionHours,
    this.byCategory = const [],
    this.byMonth = const [],
  });

  /// Aceitas sobre as já decididas (pendentes não entram na conta).
  double get acceptanceRate {
    final decided = accepted + rejected;
    return decided == 0 ? 0 : accepted / decided;
  }

  /// Propostas que tiveram alguma resposta do cliente.
  double get responseRate =>
      sent == 0 ? 0 : (accepted + rejected + negotiated).clamp(0, sent) / sent;

  factory ProposalStats.fromJson(Map<String, dynamic> json) => ProposalStats(
    days: _int(json['days']),
    sent: _int(json['sent']),
    accepted: _int(json['accepted']),
    rejected: _int(json['rejected']),
    pending: _int(json['pending']),
    negotiated: _int(json['negotiated']),
    avgBid: _double(json['avg_bid']),
    avgBidVsBudget: _double(json['avg_bid_vs_budget']),
    avgDecisionHours: _double(json['avg_decision_hours']),
    byCategory: [
      for (final c in (json['by_category'] as List? ?? const []))
        CategoryStat(
          (c as Map)['category'] as String? ?? 'Outros',
          _int(c['sent']),
          _int(c['accepted']),
        ),
    ],
    byMonth: [
      for (final m in (json['by_month'] as List? ?? const []))
        MonthStat(
          (m as Map)['month'] as String? ?? '',
          _int(m['sent']),
          _int(m['accepted']),
        ),
    ],
  );
}

class ClientProject {
  final String jobId;
  final String title;
  final String proposalStatus;
  final String? contractStatus;
  final double bid;
  final DateTime createdAt;

  const ClientProject({
    required this.jobId,
    required this.title,
    required this.proposalStatus,
    this.contractStatus,
    required this.bid,
    required this.createdAt,
  });

  /// Situação resumida para a lista.
  String get label => switch (contractStatus) {
    'active' => 'Em andamento',
    'completed' => 'Concluído',
    'cancelled' => 'Contrato cancelado',
    _ => switch (proposalStatus) {
      'accepted' => 'Proposta aceita',
      'rejected' => 'Proposta recusada',
      'counter_offered' => 'Em negociação',
      _ => 'Proposta enviada',
    },
  };
}

class ClientSummary {
  final String clientId;
  final String name;
  final String? company;
  final String? avatarUrl;
  final int proposals;
  final int accepted;
  final int activeContracts;
  final int completedContracts;
  final double totalAccepted;
  final DateTime? lastActivity;
  final List<ClientProject> projects;
  final String note;
  final List<String> tags;

  const ClientSummary({
    required this.clientId,
    required this.name,
    this.company,
    this.avatarUrl,
    required this.proposals,
    required this.accepted,
    required this.activeContracts,
    required this.completedContracts,
    required this.totalAccepted,
    this.lastActivity,
    this.projects = const [],
    this.note = '',
    this.tags = const [],
  });

  factory ClientSummary.fromJson(Map<String, dynamic> json) => ClientSummary(
    clientId: json['client_id'] as String,
    name: json['client_name'] as String? ?? 'Cliente',
    company: json['company_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    proposals: _int(json['proposals_count']),
    accepted: _int(json['accepted_count']),
    activeContracts: _int(json['active_contracts']),
    completedContracts: _int(json['completed_contracts']),
    totalAccepted: _double(json['total_accepted']) ?? 0,
    lastActivity: DateTime.tryParse('${json['last_activity']}'),
    projects: [
      for (final p in (json['projects'] as List? ?? const []))
        ClientProject(
          jobId: (p as Map)['job_id'] as String,
          title: p['title'] as String? ?? '',
          proposalStatus: p['proposal_status'] as String? ?? 'pending',
          contractStatus: p['contract_status'] as String?,
          bid: _double(p['bid']) ?? 0,
          createdAt: DateTime.tryParse('${p['created_at']}') ?? DateTime.now(),
        ),
    ],
    note: json['note'] as String? ?? '',
    tags: [for (final t in (json['tags'] as List? ?? const [])) '$t'],
  );
}
