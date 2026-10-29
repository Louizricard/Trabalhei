import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../domain/entities/pricing.dart';
import '../providers/pricing_provider.dart';
import '../providers/billing_provider.dart';
import 'checkout_sheet.dart';
import 'pix_payment_sheet.dart';

/// Destaque de projeto (vaga patrocinada): resumo com cupom, cobrança no
/// Asaas e pagamento por Pix dentro do app ou cartão na página segura. O
/// destaque é aplicado pelo servidor quando o webhook confirma o pagamento.
Future<void> startFeatureJobFlow(
  BuildContext context,
  WidgetRef ref,
  Job job,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final pricing = ref.read(pricingProvider).valueOrNull ?? Pricing.fallback;
  final data = await CheckoutSheet.show(
    context,
    title: 'Destacar projeto',
    summary:
        '"${job.title}" entra no espaço de vagas patrocinadas do mural por '
        '${pricing.feature.periodDays} dias, com a etiqueta "Patrocinado". Se '
        'houver mais vagas patrocinadas que espaços, elas se revezam no topo.',
    product: 'job_feature',
    price: pricing.feature.price,
    priceSuffix: 'por ${pricing.feature.periodDays} dias',
  );
  if (data == null || !context.mounted) return;

  final repo = ref.read(billingRepositoryProvider);
  try {
    final result = await repo.startFeatureJobCheckout(
      jobId: job.id,
      method: data.method,
      cpfCnpj: data.cpfCnpj,
      couponCode: data.couponCode,
    );
    if (!context.mounted) return;
    await completeCheckout(
      context,
      result,
      successMessage: 'Sua vaga já está no espaço de vagas patrocinadas.',
      isPaid: () => repo.isFeaturePaid(job.id, result.paymentId),
      onPaid: () async {
        ref.invalidate(jobDetailProvider(job.id));
        ref.invalidate(jobsListProvider);
      },
    );
    ref.invalidate(jobDetailProvider(job.id));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(friendlyError(e)),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
