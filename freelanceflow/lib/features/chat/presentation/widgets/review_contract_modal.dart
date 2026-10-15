import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../../core/errors/backend_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/conversation.dart';
import '../providers/chat_provider.dart';

class ReviewContractModal extends ConsumerStatefulWidget {
  final Conversation conversation;

  const ReviewContractModal({super.key, required this.conversation});

  @override
  ConsumerState<ReviewContractModal> createState() =>
      _ReviewContractModalState();
}

class _ReviewContractModalState extends ConsumerState<ReviewContractModal> {
  final _commentController = TextEditingController();
  double _rating = 5.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitReview() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final currentUser = ref.read(authProvider).value;
      if (currentUser == null) throw Exception('Não autenticado');

      final contractId = widget.conversation.contractId;
      if (contractId == null) {
        throw Exception('Esta conversa não possui um contrato para avaliar.');
      }

      final targetId = widget.conversation.otherParticipantId;
      final comment = _commentController.text.trim();

      await supabase.from('reviews').insert({
        'contract_id': contractId,
        'reviewer_id': currentUser.id,
        'target_id': targetId,
        'rating': _rating.toInt(),
        'comment': comment.isEmpty ? null : comment,
      });

      ref.invalidate(userReviewsProvider);
      ref.invalidate(publicReviewsProvider(targetId));
      ref.invalidate(conversationDetailProvider(widget.conversation.id));
      ref.invalidate(clientStatsProvider);
      ref.invalidate(freelancerStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Avaliação enviada com sucesso! Obrigado pelo feedback.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('23505') ||
                      e.toString().contains('duplicate key')
                  ? 'Você já avaliou este contrato.'
                  : 'Erro ao enviar avaliação: ${friendlyError(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    final isClient = currentUser?.id == widget.conversation.clientId;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isClient ? 'Avaliar Profissional' : 'Avaliar Contratante',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isClient
                  ? 'Como foi a entrega do projeto "${widget.conversation.jobTitle}"?'
                  : 'Como foi a parceria e comunicação com o contratante no projeto "${widget.conversation.jobTitle}"?',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    iconSize: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(
                      starIndex <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.warning,
                    ),
                    onPressed: () =>
                        setState(() => _rating = starIndex.toDouble()),
                  );
                }),
              ),
            ),
            Center(
              child: Text(
                '$_rating de 5.0 estrelas',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _commentController,
              label: 'Seu Comentário ou Elogio',
              hint: isClient
                  ? 'Conte como foi trabalhar com este profissional...'
                  : 'Conte como foi a experiência com este contratante...',
              prefixIcon: Icons.rate_review_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Enviar Avaliação',
              icon: Icons.send_rounded,
              isLoading: _isLoading,
              onPressed: _handleSubmitReview,
            ),
          ],
        ),
      ),
    );
  }
}
