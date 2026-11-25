import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/input_formatters.dart';
import 'field_label.dart';

/// Campo de texto padrão dos formulários.
///
/// Mostra a orientação ([helperText]) antes de qualquer interação e só valida
/// depois que a pessoa sai do campo pela primeira vez; daí em diante a
/// mensagem acompanha a digitação até o valor ficar certo. Assim ninguém
/// precisa errar para descobrir o formato, e ninguém vê erro ao começar a
/// digitar.
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;

  /// Instrução ou exemplo exibido abaixo do campo desde o início.
  final String? helperText;

  /// Marca o campo como obrigatório ou opcional no rótulo.
  final FieldRequirement requirement;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? minLines;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  /// Limite de caracteres (o mesmo do banco); mostra o contador abaixo.
  final int? maxLength;

  /// Campo de valor em reais: mostra "R$" fixo, abre o teclado numérico,
  /// agrupa os milhares enquanto a pessoa digita e completa os centavos ao
  /// sair do campo ("1500" vira "1.500,00").
  final bool money;

  /// Dicas para o preenchimento automático e gerenciadores de senha.
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.requirement = FieldRequirement.none,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.money = false,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  final _focus = FocusNode();
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focus.hasFocus || !mounted) return;
    if (widget.money) _normalizeMoney();
    if (!_touched) setState(() => _touched = true);
  }

  void _normalizeMoney() {
    final controller = widget.controller;
    final formatted = CurrencyFormatter.normalizeInput(controller.text);
    if (formatted == controller.text) return;
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onChanged?.call(formatted);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(w.label, requirement: w.requirement, enabled: w.enabled),
        const SizedBox(height: 6),
        TextFormField(
          controller: w.controller,
          focusNode: _focus,
          enabled: w.enabled,
          obscureText: w.obscureText,
          keyboardType: w.money
              ? const TextInputType.numberWithOptions(decimal: true)
              : w.keyboardType,
          validator: w.validator,
          autovalidateMode: _touched
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          maxLines: w.obscureText ? 1 : w.maxLines,
          minLines: w.minLines,
          onChanged: w.onChanged,
          inputFormatters: w.money
              ? const [CurrencyInputFormatter()]
              : w.inputFormatters,
          textCapitalization: w.textCapitalization,
          maxLength: w.maxLength,
          autofillHints: w.autofillHints,
          textInputAction: w.textInputAction,
          onFieldSubmitted: w.onFieldSubmitted,
          style: TextStyle(
            color: w.enabled
                ? AppColors.textPrimaryDark
                : AppColors.textDisabledDark,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: w.hint ?? (w.money ? '0,00' : null),
            helperText: w.helperText,
            prefixIcon: w.prefixIcon != null
                ? Icon(w.prefixIcon, color: AppColors.textMutedDark, size: 20)
                : w.money
                ? _CurrencyPrefix(enabled: w.enabled)
                : null,
            prefixIconConstraints: w.money ? const BoxConstraints() : null,
            // O "R\$" já abre o campo; o valor começa logo depois dele.
            contentPadding: w.money
                ? const EdgeInsetsDirectional.fromSTEB(6, 16, 18, 16)
                : null,
            suffixIcon: w.suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// "R\$" fixo, visível mesmo com o campo vazio: o `prefixText` do Flutter
/// some até o campo ganhar foco, e a pessoa não sabe em que unidade digitar.
class _CurrencyPrefix extends StatelessWidget {
  final bool enabled;

  const _CurrencyPrefix({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 18),
      child: Text(
        'R\$',
        style: TextStyle(
          color: enabled
              ? AppColors.textSecondaryDark
              : AppColors.textDisabledDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
