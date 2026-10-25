import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Verdadeiro quando o usuário chegou por um link de redefinição de senha: o
/// roteador leva para /reset-password antes de qualquer outra tela. A tela de
/// redefinição desliga o aviso ao abrir.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);
