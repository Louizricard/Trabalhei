import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/profile/data/datasources/freelancer_search_filters.dart';
import 'package:trabalhei/features/profile/presentation/providers/profile_provider.dart';

void main() {
  test('habilidade é buscada sem diferenciar maiúsculas', () {
    expect(
      skillCaseVariants('edição de vídeo'),
      containsAll(['edição de vídeo', 'Edição De Vídeo', 'EDIÇÃO DE VÍDEO']),
    );
    final filter = freelancerQueryFilter('figma')!;
    expect(filter, contains('headline.ilike.*figma*'));
    expect(filter, contains('skills.ov.{"figma","FIGMA","Figma"}'));
  });

  test('texto com caracteres de filtro não quebra a consulta', () {
    final filter = freelancerQueryFilter('a,b),or(c')!;
    expect(filter, isNot(contains('(')));
    expect(freelancerQueryFilter('  '), isNull);
  });

  test('área casa pela área do perfil ou pelas habilidades da área', () {
    final filter = freelancerAreaFilter('Tradução')!;
    expect(filter, startsWith('category.eq."Tradução",skills.ov.{'));
    expect(filter, contains('"Legendas"'));
    expect(freelancerAreaFilter('Inexistente'), isNull);
  });

  test('voltar para "Todas" limpa a área escolhida', () {
    final notifier = FreelancerSearchFilterNotifier()..setArea('Design');
    expect(notifier.state.area, 'Design');
    notifier.setArea(null);
    expect(notifier.state.area, isNull);
  });
}
