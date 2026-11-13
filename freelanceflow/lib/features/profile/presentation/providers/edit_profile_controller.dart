import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/entities/profile_draft.dart';
import '../../domain/entities/profile_update.dart';
import 'profile_provider.dart';

class EditProfileState {
  final ProfileDraft initial;
  final ProfileDraft draft;
  final bool saving;

  const EditProfileState({
    required this.initial,
    required this.draft,
    this.saving = false,
  });

  bool get isDirty => draft != initial;

  EditProfileState copyWith({
    ProfileDraft? initial,
    ProfileDraft? draft,
    bool? saving,
  }) => EditProfileState(
    initial: initial ?? this.initial,
    draft: draft ?? this.draft,
    saving: saving ?? this.saving,
  );
}

/// Estado da página "Editar perfil": rascunho, comparação com o salvo e
/// gravação.
class EditProfileController extends StateNotifier<EditProfileState> {
  final bool isFreelancer;
  final Future<void> Function(ProfileUpdate) _save;

  EditProfileController(
    ProfileDraft initial,
    this._save, {
    required this.isFreelancer,
  }) : super(EditProfileState(initial: initial, draft: initial));

  void edit(ProfileDraft Function(ProfileDraft) change) =>
      state = state.copyWith(draft: change(state.draft));

  /// Grava o rascunho; em caso de erro, mantém o que foi digitado e repassa
  /// a exceção para a tela mostrar.
  Future<void> save() async {
    if (state.saving) return;
    state = state.copyWith(saving: true);
    try {
      await _save(
        state.draft.toUpdate(
          isFreelancer: isFreelancer,
          parseRate: CurrencyFormatter.parse,
        ),
      );
      state = state.copyWith(initial: state.draft, saving: false);
    } catch (_) {
      state = state.copyWith(saving: false);
      rethrow;
    }
  }
}

/// Texto inicial do campo de valor/hora (vazio quando não informado).
String initialRateText(UserProfile user) =>
    user.hourlyRate > 0 ? CurrencyFormatter.toInput(user.hourlyRate) : '';

final editProfileControllerProvider = StateNotifierProvider.autoDispose
    .family<EditProfileController, EditProfileState, UserProfile>((ref, user) {
      return EditProfileController(
        ProfileDraft.fromUser(user, rateText: initialRateText(user)),
        (update) => ref.read(updateProfileProvider)(update),
        isFreelancer: user.role == UserRole.freelancer,
      );
    });
