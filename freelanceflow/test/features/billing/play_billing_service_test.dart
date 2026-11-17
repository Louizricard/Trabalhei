import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:trabalhei/features/billing/data/play_billing_service.dart';

class _Iap implements InAppPurchase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails _purchase(String product, PurchaseStatus status) =>
    PurchaseDetails(
      productID: product,
      verificationData: PurchaseVerificationData(
        localVerificationData: '{}',
        serverVerificationData: 'token-$product',
        source: 'google_play',
      ),
      transactionDate: '0',
      status: status,
    );

void main() {
  test(
    'compra concluída só vira benefício depois de conferida no servidor',
    () async {
      final verified = <String>[];
      final service = PlayBillingService(
        (product, token) async => verified.add('$product:$token'),
        iap: _Iap(),
      );
      final events = <PlayPurchaseEvent>[];
      service.events.listen(events.add);

      await service.handlePurchases([
        _purchase(PlayProducts.pro, PurchaseStatus.purchased),
        _purchase(PlayProducts.feature, PurchaseStatus.pending),
        _purchase('outro_app', PurchaseStatus.purchased),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(verified, ['pro_monthly:token-pro_monthly']);
      expect(events.map((e) => (e.product, e.outcome)), [
        (PlayProducts.pro, PlayOutcome.granted),
        (PlayProducts.feature, PlayOutcome.pending),
      ]);
    },
  );

  test('falha do servidor não concede e explica o erro', () async {
    final service = PlayBillingService(
      (product, token) async => throw Exception('Compra de outra conta.'),
      iap: _Iap(),
    );
    final events = <PlayPurchaseEvent>[];
    service.events.listen(events.add);

    await service.handlePurchases([
      _purchase(PlayProducts.feature, PurchaseStatus.restored),
      _purchase(PlayProducts.pro, PurchaseStatus.canceled),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(events.first.outcome, PlayOutcome.failed);
    expect(events.first.message, contains('outra conta'));
    expect(events.last.outcome, PlayOutcome.cancelled);
  });
}
