import 'package:flutter_test/flutter_test.dart';
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/features/payments/domain/entities/payment_intent.dart';
import 'package:freelanceflow/features/payments/domain/entities/transaction.dart';

void main() {
  group('Mercado Pago Payment Intent Tests', () {
    test('PaymentIntentResult parses Pix response correctly', () {
      final json = {
        'success': true,
        'transaction_id': 'tx-123456',
        'gateway_ref': 'mp-99887766',
        'status': 'pending',
        'qr_code':
            '00020126580014br.gov.bcb.pix0136123e4567-e89b-12d3-a456-426614174000',
        'qr_code_base64':
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'ticket_url': 'https://www.mercadopago.com.br/payments/123/ticket',
        'expires_at': '2026-08-05T20:00:00.000Z',
      };

      final result = PaymentIntentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.transactionId, 'tx-123456');
      expect(result.gatewayRef, 'mp-99887766');
      expect(result.status, 'pending');
      expect(result.isPending, isTrue);
      expect(result.isApproved, isFalse);
      expect(result.qrCode, isNotNull);
      expect(result.qrCodeBase64, isNotNull);
      expect(
        result.ticketUrl,
        'https://www.mercadopago.com.br/payments/123/ticket',
      );
      expect(result.expiresAt, isNotNull);
    });

    test('CardPaymentData correctly detects card brands and cleans input', () {
      // Visa
      const visaCard = CardPaymentData(
        cardNumber: '4111 2222 3333 4444',
        cardholderName: 'LUIZ RICARDO',
        expirationMonth: '08',
        expirationYear: '2028',
        securityCode: '123',
        cpf: '123.456.789-00',
      );
      expect(visaCard.cleanCardNumber, '4111222233334444');
      expect(visaCard.cleanCpf, '12345678900');
      expect(visaCard.detectBrand(), 'visa');

      // Mastercard
      const masterCard = CardPaymentData(
        cardNumber: '5123 4567 8901 2345',
        cardholderName: 'LUIZ RICARDO',
        expirationMonth: '12',
        expirationYear: '2027',
        securityCode: '456',
        cpf: '12345678900',
      );
      expect(masterCard.detectBrand(), 'master');

      // Elo
      const eloCard = CardPaymentData(
        cardNumber: '4011 7800 0000 0000',
        cardholderName: 'LUIZ RICARDO',
        expirationMonth: '05',
        expirationYear: '2029',
        securityCode: '789',
        cpf: '12345678900',
      );
      expect(eloCard.detectBrand(), 'elo');

      // Amex
      const amexCard = CardPaymentData(
        cardNumber: '3400 0000 0000 000',
        cardholderName: 'LUIZ RICARDO',
        expirationMonth: '01',
        expirationYear: '2026',
        securityCode: '1234',
        cpf: '12345678900',
      );
      expect(amexCard.detectBrand(), 'amex');
    });

    test(
      'WalletTransaction serializes and deserializes Mercado Pago fields',
      () {
        final json = {
          'id': 'tx-abc-123',
          'user_id': 'user-789',
          'contract_id': 'contract-001',
          'type': 'deposit',
          'amount': 1500.50,
          'status': 'completed',
          'gateway_provider': 'mercadopago',
          'gateway_ref': 'mp-pay-999',
          'gateway_status': 'approved',
          'qr_code': 'pix-payload-string',
          'qr_code_base64': 'base64-image-string',
          'payment_method': 'pix',
          'created_at': '2026-08-05T12:00:00.000Z',
        };

        final tx = WalletTransaction.fromJson(json);

        expect(tx.id, 'tx-abc-123');
        expect(tx.userId, 'user-789');
        expect(tx.type, TransactionType.deposit);
        expect(tx.amount, 1500.50);
        expect(tx.status, TransactionStatus.completed);
        expect(tx.gatewayProvider, 'mercadopago');
        expect(tx.gatewayRef, 'mp-pay-999');
        expect(tx.gatewayStatus, 'approved');
        expect(tx.qrCode, 'pix-payload-string');
        expect(tx.qrCodeBase64, 'base64-image-string');
        expect(tx.paymentMethod, 'pix');
        expect(tx.isCredit, isTrue);

        final exported = tx.toJson();
        expect(exported['gateway_provider'], 'mercadopago');
        expect(exported['gateway_ref'], 'mp-pay-999');
        expect(exported['payment_method'], 'pix');
      },
    );

    test('CurrencyFormatter formats Brazilian Real amounts properly', () {
      expect(CurrencyFormatter.format(1500.0), contains('1.500,00'));
      expect(CurrencyFormatter.format(50.25), contains('50,25'));
      expect(CurrencyFormatter.format(0.0), contains('0,00'));
    });

    test('PaymentIntentResult handles error and approved states correctly', () {
      final errorResult = PaymentIntentResult.error(
        'Erro de autorização do gateway',
      );
      expect(errorResult.success, isFalse);
      expect(errorResult.errorMessage, 'Erro de autorização do gateway');
      expect(errorResult.isPending, isFalse);
      expect(errorResult.isApproved, isFalse);

      final approvedResult = PaymentIntentResult(
        success: true,
        transactionId: 'tx-555',
        gatewayRef: 'mp-777',
        status: 'approved',
      );
      expect(approvedResult.success, isTrue);
      expect(approvedResult.isApproved, isTrue);
      expect(approvedResult.isPending, isFalse);
    });

    test('CardPaymentData sanitization and extraction work reliably', () {
      const card = CardPaymentData(
        cardNumber: '  5200 1234 5678 9010 ',
        cardholderName: ' MARIA DA SILVA ',
        expirationMonth: ' 07 ',
        expirationYear: ' 2030 ',
        securityCode: ' 999 ',
        cpf: ' 999.888.777-66 ',
      );

      expect(card.cleanCardNumber, '5200123456789010');
      expect(card.cleanCpf, '99988877766');
      expect(card.cardholderName.trim(), 'MARIA DA SILVA');
      expect(card.expirationMonth.trim(), '07');
      expect(card.expirationYear.trim(), '2030');
      expect(card.securityCode.trim(), '999');
    });
  });
}
