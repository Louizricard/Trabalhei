import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';

class InviteToJobModal extends ConsumerStatefulWidget {
  final UserProfile freelancer;

  const InviteToJobModal({super.key, required this.freelancer});

  static Future<void> show(BuildContext context, UserProfile freelancer) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => InviteToJobModal(freelancer: freelancer),
    );
  }

  @override
  ConsumerState<InviteToJobModal> createState() => _InviteToJobModalState();
}

class _InviteToJobModalState extends ConsumerState<InviteToJobModal> {
  String? _selectedJobId;
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messageController.text =
        'Olá ${widget.freelancer.fullName}, vi seu perfil e gostaria de convidar você para participar do meu projeto!';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Job> myJobs) async {
    final client = ref.read(authProvider).value;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para enviar um convite.')),
      );
      return;
    }

    if (_selectedJobId == null && myJobs.isNotEmpty) {
      _selectedJobId = myJobs.first.id;
    }

    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa publicar uma vaga antes de convidar freelancers.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversation = await chatRepo.getOrCreateConversation(
        jobId: _selectedJobId!,
        freelancerId: widget.freelancer.id,
        clientId: client.id,
      );

      final messageText = _messageController.text.trim();
      if (messageText.isNotEmpty) {
        await chatRepo.sendMessage(conversation.id, messageText);
      }

      if (mounted) {
        Navigator.of(context).pop();
        context.push('/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar convite: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(authProvider).value;
    final allJobsAsync = ref.watch(jobsListProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: allJobsAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Erro ao carregar vagas: $err', style: const TextStyle(color: AppColors.error)),
        ),
        data: (allJobs) {
          final myJobs = allJobs.where((j) => j.clientId == client?.id).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Convidar ${widget.freelancer.fullName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecione uma vaga em aberto e envie uma mensagem direta de convite.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
              ),
              const SizedBox(height: 16),

              if (myJobs.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.work_outline_rounded, color: AppColors.warning, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'Você ainda não possui vagas abertas',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Crie um projeto primeiro para poder convidar profissionais.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Publicar Vaga Agora',
                        variant: ButtonVariant.primary,
                        height: 40,
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/jobs/create');
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'Selecione o Projeto',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedJobId ?? myJobs.first.id,
                      dropdownColor: AppColors.cardDark,
                      items: myJobs.map((j) {
                        return DropdownMenuItem(
                          value: j.id,
                          child: Text(
                            j.title,
                            style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedJobId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _messageController,
                  label: 'Mensagem de Apresentação',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                CustomButton(
                  text: 'Enviar Convite e Abrir Chat',
                  isLoading: _isLoading,
                  icon: Icons.send_rounded,
                  onPressed: () => _submit(myJobs),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
