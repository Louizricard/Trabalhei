import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freelanceflow/core/theme/app_colors.dart';
import 'package:freelanceflow/core/utils/date_formatter.dart';
import 'package:freelanceflow/core/widgets/empty_state.dart';
import 'package:freelanceflow/core/widgets/glass_card.dart';
import 'package:freelanceflow/core/widgets/responsive_layout.dart';
import 'package:freelanceflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convAsync = ref.watch(conversationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversas & Projetos'),
      ),
      body: ResponsiveLayout(
        child: convAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar conversas',
            description: err.toString(),
          ),
          data: (conversations) {
            if (conversations.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Nenhuma conversa ativa',
                description: 'Suas mensagens e negociações com clientes e freelancers aparecerão aqui.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () => context.push('/chat/${conv.id}'),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          conv.otherParticipantName.trim().isNotEmpty
                              ? conv.otherParticipantName.trim()[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    conv.otherParticipantName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimaryDark),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  DateFormatter.relativeTime(conv.lastMessageAt),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              conv.jobTitle,
                              style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              conv.lastMessage,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (conv.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
