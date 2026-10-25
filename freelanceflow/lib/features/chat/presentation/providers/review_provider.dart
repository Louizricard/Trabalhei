import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/contract_review.dart';

/// Avaliação que o usuário logado já deixou no contrato, ou null se ainda não
/// avaliou. Cada parte avalia uma vez (o banco impede a segunda).
final myContractReviewProvider = FutureProvider.family
    .autoDispose<ContractReview?, String>((ref, contractId) async {
      final user = ref.watch(authProvider).valueOrNull;
      if (user == null) return null;
      final row = await ref
          .watch(supabaseClientProvider)
          .from('reviews')
          .select('rating, comment, created_at')
          .eq('contract_id', contractId)
          .eq('reviewer_id', user.id)
          .maybeSingle();
      return row == null ? null : ContractReview.fromJson(row);
    });
