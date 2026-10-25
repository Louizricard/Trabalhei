import 'package:trabalhei/features/chat/domain/entities/chat_message.dart';
import 'package:trabalhei/features/chat/domain/entities/conversation.dart';
import 'package:trabalhei/features/notifications/domain/entities/app_notification.dart';
import 'demo_data.dart';

const _contractId = 'demo-contract-1';
const _jobTitle = 'App de agendamento para clínica veterinária';

/// Conversa do contrato vista por [viewerIsClient] (o "outro" lado muda).
Conversation demoConversation({required bool viewerIsClient}) {
  final other = viewerIsClient ? demoFreelancer : demoClient;
  return Conversation(
    id: conversationId,
    contractId: _contractId,
    contractStatus: 'active',
    clientId: demoClient.id,
    freelancerId: demoFreelancer.id,
    jobTitle: _jobTitle,
    otherParticipantId: other.id,
    otherParticipantName: viewerIsClient ? other.fullName : 'Carla Menezes',
    lastMessage: 'Build de teste enviada. Pode instalar e conferir a agenda.',
    lastMessageAt: ago(minutes: 12),
    unreadCount: viewerIsClient ? 1 : 0,
    // Sem marcos na proposta, o servidor cria um marco único com o valor total.
    milestones: [
      ContractMilestone(
        id: 'demo-ms-1',
        contractId: _contractId,
        title: 'Entrega do projeto',
        amount: 5200,
        status: MilestoneStatus.submitted,
        dueDate: ago(days: -12),
        deliverableNotes:
            'Build de teste com agenda, lembretes e cadastro de pets.',
        submittedAt: ago(minutes: 14),
      ),
    ],
  );
}

List<Conversation> demoConversations({required bool viewerIsClient}) => [
  demoConversation(viewerIsClient: viewerIsClient),
  Conversation(
    id: 'demo-conv-2',
    jobTitle: 'Identidade visual para cafeteria',
    otherParticipantId: 'demo-f2',
    otherParticipantName: 'Juliana Prado',
    lastMessage: 'Envio as três opções de logo amanhã cedo.',
    lastMessageAt: ago(hours: 3),
  ),
  Conversation(
    id: 'demo-conv-3',
    jobTitle: 'API de pedidos com pagamento via Pix',
    otherParticipantId: 'demo-f3',
    otherParticipantName: 'Tiago Ramos',
    lastMessage: 'Webhook de confirmação testado no sandbox.',
    lastMessageAt: ago(days: 1),
  ),
];

ChatMessage _msg(
  String id,
  String senderId,
  String content,
  DateTime at, {
  MessageType type = MessageType.text,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  senderId: senderId,
  content: content,
  messageType: type,
  isRead: true,
  createdAt: at,
);

/// Mesmos textos de sistema gerados pelas funções do banco.
List<ChatMessage> demoMessages() {
  final c = demoClient.id;
  final f = demoFreelancer.id;
  const system = MessageType.systemEvent;
  return [
    _msg(
      'm1',
      c,
      '🤝 Contrato iniciado para "$_jobTitle". Combinem prazos e forma de '
          'pagamento aqui no chat.',
      ago(days: 16),
      type: system,
    ),
    _msg(
      'm2',
      c,
      'Oi, Rafael! Podemos começar pelo fluxo de agendamento?',
      ago(days: 16),
    ),
    _msg(
      'm3',
      f,
      'Claro! Metade no início e metade na entrega, como combinamos?',
      ago(days: 16),
    ),
    _msg('m4', c, 'Combinado. Pago por Pix nas duas etapas.', ago(days: 16)),
    _msg(
      'm6',
      f,
      '📦 Entrega enviada para o marco "Entrega do projeto":\n\n"Build de '
          'teste com agenda, lembretes e cadastro de pets."',
      ago(minutes: 14),
      type: system,
    ),
    _msg(
      'm7',
      f,
      'Build de teste enviada. Pode instalar e conferir a agenda.',
      ago(minutes: 12),
    ),
  ];
}

List<AppNotification> demoNotifications(String userId) => [
  AppNotification(
    id: 'n1',
    userId: userId,
    title: 'Entrega recebida',
    body: 'O marco "Entrega do projeto" de "$_jobTitle" aguarda sua análise.',
    type: NotificationType.milestoneSubmitted,
    createdAt: ago(minutes: 14),
  ),
  AppNotification(
    id: 'n2',
    userId: userId,
    title: 'Nova proposta recebida',
    body: 'Juliana Prado enviou uma proposta para "$_jobTitle".',
    type: NotificationType.proposalReceived,
    createdAt: ago(hours: 2),
  ),
];
