/// Catálogo único de áreas profissionais, usado em vagas, perfis, filtros,
/// busca de talentos e alertas. A lista de áreas e subcategorias é repetida
/// na migration `generalist_categories` (constraint do banco); o teste
/// `work_categories_test.dart` garante que as duas continuam iguais.
library;

part 'work_areas_creative.dart';
part 'work_areas_services.dart';

class WorkSubcategory {
  final String name;
  final List<String> skills;

  const WorkSubcategory(this.name, this.skills);
}

class WorkArea {
  final String name;
  final String description;
  final List<WorkSubcategory> subcategories;

  const WorkArea(this.name, this.description, this.subcategories);

  /// Habilidades sugeridas da área inteira, sem repetição.
  List<String> get skills =>
      {for (final sub in subcategories) ...sub.skills}.toList();

  WorkSubcategory? subcategory(String? name) {
    if (name == null) return null;
    final key = name.toLowerCase();
    for (final sub in subcategories) {
      if (sub.name.toLowerCase() == key) return sub;
    }
    return null;
  }
}

class WorkCategories {
  WorkCategories._();

  static const other = 'Outros';

  static const areas = <WorkArea>[..._creativeAreas, ..._serviceAreas];

  static List<String> get names => [for (final a in areas) a.name];

  static WorkArea? area(String? name) {
    if (name == null) return null;
    final key = name.toLowerCase();
    for (final area in areas) {
      if (area.name.toLowerCase() == key) return area;
    }
    return null;
  }

  /// Sugestões de habilidade: da subcategoria, se houver; senão, da área;
  /// sem área escolhida, uma amostra de todas as áreas.
  static List<String> suggestedSkills({String? area, String? subcategory}) {
    final selected = WorkCategories.area(area);
    if (selected == null) {
      return [for (final a in areas) ...a.skills.take(2)];
    }
    return selected.subcategory(subcategory)?.skills ?? selected.skills;
  }

  /// Área e subcategoria para valores antigos de `jobs.category` (antes do
  /// catálogo, as categorias eram só de tecnologia). Mesma regra da migration.
  static ({String area, String? subcategory}) fromLegacy(String value) {
    final known = area(value);
    if (known != null) return (area: known.name, subcategory: null);
    final tech = areas.first.subcategory(value);
    if (tech != null) return (area: areas.first.name, subcategory: tech.name);
    return (area: other, subcategory: value.isEmpty ? null : value);
  }
}
