import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/services/file_validation.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import 'profile_provider.dart';

/// Limite do bucket `resumes`.
const resumeMaxBytes = 5 * 1024 * 1024;

/// Escolhe um PDF e envia como currículo do usuário logado. Devolve false se
/// a escolha foi cancelada.
final uploadResumeProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      throw const AppMessageException('Entre de novo para enviar o currículo.');
    }
    final file = await ref
        .read(storageServiceProvider)
        .pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (file == null) return false;
    if (!FileValidation.isPdf(file.bytes)) {
      throw const AppMessageException(
        'O currículo precisa ser um arquivo PDF.',
      );
    }
    FileValidation.checkSize(file.size, resumeMaxBytes);
    await ref
        .read(profileRepositoryProvider)
        .uploadResume(
          userId: user.id,
          bytes: file.bytes,
          previousUrl: user.resumeUrl,
        );
    ref.invalidate(authProvider);
    ref.invalidate(publicProfileProvider(user.id));
    return true;
  };
});

final removeResumeProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final user = ref.read(authProvider).valueOrNull;
    final url = user?.resumeUrl;
    if (user == null || url == null) return;
    await ref
        .read(profileRepositoryProvider)
        .removeResume(userId: user.id, url: url);
    ref.invalidate(authProvider);
    ref.invalidate(publicProfileProvider(user.id));
  };
});
