import '../../../../core/config/legal.dart';
import '../../../../core/errors/backend_errors.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_profile.dart';

class AuthRemoteDataSource {
  final SupabaseClient _supabase;

  AuthRemoteDataSource(this._supabase);

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson({...response, 'email': user.email ?? ''});
    } catch (e, st) {
      debugPrint('🚨 [Auth] Falha ao carregar perfil: $e\n$st');
      return null;
    }
  }

  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception('Falha ao autenticar.');

      final profile = await getCurrentUserProfile();
      return profile ??
          UserProfile(
            id: user.id,
            email: user.email ?? email,
            fullName: user.userMetadata?['full_name'] as String? ?? 'Usuário',
            role: UserRole.fromString(user.userMetadata?['role'] as String?),
            createdAt: DateTime.now(),
          );
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed' ||
          e.message.toLowerCase().contains('email not confirmed')) {
        throw EmailNotConfirmedException(email.trim());
      }
      rethrow;
    }
  }

  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role.toDbString(),
        // O cadastro só é enviado com o aceite marcado; guarda a versão aceita.
        'terms_version': LegalInfo.termsVersion,
        'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    final user = response.user;
    if (user == null) throw Exception('Falha ao cadastrar usuário.');

    // E-mail já cadastrado: o Supabase responde "sucesso" com um usuário sem
    // identidades (para não revelar quais e-mails existem) e não envia nada.
    if (response.session == null && (user.identities?.isEmpty ?? false)) {
      throw const EmailAlreadyRegisteredException();
    }

    // Com confirmação de e-mail ativa não há sessão: o usuário só entra depois
    // de clicar no link. Nunca tratamos como logado sem sessão real.
    if (response.session == null) {
      throw EmailConfirmationPendingException(email.trim());
    }
    final profile = await getCurrentUserProfile();
    if (profile == null) {
      throw Exception('Não foi possível carregar o perfil.');
    }
    return profile;
  }

  Future<void> sendPasswordReset(String email) async {
    await _supabase.auth.resetPasswordForEmail(email.trim());
  }

  /// Valida o link de confirmação ou de redefinição de senha enviado por
  /// e-mail (`?token_hash=...&type=...`) e abre a sessão neste aparelho.
  Future<void> verifyEmailLink({
    required String tokenHash,
    required bool recovery,
  }) async {
    await _supabase.auth.verifyOTP(
      tokenHash: tokenHash,
      type: recovery ? OtpType.recovery : OtpType.email,
    );
  }

  /// Reenvia o e-mail de confirmação de cadastro.
  Future<void> resendSignupConfirmation(String email) async {
    await _supabase.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Exclui a conta no servidor (Edge Function `delete-account`) e encerra a
  /// sessão local. O token já não vale no servidor, então o logout é só local.
  Future<void> deleteAccount() async {
    await _supabase.functions.invoke('delete-account');
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final payload = profile.toUpdateJson();
    await _supabase.from('profiles').update(payload).eq('id', profile.id);

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': profile.fullName,
            'role': profile.role.toDbString(),
          },
        ),
      );
    } catch (_) {}

    return profile;
  }

  Future<UserProfile> switchRole(UserRole newRole) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    await _supabase.rpc(
      'switch_role',
      params: {'p_role': newRole.toDbString()},
    );

    final updated = await getCurrentUserProfile();
    if (updated == null) throw Exception('Não foi possível carregar o perfil.');
    return updated;
  }
}
