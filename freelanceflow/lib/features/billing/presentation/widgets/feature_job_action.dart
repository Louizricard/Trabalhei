import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/play_billing_service.dart';
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
  if (ref.read(playBillingEnabledProvider)) {
    return _featureWithPlay(context, ref, job);
  }
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

/// Android: o Destaque é comprado pelo Google Play. A vaga vai junto com a
/// compra (o servidor lê do Google) e o destaque é aplicado na confirmação.
Future<void> _featureWithPlay(
  BuildContext context,
  WidgetRef ref,
  Job job,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final userId = ref.read(authProvider).valueOrNull?.id;
  if (userId == null) return;
  final pricing = ref.read(pricingProvider).valueOrNull ?? Pricing.fallback;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('feature-play-confirm'),
      title: const Text('Destacar projeto'),
      content: Text(
        '"${job.title}" entra no espaço de vagas patrocinadas do mural por '
        '${pricing.feature.periodDays} dias, com a etiqueta "Patrocinado". O '
        'pagamento é feito pela sua conta do Google Play.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  void show(String text, {bool error = false}) => messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ),
  );
  try {
    final event = await ref
        .read(playBillingProvider)
        .buyFeature(userId: userId, jobId: job.id);
    switch (event.outcome) {
      case PlayOutcome.granted:
        ref.invalidate(jobDetailProvider(job.id));
        ref.invalidate(jobsListProvider);
        show('Sua vaga já está no espaço de vagas patrocinadas.');
      case PlayOutcome.pending:
        show(
          'Pagamento pendente no Google Play. O destaque entra assim que ele '
          'for aprovado.',
        );
      case PlayOutcome.cancelled:
        break;
      case PlayOutcome.failed:
        show(
          event.message ?? 'Não foi possível concluir a compra.',
          error: true,
        );
    }
  } catch (e) {
    show(friendlyError(e), error: true);
  }
}
