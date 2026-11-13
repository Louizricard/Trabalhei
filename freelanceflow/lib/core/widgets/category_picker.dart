import 'package:flutter/material.dart';
import '../config/work_categories.dart';
import '../theme/app_colors.dart';
import 'category_search_sheet.dart';
import 'field_label.dart';

/// Escolha em dois passos: área (obrigatória, com busca) e especialidade
/// (opcional, mostrada depois da área). Em "Outros", a especialidade é
/// texto livre de até 60 caracteres, como no banco.
class CategoryPicker extends FormField<CategoryChoice> {
  CategoryPicker({
    super.key,
    super.initialValue,
    required ValueChanged<CategoryChoice> onChanged,
    String label = 'Área do trabalho',
    bool isRequired = true,
  }) : super(
         validator: (v) =>
             isRequired && v == null ? 'Escolha a área do trabalho.' : null,
         builder: (state) => _CategoryPickerBody(
           state: state,
           label: label,
           isRequired: isRequired,
           onChanged: onChanged,
         ),
       );
}

class _CategoryPickerBody extends StatelessWidget {
  final FormFieldState<CategoryChoice> state;
  final String label;
  final bool isRequired;
  final ValueChanged<CategoryChoice> onChanged;

  const _CategoryPickerBody({
    required this.state,
    required this.label,
    required this.isRequired,
    required this.onChanged,
  });

  void _set(CategoryChoice choice) {
    final sub = choice.subcategory?.trim();
    final clean = (
      area: choice.area,
      subcategory: sub == null || sub.isEmpty
          ? null
          : (sub.length > 60 ? sub.substring(0, 60) : sub),
    );
    state.didChange(clean);
    onChanged(clean);
  }

  Future<void> _open(BuildContext context) async {
    final choice = await showCategorySearchSheet(context);
    if (choice != null) _set(choice);
  }

  @override
  Widget build(BuildContext context) {
    final value = state.value;
    final area = WorkCategories.area(value?.area);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(
          label,
          requirement: isRequired
              ? FieldRequirement.required
              : FieldRequirement.optional,
        ),
        const SizedBox(height: 6),
        InkWell(
          key: const Key('category-picker'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context),
          child: InputDecorator(
            isEmpty: value == null,
            decoration: InputDecoration(
              hintText: 'Escolha ou busque uma área',
              helperText:
                  area?.description ??
                  'Ex.: Design, Tradução, Marketing, Tecnologia.',
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.search_rounded),
            ),
            child: value == null ? null : Text(value.area),
          ),
        ),
        if (area != null) ...[
          const SizedBox(height: 12),
          const FieldLabel(
            'Especialidade',
            requirement: FieldRequirement.optional,
          ),
          const SizedBox(height: 6),
          if (area.subcategories.isEmpty)
            _OtherSubcategoryField(
              key: ValueKey(area.name),
              initial: value?.subcategory,
              onChanged: (v) => _set((area: area.name, subcategory: v)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sub in area.subcategories)
                  ChoiceChip(
                    label: Text(sub.name),
                    selected: value?.subcategory == sub.name,
                    onSelected: (on) => _set((
                      area: area.name,
                      subcategory: on ? sub.name : null,
                    )),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _OtherSubcategoryField extends StatefulWidget {
  final String? initial;
  final ValueChanged<String> onChanged;

  const _OtherSubcategoryField({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_OtherSubcategoryField> createState() => _OtherSubcategoryFieldState();
}

class _OtherSubcategoryFieldState extends State<_OtherSubcategoryField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLength: 60,
      decoration: const InputDecoration(
        hintText: 'Ex.: Confeitaria, Paisagismo',
        counterStyle: TextStyle(color: AppColors.textMutedDark),
      ),
      onChanged: widget.onChanged,
    );
  }
}
