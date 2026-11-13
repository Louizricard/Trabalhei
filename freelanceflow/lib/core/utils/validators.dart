import 'currency_formatter.dart';

typedef FieldValidator = String? Function(String?);

/// Validações de formulário compartilhadas. As mensagens dizem o que está
/// errado e como corrigir, sempre perto do campo.
class Validators {
  Validators._();

  // Usuário, @, domínio e extensão com pelo menos 2 letras (ex.: .com, .br).
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[A-Za-z]{2,}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe seu e-mail';
    return isEmail(text)
        ? null
        : 'Digite um e-mail válido, como nome@exemplo.com';
  }

  /// Campo obrigatório: [what] completa a frase "Informe ...".
  static FieldValidator required(String what) =>
      (value) => (value?.trim().isEmpty ?? true) ? 'Informe $what.' : null;

  /// Texto obrigatório com tamanho mínimo, informando quanto falta.
  static FieldValidator minLength(String what, int min) => (value) {
    final length = value?.trim().length ?? 0;
    if (length == 0) return 'Informe $what.';
    if (length < min) {
      return 'Use pelo menos $min caracteres (faltam ${min - length}).';
    }
    return null;
  };

  /// Valor em reais entre [min] e [max].
  static FieldValidator money({
    double min = 0.01,
    double max = 10000000,
    bool optional = false,
  }) => (value) {
    if ((value?.trim().isEmpty ?? true)) {
      return optional ? null : 'Informe o valor em reais. Ex.: 1.500';
    }
    final amount = CurrencyFormatter.parse(value);
    if (amount == null) return 'Valor inválido. Use o formato 1.500,00';
    if (amount < min) {
      return 'O valor mínimo é ${CurrencyFormatter.format(min)}.';
    }
    if (amount > max) {
      return 'O valor máximo é ${CurrencyFormatter.format(max)}.';
    }
    return null;
  };

  /// Número inteiro entre [min] e [max]; [unit] aparece nas mensagens.
  static FieldValidator intRange(
    int min,
    int max, {
    String unit = '',
    bool optional = false,
  }) => (value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return optional ? null : 'Informe um número.';
    final n = int.tryParse(text);
    final suffix = unit.isEmpty ? '' : ' $unit';
    if (n == null) return 'Use apenas números.';
    if (n < min || n > max) return 'Use de $min a $max$suffix.';
    return null;
  };

  /// Link opcional. Aceita "site.com.br" e completa com https://.
  static String? optionalUrl(String? value) {
    final text = normalizeUrl(value ?? '');
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final ok = uri != null && uri.host.contains('.') && !text.contains(' ');
    if (!ok) return 'Link inválido. Ex.: https://meusite.com.br';
    return text.length > 300 ? 'O link pode ter até 300 caracteres.' : null;
  }

  /// Link opcional que precisa ser do domínio [host] (ex.: linkedin.com).
  static FieldValidator optionalUrlFor(String host, String example) => (value) {
    final error = optionalUrl(value);
    if (error != null || (value?.trim().isEmpty ?? true)) return error;
    final uri = Uri.parse(normalizeUrl(value!));
    final ok = uri.host == host || uri.host.endsWith('.$host');
    return ok ? null : 'Use um link do $host. Ex.: $example';
  };

  /// Completa com https:// quando o endereço vem sem protocolo.
  static String normalizeUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    return RegExp(r'^https?://', caseSensitive: false).hasMatch(text)
        ? text
        : 'https://$text';
  }
}
