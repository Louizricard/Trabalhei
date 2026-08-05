import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_provider.dart';
import '../widgets/contract_milestone_sheet.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatRoomScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatRepositoryProvider).sendMessage(widget.conversationId, text);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationDetailProvider(widget.conversationId)).value;
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.conversationId));
    final currentUserId = ref.watch(authProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation?.otherParticipantName ?? 'Chat do Projeto',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (conversation != null)
              Text(
                conversation.jobTitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (conversation != null && conversation.milestones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withAlpha(30),
                  foregroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Marcos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ContractMilestoneSheet(conversation: conversation),
                  );
                },
              ),
            ),
        ],
      ),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Erro ao carregar mensagens',
                  description: err.toString(),
                ),
                data: (messages) {
                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(msg, currentUserId);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(top: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.borderDark),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, String? currentUserId) {
    if (msg.messageType == MessageType.systemEvent) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_rounded, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg.content,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryDark),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isMe = msg.senderId == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceElevatedDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isMe ? AppColors.onPrimary : AppColors.textPrimaryDark,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormatter.timeOnly(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? AppColors.onPrimary.withAlpha(200) : AppColors.textMutedDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
