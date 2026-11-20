import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

/// Ids que o usuário logado bloqueou (refaz ao trocar de conta).
final blockedUsersProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return const {};
  return ref.watch(adminRepositoryProvider).blockedUsers();
});

/// O usuário logado é administrador? (Refaz a consulta ao trocar de conta.)
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return false;
  try {
    return await ref.watch(adminRepositoryProvider).isAdmin();
  } catch (_) {
    return false;
  }
});

final adminOverviewProvider = FutureProvider.autoDispose<AdminOverview>(
  (ref) => ref.watch(adminRepositoryProvider).overview(),
);

final adminReportsProvider = FutureProvider.autoDispose
    .family<List<AdminReport>, String>(
      (ref, status) => ref.watch(adminRepositoryProvider).reports(status),
    );

final adminBugReportsProvider = FutureProvider.autoDispose
    .family<List<AdminBugReport>, String>(
      (ref, status) => ref.watch(adminRepositoryProvider).bugReports(status),
    );

final adminUsersProvider = FutureProvider.autoDispose
    .family<List<AdminUser>, String>(
      (ref, query) => ref.watch(adminRepositoryProvider).users(query),
    );

final adminJobsProvider = FutureProvider.autoDispose
    .family<List<AdminJob>, String>(
      (ref, query) => ref.watch(adminRepositoryProvider).jobs(query),
    );

final adminCouponsProvider = FutureProvider.autoDispose<List<AdminCoupon>>(
  (ref) => ref.watch(adminRepositoryProvider).coupons(),
);
