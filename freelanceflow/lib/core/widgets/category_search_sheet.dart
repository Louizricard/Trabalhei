import 'package:flutter/material.dart';
import '../config/work_categories.dart';
import '../theme/app_colors.dart';

typedef CategoryChoice = ({String area, String? subcategory});

String _fold(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    buffer.write(i < 0 ? char : to[i]);
  }
  return buffer.toString();
}

/// Áreas e subcategorias que casam com [query] (sem acento nem maiúsculas),
/// buscando também nas habilidades de cada subcategoria. Sem busca, só as
/// áreas.
List<CategoryChoice> searchCategories(String query) {
  final q = _fold(query.trim());
  if (q.isEmpty) {
    return [
      for (final a in WorkCategories.areas) (area: a.name, subcategory: null),
    ];
  }
  final results = <CategoryChoice>[];
  for (final area in WorkCategories.areas) {
    if (_fold('${area.name} ${area.description}').contains(q)) {
      results.add((area: area.name, subcategory: null));
    }
    for (final sub in area.subcategories) {
      final text = _fold('${sub.name} ${sub.skills.join(' ')}');
      if (text.contains(q)) {
        results.add((area: area.name, subcategory: sub.name));
      }
    }
  }
  return results;
}

/// Abre a busca de categorias e devolve a escolha (ou null se fechar).
Future<CategoryChoice?> showCategorySearchSheet(BuildContext context) {
  return showModalBottomSheet<CategoryChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CategorySearchSheet(),
  );
}

class _CategorySearchSheet extends StatefulWidget {
  const _CategorySearchSheet();

  @override
  State<_CategorySearchSheet> createState() => _CategorySearchSheetState();
}

class _CategorySearchSheetState extends State<_CategorySearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = searchCategories(_query);
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Qual é a área do trabalho?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('category-search-field'),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Busque: logotipo, legenda, contabilidade...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? _empty(context)
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) => _tile(context, results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, CategoryChoice choice) {
    final area = WorkCategories.area(choice.area)!;
    final sub = choice.subcategory;
    return ListTile(
      title: Text(sub == null ? area.name : '${area.name} › $sub'),
      subtitle: sub == null
          ? Text(
              area.description,
              style: const TextStyle(color: AppColors.textMutedDark),
            )
          : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).pop(choice),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Nenhuma área encontrada.',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop((
              area: WorkCategories.other,
              subcategory: _query.trim().isEmpty ? null : _query.trim(),
            )),
            child: Text('Usar "${WorkCategories.other}"'),
          ),
        ],
      ),
    );
  }
}
