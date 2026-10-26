import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../domain/entities/billing.dart';
import '../../domain/entities/checkout.dart';
import '../providers/billing_provider.dart';

/// Dados coletados no checkout. O CPF/CNPJ é exigido pelo Asaas para emitir
/// a cobrança e não é armazenado no banco do app.
class CheckoutData {
  final BillingMethod method;
  final String cpfCnpj;
  final String? couponCode;
  final PriceQuote quote;

  const CheckoutData({
    required this.method,
    required this.cpfCnpj,
    required this.quote,
    this.couponCode,
  });
}

/// Resumo da compra: forma de pagamento, cupom e CPF/CNPJ.
class CheckoutSheet extends ConsumerStatefulWidget {
  final String title;
  final String summary;

  /// `pro_monthly` ou `job_feature` (tabela billing_products).
  final String product;
  final double price;

  /// Texto do preço sem desconto, ex.: "por mês".
  final String priceSuffix;

  const CheckoutSheet({
    super.key,
    required this.title,
    required this.summary,
    required this.product,
    required this.price,
    this.priceSuffix = '',
  });

  static Future<CheckoutData?> show(
    BuildContext context, {
    required String title,
    required String summary,
    required String product,
    required double price,
    String priceSuffix = '',
  }) {
    return showModalBottomSheet<CheckoutData>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => CheckoutSheet(
        title: title,
        summary: summary,
        product: product,
        price: price,
        priceSuffix: priceSuffix,
      ),
    );
  }

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _docController = TextEditingController();
  final _couponController = TextEditingController();
  BillingMethod _method = BillingMethod.pix;
  PriceQuote? _quote;
  String? _couponError;
  bool _checkingCoupon = false;

  PriceQuote get _effective =>
      _quote ?? PriceQuote(price: widget.price, finalPrice: widget.price);

  @override
  void dispose() {
    _docController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  String? _validateDoc(String? value) {
    if (_effective.isFree) return null;
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11 && digits.length != 14) {
      return 'Informe um CPF (11 dígitos) ou CNPJ (14 dígitos).';
    }
    return null;
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _checkingCoupon = true;
      _couponError = null;
    });
    try {
      final quote = await ref
          .read(billingRepositoryProvider)
          .quote(widget.product, couponCode: code);
      if (mounted) setState(() => _quote = quote);
    } catch (e) {
      if (mounted) {
        setState(() {
          _quote = null;
          _couponError = friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  void _removeCoupon() => setState(() {
    _quote = null;
    _couponError = null;
    _couponController.clear();
  });

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CheckoutData(
        method: _method,
        cpfCnpj: _docController.text.replaceAll(RegExp(r'\D'), ''),
        couponCode: _quote?.code,
        quote: _effective,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _effective;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
                      height: 1.45,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PriceLine(quote: q, suffix: widget.priceSuffix),
                  const SizedBox(height: 16),
                  // Cupom
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          enabled: _quote == null,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_-]'),
                            ),
                            LengthLimitingTextInputFormatter(30),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Cupom de desconto (opcional)',
                            prefixIcon: const Icon(Icons.local_offer_outlined),
                            errorText: _couponError,
                          ),
                          onSubmitted: (_) => _applyCoupon(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _quote == null
                            ? OutlinedButton(
                                onPressed: _checkingCoupon
                                    ? null
                                    : _applyCoupon,
                                child: Text(
                                  _checkingCoupon ? '...' : 'Aplicar',
                                ),
                              )
                            : TextButton(
                                onPressed: _removeCoupon,
                                child: const Text('Remover'),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!q.isFree) ...[
                    SegmentedButton<BillingMethod>(
                      segments: [
                        for (final m in BillingMethod.values)
                          ButtonSegment(
                            value: m,
                            icon: Icon(
                              m == BillingMethod.pix
                                  ? Icons.pix_rounded
                                  : Icons.credit_card_rounded,
                            ),
                            label: Text(m.label),
                          ),
                      ],
                      selected: {_method},
                      onSelectionChanged: (s) =>
                          setState(() => _method = s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _method == BillingMethod.pix
                          ? 'Você paga aqui mesmo, com o QR Code ou o código copia e cola, e a confirmação chega em segundos.'
                          : 'Abre a página segura do Asaas para digitar o cartão. O Trabalhei não vê nem guarda os dados do cartão.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      'Exigido para emitir a cobrança. O pagamento é processado pelo Asaas; '
                      'o Trabalhei não guarda seu documento.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  CustomButton(
                    text: q.isFree
                        ? 'Ativar com o cupom'
                        : _method == BillingMethod.pix
                        ? 'Gerar Pix de ${CurrencyFormatter.format(q.finalPrice)}'
                        : 'Pagar ${CurrencyFormatter.format(q.finalPrice)} com cartão',
                    icon: q.isFree
                        ? Icons.check_rounded
                        : Icons.lock_outline_rounded,
                    width: double.infinity,
                    onPressed: _checkingCoupon ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final PriceQuote quote;
  final String suffix;
  const _PriceLine({required this.quote, required this.suffix});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = quote.discount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDiscount ? AppColors.primary : AppColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quote.isFree
                    ? 'Grátis'
                    : CurrencyFormatter.format(quote.finalPrice),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              if (hasDiscount)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    CurrencyFormatter.format(quote.price),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMutedDark,
                    ),
                  ),
                )
              else if (suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    suffix,
                    style: const TextStyle(color: AppColors.textMutedDark),
                  ),
                ),
            ],
          ),
          if (hasDiscount)
            Text(
              'Cupom ${quote.code}: ${CurrencyFormatter.format(quote.discount)} de desconto'
              '${quote.description != null ? ' · ${quote.description}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.success),
            ),
        ],
      ),
    );
  }
}
