import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/pro_insights.dart';

/// Estatísticas das propostas e organização de clientes (plano Pro). As
/// funções do banco recusam quem não é Pro com `PRO_REQUIRED`.
class ProInsightsRepository {
  final SupabaseClient _supabase;

  ProInsightsRepository(this._supabase);

  Future<ProposalStats> proposalStats(int days) async => ProposalStats.fromJson(
    Map<String, dynamic>.from(
      await _supabase.rpc('proposal_stats', params: {'p_days': days}) as Map,
    ),
  );

  Future<List<ClientSummary>> clients() async {
    final rows = await _supabase.rpc('freelancer_clients') as List;
    return [
      for (final r in rows)
        ClientSummary.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Anotação privada e etiquetas sobre um cliente.
  Future<void> saveNote(String clientId, String note, List<String> tags) =>
      _supabase.from('client_notes').upsert({
        'client_id': clientId,
        'note': note.trim(),
        'tags': tags,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
}
