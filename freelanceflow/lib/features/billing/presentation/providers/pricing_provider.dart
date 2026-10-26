import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/pricing.dart';

/// Preços e limites atuais, lidos do banco (públicos, inclusive para
/// visitantes). Se a leitura falhar, usa [Pricing.fallback].
final pricingProvider = FutureProvider<Pricing>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final productsQuery = supabase
        .from('billing_products')
        .select()
        .eq('active', true);
    final settingsQuery = supabase
        .from('platform_settings')
        .select()
        .limit(1)
        .maybeSingle();
    final rows = await productsQuery;
    final settingsRow = await settingsQuery;
    final products = {
      for (final row in rows)
        row['code'] as String: BillingProduct.fromJson(row),
    };
    return Pricing(
      pro: products['pro_monthly'] ?? Pricing.fallback.pro,
      feature: products['job_feature'] ?? Pricing.fallback.feature,
      settings: settingsRow == null
          ? Pricing.fallback.settings
          : PlatformSettings.fromJson(settingsRow),
    );
  } catch (_) {
    return Pricing.fallback;
  }
});

/// Tamanho máximo por arquivo enviado (chat, entregas e anexos de vaga), de
/// acordo com o plano de quem envia. O bucket aceita até o limite do Pro.
final uploadLimitBytesProvider = Provider<int>((ref) {
  final pricing = ref.watch(pricingProvider).valueOrNull ?? Pricing.fallback;
  final isPro = ref.watch(authProvider).valueOrNull?.isPro ?? false;
  return pricing.settings.fileLimitBytes(isPro: isPro);
});
