import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/payment_intent.dart';
import '../../domain/entities/transaction.dart';
import '../services/card_tokenization_service.dart';

class PaymentRemoteDataSource {
  final SupabaseClient _supabase;
  final CardTokenizationService _cardTokenizationService;

  PaymentRemoteDataSource(
    this._supabase, {
    CardTokenizationService? cardTokenizationService,
  }) : _cardTokenizationService =
           cardTokenizationService ?? CardTokenizationService();

  SupabaseClient get supabase => _supabase;

  Future<List<WalletTransaction>> getTransactions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('transactions')
        .select('*, contracts (jobs (title))')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => WalletTransaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentIntentResult> createPixPayment({
    String? contractId,
    required double amount,
    String? description,
    String? payerCpf,
    String? payerName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    try {
      final response = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'contract_id': contractId,
          'amount': amount,
          'payment_method': 'pix',
          'description': description,
          'payer_cpf': payerCpf,
          'payer_name': payerName,
          'payer_email': user.email,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Erro no servidor')
            : 'Erro no processamento';
        return PaymentIntentResult.error(errorMsg.toString());
      }

      final data = response.data as Map<String, dynamic>;
      return PaymentIntentResult.fromJson(data);
    } catch (e) {
      return PaymentIntentResult.error(
        'Falha ao conectar com o gateway de pagamento: $e',
      );
    }
  }

  /// Processa pagamento via Cartão de Crédito com Tokenização Segura Client-side
  Future<PaymentIntentResult> createCreditCardPayment({
    String? contractId,
    required double amount,
    required CardPaymentData cardData,
    String? description,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    try {
      // 1. Tokenizar o cartão diretamente com o Mercado Pago no dispositivo (Client-side)
      final cardToken = await _cardTokenizationService.tokenizeCard(
        cardNumber: cardData.cleanCardNumber,
        cardholderName: cardData.cardholderName,
        expirationMonth: cardData.expirationMonth,
        expirationYear: cardData.expirationYear,
        securityCode: cardData.securityCode,
        identificationNumber: cardData.cleanCpf,
      );

      // 2. Enviar APENAS o token seguro para a Edge Function
      final response = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'contract_id': contractId,
          'amount': amount,
          'payment_method': 'credit_card',
          'description': description,
          'token': cardToken,
          'installments': cardData.installments,
          'payment_method_id': cardData.detectBrand(),
          'payer_cpf': cardData.cleanCpf,
          'payer_name': cardData.cardholderName,
          'payer_email': user.email,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Cartão recusado')
            : 'Erro no processamento';
        return PaymentIntentResult.error(errorMsg.toString());
      }

      final data = response.data as Map<String, dynamic>;
      return PaymentIntentResult.fromJson(data);
    } catch (e) {
      return PaymentIntentResult.error('Falha ao processar cartão: $e');
    }
  }

  Future<void> requestPixWithdrawal({
    required double amount,
    required String pixKey,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    try {
      final response = await _supabase.functions.invoke(
        'process-pix-payout',
        body: {'amount': amount, 'pix_key': pixKey.trim()},
      );

      if (response.status != 200) {
        throw Exception(
          response.data?['error'] ?? 'Falha ao solicitar saque Pix.',
        );
      }
    } catch (_) {
      // Fallback para Stored Procedure direta
      await _supabase.rpc(
        'request_pix_payout',
        params: {'p_amount': amount, 'p_pix_key': pixKey.trim()},
      );
    }
  }

  Future<void> depositEscrow({
    required double amount,
    required String contractId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    await _supabase.rpc(
      'fund_contract_escrow',
      params: {'p_contract_id': contractId},
    );
  }

  Stream<WalletTransaction?> listenToTransaction(String transactionId) {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('id', transactionId)
        .map((records) {
          if (records.isEmpty) return null;
          return WalletTransaction.fromJson(records.first);
        });
  }

  Future<PaymentIntentResult> checkPaymentStatus({
    String? gatewayRef,
    String? transactionId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'check-payment-status',
        body: {'gateway_ref': gatewayRef, 'transaction_id': transactionId},
      );

      if (response.status != 200) {
        return PaymentIntentResult.error('Erro ao verificar status');
      }

      final data = response.data as Map<String, dynamic>;
      return PaymentIntentResult.fromJson(data);
    } catch (e) {
      return PaymentIntentResult.error('Falha ao consultar status: $e');
    }
  }
}
