import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/billing.dart';
import '../domain/entities/checkout.dart';

/// Acesso ao billing. Toda cobrança é criada por Edge Functions (Asaas). O app
/// recebe o QR Code Pix (pago sem sair do app) ou o link da página segura do
/// Asaas para cartão, e nunca toca em dados de cartão.
class BillingRepository {
  final SupabaseClient _supabase;

  BillingRepository(this._supabase);

  /// Assinatura mais recente do usuário logado, se houver.
  Future<Subscription?> getSubscription() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _supabase
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return Subscription.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  /// Cria a assinatura Pro. Pix devolve o QR Code; cartão, a página segura
  /// do Asaas; cupom de 100% libera o Pro na hora.
  Future<CheckoutResult> startProCheckout({
    required BillingMethod method,
    required String cpfCnpj,
    String? couponCode,
  }) => _invoke('asaas-create-subscription', {
    'billing_type': method.apiValue,
    'cpf_cnpj': cpfCnpj,
    if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
  });

  /// Gera a cobrança do destaque de projeto (vaga patrocinada).
  Future<CheckoutResult> startFeatureJobCheckout({
    required String jobId,
    required BillingMethod method,
    required String cpfCnpj,
    String? couponCode,
  }) => _invoke('asaas-feature-job', {
    'job_id': jobId,
    'billing_type': method.apiValue,
    'cpf_cnpj': cpfCnpj,
    if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
  });

  /// Preço final com o cupom (lança erro amigável se o cupom não valer).
  Future<PriceQuote> quote(String product, {String? couponCode}) async {
    final data = await _supabase.rpc(
      'quote_price',
      params: {'p_product': product, 'p_code': couponCode},
    );
    return PriceQuote.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Destaque já confirmado para a vaga (webhook do Asaas)?
  Future<bool> isFeaturePaid(String jobId) async {
    final row = await _supabase
        .from('job_featurings')
        .select('id')
        .eq('job_id', jobId)
        .eq('status', 'paid')
        .gt(
          'paid_at',
          DateTime.now()
              .subtract(const Duration(hours: 2))
              .toUtc()
              .toIso8601String(),
        )
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  Future<void> cancelSubscription() async {
    await _supabase.functions.invoke('asaas-cancel-subscription');
  }

  Future<CheckoutResult> _invoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    final response = await _supabase.functions.invoke(function, body: body);
    final data = response.data;
    if (data is! Map) {
      throw Exception('Pagamento indisponível. Tente novamente.');
    }
    final result = CheckoutResult.fromJson(Map<String, dynamic>.from(data));
    if (!result.granted && result.pix == null && result.invoiceUrl == null) {
      throw Exception('Pagamento indisponível. Tente novamente.');
    }
    return result;
  }
}
