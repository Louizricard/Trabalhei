import '../../../../core/config/work_categories.dart';

/// Tira do texto os caracteres que têm significado nos filtros do
/// PostgREST (vírgula, parênteses, chaves, aspas, curingas).
String _safe(String value) =>
    value.replaceAll(RegExp(r'[,(){}"\\%*:]'), ' ').trim();

String _array(Iterable<String> values) =>
    '{${values.map((v) => '"${_safe(v)}"').join(',')}}';

/// Variações de caixa de uma habilidade, já que `skills` é um array de
/// texto e a comparação no banco diferencia maiúsculas.
List<String> skillCaseVariants(String term) {
  final t = _safe(term);
  if (t.isEmpty) return const [];
  final title = t
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return {t, t.toLowerCase(), t.toUpperCase(), title}.toList();
}

/// Filtro `or` da busca por texto: nome, título profissional, bio ou
/// habilidade (sem diferenciar maiúsculas). Null se não houver texto.
String? freelancerQueryFilter(String? query) {
  final term = _safe(query ?? '');
  if (term.isEmpty) return null;
  return 'full_name.ilike.*$term*,headline.ilike.*$term*,'
      'bio.ilike.*$term*,skills.ov.${_array(skillCaseVariants(term))}';
}

/// Filtro `or` por área: quem marcou a área no perfil ou tem alguma das
/// habilidades sugeridas para ela. Null para área desconhecida.
String? freelancerAreaFilter(String? area) {
  final known = WorkCategories.area(area);
  if (known == null) return null;
  final skills = known.skills;
  return [
    'category.eq."${_safe(known.name)}"',
    if (skills.isNotEmpty) 'skills.ov.${_array(skills)}',
  ].join(',');
}
