import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../admin/presentation/providers/admin_provider.dart';
import '../../../admin/presentation/widgets/report_dialog.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';

/// Menu da conversa: denunciar o perfil da outra pessoa e bloquear/desbloquear.
/// Bloquear impede mensagens nos dois sentidos e conversas novas; contratos e
/// histórico continuam como estão (ver docs/moderacao-chat.md).
class ChatSafetyMenu extends ConsumerWidget {
  final Conversation conversation;

  const ChatSafetyMenu({super.key, required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked =
        ref
            .watch(blockedUsersProvider)
            .valueOrNull
            ?.contains(conversation.otherParticipantId) ??
        false;
    return PopupMenuButton<String>(
      key: const Key('chat-safety-menu'),
      tooltip: 'Mais opções',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) => switch (value) {
        'report' => showReportDialog(
          context,
          ref,
          target: ReportTarget.profile,
          targetId: conversation.otherParticipantId,
        ),
        'block' => confirmBlock(context, ref, conversation),
        _ => setBlocked(context, ref, conversation.otherParticipantId, false),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Denunciar perfil'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: Key(blocked ? 'chat-unblock' : 'chat-block'),
          value: blocked ? 'unblock' : 'block',
          child: ListTile(
            leading: Icon(
              blocked ? Icons.lock_open_rounded : Icons.block_rounded,
              color: blocked ? null : AppColors.error,
            ),
            title: Text(
              blocked
                  ? 'Desbloquear ${conversation.otherParticipantName}'
                  : 'Bloquear ${conversation.otherParticipantName}',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

Future<void> confirmBlock(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
) async {
  final name = conversation.otherParticipantName;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Bloquear $name?'),
      content: const Text(
        'Vocês não poderão mais trocar mensagens nem abrir conversas novas. '
        'A outra pessoa não é avisada. Contratos em andamento continuam; se '
        'precisar, encerre o contrato no botão Marcos. Se houver golpe ou '
        'ofensa, denuncie também.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          key: const Key('confirm-block'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await setBlocked(context, ref, conversation.otherParticipantId, true);
  }
}

Future<void> setBlocked(
  BuildContext context,
  WidgetRef ref,
  String userId,
  bool block,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(adminRepositoryProvider);
  try {
    block ? await repo.blockUser(userId) : await repo.unblockUser(userId);
    ref.invalidate(blockedUsersProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(block ? 'Usuário bloqueado.' : 'Usuário desbloqueado.'),
        backgroundColor: AppColors.success,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(friendlyError(e)),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

/// Toque longo numa mensagem da outra pessoa: denunciar a mensagem.
Future<void> showMessageActions(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('report-message'),
            leading: const Icon(Icons.flag_outlined, color: AppColors.error),
            title: const Text('Denunciar mensagem'),
            subtitle: const Text(
              'A moderação vê só esta mensagem. A outra pessoa não é avisada.',
            ),
            onTap: () => Navigator.of(ctx).pop('report'),
          ),
        ],
      ),
    ),
  );
  if (action == 'report' && context.mounted) {
    await showReportDialog(
      context,
      ref,
      target: ReportTarget.message,
      targetId: message.id,
    );
  }
}

/// Substitui o campo de mensagem quando o usuário bloqueou a outra pessoa.
class BlockedChatNotice extends ConsumerWidget {
  final Conversation conversation;

  const BlockedChatNotice({super.key, required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('chat-blocked-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.borderDark)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.textSecondaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Você bloqueou ${conversation.otherParticipantName}.',
              style: const TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () => setBlocked(
              context,
              ref,
              conversation.otherParticipantId,
              false,
            ),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }
}
