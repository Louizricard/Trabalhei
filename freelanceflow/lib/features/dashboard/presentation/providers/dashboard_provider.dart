import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/dashboard_stats.dart';

final freelancerStatsProvider = FutureProvider.autoDispose<FreelancerDashboardStats>((
  ref,
) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authProvider).value;

  if (user == null) {
    return const FreelancerDashboardStats(
      availableBalance: 0,
      escrowBalance: 0,
      monthlyEarnings: 0,
      activeContractsCount: 0,
      pendingProposalsCount: 0,
      jobSuccessScore: 100.0,
      monthlyChartData: [0, 0, 0, 0, 0, 0],
    );
  }

  double availableBalance = 0.0;
  double monthlyEarnings = 0.0;
  final chartData = <double>[0, 0, 0, 0, 0, 0];
  final now = DateTime.now();

  try {
    final txResponse = await supabase
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    for (final tx in (txResponse as List<dynamic>)) {
      final type = tx['type'] as String?;
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final createdAt =
          DateTime.tryParse(tx['created_at'] as String? ?? '') ?? now;

      if (type == 'escrow_release' || type == 'deposit') {
        availableBalance += amount;
      } else {
        availableBalance -= amount;
      }

      if (type == 'escrow_release') {
        final monthDiff =
            (now.year - createdAt.year) * 12 + now.month - createdAt.month;
        if (monthDiff >= 0 && monthDiff < 6) {
          chartData[5 - monthDiff] += amount;
        }
        if (createdAt.year == now.year && createdAt.month == now.month) {
          monthlyEarnings += amount;
        }
      }
    }
    if (user.walletBalance > 0) {
      availableBalance = user.walletBalance;
    }
  } catch (_) {}

  double escrowBalance = 0.0;
  int activeContracts = 0;
  try {
    final contracts = await supabase
        .from('contracts')
        .select('escrow_amount')
        .eq('freelancer_id', user.id)
        .eq('status', 'active');

    for (final c in (contracts as List<dynamic>)) {
      activeContracts++;
      escrowBalance += (c['escrow_amount'] as num?)?.toDouble() ?? 0.0;
    }
  } catch (_) {}

  int pendingProposals = 0;
  try {
    final proposals = await supabase
        .from('proposals')
        .select('id')
        .eq('freelancer_id', user.id)
        .eq('status', 'pending');
    pendingProposals = (proposals as List<dynamic>).length;
  } catch (_) {}

  final successScore = (user.rating / 5.0) * 100.0;

  return FreelancerDashboardStats(
    availableBalance: availableBalance < 0 ? 0.0 : availableBalance,
    escrowBalance: escrowBalance,
    monthlyEarnings: monthlyEarnings,
    activeContractsCount: activeContracts,
    pendingProposalsCount: pendingProposals,
    jobSuccessScore: successScore > 0 ? successScore : 100.0,
    monthlyChartData: chartData,
  );
});

final clientStatsProvider = FutureProvider.autoDispose<ClientDashboardStats>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authProvider).value;

  if (user == null) {
    return const ClientDashboardStats(
      totalSpent: 0,
      activeEscrowBalance: 0,
      activeJobsCount: 0,
      activeContractsCount: 0,
      unreviewedProposalsCount: 0,
    );
  }

  double totalSpent = 0.0;
  try {
    final txs = await supabase
        .from('transactions')
        .select('amount')
        .eq('user_id', user.id)
        .eq('type', 'deposit');

    for (final t in (txs as List<dynamic>)) {
      totalSpent += (t['amount'] as num?)?.toDouble() ?? 0.0;
    }
  } catch (_) {}

  double activeEscrow = 0.0;
  int activeContracts = 0;
  try {
    final contracts = await supabase
        .from('contracts')
        .select('escrow_amount')
        .eq('client_id', user.id)
        .eq('status', 'active');

    for (final c in (contracts as List<dynamic>)) {
      activeContracts++;
      activeEscrow += (c['escrow_amount'] as num?)?.toDouble() ?? 0.0;
    }
  } catch (_) {}

  int activeJobs = 0;
  try {
    final jobs = await supabase
        .from('jobs')
        .select('id')
        .eq('client_id', user.id)
        .eq('status', 'open');
    activeJobs = (jobs as List<dynamic>).length;
  } catch (_) {}

  int unreviewedProposals = 0;
  try {
    final proposals = await supabase
        .from('proposals')
        .select('id, jobs!inner(client_id)')
        .eq('jobs.client_id', user.id)
        .eq('status', 'pending');
    unreviewedProposals = (proposals as List<dynamic>).length;
  } catch (_) {}

  return ClientDashboardStats(
    totalSpent: totalSpent,
    activeEscrowBalance: activeEscrow,
    activeJobsCount: activeJobs,
    activeContractsCount: activeContracts,
    unreviewedProposalsCount: unreviewedProposals,
  );
});
