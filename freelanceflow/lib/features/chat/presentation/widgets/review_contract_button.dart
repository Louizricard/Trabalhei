import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/conversation.dart';
import '../providers/review_provider.dart';
import 'review_contract_modal.dart';

/// Botão de avaliação do contrato. Depois de avaliar, vira "Avaliação
/// enviada" e abre a avaliação só para consulta.
class ReviewContractButton extends ConsumerWidget {
  final Conversation conversation;
  final String label;
  final bool compact;

  /// Executado antes de abrir a avaliação (ex.: fechar a folha de marcos).
  final VoidCallback? beforeOpen;

  const ReviewContractButton({
    super.key,
    required this.conversation,
    required this.label,
    this.compact = false,
    this.beforeOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractId = conversation.contractId;
    final reviewed =
        contractId != null &&
        ref.watch(myContractReviewProvider(contractId)).valueOrNull != null;

    final button = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: reviewed
            ? AppColors.surfaceElevatedDark
            : AppColors.success,
        foregroundColor: reviewed ? AppColors.success : AppColors.onPrimary,
        side: reviewed ? const BorderSide(color: AppColors.success) : null,
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(vertical: 12),
        textStyle: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(
        reviewed ? Icons.check_circle_rounded : Icons.star_rate_rounded,
        size: compact ? 16 : 18,
      ),
      label: Text(reviewed ? 'Avaliação enviada' : label),
      onPressed: () {
        final navigator = Navigator.of(context);
        beforeOpen?.call();
        showModalBottomSheet(
          context: navigator.context,
          backgroundColor: AppColors.transparent,
          isScrollControlled: true,
          builder: (_) => ReviewContractModal(conversation: conversation),
        );
      },
    );
    return compact ? button : SizedBox(width: double.infinity, child: button);
  }
}
