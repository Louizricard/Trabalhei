import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/admin_models.dart';
import '../providers/admin_provider.dart';

const _products = {
  'any': 'Pro e destaque',
  'pro_monthly': 'Só Pro (1º mês)',
  'job_feature': 'Só destaque de projeto',
};

/// Cupons de desconto (ex.: lançamento): criar, acompanhar usos e desativar.
class CouponsTab extends ConsumerWidget {
  const CouponsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(adminCouponsProvider);
    return ResponsiveLayout(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'O desconto vale para a primeira cobrança. Cupom de 100% libera sem pagamento.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _create(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo cupom'),
                ),
              ],
            ),
          ),
          Expanded(
            child: coupons.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar cupons',
                description: friendlyError(e),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.local_offer_outlined,
                      title: 'Nenhum cupom ainda',
                      description:
                          'Crie cupons para promoções, como o lançamento.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _CouponTile(coupon: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponTile extends ConsumerWidget {
  final AdminCoupon coupon;
  const _CouponTile({required this.coupon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = coupon;
    final status = !c.active
        ? 'Desativado'
        : c.isExpired
        ? 'Expirado'
        : c.isExhausted
        ? 'Esgotado'
        : 'Ativo';
    final color = status == 'Ativo'
        ? AppColors.success
        : AppColors.textMutedDark;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SelectableText(
                      c.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    c.percentOff != null
                        ? '${c.percentOff}% de desconto'
                        : '${CurrencyFormatter.format(c.amountOff ?? 0)} de desconto',
                    _products[c.product] ?? c.product,
                    'usado ${c.redemptions}${c.maxRedemptions != null ? ' de ${c.maxRedemptions}' : ''} vez(es)',
                    if (c.validUntil != null)
                      'até ${DateFormatter.simpleDate(c.validUntil!)}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                if (c.description?.isNotEmpty == true)
                  Text(
                    c.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedDark,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: c.active,
            onChanged: (v) async {
              try {
                await ref
                    .read(adminRepositoryProvider)
                    .setCouponActive(c.code, v);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(friendlyError(e)),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
              ref.invalidate(adminCouponsProvider);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _create(BuildContext context, WidgetRef ref) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => const _CouponDialog(),
  );
  if (created == true) ref.invalidate(adminCouponsProvider);
}

class _CouponDialog extends ConsumerStatefulWidget {
  const _CouponDialog();

  @override
  ConsumerState<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends ConsumerState<_CouponDialog> {
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _max = TextEditingController();
  final _description = TextEditingController();
  String _product = 'any';
  bool _percent = true;
  DateTime? _until;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _max.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    final value = double.tryParse(_value.text.replaceAll(',', '.'));
    if (!RegExp(r'^[A-Z0-9_-]{3,30}$').hasMatch(code)) {
      setState(() => _error = 'Código de 3 a 30 letras, números, _ ou -.');
      return;
    }
    if (value == null ||
        value <= 0 ||
        (_percent && (value > 100 || value != value.roundToDouble()))) {
      setState(
        () => _error = _percent
            ? 'Informe uma porcentagem inteira entre 1 e 100.'
            : 'Informe um valor em reais maior que zero.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .createCoupon(
            code: code,
            product: _product,
            percentOff: _percent ? value.round() : null,
            amountOff: _percent ? null : value,
            maxRedemptions: int.tryParse(_max.text),
            validUntil: _until,
            description: _description.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo cupom'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                  LengthLimitingTextInputFormatter(30),
                ],
                decoration: const InputDecoration(
                  labelText: 'Código',
                  hintText: 'Ex.: LANCAMENTO50',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _product,
                decoration: const InputDecoration(labelText: 'Vale para'),
                items: [
                  for (final e in _products.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _product = v ?? 'any'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Porcentagem')),
                  ButtonSegment(value: false, label: Text('Valor fixo')),
                ],
                selected: {_percent},
                onSelectionChanged: (s) => setState(() => _percent = s.first),
              ),
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _percent ? 'Desconto (%)' : 'Desconto (R\$)',
                  helperText: _percent ? '100% libera sem cobrança' : null,
                ),
              ),
              TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Limite total de usos (vazio = sem limite)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _until == null
                          ? 'Sem data de validade'
                          : 'Vale até ${DateFormatter.simpleDate(_until!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 730)),
                        initialDate:
                            _until ?? now.add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(
                          () => _until = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            23,
                            59,
                            59,
                          ),
                        );
                      }
                    },
                    child: const Text('Definir validade'),
                  ),
                ],
              ),
              TextField(
                controller: _description,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Descrição (aparece para quem usar)',
                  hintText: 'Ex.: Promoção de lançamento',
                ),
              ),
              const Text(
                'Cada pessoa pode usar o cupom uma vez.',
                style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Criando...' : 'Criar cupom'),
        ),
      ],
    );
  }
}
