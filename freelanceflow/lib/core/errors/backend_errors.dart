import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_catalog.dart';
import 'error_reporter.dart';

/// Converte qualquer erro em uma mensagem curta e compreensível em português.
/// Erros que não reconhecemos viram uma mensagem genérica e vão para o log
/// (Sentry), com o texto técnico completo.
String friendlyError(Object error, [StackTrace? stackTrace]) {
  if (error is AppMessageException) return error.message;
  final raw = _rawMessage(error);
  final lower = raw.toLowerCase();

  final known = _match(raw, databaseCodes) ??
      (error is PostgrestException ? _postgrest(error, lower) : null) ??
      (error is AuthException ? _auth(error, lower) : null) ??
      (error is StorageException ? _match(lower, storageErrors) : null) ??
      (_isNetwork(lower) ? networkError : null);
  if (known != null) return known;

  // Mensagens já amigáveis lançadas pelo próprio app (`Exception('...')`).
  if (error is! PostgrestException &&
      error is! AuthException &&
      error is! StorageException &&
      error is! FunctionException &&
      _looksFriendly(raw)) {
    return raw.replaceFirst('Exception: ', '').trim();
  }
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String) return details['error'] as String;
  }
  reportError(error, stackTrace, 'erro não mapeado');
  return unexpectedError;
}

String _rawMessage(Object error) => switch (error) {
  PostgrestException e => '${e.code ?? ''} ${e.message} ${e.details ?? ''}',
  AuthException e => '${e.code ?? ''} ${e.message}',
  StorageException e => '${e.statusCode ?? ''} ${e.error ?? ''} ${e.message}',
  FunctionException e => '${e.status} ${e.details ?? ''}',
  _ => error.toString(),
};

String? _match(String text, Map<String, String> table) {
  final lower = text.toLowerCase();
  for (final entry in table.entries) {
    if (text.contains(entry.key) || lower.contains(entry.key.toLowerCase())) {
      return entry.value;
    }
  }
  return null;
}

String? _postgrest(PostgrestException e, String lower) {
  switch (e.code) {
    case '23514':
      return _match(e.message, checkConstraints) ??
          'Algum campo passou do tamanho permitido. Revise e tente de novo.';
    case '23505':
      return 'Este registro já existe.';
    case '42501':
      return 'Você não tem permissão para esta ação.';
    case '22001':
      return 'Um dos textos passou do tamanho permitido. Encurte e tente de novo.';
  }
  if (lower.contains('row-level security') || lower.contains('permission denied')) {
    return 'Você não tem permissão para esta ação.';
  }
  return null;
}

String? _auth(AuthException e, String lower) =>
    _match(lower, authErrors) ??
    ((e.statusCode ?? '').startsWith('5')
        ? 'Não conseguimos concluir agora. Tente de novo em instantes.'
        : null);

bool _isNetwork(String lower) =>
    lower.contains('socketexception') ||
    lower.contains('failed host lookup') ||
    lower.contains('clientexception') ||
    lower.contains('failed to fetch') ||
    lower.contains('connection refused') ||
    lower.contains('network is unreachable');

/// Texto em linguagem natural, sem cara de log (JSON, códigos, classes).
bool _looksFriendly(String raw) {
  final text = raw.replaceFirst('Exception: ', '').trim();
  return text.isNotEmpty &&
      text.length < 220 &&
      !RegExp(r'[{}<>]|Exception\(|Error:|code:|\b(null|undefined)\b').hasMatch(text);
}

/// Erro com mensagem pronta para o usuário, lançado pelo próprio app.
class AppMessageException implements Exception {
  final String message;
  const AppMessageException(this.message);

  @override
  String toString() => message;
}

/// O cadastro foi criado, mas o Supabase exige confirmar o e-mail antes de abrir sessão.
class EmailConfirmationPendingException implements Exception {
  final String email;
  const EmailConfirmationPendingException(this.email);

  @override
  String toString() =>
      'Conta criada! Enviamos um link de confirmação para $email. '
      'Abra o e-mail, confirme e depois entre aqui.';
}

/// Login de uma conta que ainda não confirmou o e-mail.
class EmailNotConfirmedException implements Exception {
  final String email;
  const EmailNotConfirmedException(this.email);

  @override
  String toString() =>
      'Confirme seu e-mail antes de entrar. Enviamos o link para $email.';
}

/// Cadastro com um e-mail que já tem conta.
class EmailAlreadyRegisteredException implements Exception {
  const EmailAlreadyRegisteredException();

  @override
  String toString() =>
      'Este e-mail já tem uma conta. Entre com sua senha ou use "Esqueci minha senha".';
}
