import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/core/utils/rating_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('friendlyError', () {
    test('traduz códigos levantados pelo banco', () {
      final err = const PostgrestException(message: 'PROPOSAL_QUOTA_EXCEEDED');
      expect(
        friendlyError(err),
        contains('Você usou todas as propostas deste mês'),
      );
    });

    test('traduz violação de RLS', () {
      final err = const PostgrestException(
        message: 'new row violates row-level security policy',
      );
      expect(friendlyError(err), 'Você não tem permissão para esta ação.');
    });

    test('traduz falhas de rede', () {
      expect(
        friendlyError(Exception('SocketException: Failed host lookup')),
        contains('Sem conexão'),
      );
    });

    test('lê a mensagem de erro de Edge Functions', () {
      final err = const FunctionException(
        status: 400,
        details: {'error': 'CPF/CNPJ inválido.'},
      );
      expect(friendlyError(err), 'CPF/CNPJ inválido.');
    });

    test('traduz código do banco vindo com a frase HTTP', () {
      final err = const PostgrestException(
        message: 'COVER_LETTER_TOO_SHORT',
        code: 'P0001',
        details: 'Bad Request',
      );
      expect(friendlyError(err), contains('carta de apresentação está curta'));
    });

    test('nunca mostra código interno ou frase HTTP desconhecidos', () {
      expect(
        friendlyError(Exception('ALGUM_CODIGO_NOVO Bad Request')),
        isNot(contains('ALGUM_CODIGO_NOVO')),
      );
      final fn = const FunctionException(
        status: 400,
        details: {'error': 'INVALID_PAYLOAD'},
      );
      expect(friendlyError(fn), isNot(contains('INVALID_PAYLOAD')));
    });

    test('mantém mensagens desconhecidas sem o prefixo Exception', () {
      expect(friendlyError(Exception('algo específico')), 'algo específico');
    });
  });

  group('RatingFormatter', () {
    test('exibe "Novo" quando não há avaliações', () {
      expect(RatingFormatter.format(0), 'Novo');
    });

    test('formata com uma casa decimal', () {
      expect(RatingFormatter.format(4.666), '4.7');
    });
  });
}
