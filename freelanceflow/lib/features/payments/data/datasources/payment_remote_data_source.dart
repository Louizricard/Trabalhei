import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/transaction.dart';

class PaymentRemoteDataSource {
  final SupabaseClient _supabase;

  PaymentRemoteDataSource(this._supabase);

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
    return data.map((json) => WalletTransaction.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> requestPixWithdrawal({required double amount, required String pixKey}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    await _supabase.from('transactions').insert({
      'user_id': user.id,
      'type': 'payout_pix',
      'amount': amount,
      'status': 'completed',
      'pix_key': pixKey.trim(),
    });
  }

  Future<void> depositEscrow({required double amount, required String contractId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    await _supabase.from('transactions').insert({
      'user_id': user.id,
      'contract_id': contractId,
      'type': 'deposit',
      'amount': amount,
      'status': 'completed',
    });
  }
}
