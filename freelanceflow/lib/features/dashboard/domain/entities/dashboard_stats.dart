class FreelancerDashboardStats {
  final int activeContractsCount;
  final int completedContractsCount;
  final int pendingProposalsCount;
  final int sentProposalsCount;
  final int acceptedProposalsCount;

  /// Contratos concluídos por mês nos últimos 6 meses (do mais antigo ao atual).
  final List<double> monthlyCompleted;

  const FreelancerDashboardStats({
    required this.activeContractsCount,
    required this.completedContractsCount,
    required this.pendingProposalsCount,
    required this.sentProposalsCount,
    required this.acceptedProposalsCount,
    required this.monthlyCompleted,
  });

  /// Taxa de sucesso: propostas aceitas ÷ propostas enviadas (0–100).
  double get proposalSuccessRate => sentProposalsCount == 0
      ? 0
      : acceptedProposalsCount / sentProposalsCount * 100;
}

class ClientDashboardStats {
  final int activeJobsCount;
  final int activeContractsCount;
  final int completedContractsCount;
  final int unreviewedProposalsCount;

  /// Contratos concluídos por mês nos últimos 6 meses (do mais antigo ao atual).
  final List<double> monthlyCompleted;

  const ClientDashboardStats({
    required this.activeJobsCount,
    required this.activeContractsCount,
    required this.completedContractsCount,
    required this.unreviewedProposalsCount,
    required this.monthlyCompleted,
  });
}
