import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/backend_errors.dart';

/// Produtos cadastrados no Play Console (ids iguais aos de `billing_products`).
abstract final class PlayProducts {
  static const pro = 'pro_monthly';
  static const feature = 'job_feature';
  static const all = {pro, feature};

  /// Tela de assinaturas do Google Play (cancelar/trocar forma de pagamento).
  static const manageUrl =
      'https://play.google.com/store/account/subscriptions'
      '?sku=$pro&package=com.trabalhei.app';
}

enum PlayOutcome { granted, pending, cancelled, failed }

class PlayPurchaseEvent {
  final String product;
  final PlayOutcome outcome;
  final String? message;

  const PlayPurchaseEvent(this.product, this.outcome, [this.message]);
}

/// Confirma no servidor a compra feita no Google Play (Edge Function play-billing).
/// Só o servidor concede o benefício, depois de conferir o token na API do Google.
typedef PlayVerifier = Future<void> Function(String product, String token);

/// Compras do Pro e do Destaque pelo Google Play Billing (app Android). No web
/// e em outras plataformas a cobrança continua pelo Asaas.
///
/// O id do usuário vai como `obfuscatedAccountId` e o da vaga como
/// `obfuscatedProfileId`: o servidor lê os dois do Google, não do app.
class PlayBillingService {
  final InAppPurchase _iap;
  final PlayVerifier _verify;
  final _events = StreamController<PlayPurchaseEvent>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> _products = {};

  PlayBillingService(this._verify, {InAppPurchase? iap})
    : _iap = iap ?? InAppPurchase.instance;

  factory PlayBillingService.supabase(SupabaseClient supabase) =>
      PlayBillingService((product, token) async {
        await supabase.functions.invoke(
          'play-billing',
          body: {'product': product, 'purchase_token': token},
        );
      });

  /// Android instalado pela Play Store/teste: compras pelo Google Play.
  static bool get platformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<PlayPurchaseEvent> get events => _events.stream;

  void start() {
    _subscription ??= _iap.purchaseStream.listen(
      handlePurchases,
      onError: (Object e) =>
          _events.add(PlayPurchaseEvent('', PlayOutcome.failed, '$e')),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _events.close();
  }

  /// Detalhes dos produtos (preço local vindo do Google).
  Future<Map<String, ProductDetails>> products() async {
    if (_products.length == PlayProducts.all.length) return _products;
    if (!await _iap.isAvailable()) {
      throw const PlayUnavailableException(
        'Google Play indisponível neste aparelho.',
      );
    }
    final response = await _iap.queryProductDetails(PlayProducts.all);
    for (final p in response.productDetails) {
      // A assinatura volta uma vez por oferta; fica a primeira (plano básico).
      _products.putIfAbsent(p.id, () => p);
    }
    return _products;
  }

  Future<PlayPurchaseEvent> buyPro({required String userId}) =>
      _buy(PlayProducts.pro, userId: userId);

  Future<PlayPurchaseEvent> buyFeature({
    required String userId,
    required String jobId,
  }) => _buy(PlayProducts.feature, userId: userId, jobId: jobId);

  /// Reentrega compras ainda não confirmadas (app fechado durante a compra).
  Future<void> restore(String userId) =>
      _iap.restorePurchases(applicationUserName: userId);

  Future<PlayPurchaseEvent> _buy(
    String product, {
    required String userId,
    String? jobId,
  }) async {
    start();
    final details = (await products())[product];
    if (details == null) {
      throw const PlayUnavailableException(
        'Produto indisponível no Google Play no momento.',
      );
    }
    final outcome = events
        .firstWhere((e) => e.product == product || e.product.isEmpty)
        .timeout(
          const Duration(minutes: 15),
          onTimeout: () => PlayPurchaseEvent(product, PlayOutcome.pending),
        );
    final param = GooglePlayPurchaseParam(
      productDetails: details,
      applicationUserName: userId,
      obfuscatedProfileId: jobId,
    );
    // Consumo e reconhecimento ficam com o servidor, depois de conceder.
    final started = product == PlayProducts.feature
        ? await _iap.buyConsumable(purchaseParam: param, autoConsume: false)
        : await _iap.buyNonConsumable(purchaseParam: param);
    if (!started) return PlayPurchaseEvent(product, PlayOutcome.cancelled);
    return outcome;
  }

  @visibleForTesting
  Future<void> handlePurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!PlayProducts.all.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(PlayPurchaseEvent(p.productID, PlayOutcome.pending));
        case PurchaseStatus.canceled:
          _events.add(PlayPurchaseEvent(p.productID, PlayOutcome.cancelled));
        case PurchaseStatus.error:
          _events.add(
            PlayPurchaseEvent(
              p.productID,
              PlayOutcome.failed,
              p.error?.message,
            ),
          );
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            await _verify(
              p.productID,
              p.verificationData.serverVerificationData,
            );
            _events.add(PlayPurchaseEvent(p.productID, PlayOutcome.granted));
          } catch (e) {
            // Sem confirmação o Google estorna em 3 dias; a notificação do
            // Google (play-rtdn) ainda pode confirmar pelo servidor.
            _events.add(
              PlayPurchaseEvent(
                p.productID,
                PlayOutcome.failed,
                friendlyError(e),
              ),
            );
          }
      }
    }
  }
}

class PlayUnavailableException extends AppMessageException {
  const PlayUnavailableException(super.message);
}
