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
import 'package:freelanceflow/core/utils/currency_formatter.dart';
import 'package:freelanceflow/features/auth/domain/entities/user_profile.dart';
import '../widgets/contract_milestone_sheet.dart';
import '../widgets/request_revision_modal.dart';
import '../widgets/review_contract_modal.dart';
import '../widgets/submit_deliverable_modal.dart';

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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatRepositoryProvider).sendMessage(widget.conversationId, text);
    _messageController.clear();
    _scrollToBottom();
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
      allowedExtensions: ['pdf', 'doc', 'docx', 'zip', 'txt', 'png', 'jpg', 'jpeg'],
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
        await ref.read(chatRepositoryProvider).sendAttachmentMessage(
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevatedDark,
                    child: Icon(Icons.photo_library_rounded, color: AppColors.primaryLight),
                  ),
                  title: const Text('Foto da Galeria', style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600)),
                  subtitle: const Text('PNG, JPG, WEBP', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevatedDark,
                    child: Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight),
                  ),
                  title: const Text('Tirar Foto', style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevatedDark,
                    child: Icon(Icons.description_rounded, color: AppColors.info),
                  ),
                  title: const Text('Documento ou PDF', style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600)),
                  subtitle: const Text('PDF, DOC, DOCX, ZIP até 20MB', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
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
    final conversation = ref.watch(conversationDetailProvider(widget.conversationId)).value;
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.conversationId));
    final currentUser = ref.watch(authProvider).value;
    final currentUserId = currentUser?.id;

    ref.listen(chatMessagesStreamProvider(widget.conversationId), (prev, next) {
      if (next.hasValue && (prev?.value?.length != next.value?.length)) {
        ref.invalidate(conversationDetailProvider(widget.conversationId));
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
            if (conversation != null && conversation.milestones.isNotEmpty)
              _buildDeliveryActionBanner(conversation, currentUser),
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
                      return _buildMessageBubble(msg, currentUserId, conversation, currentUser);
                    },
                  );
                },
              ),
            ),
            if (_isUploadingAttachment)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.surfaceElevatedDark,
                child: Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadStatus,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
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
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryLight, size: 24),
                    tooltip: 'Enviar Anexo ou Imagem',
                    onPressed: _isUploadingAttachment ? null : _showAttachmentOptions,
                  ),
                  const SizedBox(width: 4),
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

  Widget _buildMessageBubble(
    ChatMessage msg,
    String? currentUserId,
    Conversation? conversation,
    dynamic currentUser,
  ) {
    if (msg.messageType == MessageType.systemEvent || msg.messageType == MessageType.milestoneUpdate) {
      return _buildSystemEventCard(msg, conversation, currentUser);
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
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.isImage && msg.attachmentUrl != null) ...[
              GestureDetector(
                onTap: () => _openImageDialog(msg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
                    child: Image.network(
                      msg.attachmentUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 160,
                          color: AppColors.surfaceDark,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        color: AppColors.surfaceDark,
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.error)),
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
                    color: isMe ? Colors.black.withAlpha(50) : AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isMe ? AppColors.pureWhite.withAlpha(40) : AppColors.borderDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file_rounded, color: AppColors.primaryLight, size: 28),
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
                                color: isMe ? AppColors.onPrimary : AppColors.textPrimaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (msg.formattedSize.isNotEmpty)
                              Text(
                                msg.formattedSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe ? AppColors.onPrimary.withAlpha(180) : AppColors.textMutedDark,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.download_rounded, color: isMe ? AppColors.onPrimary : AppColors.primaryLight, size: 20),
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
                color: isMe ? AppColors.onPrimary.withAlpha(200) : AppColors.textMutedDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemEventCard(
    ChatMessage msg,
    Conversation? conversation,
    dynamic currentUser,
  ) {
    final isClient = (conversation != null && conversation.clientId != null && currentUser?.id == conversation.clientId) ||
        (currentUser?.role == UserRole.client && conversation?.freelancerId != currentUser?.id);

    final isDelivery = msg.content.contains('Entrega') || msg.content.contains('📦');
    final isRevision = msg.content.contains('Revisão') || msg.content.contains('🔄') || msg.content.contains('Ajustes');
    final isApproved = msg.content.contains('aprovado') || msg.content.contains('liberado') || msg.content.contains('🎉');

    if (isDelivery && conversation != null && conversation.milestones.isNotEmpty) {
      final activeMilestone = conversation.milestones.firstWhere(
        (m) => m.status == MilestoneStatus.submitted || m.status == MilestoneStatus.inRevision,
        orElse: () => conversation.milestones.firstWhere(
          (m) => m.status == MilestoneStatus.fundedInEscrow,
          orElse: () => conversation.milestones.first,
        ),
      );

      return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryLight.withAlpha(90), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withAlpha(40),
                    child: const Icon(Icons.inventory_2_rounded, size: 20, color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClient ? '📦 Entrega de Marco Recebida!' : '📦 Entrega de Marco Enviada',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        Text(
                          activeMilestone.title,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(activeMilestone.amount),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppColors.borderDark, height: 1),
              ),
              Text(
                msg.content,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark, height: 1.3),
              ),
              if (activeMilestone.deliverableAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 4),
                    Text(
                      '${activeMilestone.deliverableAttachments.length} anexo(s) incluído(s)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClient ? AppColors.success : AppColors.primary,
                    foregroundColor: AppColors.pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(isClient ? Icons.check_circle_outline_rounded : Icons.visibility_outlined, size: 18),
                  label: Text(
                    isClient ? 'Revisar Arquivos & Liberar Pagamento' : 'Visualizar Detalhes da Entrega',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.transparent,
                      isScrollControlled: true,
                      builder: (_) => RequestRevisionModal(
                        conversation: conversation,
                        milestone: activeMilestone,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isRevision && conversation != null && conversation.milestones.isNotEmpty) {
      final activeMilestone = conversation.milestones.firstWhere(
        (m) => m.status == MilestoneStatus.inRevision || m.status == MilestoneStatus.submitted,
        orElse: () => conversation.milestones.first,
      );

      return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withAlpha(100), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.warningBg,
                    child: const Icon(Icons.replay_rounded, size: 20, color: AppColors.warning),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClient ? '🔄 Revisão Solicitada' : '⚠️ Ajustes Solicitados pelo Cliente',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                        Text(
                          activeMilestone.title,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppColors.borderDark, height: 1),
              ),
              Text(
                msg.content,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark, height: 1.3),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: isClient
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        label: const Text('Ver Detalhes do Marco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.transparent,
                            isScrollControlled: true,
                            builder: (_) => RequestRevisionModal(
                              conversation: conversation,
                              milestone: activeMilestone,
                            ),
                          );
                        },
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text(
                          'Reenviar Entrega Corrigida',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.transparent,
                            isScrollControlled: true,
                            builder: (_) => SubmitDeliverableModal(
                              conversation: conversation,
                              milestone: activeMilestone,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    if (isApproved && conversation != null) {
      return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withAlpha(100), width: 1.2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.successBg,
                    child: Icon(Icons.celebration_rounded, size: 20, color: AppColors.success),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '🎉 Pagamento Liberado com Sucesso!',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppColors.borderDark, height: 1),
              ),
              Text(
                msg.content,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark, height: 1.3),
                textAlign: TextAlign.center,
              ),
              if (isClient) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.star_rate_rounded, size: 18),
                    label: const Text('Avaliar Freelancer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.transparent,
                        isScrollControlled: true,
                        builder: (_) => ReviewContractModal(conversation: conversation),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Default System Message Chip
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

  void _openImageDialog(ChatMessage msg) {
    showImageViewerGallery(
      context,
      images: [
        {
          'url': msg.attachmentUrl!,
          'name': msg.attachmentName ?? 'Imagem do Chat',
          'size': msg.attachmentSize,
        }
      ],
    );
  }

  Widget _buildDeliveryActionBanner(dynamic conversation, dynamic currentUser) {
    final isClient = (conversation.clientId != null && currentUser?.id == conversation.clientId) ||
        (currentUser?.role == UserRole.client && conversation.freelancerId != currentUser?.id);

    final milestones = List<ContractMilestone>.from(conversation.milestones);
    if (milestones.isEmpty) return const SizedBox.shrink();

    // Encontrar o marco em foco prioritário
    final activeMilestone = milestones.firstWhere(
      (m) => m.status == MilestoneStatus.submitted || m.status == MilestoneStatus.inRevision,
      orElse: () => milestones.firstWhere(
        (m) => m.status == MilestoneStatus.fundedInEscrow,
        orElse: () => milestones.first,
      ),
    );

    final allApproved = milestones.every((m) => m.status == MilestoneStatus.approvedAndReleased);

    // 1. Caso: Projeto 100% Concluído & Pagamento Liberado
    if (allApproved) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withAlpha(80)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.successBg,
              child: Icon(Icons.celebration_rounded, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projeto Concluído & Pago! 🎉',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                  ),
                  Text(
                    'Todos os valores de Escrow foram transferidos.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isClient)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.star_rate_rounded, size: 16),
                label: const Text('Avaliar'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ReviewContractModal(conversation: conversation),
                  );
                },
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Ver Marcos', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ContractMilestoneSheet(conversation: conversation),
                  );
                },
              ),
          ],
        ),
      );
    }

    // 2. Caso: Entrega enviada pelo Freelancer (Aguardando Aprovação)
    if (activeMilestone.status == MilestoneStatus.submitted) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryLight.withAlpha(100), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(40),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceElevatedDark,
              child: Icon(Icons.inventory_2_rounded, color: AppColors.primaryLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isClient ? '📦 Entrega Recebida!' : '⏳ Entrega Enviada',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        CurrencyFormatter.format(activeMilestone.amount),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ],
                  ),
                  Text(
                    isClient
                      ? 'Analise os arquivos e aprove para liberar o pagamento.'
                      : 'Aguardando o contratante analisar e liberar o pagamento.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isClient ? AppColors.success : AppColors.primary,
                foregroundColor: AppColors.pureWhite,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              icon: Icon(isClient ? Icons.check_circle_outline_rounded : Icons.visibility_outlined, size: 16),
              label: Text(isClient ? 'Revisar & Aprovar' : 'Ver Entrega'),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.transparent,
                  isScrollControlled: true,
                  builder: (_) => RequestRevisionModal(conversation: conversation, milestone: activeMilestone),
                );
              },
            ),
          ],
        ),
      );
    }

    // 3. Caso: Revisão Solicitada pelo Cliente
    if (activeMilestone.status == MilestoneStatus.inRevision) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withAlpha(100), width: 1.2),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.warningBg,
              child: Icon(Icons.replay_rounded, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClient ? '🔄 Revisão em Andamento' : '⚠️ Ajustes Solicitados!',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning),
                  ),
                  Text(
                    isClient
                      ? 'Você solicitou alterações no marco "${activeMilestone.title}".'
                      : 'O cliente solicitou correções. Faça os ajustes e reenvie.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isClient)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Reenviar'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => SubmitDeliverableModal(conversation: conversation, milestone: activeMilestone),
                  );
                },
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Ver Status', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ContractMilestoneSheet(conversation: conversation),
                  );
                },
              ),
          ],
        ),
      );
    }

    // 4. Caso: Marco com Pagamento em Custódia (Escrow Ativo)
    if (activeMilestone.status == MilestoneStatus.fundedInEscrow) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.successBg,
              child: Icon(Icons.lock_rounded, color: AppColors.success, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Escrow Ativo: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimaryDark),
                      ),
                      Text(
                        CurrencyFormatter.format(activeMilestone.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                      ),
                    ],
                  ),
                  Text(
                    isClient
                      ? 'Valor seguro em custódia até sua aprovação.'
                      : 'Marco: ${activeMilestone.title}. Realize a entrega quando concluir.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isClient)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Entregar'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => SubmitDeliverableModal(conversation: conversation, milestone: activeMilestone),
                  );
                },
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: AppColors.borderDark),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Marcos', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ContractMilestoneSheet(conversation: conversation),
                  );
                },
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

