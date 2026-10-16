import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/dashboard_stats.dart';

/// Conta contratos concluídos por mês nos últimos 6 meses (índice 5 = mês atual).
List<double> _completedPerMonth(List<Map<String, dynamic>> completed) {
  final now = DateTime.now();
  final result = List<double>.filled(6, 0);
  for (final row in completed) {
    final completedAt = DateTime.tryParse(
      row['completed_at'] as String? ?? '',
    )?.toLocal();
    if (completedAt == null) continue;
    final diff =
        (now.year - completedAt.year) * 12 + now.month - completedAt.month;
    if (diff >= 0 && diff < 6) result[5 - diff] += 1;
  }
  return result;
}

Future<List<Map<String, dynamic>>> _contracts(
  SupabaseClient supabase,
  String column,
  String userId,
) async {
  final rows = await supabase
      .from('contracts')
      .select('status, completed_at')
      .eq(column, userId);
  return List<Map<String, dynamic>>.from(rows);
}

final freelancerStatsProvider =
    FutureProvider.autoDispose<FreelancerDashboardStats>((ref) async {
      final supabase = ref.watch(supabaseClientProvider);
      final user = ref.watch(authProvider).value;
      if (user == null) throw Exception('Usuário não autenticado.');

      final contracts = await _contracts(supabase, 'freelancer_id', user.id);
      final proposals = List<Map<String, dynamic>>.from(
        await supabase
            .from('proposals')
            .select('status')
            .eq('freelancer_id', user.id),
      );

      final completed = contracts
          .where((c) => c['status'] == 'completed')
          .toList();
      int countProposals(String status) =>
          proposals.where((p) => p['status'] == status).length;

      return FreelancerDashboardStats(
        activeContractsCount: contracts
            .where((c) => c['status'] == 'active')
            .length,
        completedContractsCount: completed.length,
        pendingProposalsCount: countProposals('pending'),
        sentProposalsCount: proposals.length,
        acceptedProposalsCount: countProposals('accepted'),
        monthlyCompleted: _completedPerMonth(completed),
      );
    });

final clientStatsProvider = FutureProvider.autoDispose<ClientDashboardStats>((
  ref,
) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) throw Exception('Usuário não autenticado.');

  final contracts = await _contracts(supabase, 'client_id', user.id);
  final openJobs = List<Map<String, dynamic>>.from(
    await supabase
        .from('jobs')
        .select('id')
        .eq('client_id', user.id)
        .eq('status', 'open'),
  );
  final pendingProposals = List<Map<String, dynamic>>.from(
    await supabase
        .from('proposals')
        .select('id, jobs!inner(client_id)')
        .eq('jobs.client_id', user.id)
        .eq('status', 'pending'),
  );
  final completed = contracts
      .where((c) => c['status'] == 'completed')
      .toList();

  return ClientDashboardStats(
    activeJobsCount: openJobs.length,
    activeContractsCount: contracts
        .where((c) => c['status'] == 'active')
        .length,
    completedContractsCount: completed.length,
    unreviewedProposalsCount: pendingProposals.length,
    monthlyCompleted: _completedPerMonth(completed),
  );
});
