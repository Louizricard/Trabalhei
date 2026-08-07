import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/payment_intent.dart';
import '../../domain/entities/transaction.dart';
import '../providers/payments_provider.dart';

class PixEscrowModal extends ConsumerStatefulWidget {
  final PaymentIntentResult paymentIntent;
  final double amount;
  final String title;
  final VoidCallback onPaymentConfirmed;

  const PixEscrowModal({
    super.key,
    required this.paymentIntent,
    required this.amount,
    required this.title,
    required this.onPaymentConfirmed,
  });

  @override
  ConsumerState<PixEscrowModal> createState() => _PixEscrowModalState();
}

class _PixEscrowModalState extends ConsumerState<PixEscrowModal> {
  bool _isCopied = false;
  bool _isVerifying = false;
  bool _hasConfirmed = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _hasConfirmed || _isVerifying) return;
      await _checkPayment(isAutoPoll: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPayment({bool isAutoPoll = false}) async {
    if (_hasConfirmed) return;
    if (!isAutoPoll) {
      setState(() => _isVerifying = true);
    }

    try {
      final res = await ref
          .read(paymentRepositoryProvider)
          .checkPaymentStatus(
            gatewayRef: widget.paymentIntent.gatewayRef,
            transactionId: widget.paymentIntent.transactionId,
          );

      if (res.isApproved || res.status == 'approved') {
        _handleSuccess();
        return;
      }

      if (!isAutoPoll && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.errorMessage ??
                  'Pagamento em processamento no Mercado Pago. Aguarde alguns instantes...',
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!isAutoPoll && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verificando status junto ao gateway... Tente novamente em instantes.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted && !isAutoPoll) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _copyToClipboard() {
    final code = widget.paymentIntent.qrCode ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      setState(() => _isCopied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Código Pix Copia e Cola copiado para a área de transferência!',
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isCopied = false);
      });
    }
  }

  void _handleSuccess() {
    if (_hasConfirmed) return;
    _hasConfirmed = true;
    _pollingTimer?.cancel();

    ref.invalidate(walletSummaryProvider);
    ref.invalidate(transactionsListProvider);

    widget.onPaymentConfirmed();

    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🎉 Pagamento Pix confirmado! Valor retido com segurança no Escrow.',
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final txId = widget.paymentIntent.transactionId;

    // Escuta em tempo real o status da transação no Supabase
    if (txId != null && !_hasConfirmed) {
      ref.listen<AsyncValue<WalletTransaction?>>(
        transactionStatusStreamProvider(txId),
        (previous, next) {
          final tx = next.value;
          if (tx != null && tx.status == TransactionStatus.completed) {
            _handleSuccess();
          }
        },
      );
    }

    final qrBase64 = widget.paymentIntent.qrCodeBase64;
    Uint8List? qrImageBytes;
    if (qrBase64 != null && qrBase64.isNotEmpty) {
      try {
        qrImageBytes = base64Decode(qrBase64);
      } catch (_) {}
    }

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho do Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Pagar via Pix',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMutedDark,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card com Valor e Destino do Escrow
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryDark,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Garantia protegida em Custódia (Escrow)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(widget.amount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Renderização do QR Code do Mercado Pago
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: qrImageBytes != null
                    ? Image.memory(
                        qrImageBytes,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      )
                    : Container(
                        width: 200,
                        height: 200,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 140,
                          color: AppColors.bgDark,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Status reativo "Aguardando pagamento"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Aguardando confirmação em tempo real...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botão Copia e Cola
            CustomButton(
              text: _isCopied ? 'Código Copiado!' : 'Copiar Código Pix',
              icon: _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
              variant: _isCopied
                  ? ButtonVariant.secondary
                  : ButtonVariant.primary,
              onPressed: _copyToClipboard,
            ),
            const SizedBox(height: 10),

            // Botão de verificação manual
            TextButton.icon(
              onPressed: _isVerifying
                  ? null
                  : () => _checkPayment(isAutoPoll: false),
              icon: _isVerifying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textSecondaryDark,
                      ),
                    )
                  : const Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: AppColors.textSecondaryDark,
                    ),
              label: const Text(
                'Já realizei o pagamento',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
