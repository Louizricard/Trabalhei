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

      if (response != null) {
        return UserProfile.fromJson(response);
      }

      // If profile record isn't found, construct from auth metadata and ensure record exists
      final profile = UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name'] as String? ?? 'Usuário',
        role: UserRole.fromString(user.userMetadata?['role'] as String?),
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );

      try {
        await _supabase.from('profiles').upsert(profile.toJson());
      } catch (_) {}

      return profile;
    } catch (_) {
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
      throw Exception(_mapAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception(_mapAuthErrorMessage(e.toString()));
    }
  }

  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role.toDbString(),
        },
      );

      final user = response.user;
      if (user == null) throw Exception('Falha ao cadastrar usuário.');

      final profile = UserProfile(
        id: user.id,
        email: email.trim(),
        fullName: fullName.trim(),
        role: role,
        createdAt: DateTime.now(),
      );

      try {
        await _supabase.from('profiles').upsert(profile.toJson());
      } catch (_) {}

      return profile;
    } on AuthException catch (e) {
      throw Exception(_mapAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception(_mapAuthErrorMessage(e.toString()));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw Exception(_mapAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception(_mapAuthErrorMessage(e.toString()));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(_mapAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception(_mapAuthErrorMessage(e.toString()));
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _supabase.from('profiles').upsert(profile.toJson());
    return profile;
  }

  String _mapAuthErrorMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated with hostname')) {
      return 'Sem conexão com a internet ou servidor inacessível. Reinstale o APK com as permissões de rede.';
    }
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (lower.contains('user already registered') || lower.contains('already registered')) {
      return 'Este e-mail já está cadastrado no sistema.';
    }
    if (lower.contains('password should be at least')) {
      return 'A senha deve conter no mínimo 6 caracteres.';
    }
    if (lower.contains('rate limit')) {
      return 'Muitas tentativas. Aguarde alguns instantes e tente novamente.';
    }
    return msg.replaceAll('Exception: ', '');
  }
}
