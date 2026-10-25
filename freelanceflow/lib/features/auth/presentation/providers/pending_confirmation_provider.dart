import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E-mail de um cadastro que ainda aguarda confirmação. Fica salvo no aparelho
/// para o aviso continuar na tela (mesmo depois de fechar o app) até o usuário
/// confirmar e entrar. Quem limpa ao entrar é o `RouterNotifier`.
class PendingConfirmationNotifier extends StateNotifier<String?> {
  static const _key = 'pending_confirmation_email';

  /// Evita que a leitura inicial sobrescreva um valor definido logo em seguida.
  bool _changed = false;

  PendingConfirmationNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (mounted && !_changed) state = saved;
    } catch (_) {
      // Sem armazenamento local (ex.: testes): o aviso vale só nesta sessão.
    }
  }

  Future<void> set(String email) async {
    _changed = true;
    state = email;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, email);
    } catch (_) {}
  }

  Future<void> clear() async {
    _changed = true;
    state = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

final pendingConfirmationProvider =
    StateNotifierProvider<PendingConfirmationNotifier, String?>(
      (ref) => PendingConfirmationNotifier(),
    );

/// Segundos até poder pedir outro link de confirmação. Compartilhado entre o
/// aviso do login e a tela de confirmação (o Supabase também limita).
class ResendCooldownNotifier extends StateNotifier<int> {
  static const seconds = 60;
  Timer? _timer;

  ResendCooldownNotifier() : super(0);

  void start() {
    _timer?.cancel();
    state = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state <= 1) {
        timer.cancel();
        state = 0;
        return;
      }
      state--;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final resendCooldownProvider =
    StateNotifierProvider<ResendCooldownNotifier, int>(
      (ref) => ResendCooldownNotifier(),
    );
