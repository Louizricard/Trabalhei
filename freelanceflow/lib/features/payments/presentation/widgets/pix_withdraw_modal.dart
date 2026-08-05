import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../providers/payments_provider.dart';

class PixWithdrawModal extends ConsumerStatefulWidget {
  final double availableBalance;
  final VoidCallback? onWithdrawSuccess;

  const PixWithdrawModal({
    super.key,
    required this.availableBalance,
    this.onWithdrawSuccess,
  });

  @override
  ConsumerState<PixWithdrawModal> createState() => _PixWithdrawModalState();
}

class _PixWithdrawModalState extends ConsumerState<PixWithdrawModal> {
  final _amountController = TextEditingController();
  final _pixKeyController = TextEditingController();
  String _keyType = 'E-mail';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    if (user != null && user.email.isNotEmpty) {
      _pixKeyController.text = user.email;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _pixKeyController.dispose();
    super.dispose();
  }

  Future<void> _processWithdraw() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0 || amount > widget.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor solicitado inválido ou maior que o saldo disponível.')),
      );
      return;
    }

    if (_pixKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe a chave Pix.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(paymentRepositoryProvider).requestPixWithdrawal(
            amount: amount,
            pixKey: _pixKeyController.text.trim(),
          );

      widget.onWithdrawSuccess?.call();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saque Pix de ${CurrencyFormatter.format(amount)} realizado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao processar saque: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Solicitar Saque Pix Instantâneo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saldo Disponível para Saque:', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
                  Text(
                    CurrencyFormatter.format(widget.availableBalance),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _amountController,
              label: 'Valor do Saque (R\$)',
              hint: 'Ex: 500.00',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text('Tipo de Chave Pix', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryDark)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _keyType,
              items: ['E-mail', 'CPF', 'Telefone', 'Chave Aleatória'].map((t) {
                return DropdownMenuItem(value: t, child: Text(t));
              }).toList(),
              onChanged: (v) => setState(() => _keyType = v ?? 'E-mail'),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _pixKeyController,
              label: 'Chave Pix',
              hint: 'Digite sua chave...',
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Confirmar Transferência Pix',
              icon: Icons.pix_rounded,
              isLoading: _isLoading,
              width: double.infinity,
              onPressed: _processWithdraw,
            ),
          ],
        ),
      ),
    );
  }
}
