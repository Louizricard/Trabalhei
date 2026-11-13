import 'package:flutter/material.dart';
import '../config/work_categories.dart';
import '../theme/app_colors.dart';
import 'field_label.dart';

/// Normaliza uma habilidade digitada: sem espaços sobrando, até 40 letras.
String cleanSkill(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.length > 40 ? text.substring(0, 40) : text;
}

/// Sugestões que ainda não foram escolhidas, filtradas pelo que se digitou.
List<String> filterSkillSuggestions(
  List<String> suggestions,
  List<String> chosen,
  String query, {
  int limit = 8,
}) {
  final taken = {for (final s in chosen) s.toLowerCase()};
  final q = query.trim().toLowerCase();
  return suggestions
      .where((s) => !taken.contains(s.toLowerCase()))
      .where((s) => q.isEmpty || s.toLowerCase().contains(q))
      .take(limit)
      .toList();
}

/// Campo de habilidades em chips. Aceita sugestões (clique), habilidades
/// próprias (Enter, vírgula ou "Adicionar") e guarda o texto pendente ao
/// sair do campo. Não repete habilidades, sem diferenciar maiúsculas.
class SkillsInputWidget extends FormField<List<String>> {
  SkillsInputWidget({
    super.key,
    List<String> initialValue = const [],
    super.onSaved,
    super.validator,
    ValueChanged<List<String>>? onChanged,
    String label = 'Habilidades',
    String helperText = 'Escolha uma sugestão ou digite e tecle Enter.',
    FieldRequirement requirement = FieldRequirement.required,
    List<String>? suggestions,
    int maxSkills = 15,
  }) : super(
         initialValue: initialValue,
         builder: (state) => _SkillsField(
           state: state,
           onChanged: onChanged,
           label: label,
           helperText: helperText,
           requirement: requirement,
           suggestions: suggestions ?? WorkCategories.suggestedSkills(),
           maxSkills: maxSkills,
         ),
       );
}

class _SkillsField extends StatefulWidget {
  final FormFieldState<List<String>> state;
  final ValueChanged<List<String>>? onChanged;
  final String label;
  final String helperText;
  final FieldRequirement requirement;
  final List<String> suggestions;
  final int maxSkills;

  const _SkillsField({
    required this.state,
    required this.onChanged,
    required this.label,
    required this.helperText,
    required this.requirement,
    required this.suggestions,
    required this.maxSkills,
  });

  @override
  State<_SkillsField> createState() => _SkillsFieldState();
}

class _SkillsFieldState extends State<_SkillsField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // Campo e sugestões no mesmo grupo: clicar numa sugestão não tira o foco
  // do campo (antes, a sugestão sumia no clique e não era adicionada).
  final _tapGroup = Object();

  List<String> get _skills => widget.state.value ?? const [];
  bool get _full => _skills.length >= widget.maxSkills;

  @override
  void initState() {
    super.initState();
    // Texto digitado e não confirmado vira habilidade ao sair do campo.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _add(_controller.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _set(List<String> skills) {
    widget.state.didChange(skills);
    widget.onChanged?.call(skills);
  }

  void _add(String raw) {
    final skill = cleanSkill(raw.replaceAll(',', ''));
    _controller.clear();
    if (skill.isEmpty || _full) return;
    final exists = _skills.any((s) => s.toLowerCase() == skill.toLowerCase());
    if (!exists) _set([..._skills, skill]);
  }

  void _onTextChanged(String text) {
    if (text.contains(',')) {
      text.split(',').forEach(_add);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final borderColor = state.hasError
        ? AppColors.error
        : _focusNode.hasFocus
        ? AppColors.primary
        : AppColors.borderDark;
    return TapRegion(
      groupId: _tapGroup,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.label, requirement: widget.requirement),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevatedDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in _skills)
                  InputChip(
                    label: Text(skill),
                    onDeleted: () => _set([..._skills]..remove(skill)),
                    deleteButtonTooltipMessage: 'Remover $skill',
                  ),
                _input(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.errorText ??
                (_full
                    ? 'Limite de ${widget.maxSkills} habilidades.'
                    : widget.helperText),
            style: TextStyle(
              fontSize: 12,
              color: state.hasError ? AppColors.error : AppColors.textMutedDark,
            ),
          ),
          _suggestionsRow(),
        ],
      ),
    );
  }

  Widget _input() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: TextField(
        key: const Key('skills-input-field'),
        controller: _controller,
        focusNode: _focusNode,
        groupId: _tapGroup,
        enabled: !_full,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: _skills.isEmpty ? 'Ex.: Edição de vídeo' : 'Adicionar...',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
        ),
        onChanged: _onTextChanged,
        onSubmitted: (text) {
          _add(text);
          _focusNode.requestFocus();
        },
      ),
    );
  }

  Widget _suggestionsRow() {
    final typed = cleanSkill(_controller.text);
    final options = filterSkillSuggestions(widget.suggestions, _skills, typed);
    final custom =
        typed.isNotEmpty &&
        !options.any((s) => s.toLowerCase() == typed.toLowerCase());
    if (_full || (options.isEmpty && !custom)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (custom)
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16),
              label: Text('Adicionar "$typed"'),
              onPressed: () => _add(typed),
            ),
          for (final s in options)
            ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onPressed: () => _add(s),
            ),
        ],
      ),
    );
  }
}
