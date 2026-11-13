import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../jobs/domain/entities/job.dart';

/// Vaga para a qual a proposta está sendo enviada.
class ApplyJobSummary extends StatelessWidget {
  final Job job;

  const ApplyJobSummary({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Candidatando-se para:',
            style: TextStyle(fontSize: 12, color: AppColors.textMutedDark),
          ),
          const SizedBox(height: 4),
          Text(
            job.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Orçamento sugerido pelo cliente: '
            '${CurrencyFormatter.formatRange(job.budgetMin, job.budgetMax)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que a pessoa está editando uma proposta já enviada.
class EditingProposalNotice extends StatelessWidget {
  const EditingProposalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.4),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryLight,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Você já enviou uma proposta para esta vaga. '
              'Atualize os valores, as condições e as amostras abaixo.',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
