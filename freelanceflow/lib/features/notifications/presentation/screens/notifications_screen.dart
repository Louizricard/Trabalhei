import 'package:flutter/material.dart';
import '../../../../core/errors/backend_errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _filterUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimaryDark,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Text(
              'Notificações',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () => ref
                  .read(notificationManagerProvider.notifier)
                  .markAllAsRead(),
              icon: const Icon(
                Icons.done_all_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              label: const Text(
                'Ler todas',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: !_filterUnreadOnly,
                  onSelected: (selected) {
                    if (selected) setState(() => _filterUnreadOnly = false);
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surfaceDark,
                  labelStyle: TextStyle(
                    color: !_filterUnreadOnly
                        ? AppColors.primary
                        : AppColors.textSecondaryDark,
                    fontWeight: !_filterUnreadOnly
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Não lidas ($unreadCount)'),
                  selected: _filterUnreadOnly,
                  onSelected: (selected) {
                    if (selected) setState(() => _filterUnreadOnly = true);
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surfaceDark,
                  labelStyle: TextStyle(
                    color: _filterUnreadOnly
                        ? AppColors.primary
                        : AppColors.textSecondaryDark,
                    fontWeight: _filterUnreadOnly
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erro ao carregar notificações: ${friendlyError(err)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondaryDark),
                  ),
                ),
              ),
              data: (notifications) {
                final filtered = _filterUnreadOnly
                    ? notifications.where((n) => !n.isRead).toList()
                    : notifications;

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filterUnreadOnly
                              ? Icons.mark_email_read_outlined
                              : Icons.notifications_none_rounded,
                          size: 64,
                          color: AppColors.textMutedDark,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filterUnreadOnly
                              ? 'Nenhuma notificação não lida'
                              : 'Você não tem notificações',
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Avisos sobre mensagens, propostas e marcos aparecerão aqui.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notif = filtered[index];
                    return _NotificationTile(
                      notification: notif,
                      onTap: () => _handleNotificationTap(notif),
                      onDismissed: () => ref
                          .read(notificationManagerProvider.notifier)
                          .deleteNotification(notif.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(AppNotification notif) {
    if (!notif.isRead) {
      ref.read(notificationManagerProvider.notifier).markAsRead(notif.id);
    }

    final targetRoute = notif.targetRoute;
    if (targetRoute != null && targetRoute.isNotEmpty) {
      try {
        context.push(targetRoute);
      } catch (e) {
        debugPrint(
          '🚨 [NotificationNavigation] Erro ao navegar para $targetRoute: $e',
        );
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final typeConfig = _getTypeConfig(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          backgroundColor: notification.isRead
              ? AppColors.surfaceDark.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.08),
          borderColor: notification.isRead
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.primary.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: typeConfig.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    typeConfig.icon,
                    color: typeConfig.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimaryDark,
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(notification.createdAt),
                            style: const TextStyle(
                              color: AppColors.textMutedDark,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: notification.isRead
                              ? AppColors.textSecondaryDark
                              : AppColors.textPrimaryDark.withValues(
                                  alpha: 0.9,
                                ),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Unread Indicator Dot
                if (!notification.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _TypeConfig _getTypeConfig(NotificationType type) {
    switch (type) {
      case NotificationType.newMessage:
        return const _TypeConfig(Icons.chat_bubble_rounded, AppColors.primary);
      case NotificationType.proposalReceived:
        return const _TypeConfig(
          Icons.assignment_ind_rounded,
          Colors.purpleAccent,
        );
      case NotificationType.proposalAccepted:
      case NotificationType.contractActive:
        return const _TypeConfig(Icons.verified_rounded, Colors.tealAccent);
      case NotificationType.milestoneSubmitted:
        return const _TypeConfig(Icons.rate_review_rounded, Colors.amber);
      case NotificationType.milestoneInRevision:
        return const _TypeConfig(Icons.replay_rounded, Colors.orangeAccent);
      case NotificationType.milestoneApproved:
        return const _TypeConfig(
          Icons.check_circle_rounded,
          Colors.greenAccent,
        );
      case NotificationType.jobAlert:
        return const _TypeConfig(Icons.travel_explore_rounded, AppColors.info);
      case NotificationType.system:
        return const _TypeConfig(
          Icons.notifications_active_rounded,
          Colors.blueAccent,
        );
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  const _TypeConfig(this.icon, this.color);
}
