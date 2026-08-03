class FreelancerDashboardStats {
  final double availableBalance;
  final double escrowBalance;
  final double monthlyEarnings;
  final int activeContractsCount;
  final int pendingProposalsCount;
  final double jobSuccessScore; // e.g. 98.5%
  final List<double> monthlyChartData;

  const FreelancerDashboardStats({
    required this.availableBalance,
    required this.escrowBalance,
    required this.monthlyEarnings,
    required this.activeContractsCount,
    required this.pendingProposalsCount,
    required this.jobSuccessScore,
    required this.monthlyChartData,
  });
}

class ClientDashboardStats {
  final double totalSpent;
  final double activeEscrowBalance;
  final int activeJobsCount;
  final int activeContractsCount;
  final int unreviewedProposalsCount;

  const ClientDashboardStats({
    required this.totalSpent,
    required this.activeEscrowBalance,
    required this.activeJobsCount,
    required this.activeContractsCount,
    required this.unreviewedProposalsCount,
  });
}
