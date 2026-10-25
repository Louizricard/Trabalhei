import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:trabalhei/core/errors/error_catalog.dart';
import 'package:trabalhei/core/services/file_validation.dart';
import 'package:trabalhei/core/utils/validators.dart';
import 'package:trabalhei/features/auth/presentation/email_link.dart';
import 'package:trabalhei/features/profile/domain/entities/profile_update.dart';

void main() {
  group('friendlyError', () {
    test('limite de tamanho do banco vira mensagem do campo', () {
      const e = PostgrestException(
        message:
            'new row for relation "profiles" violates check constraint "profiles_bio_check"',
        code: '23514',
      );
      expect(friendlyError(e), 'A bio pode ter até 2.000 caracteres.');
    });

    test('falha ao enviar e-mail de confirmação não mostra JSON', () {
      const e = AuthException(
        '{"code":"unexpected_failure","message":"Error sending confirmation email"}',
        statusCode: '500',
        code: 'unexpected_failure',
      );
      final text = friendlyError(e);
      expect(text, contains('e-mail de confirmação'));
      expect(text, isNot(contains('{')));
    });

    test('credenciais inválidas', () {
      const e = AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      expect(friendlyError(e), 'E-mail ou senha incorretos.');
    });

    test('mensagem amigável lançada pelo app é mantida', () {
      expect(
        friendlyError(Exception('Esta conversa não possui um contrato.')),
        'Esta conversa não possui um contrato.',
      );
      expect(
        friendlyError(const AppMessageException('Escolha uma imagem.')),
        'Escolha uma imagem.',
      );
    });

    test('erro técnico desconhecido vira mensagem genérica', () {
      expect(
        friendlyError(StateError('Bad state: null check {x}')),
        unexpectedError,
      );
      expect(
        friendlyError(const PostgrestException(message: 'boom', code: 'XX000')),
        unexpectedError,
      );
    });
  });

  group('Validators', () {
    test('e-mail precisa de domínio completo', () {
      expect(Validators.email('dasdas@gmail'), isNotNull);
      expect(Validators.email('pessoa@exemplo.com'), isNull);
      expect(Validators.email(''), isNotNull);
    });

    test('links aceitam endereço sem https e completam', () {
      expect(Validators.optionalUrl(''), isNull);
      expect(Validators.optionalUrl('meusite.com.br'), isNull);
      expect(Validators.optionalUrl('não é link'), isNotNull);
      expect(
        Validators.normalizeUrl('meusite.com.br'),
        'https://meusite.com.br',
      );
      expect(Validators.normalizeUrl('http://a.com'), 'http://a.com');
    });
  });

  group('FileValidation', () {
    test('reconhece imagens pelo conteúdo, não pela extensão', () {
      expect(
        FileValidation.imageMime(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0]),
        ),
        'image/png',
      );
      expect(
        FileValidation.imageMime(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        'image/jpeg',
      );
      expect(
        FileValidation.imageMime(Uint8List.fromList('%PDF-1.7'.codeUnits)),
        isNull,
      );
      expect(
        FileValidation.imageMime(Uint8List.fromList('olá mundo'.codeUnits)),
        isNull,
      );
    });

    test('PDF e limite de tamanho', () {
      expect(
        FileValidation.isPdf(Uint8List.fromList('%PDF-1.7'.codeUnits)),
        isTrue,
      );
      expect(
        FileValidation.isPdf(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0])),
        isFalse,
      );
      expect(
        () => FileValidation.checkSize(6 * 1024 * 1024, 5 * 1024 * 1024),
        throwsA(isA<AppMessageException>()),
      );
    });
  });

  test('link de e-mail com token_hash', () {
    final recovery = EmailLink.fromUri(
      Uri.parse('https://trabalhei.site/app/?token_hash=abc&type=recovery'),
    );
    expect(recovery?.recovery, isTrue);
    final signup = EmailLink.fromUri(
      Uri.parse('https://trabalhei.site/app/?token_hash=abc&type=email'),
    );
    expect(signup?.recovery, isFalse);
    expect(
      EmailLink.fromUri(Uri.parse('https://trabalhei.site/app/?code=x')),
      isNull,
    );
  });

  test('perfil: campos vazios viram null e links ganham https', () {
    final json = const ProfileUpdate(
      fullName: ' Ana ',
      websiteUrl: 'ana.dev',
      linkedinUrl: '  ',
      hourlyRate: 120,
    ).toJson();
    expect(json['full_name'], 'Ana');
    expect(json['website_url'], 'https://ana.dev');
    expect(json['linkedin_url'], isNull);
    expect(json['hourly_rate'], 120);
    expect(json.containsKey('company_name'), isFalse);
  });
}
