import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../domain/entities/billing.dart';
import '../providers/billing_provider.dart';
import 'checkout_sheet.dart';

/// Fluxo de destaque pago da vaga: coleta o documento, gera a cobrança no Asaas
/// e abre a fatura. O destaque é aplicado pelo servidor quando o webhook confirma o pagamento.
Future<void> startFeatureJobFlow(
  BuildContext context,
  WidgetRef ref,
  Job job,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final data = await CheckoutSheet.show(
    context,
    title: 'Destacar vaga',
    summary:
        '"${job.title}" aparece no topo do mural por ${BillingConfig.featureJobDays} dias '
        'por ${CurrencyFormatter.format(BillingConfig.featureJobPrice)}.',
    askMethod: false,
  );
  if (data == null) return;

  try {
    final url = await ref
        .read(billingRepositoryProvider)
        .startFeatureJobCheckout(jobId: job.id, cpfCnpj: data.cpfCnpj);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Não foi possível abrir a página de pagamento.');
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Conclua o pagamento na página aberta. O destaque é ativado assim que for confirmado.',
        ),
      ),
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
