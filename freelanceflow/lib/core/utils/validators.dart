/// Validações de formulário compartilhadas.
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

  /// Link opcional. Aceita "site.com.br" e completa com https://.
  static String? optionalUrl(String? value) {
    final text = normalizeUrl(value ?? '');
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final ok = uri != null && uri.host.contains('.') && !text.contains(' ');
    if (!ok) return 'Link inválido. Ex.: https://meusite.com.br';
    return text.length > 300 ? 'O link pode ter até 300 caracteres.' : null;
  }

  /// Completa com https:// quando o endereço vem sem protocolo.
  static String normalizeUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    return RegExp(r'^https?://', caseSensitive: false).hasMatch(text)
        ? text
        : 'https://$text';
  }
}
