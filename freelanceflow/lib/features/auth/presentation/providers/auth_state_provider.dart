import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

final authDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authDataSourceProvider));
});

/// Auth Controller providing reactive state and actions connected directly to Supabase Auth
class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _repository;
  StreamSubscription<UserProfile?>? _authSubscription;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _repository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }

    _authSubscription = _repository.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    }, onError: (Object err, StackTrace st) {
      state = AsyncValue.error(err, st);
    });
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signUpWithEmailPassword(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    await _repository.sendPasswordReset(email);
  }

  Future<void> switchRole(UserRole newRole) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(role: newRole);
    await updateProfile(updated);
  }

  Future<void> updateProfile(UserProfile profile) async {
    try {
      final updated = await _repository.updateProfile(profile);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    final user = await _repository.getCurrentUser();
    state = AsyncValue.data(user);
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } catch (_) {}
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
