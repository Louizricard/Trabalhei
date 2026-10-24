import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../domain/entities/billing.dart';

/// Dados coletados no checkout. O CPF/CNPJ é exigido pelo Asaas para emitir
/// a cobrança e não é armazenado no banco do app.
class CheckoutData {
  final BillingMethod method;
  final String cpfCnpj;

  const CheckoutData({required this.method, required this.cpfCnpj});
}

class CheckoutSheet extends StatefulWidget {
  final String title;
  final String summary;

  /// Quando `false`, a forma de pagamento é escolhida na própria fatura.
  final bool askMethod;

  const CheckoutSheet({
    super.key,
    required this.title,
    required this.summary,
    this.askMethod = true,
  });

  static Future<CheckoutData?> show(
    BuildContext context, {
    required String title,
    required String summary,
    bool askMethod = true,
  }) {
    return showModalBottomSheet<CheckoutData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => CheckoutSheet(
        title: title,
        summary: summary,
        askMethod: askMethod,
      ),
    );
  }

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _docController = TextEditingController();
  BillingMethod _method = BillingMethod.pix;

  @override
  void dispose() {
    _docController.dispose();
    super.dispose();
  }

  String? _validateDoc(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11 && digits.length != 14) {
      return 'Informe um CPF (11 dígitos) ou CNPJ (14 dígitos).';
    }
    return null;
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CheckoutData(
        method: _method,
        cpfCnpj: _docController.text.replaceAll(RegExp(r'\D'), ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  widget.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.askMethod) ...[
                  SegmentedButton<BillingMethod>(
                    segments: [
                      for (final m in BillingMethod.values)
                        ButtonSegment(value: m, label: Text(m.label)),
                    ],
                    selected: {_method},
                    onSelectionChanged: (s) => setState(() => _method = s.first),
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  controller: _docController,
                  label: 'CPF ou CNPJ',
                  hint: 'Somente números',
                  prefixIcon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-/]')),
                  ],
                  validator: _validateDoc,
                ),
                const SizedBox(height: 8),
                const Text(
                  'O pagamento é processado com segurança pelo Asaas. '
                  'O Trabalhei não armazena dados de cartão nem seu documento.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Continuar para o pagamento',
                  icon: Icons.lock_outline_rounded,
                  width: double.infinity,
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
