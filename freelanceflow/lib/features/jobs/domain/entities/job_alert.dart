import '../../../../core/utils/currency_formatter.dart';
import '../repositories/job_repository.dart';
import 'job.dart';

/// Filtro salvo do mural: quando sai uma vaga compatível, a pessoa recebe uma
/// notificação (no app, por e-mail e push). A comparação é feita no banco
/// (`job_matches_alert`), com as mesmas regras dos filtros do mural.
class JobAlert {
  final String id;
  final String name;
  final String? query;
  final String? category;
  final ExperienceLevel? experienceLevel;
  final ContractType? contractType;
  final double? minBudget;
  final int? maxDeadlineDays;
  final bool urgentOnly;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastMatchedAt;

  const JobAlert({
    required this.id,
    required this.name,
    this.query,
    this.category,
    this.experienceLevel,
    this.contractType,
    this.minBudget,
    this.maxDeadlineDays,
    this.urgentOnly = false,
    this.isActive = true,
    required this.createdAt,
    this.lastMatchedAt,
  });

  factory JobAlert.fromJson(Map<String, dynamic> json) => JobAlert(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    query: json['query'] as String?,
    category: json['category'] as String?,
    experienceLevel: ExperienceLevel.values
        .where((e) => e.name == json['experience_level'])
        .firstOrNull,
    contractType: ContractType.values
        .where((e) => e.name == json['contract_type'])
        .firstOrNull,
    minBudget: (json['min_budget'] as num?)?.toDouble(),
    maxDeadlineDays: (json['max_deadline_days'] as num?)?.toInt(),
    urgentOnly: json['urgent_only'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    lastMatchedAt: DateTime.tryParse('${json['last_matched_at']}'),
  );

  /// Campos gravados ao criar um alerta a partir do mural.
  static Map<String, dynamic> insertJson({
    required String name,
    required JobFilter filter,
    String? query,
    String? category,
  }) {
    final q = query?.trim() ?? '';
    final level = filter.experienceLevel;
    return {
      'name': name.trim(),
      'query': q.isEmpty ? null : q,
      'category': category,
      'experience_level': level == null || level == ExperienceLevel.all
          ? null
          : level.name,
      'contract_type': filter.contractType?.name,
      'min_budget': filter.minBudget,
      'max_deadline_days': filter.maxDeadlineDays,
      'urgent_only': filter.urgentOnly,
    };
  }

  /// Resumo legível dos critérios ("Mobile · Pleno · a partir de R$ 1.000").
  String describe() {
    const levels = {
      ExperienceLevel.junior: 'Júnior',
      ExperienceLevel.pleno: 'Pleno',
      ExperienceLevel.senior: 'Sênior',
    };
    final parts = [
      if (query?.isNotEmpty == true) '"$query"',
      ?category,
      ?levels[experienceLevel],
      if (contractType == ContractType.fixed) 'Preço fixo',
      if (contractType == ContractType.hourly) 'Por hora',
      if (minBudget != null)
        'a partir de ${CurrencyFormatter.format(minBudget!)}',
      if (maxDeadlineDays != null) 'prazo até $maxDeadlineDays dias',
      if (urgentOnly) 'só urgentes',
    ];
    return parts.isEmpty ? 'Qualquer vaga nova' : parts.join(' · ');
  }
}
