import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

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
