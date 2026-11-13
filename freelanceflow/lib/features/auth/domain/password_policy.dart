/// Tamanho mínimo de senha para cadastro e redefinição. Deve ser igual ao
/// "Minimum password length" do Supabase (Authentication > Providers > Email).
/// O login não aplica a regra, para não barrar senhas antigas mais curtas.
const int minPasswordLength = 8;

/// Orientação mostrada antes de a pessoa digitar a nova senha.
const String passwordHelp =
    'Pelo menos $minPasswordLength caracteres. Misture letras e números.';

/// Validação de senha nova (cadastro e redefinição), dizendo quanto falta.
String? validateNewPassword(String? value) {
  final length = value?.length ?? 0;
  if (length == 0) return 'Crie uma senha.';
  if (length < minPasswordLength) {
    return 'Use pelo menos $minPasswordLength caracteres '
        '(faltam ${minPasswordLength - length}).';
  }
  return null;
}
