import 'package:flutter/material.dart';
import '../../../../../core/config/work_categories.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/input_formatters.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/category_picker.dart';
import '../../../../../core/widgets/category_search_sheet.dart';
import '../../../../../core/widgets/custom_text_field.dart';
import '../../../../../core/widgets/field_label.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/skills_input_widget.dart';

const _titleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);

/// Título, área e descrição da vaga.
class JobBasicsCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final CategoryChoice? category;
  final ValueChanged<CategoryChoice> onCategoryChanged;

  const JobBasicsCard({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.category,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sobre o trabalho', style: _titleStyle),
          const SizedBox(height: 4),
          const RequiredFieldsNote(),
          const SizedBox(height: 16),
          CustomTextField(
            controller: titleController,
            label: 'Título da vaga',
            requirement: FieldRequirement.required,
            hint: 'Ex.: Identidade visual para cafeteria',
            helperText: 'Diga em poucas palavras o que precisa ser feito.',
            maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: Validators.minLength('o título', 10),
          ),
          const SizedBox(height: 16),
          CategoryPicker(initialValue: category, onChanged: onCategoryChanged),
          const SizedBox(height: 16),
          CustomTextField(
            controller: descriptionController,
            label: 'Descrição',
            requirement: FieldRequirement.required,
            hint:
                'Objetivo, o que deve ser entregue, referências e qualquer '
                'restrição de prazo ou formato.',
            helperText:
                'Mínimo de 30 caracteres. Quanto mais claro, '
                'melhores as propostas.',
            maxLines: 6,
            minLines: 4,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            validator: Validators.minLength('a descrição', 30),
          ),
        ],
      ),
    );
  }
}

/// Faixa de orçamento e prazo, com máscara de moeda.
class JobBudgetCard extends StatelessWidget {
  final TextEditingController minController;
  final TextEditingController maxController;
  final TextEditingController daysController;

  const JobBudgetCard({
    super.key,
    required this.minController,
    required this.maxController,
    required this.daysController,
  });

  String? _validateMax(String? value) {
    final error = Validators.money(min: 1)(value);
    if (error != null) return error;
    final min = CurrencyFormatter.parse(minController.text) ?? 0;
    return CurrencyFormatter.parse(value)! < min
        ? 'Deve ser igual ou maior que o mínimo.'
        : null;
  }

  CustomTextField _money(
    TextEditingController c,
    String label,
    String? Function(String?) validator,
  ) {
    return CustomTextField(
      controller: c,
      label: label,
      prefixText: 'R\$ ',
      hint: '1.500,00',
      requirement: FieldRequirement.required,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [CurrencyInputFormatter()],
      textInputAction: TextInputAction.next,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final min = _money(
      minController,
      'Orçamento mínimo',
      Validators.money(min: 1),
    );
    final max = _money(maxController, 'Orçamento máximo', _validateMax);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orçamento e prazo', style: _titleStyle),
          const SizedBox(height: 4),
          const Text(
            'Uma faixa realista ajuda a receber propostas adequadas.',
            style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < 420
                ? Column(children: [min, const SizedBox(height: 12), max])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: min),
                      const SizedBox(width: 12),
                      Expanded(child: max),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: daysController,
            label: 'Prazo de execução',
            hint: '30',
            helperText: 'Em dias corridos, a partir da contratação.',
            requirement: FieldRequirement.required,
            keyboardType: TextInputType.number,
            inputFormatters: const [IntegerInputFormatter(maxDigits: 4)],
            validator: Validators.intRange(1, 3650, unit: 'dias'),
          ),
        ],
      ),
    );
  }
}

/// Habilidades (sugeridas pela área escolhida) e prazo urgente.
class JobSkillsCard extends StatelessWidget {
  final List<String> skills;
  final CategoryChoice? category;
  final ValueChanged<List<String>> onSkillsChanged;
  final bool isUrgent;
  final ValueChanged<bool> onUrgentChanged;

  const JobSkillsCard({
    super.key,
    required this.skills,
    required this.category,
    required this.onSkillsChanged,
    required this.isUrgent,
    required this.onUrgentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkillsInputWidget(
            label: 'Habilidades desejadas',
            initialValue: skills,
            onChanged: onSkillsChanged,
            suggestions: WorkCategories.suggestedSkills(
              area: category?.area,
              subcategory: category?.subcategory,
            ),
            validator: (v) => v == null || v.isEmpty
                ? 'Adicione pelo menos uma habilidade.'
                : null,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('job-urgent-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Prazo urgente',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Para trabalhos que precisam começar logo. A vaga ganha o selo '
              '"Urgente" e entra no filtro de urgentes; a posição no mural '
              'não muda. Para mais visibilidade, use o Destaque patrocinado '
              'depois de publicar.',
              style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
            ),
            value: isUrgent,
            onChanged: onUrgentChanged,
          ),
        ],
      ),
    );
  }
}
