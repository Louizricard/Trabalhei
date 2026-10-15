import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../../proposals/presentation/providers/proposals_provider.dart';
import '../../data/billing_repository.dart';
import '../../domain/entities/billing.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.watch(supabaseClientProvider));
});

final subscriptionProvider = FutureProvider.autoDispose<Subscription?>((ref) {
  // Recarrega quando o perfil muda (o webhook atualiza o plano no servidor).
  ref.watch(authProvider);
  return ref.watch(billingRepositoryProvider).getSubscription();
});

/// Recarrega plano, assinatura, cota e vagas após o retorno do checkout.
Future<void> refreshBillingState(WidgetRef ref) async {
  await ref.read(authProvider.notifier).refreshProfile();
  ref.invalidate(subscriptionProvider);
  ref.invalidate(proposalQuotaProvider);
  ref.invalidate(jobsListProvider);
}
