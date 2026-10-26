import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/checkout.dart';

/// Leva a compra até o fim: cupom de 100% (já liberado), Pix dentro do app ou
/// cartão na página segura do Asaas (aberta no navegador do próprio app).
/// [isPaid] consulta o banco; o webhook do Asaas marca o pagamento.
Future<void> completeCheckout(
  BuildContext context,
  CheckoutResult result, {
  required Future<bool> Function() isPaid,
  required String successMessage,
  required Future<void> Function() onPaid,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (result.granted) {
    await onPaid();
    messenger.showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: AppColors.success,
      ),
    );
    return;
  }
  if (result.pix != null) {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: false,
      backgroundColor: AppColors.transparent,
      builder: (_) => PixPaymentSheet(
        pix: result.pix!,
        amount: result.amount,
        isPaid: isPaid,
        successMessage: successMessage,
      ),
    );
    if (paid == true) await onPaid();
    return;
  }
  final url = result.invoiceUrl;
  if (url == null) return;
  final opened =
      await launchUrl(url, mode: LaunchMode.inAppBrowserView) ||
      await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a página de pagamento.'),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }
  messenger.showSnackBar(
    const SnackBar(
      content: Text(
        'Conclua o pagamento na página segura do Asaas. A confirmação aparece aqui em instantes.',
      ),
    ),
  );
}

/// QR Code e código copia e cola do Pix. Consulta o pagamento a cada poucos
/// segundos e fecha sozinho quando o Asaas confirma.
class PixPaymentSheet extends StatefulWidget {
  final PixCharge pix;
  final double? amount;
  final Future<bool> Function() isPaid;
  final String successMessage;

  const PixPaymentSheet({
    super.key,
    required this.pix,
    required this.isPaid,
    required this.successMessage,
    this.amount,
  });

  @override
  State<PixPaymentSheet> createState() => _PixPaymentSheetState();
}

class _PixPaymentSheetState extends State<PixPaymentSheet> {
  static const _interval = Duration(seconds: 4);
  static const _maxWait = Duration(minutes: 15);
  Timer? _timer;
  final _started = DateTime.now();
  bool _paid = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  Future<void> _check() async {
    if (DateTime.now().difference(_started) > _maxWait) {
      _timer?.cancel();
      return;
    }
    try {
      if (await widget.isPaid() && mounted) {
        _timer?.cancel();
        setState(() => _paid = true);
      }
    } catch (_) {
      // Rede instável: tenta de novo no próximo intervalo.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.pix.payload));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _paid ? _success(context) : _waiting(context),
          ),
        ),
      ),
    );
  }

  Widget _success(BuildContext context) => Column(
    key: const ValueKey('paid'),
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 12),
      const Icon(
        Icons.check_circle_rounded,
        size: 64,
        color: AppColors.success,
      ),
      const SizedBox(height: 12),
      const Text(
        'Pagamento confirmado',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        widget.successMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondaryDark),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continuar'),
        ),
      ),
    ],
  );

  Widget _waiting(BuildContext context) {
    final image = widget.pix.imageBase64.isEmpty
        ? null
        : base64Decode(widget.pix.imageBase64);
    return Column(
      key: const ValueKey('waiting'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.pix_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.amount == null
                    ? 'Pague com Pix'
                    : 'Pague ${CurrencyFormatter.format(widget.amount!)} com Pix',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Abra o app do seu banco, escolha Pix e leia o QR Code ou cole o código.',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 16),
        if (image != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.memory(
                image,
                width: 220,
                height: 220,
                gaplessPlayback: true,
                semanticLabel: 'QR Code do Pix',
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _copy,
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(_copied ? 'Código copiado' : 'Copiar código Pix'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.pix.expiresAt == null
                    ? 'Aguardando a confirmação do pagamento...'
                    : 'Aguardando a confirmação. O código vale até ${_formatExpiry(widget.pix.expiresAt!)}.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Pode fechar esta tela: avisamos assim que o pagamento for confirmado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMutedDark),
        ),
      ],
    );
  }

  String _formatExpiry(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} às ${two(local.hour)}:${two(local.minute)}';
  }
}
