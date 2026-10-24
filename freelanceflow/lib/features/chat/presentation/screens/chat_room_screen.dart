import 'package:trabalhei/core/errors/backend_errors.dart';
import '../widgets/chat_system_event_card.dart';
import '../widgets/chat_delivery_action_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/attachment_widgets.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
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
  bool _isUploadingAttachment = false;
  String _uploadStatus = '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  /// Marca como lidas as mensagens recebidas (zera o contador na lista).
  Future<void> _markRead() async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .markConversationRead(widget.conversationId);
      ref.invalidate(conversationsListProvider);
    } catch (_) {
      // Falha ao marcar leitura não deve interromper o chat.
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _scrollToBottom();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.conversationId, text);
    } catch (e) {
      if (!mounted) return;
      // Devolve o texto ao campo para o usuário não perdê-lo.
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível enviar: ${friendlyError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final storage = ref.read(storageServiceProvider);
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final picked = await storage.pickImage(source: source);
    if (picked == null) return;

    await _uploadAndSendFile(picked, user.id);
  }

  Future<void> _pickAndSendDocument() async {
    final storage = ref.read(storageServiceProvider);
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final picked = await storage.pickFile(
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'zip',
        'txt',
        'png',
        'jpg',
        'jpeg',
      ],
    );
    if (picked == null) return;

    await _uploadAndSendFile(picked, user.id);
  }

  Future<void> _uploadAndSendFile(PickedFileData file, String userId) async {
    setState(() {
      _isUploadingAttachment = true;
      _uploadStatus = 'Enviando ${file.name}...';
    });

    try {
      final storage = ref.read(storageServiceProvider);
      final attachment = await storage.uploadFile(
        bucket: 'chat_attachments',
        folder: widget.conversationId,
        file: file,
      );

      if (attachment != null) {
        final caption = _messageController.text.trim();
        await ref
            .read(chatRepositoryProvider)
            .sendAttachmentMessage(
              conversationId: widget.conversationId,
              attachment: attachment,
              caption: caption.isNotEmpty ? caption : null,
            );
        _messageController.clear();
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao fazer upload do anexo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao enviar arquivo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Enviar Anexo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevatedDark,
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  title: const Text(
                    'Foto da Galeria',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'PNG, JPG, WEBP',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevatedDark,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  title: const Text(
                    'Tirar Foto',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevatedDark,
                    child: Icon(
                      Icons.description_rounded,
                      color: AppColors.info,
                    ),
                  ),
                  title: const Text(
                    'Documento ou PDF',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'PDF, DOC, DOCX, ZIP até 20MB',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendDocument();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref
        .watch(conversationDetailProvider(widget.conversationId))
        .value;
    final messagesAsync = ref.watch(
      chatMessagesStreamProvider(widget.conversationId),
    );
    final currentUser = ref.watch(authProvider).value;
    final currentUserId = currentUser?.id;

    ref.listen(chatMessagesStreamProvider(widget.conversationId), (prev, next) {
      if (next.hasValue && (prev?.value?.length != next.value?.length)) {
        ref.invalidate(conversationDetailProvider(widget.conversationId));
        _markRead();
      }
    });

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
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryDark,
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text(
                  'Marcos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) =>
                        ContractMilestoneSheet(conversation: conversation),
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
            if (conversation != null && conversation.milestones.isNotEmpty)
              ChatDeliveryActionBanner(conversation: conversation, currentUser: currentUser),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Erro ao carregar mensagens',
                  description: friendlyError(err),
                ),
                data: (messages) {
                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(
                        msg,
                        currentUserId,
                        conversation,
                        currentUser,
                      );
                    },
                  );
                },
              ),
            ),
            if (_isUploadingAttachment)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppColors.surfaceElevatedDark,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(top: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primaryLight,
                      size: 24,
                    ),
                    tooltip: 'Enviar Anexo ou Imagem',
                    onPressed: _isUploadingAttachment
                        ? null
                        : _showAttachmentOptions,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.borderDark,
                          ),
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

  Widget _buildMessageBubble(
    ChatMessage msg,
    String? currentUserId,
    Conversation? conversation,
    dynamic currentUser,
  ) {
    if (msg.messageType == MessageType.systemEvent ||
        msg.messageType == MessageType.milestoneUpdate) {
      return ChatSystemEventCard(msg: msg, conversation: conversation, currentUser: currentUser);
    }

    final isMe = msg.senderId == currentUserId;
    final storage = ref.read(storageServiceProvider);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (msg.isImage && msg.attachmentUrl != null) ...[
              GestureDetector(
                onTap: () => _openImageDialog(msg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 240,
                      maxWidth: 360,
                    ),
                    child: Image.network(
                      msg.attachmentUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 160,
                          color: AppColors.surfaceDark,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        color: AppColors.surfaceDark,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (msg.attachmentUrl != null) ...[
              GestureDetector(
                onTap: () => storage.launchAttachment(msg.attachmentUrl!),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.black.withAlpha(50)
                        : AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMe
                          ? AppColors.pureWhite.withAlpha(40)
                          : AppColors.borderDark,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.insert_drive_file_rounded,
                        color: AppColors.primaryLight,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.attachmentName ?? 'Documento',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isMe
                                    ? AppColors.onPrimary
                                    : AppColors.textPrimaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (msg.formattedSize.isNotEmpty)
                              Text(
                                msg.formattedSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe
                                      ? AppColors.onPrimary.withAlpha(180)
                                      : AppColors.textMutedDark,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.download_rounded,
                        color: isMe
                            ? AppColors.onPrimary
                            : AppColors.primaryLight,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (msg.content.isNotEmpty &&
                msg.content != msg.attachmentName &&
                msg.content != msg.attachmentUrl) ...[
              Text(
                msg.content,
                style: TextStyle(
                  color: isMe ? AppColors.onPrimary : AppColors.textPrimaryDark,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              DateFormatter.timeOnly(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? AppColors.onPrimary.withAlpha(200)
                    : AppColors.textMutedDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  void _openImageDialog(ChatMessage msg) {
    showImageViewerGallery(
      context,
      images: [
        {
          'url': msg.attachmentUrl!,
          'name': msg.attachmentName ?? 'Imagem do Chat',
          'size': msg.attachmentSize,
        },
      ],
    );
  }

  
}
