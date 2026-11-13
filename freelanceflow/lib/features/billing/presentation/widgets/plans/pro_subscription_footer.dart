import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/widgets/custom_button.dart';
import '../../../domain/entities/billing.dart';

/// Rodapé do cartão Pro: situação da assinatura e a ação possível
/// (assinar, ou cancelar quando há assinatura recorrente aberta).
class ProSubscriptionFooter extends StatelessWidget {
  final bool isPro;
  final DateTime? expiresAt;
  final Subscription? subscription;
  final bool busy;
  final VoidCallback onSubscribe;
  final VoidCallback onCancel;

  const ProSubscriptionFooter({
    super.key,
    required this.isPro,
    required this.expiresAt,
    required this.subscription,
    required this.busy,
    required this.onSubscribe,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: isPro ? _active() : _inactive(),
      ),
    );
  }

  List<Widget> _active() {
    final sub = subscription;
    final cancelled = sub?.status == SubscriptionStatus.cancelled;
    return [
      if (expiresAt != null)
        Text(
          cancelled
              ? 'Cancelada — Pro ativo até ${DateFormatter.simpleDate(expiresAt!)}.'
              : 'Pro ativo até ${DateFormatter.simpleDate(expiresAt!)}.',
          style: const TextStyle(color: AppColors.success, fontSize: 13),
        ),
      if (sub != null && sub.isOpen && !cancelled) ...[
        const SizedBox(height: 12),
        CustomButton(
          text: 'Cancelar assinatura',
          variant: ButtonVariant.outline,
          width: double.infinity,
          isLoading: busy,
          onPressed: onCancel,
        ),
      ],
    ];
  }

  List<Widget> _inactive() {
    final status = subscription?.status;
    return [
      if (status == SubscriptionStatus.pending)
        const _Notice(
          'Pagamento pendente. Se já pagou, puxe a tela para atualizar.',
          AppColors.warning,
        ),
      if (status == SubscriptionStatus.overdue)
        const _Notice(
          'Pagamento em atraso. Regularize para manter o Pro.',
          AppColors.error,
        ),
      CustomButton(
        key: const Key('plans-subscribe'),
        text: 'Assinar Pro',
        icon: Icons.workspace_premium_rounded,
        width: double.infinity,
        isLoading: busy,
        onPressed: onSubscribe,
      ),
    ];
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final Color color;

  const _Notice(this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(color: color, fontSize: 13)),
  );
}
