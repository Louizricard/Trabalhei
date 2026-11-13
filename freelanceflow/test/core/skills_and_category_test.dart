import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/widgets/category_picker.dart';
import 'package:trabalhei/core/widgets/category_search_sheet.dart';
import 'package:trabalhei/core/widgets/skills_input_widget.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: Form(child: child)),
  ),
);

void main() {
  group('habilidades', () {
    test('filtra sugestões pelo texto e tira as escolhidas', () {
      final list = filterSkillSuggestions(
        ['Figma', 'Photoshop', 'Illustrator'],
        ['figma'],
        'sho',
      );
      expect(list, ['Photoshop']);
    });

    testWidgets('clicar na sugestão com o campo focado adiciona só ela', (
      tester,
    ) async {
      var skills = <String>[];
      await tester.pumpWidget(
        _app(
          SkillsInputWidget(
            suggestions: const ['Edição de vídeo', 'Legendas'],
            onChanged: (v) => skills = v,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('skills-input-field')),
        'edi',
      );
      await tester.pump();
      await tester.tap(find.text('Edição de vídeo'));
      await tester.pump();
      expect(skills, ['Edição de vídeo']);
    });

    testWidgets('não repete, aceita vírgula e salva o texto ao sair', (
      tester,
    ) async {
      var skills = <String>[];
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              SkillsInputWidget(
                suggestions: const [],
                onChanged: (v) => skills = v,
              ),
              const TextField(key: Key('outro')),
            ],
          ),
        ),
      );
      final field = find.byKey(const Key('skills-input-field'));
      await tester.enterText(field, 'Excel, excel,');
      await tester.pump();
      expect(skills, ['Excel']);

      await tester.enterText(field, 'Power BI');
      await tester.tap(find.byKey(const Key('outro')));
      await tester.pump();
      expect(skills, ['Excel', 'Power BI']);
    });
  });

  group('categorias', () {
    test('busca sem acento encontra área e subcategoria', () {
      expect(
        searchCategories('traducao').map((c) => c.area),
        contains('Tradução'),
      );
      expect(
        searchCategories('logotipo'),
        contains((area: 'Design', subcategory: 'Identidade visual')),
      );
      expect(searchCategories(''), hasLength(12));
    });

    testWidgets('área é obrigatória; escolhida, mostra especialidades', (
      tester,
    ) async {
      final key = GlobalKey<FormState>();
      CategoryChoice? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: key,
              child: CategoryPicker(onChanged: (v) => chosen = v),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Escolha a área do trabalho.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('category-picker')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('category-search-field')),
        'design',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Design').first);
      await tester.pumpAndSettle();
      expect(chosen, (area: 'Design', subcategory: null));

      await tester.tap(find.text('UI/UX'));
      await tester.pump();
      expect(chosen, (area: 'Design', subcategory: 'UI/UX'));
      expect(key.currentState!.validate(), isTrue);
    });
  });
}
