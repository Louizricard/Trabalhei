import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/contract_review.dart';

/// Avaliação já enviada, só para consulta: cada parte avalia uma vez.
class ReviewSummaryView extends StatelessWidget {
  final ContractReview review;
  final String targetLabel;

  const ReviewSummaryView({
    super.key,
    required this.review,
    required this.targetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final comment = review.comment?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Você já avaliou $targetLabel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enviada em ${DateFormatter.simpleDate(review.createdAt)}. '
          'Cada parte avalia o contrato uma vez.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => Icon(
              i < review.rating
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: AppColors.warning,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Text(
            comment.isEmpty ? 'Sem comentário.' : comment,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: comment.isEmpty
                  ? AppColors.textMutedDark
                  : AppColors.textPrimaryDark,
            ),
          ),
        ),
        const SizedBox(height: 20),
        CustomButton(
          text: 'Fechar',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
