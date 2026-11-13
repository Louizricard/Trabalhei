import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/config/work_categories.dart';

/// O catálogo é repetido na migration (constraints do banco). Se um lado
/// mudar sem o outro, o app grava vagas que o banco recusa.
void main() {
  final sql = File(
    '../supabase/migrations/20261113120100_generalist_categories.sql',
  ).readAsStringSync();

  List<String> quoted(String text) =>
      RegExp(r"'([^']+)'").allMatches(text).map((m) => m.group(1)!).toList();

  test('áreas do app e do banco são as mesmas, na mesma ordem', () {
    final block = RegExp(
      r'select array\[(.*?)\]',
      dotAll: true,
    ).firstMatch(sql)!.group(1)!;
    expect(quoted(block), WorkCategories.names);
  });

  test('subcategorias de cada área batem com o banco', () {
    for (final area in WorkCategories.areas) {
      if (area.subcategories.isEmpty) continue;
      final block = RegExp(
        "when '${RegExp.escape(area.name)}' then p_subcategory = any \\(array\\[(.*?)\\]\\)",
        dotAll: true,
      ).firstMatch(sql);
      expect(block, isNotNull, reason: area.name);
      expect(quoted(block!.group(1)!), [
        for (final s in area.subcategories) s.name,
      ], reason: area.name);
    }
  });

  test('valores antigos viram área + subcategoria sem perda', () {
    expect(WorkCategories.fromLegacy('Mobile'), (
      area: 'Tecnologia',
      subcategory: 'Mobile',
    ));
    expect(WorkCategories.fromLegacy('devops'), (
      area: 'Tecnologia',
      subcategory: 'DevOps',
    ));
    expect(WorkCategories.fromLegacy('Design'), (
      area: 'Design',
      subcategory: null,
    ));
    expect(WorkCategories.fromLegacy('Confeitaria'), (
      area: 'Outros',
      subcategory: 'Confeitaria',
    ));
  });

  test('sugestões seguem a área e a subcategoria', () {
    expect(
      WorkCategories.suggestedSkills(area: 'Design', subcategory: 'UI/UX'),
      contains('Figma'),
    );
    expect(
      WorkCategories.suggestedSkills(area: 'Tradução'),
      contains('Legendas'),
    );
    final all = WorkCategories.suggestedSkills();
    expect(all, isNot(contains('Flutter')));
    expect(all.length, greaterThan(10));
  });
}
