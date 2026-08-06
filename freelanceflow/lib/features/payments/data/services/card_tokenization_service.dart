import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/env_config.dart';

/// Serviço de tokenização direta de cartões de crédito com a API do Mercado Pago.
/// Segue os padrões oficiais PCI-DSS: dados brutos de cartão NUNCA passam pelo backend.
class CardTokenizationService {
  final http.Client _httpClient;

  CardTokenizationService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Tokeniza os dados do cartão de crédito diretamente nos servidores seguros do Mercado Pago.
  Future<String> tokenizeCard({
    required String cardNumber,
    required String cardholderName,
    required String expirationMonth,
    required String expirationYear,
    required String securityCode,
    String? identificationNumber,
    String identificationType = 'CPF',
  }) async {
    final cleanCardNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    final cleanCvv = securityCode.replaceAll(RegExp(r'\D'), '');
    final cleanCpf = identificationNumber?.replaceAll(RegExp(r'\D'), '');
    final month = int.tryParse(expirationMonth) ?? 12;
    final year = int.tryParse(expirationYear.length == 2 ? '20$expirationYear' : expirationYear) ?? 2030;

    final publicKey = EnvConfig.mercadoPagoPublicKey;
    if (publicKey.isEmpty) {
      throw Exception('MERCADO_PAGO_PUBLIC_KEY não configurada no aplicativo.');
    }

    final url = Uri.parse('https://api.mercadopago.com/v1/card_tokens?public_key=$publicKey');

    final payload = {
      'card_number': cleanCardNumber,
      'cardholder': {
        'name': cardholderName.trim(),
        if (cleanCpf != null && cleanCpf.isNotEmpty)
          'identification': {
            'type': identificationType,
            'number': cleanCpf,
          },
      },
      'expiration_month': month,
      'expiration_year': year,
      'security_code': cleanCvv,
    };

    final response = await _httpClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tokenId = data['id'] as String?;
      if (tokenId != null && tokenId.isNotEmpty) {
        return tokenId;
      }
      throw Exception('Token do cartão retornado pelo Mercado Pago é inválido.');
    } else {
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final causeList = errorData['cause'] as List<dynamic>?;
        if (causeList != null && causeList.isNotEmpty) {
          final firstCause = causeList.first as Map<String, dynamic>;
          final description = firstCause['description'] as String?;
          if (description != null && description.isNotEmpty) {
            throw Exception('Erro na validação do cartão: $description');
          }
        }
        final message = errorData['message'] as String?;
        throw Exception(message ?? 'Falha ao tokenizar cartão (${response.statusCode})');
      } on FormatException {
        throw Exception('Falha na comunicação com o Mercado Pago (${response.statusCode})');
      }
    }
  }
}
