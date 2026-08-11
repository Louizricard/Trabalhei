import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SkillsInputWidget extends FormField<List<String>> {
  SkillsInputWidget({
    super.key,
    List<String> initialValue = const [],
    super.onSaved,
    super.validator,
    String label = 'Habilidades Desejadas',
    String hint = 'Digite e pressione Enter...',
    List<String> suggestions = const [
      'Flutter', 'Riverpod', 'Supabase', 'Dart', 'React', 'Node.js',
      'Python', 'Figma', 'UI/UX', 'Firebase'
    ],
  }) : super(
          initialValue: initialValue,
          builder: (FormFieldState<List<String>> state) {
            return _SkillsInputWidgetState(
              state: state,
              label: label,
              hint: hint,
              suggestions: suggestions,
            );
          },
        );
}

class _SkillsInputWidgetState extends StatefulWidget {
  final FormFieldState<List<String>> state;
  final String label;
  final String hint;
  final List<String> suggestions;

  const _SkillsInputWidgetState({
    required this.state,
    required this.label,
    required this.hint,
    required this.suggestions,
  });

  @override
  State<_SkillsInputWidgetState> createState() => __SkillsInputWidgetStateState();
}

class __SkillsInputWidgetStateState extends State<_SkillsInputWidgetState> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty) return;
    
    final currentList = List<String>.from(widget.state.value ?? []);
    if (!currentList.map((e) => e.toLowerCase()).contains(trimmed.toLowerCase())) {
      currentList.add(trimmed);
      widget.state.didChange(currentList);
    }
    _controller.clear();
  }

  void _removeSkill(String skill) {
    final currentList = List<String>.from(widget.state.value ?? []);
    currentList.remove(skill);
    widget.state.didChange(currentList);
  }

  @override
  Widget build(BuildContext context) {
    final currentSkills = widget.state.value ?? [];
    final hasError = widget.state.hasError;
    final filteredSuggestions = widget.suggestions
        .where((s) => !currentSkills.map((e) => e.toLowerCase()).contains(s.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : _isFocused
                      ? AppColors.primary
                      : AppColors.borderDark,
              width: _isFocused ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...currentSkills.map((skill) => Chip(
                        label: Text(
                          skill,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        backgroundColor: AppColors.primary.withAlpha(200),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white70,
                        ),
                        onDeleted: () => _removeSkill(skill),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.transparent),
                        ),
                      )),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: currentSkills.isEmpty ? widget.hint : 'Adicionar...',
                        hintStyle: const TextStyle(color: AppColors.textMutedDark),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                      onSubmitted: _addSkill,
                    ),
                  ),
                ],
              ),
              if (_isFocused && filteredSuggestions.isNotEmpty) ...[
                const Divider(color: AppColors.borderDark, height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filteredSuggestions
                        .take(5)
                        .map(
                          (suggestion) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(
                                suggestion,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              backgroundColor: AppColors.surfaceDark,
                              side: const BorderSide(color: AppColors.borderDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onPressed: () => _addSkill(suggestion),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 16),
            child: Text(
              widget.state.errorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
