import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/billing.dart';

/// Acesso ao billing. Toda cobrança é criada por Edge Functions (Asaas);
/// o app só recebe o link da fatura hospedada e lê o estado da assinatura.
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

  /// Cria a assinatura Pro e devolve o link da fatura para pagamento.
  Future<Uri> startProCheckout({
    required BillingMethod method,
    required String cpfCnpj,
  }) {
    return _invokeForInvoice('asaas-create-subscription', {
      'billing_type': method.apiValue,
      'cpf_cnpj': cpfCnpj,
    });
  }

  /// Gera a cobrança avulsa do destaque de vaga e devolve o link da fatura.
  Future<Uri> startFeatureJobCheckout({
    required String jobId,
    required String cpfCnpj,
  }) {
    return _invokeForInvoice('asaas-feature-job', {
      'job_id': jobId,
      'cpf_cnpj': cpfCnpj,
    });
  }

  Future<void> cancelSubscription() async {
    await _supabase.functions.invoke('asaas-cancel-subscription');
  }

  Future<Uri> _invokeForInvoice(String function, Map<String, dynamic> body) async {
    final response = await _supabase.functions.invoke(function, body: body);
    final data = response.data;
    final url = data is Map ? data['invoice_url'] as String? : null;
    if (url == null || url.isEmpty) {
      throw Exception('Link de pagamento indisponível. Tente novamente.');
    }
    return Uri.parse(url);
  }
}
