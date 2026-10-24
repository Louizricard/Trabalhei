/// Tamanho mínimo de senha para cadastro e redefinição. Deve ser igual ao
/// "Minimum password length" do Supabase (Authentication > Providers > Email).
/// O login não aplica a regra, para não barrar senhas antigas mais curtas.
const int minPasswordLength = 8;
