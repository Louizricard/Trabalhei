import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../domain/entities/payment_intent.dart';
import '../providers/payments_provider.dart';

class CreditCardCheckoutModal extends ConsumerStatefulWidget {
  final double amount;
  final String title;
  final String? contractId;
  final VoidCallback onPaymentConfirmed;

  const CreditCardCheckoutModal({
    super.key,
    required this.amount,
    required this.title,
    this.contractId,
    required this.onPaymentConfirmed,
  });

  @override
  ConsumerState<CreditCardCheckoutModal> createState() => _CreditCardCheckoutModalState();
}

class _CreditCardCheckoutModalState extends ConsumerState<CreditCardCheckoutModal> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cpfController = TextEditingController();

  int _installments = 1;
  bool _isLoading = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _holderNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  String _getBrand() {
    final clean = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('4')) return 'VISA';
    if (RegExp(r'^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[0-1]|2720)').hasMatch(clean)) return 'MASTERCARD';
    if (RegExp(r'^(4011|4312|4389|4514|4576|5041|5066|5067|509|6277|6362|6363)').hasMatch(clean)) return 'ELO';
    if (RegExp(r'^(34|37)').hasMatch(clean)) return 'AMEX';
    if (RegExp(r'^(606282|3841)').hasMatch(clean)) return 'HIPERCARD';
    return 'CARTÃO';
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final cleanNumber = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
      final expiryParts = _expiryController.text.split('/');
      final month = expiryParts[0].trim();
      final year = '20${expiryParts[1].trim()}';

      final cardData = CardPaymentData(
        cardNumber: cleanNumber,
        cardholderName: _holderNameController.text.trim().toUpperCase(),
        expirationMonth: month,
        expirationYear: year,
        securityCode: _cvvController.text.trim(),
        cpf: _cpfController.text.replaceAll(RegExp(r'\D'), ''),
        installments: _installments,
      );

      final repository = ref.read(paymentRepositoryProvider);
      final result = await repository.createCreditCardPayment(
        contractId: widget.contractId,
        amount: widget.amount,
        cardData: cardData,
        description: 'Garantia de Escrow Trabalhei - ${widget.title}',
      );

      if (result.isApproved || result.success) {
        ref.invalidate(walletSummaryProvider);
        ref.invalidate(transactionsListProvider);

        widget.onPaymentConfirmed();

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Pagamento com cartão aprovado! Valor garantido no Escrow.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cartão recusado: ${result.statusDetail ?? result.errorMessage ?? "Verifique os dados digitados."}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no pagamento: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = _getBrand();
    final numText = _cardNumberController.text.isEmpty ? '•••• •••• •••• ••••' : _cardNumberController.text;
    final nameText = _holderNameController.text.isEmpty ? 'NOME DO TITULAR' : _holderNameController.text.toUpperCase();
    final expText = _expiryController.text.isEmpty ? 'MM/AA' : _expiryController.text;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Cartão de Crédito',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMutedDark),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Preview do Cartão Glassmorphism
              Container(
                height: 180,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F394C), Color(0xFF081A2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.contactless_rounded, color: AppColors.primaryLight, size: 28),
                        Text(
                          brand,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      numText,
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            nameText,
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          expText,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Campo: Número do Cartão
              CustomTextField(
                controller: _cardNumberController,
                label: 'Número do Cartão',
                hint: '0000 0000 0000 0000',
                prefixIcon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  final clean = (val ?? '').replaceAll(RegExp(r'\D'), '');
                  if (clean.length < 13) return 'Número de cartão inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo: Nome do Titular
              CustomTextField(
                controller: _holderNameController,
                label: 'Nome impresso no Cartão',
                hint: 'NOME COMO NO CARTÃO',
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Informe o nome do titular';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Linha: Validade e CVV
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _expiryController,
                      label: 'Validade',
                      hint: 'MM/AA',
                      prefixIcon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryDateFormatter(),
                      ],
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.length < 5) return 'Data inválida';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _cvvController,
                      label: 'CVV',
                      hint: '123',
                      prefixIcon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (val) {
                        if (val == null || val.length < 3) return 'CVV inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Campo: CPF do Titular
              CustomTextField(
                controller: _cpfController,
                label: 'CPF do Titular',
                hint: '000.000.000-00',
                prefixIcon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                  _CpfFormatter(),
                ],
                validator: (val) {
                  final clean = (val ?? '').replaceAll(RegExp(r'\D'), '');
                  if (clean.length != 11) return 'CPF inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Seletor de Parcelas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _installments,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceElevatedDark,
                    style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                    items: List.generate(12, (index) {
                      final i = index + 1;
                      final installmentAmount = widget.amount / i;
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          '$i x de ${CurrencyFormatter.format(installmentAmount)} ${i == 1 ? "(à vista)" : "sem juros"}',
                          style: const TextStyle(color: AppColors.textPrimaryDark),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _installments = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Botão Pagar e Garantir
              CustomButton(
                text: 'Pagar ${CurrencyFormatter.format(widget.amount)}',
                icon: Icons.shield_rounded,
                isLoading: _isLoading,
                onPressed: _processPayment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Formatadores de Entrada
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
