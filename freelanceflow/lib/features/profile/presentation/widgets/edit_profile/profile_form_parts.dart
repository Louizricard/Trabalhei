import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/custom_text_field.dart';
import '../../../../../core/widgets/field_label.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/entities/profile_draft.dart';

/// Aplica uma alteração ao rascunho do perfil.
typedef DraftEdit = void Function(ProfileDraft Function(ProfileDraft));

/// Cartão de uma seção da página "Editar perfil".
class ProfileSectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Widget> children;

  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Campo de texto que nasce com o valor salvo e avisa cada mudança. O
/// controlador é do campo; o valor oficial fica no rascunho.
class DraftTextField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String label;
  final String? hint;
  final String? helperText;
  final FieldRequirement requirement;
  final IconData? prefixIcon;
  final String? prefixText;
  final int? maxLength;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const DraftTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.label,
    this.hint,
    this.helperText,
    this.requirement = FieldRequirement.optional,
    this.prefixIcon,
    this.prefixText,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  State<DraftTextField> createState() => _DraftTextFieldState();
}

class _DraftTextFieldState extends State<DraftTextField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;
    return CustomTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      requirement: widget.requirement,
      prefixIcon: widget.prefixIcon,
      prefixText: widget.prefixText,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      keyboardType: multiline ? TextInputType.multiline : widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      textCapitalization: multiline
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      onChanged: widget.onChanged,
    );
  }
}
