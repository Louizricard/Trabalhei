import 'package:trabalhei/core/errors/backend_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trabalhei/core/theme/app_colors.dart';
import 'package:trabalhei/core/widgets/empty_state.dart';
import 'package:trabalhei/core/widgets/notification_bell_button.dart';
import 'package:trabalhei/core/widgets/responsive_layout.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/auth/presentation/guest_access.dart';
import 'package:trabalhei/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:trabalhei/features/auth/presentation/providers/pending_confirmation_provider.dart';
import 'package:trabalhei/features/auth/presentation/widgets/pending_confirmation_banner.dart';
import 'package:trabalhei/features/jobs/presentation/providers/jobs_provider.dart';
import 'package:trabalhei/features/jobs/presentation/widgets/job_card.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal.dart';
import 'package:trabalhei/features/proposals/presentation/providers/proposals_provider.dart';
import 'package:trabalhei/features/chat/presentation/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';

class JobsListScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  const JobsListScreen({super.key, this.initialCategory});

  @override
  ConsumerState<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends ConsumerState<JobsListScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider);
    final auth = ref.watch(authProvider);
    final user = auth.valueOrNull;
    final isClient = user?.role == UserRole.client;
    final isGuest = !auth.isLoading && user == null;
    final pendingEmail = ref.watch(pendingConfirmationProvider);

    final proposalsAsync = user != null
        ? ref.watch(freelancerProposalsProvider(user.id))
        : const AsyncValue<List<Proposal>>.data([]);

    final categories = [
      'Todos',
      if (isClient) 'Minhas Vagas',
      'Mobile',
      'Design',
      'Fullstack',
      'Frontend',
      'Backend',
      'DevOps',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mural de Vagas'),
        actions: [
          // Visitante: Entrar e Criar conta ficam no aviso abaixo.
          if (!isGuest) const NotificationBellButton(),
          if (isClient || isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Publicar Vaga'),
                onPressed: () async {
                  if (await requireAccount(
                        context,
                        ref,
                        action: 'publicar uma vaga',
                        returnTo: '/jobs/create',
                      ) &&
                      context.mounted) {
                    context.push('/jobs/create');
                  }
                },
              ),
            ),
        ],
      ),
      body: ResponsiveLayout(
        child: Column(
          children: [
            // Visitante: cadastro aguardando confirmação mantém o aviso;
            // os demais veem o convite para criar a conta.
            if (isGuest)
              pendingEmail != null && pendingEmail.isNotEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: PendingConfirmationBanner(),
                    )
                  : const GuestWelcomeBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimaryDark),
                decoration: InputDecoration(
                  hintText: 'Buscar vagas por título, tecnologia ou cliente...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondaryDark,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected =
                      (_selectedCategory == null && cat == 'Todos') ||
                      _selectedCategory == cat;

                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat == 'Todos' ? null : cat;
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceElevatedDark,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textSecondaryDark,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderDark,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: jobsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Erro ao carregar vagas',
                  description: friendlyError(err),
                ),
                data: (jobs) {
                  var filtered = jobs;
                  if (_selectedCategory != null) {
                    if (_selectedCategory == 'Minhas Vagas') {
                      filtered = filtered
                          .where((j) => j.clientId == user?.id)
                          .toList();
                    } else {
                      filtered = filtered
                          .where(
                            (j) =>
                                j.category.toLowerCase() ==
                                _selectedCategory!.toLowerCase(),
                          )
                          .toList();
                    }
                  }
                  if (_searchController.text.isNotEmpty) {
                    final query = _searchController.text.toLowerCase();
                    filtered = filtered
                        .where(
                          (j) =>
                              j.title.toLowerCase().contains(query) ||
                              j.skillsRequired.any(
                                (s) => s.toLowerCase().contains(query),
                              ),
                        )
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.work_off_outlined,
                      title: 'Nenhuma vaga encontrada',
                      description:
                          'Tente alterar os filtros de busca ou volte mais tarde.',
                    );
                  }

                  final appliedJobIds = proposalsAsync.maybeWhen(
                    data: (list) => list.map((p) => p.jobId).toSet(),
                    orElse: () => <String>{},
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(jobsListProvider);
                      if (user != null) {
                        ref.invalidate(freelancerProposalsProvider(user.id));
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        Widget cardFor(Job job, {bool fillHeight = false}) {
                          return JobCard(
                            fillHeight: fillHeight,
                            job: job,
                            userHasApplied: appliedJobIds.contains(job.id),
                            isOwner: user?.id == job.clientId,
                            onTap: () => context.push('/jobs/${job.id}'),
                            onApply: () async {
                              if (await requireAccount(
                                    context,
                                    ref,
                                    action: 'enviar uma proposta',
                                    returnTo: '/jobs/${job.id}/apply',
                                  ) &&
                                  context.mounted) {
                                context.push('/jobs/${job.id}/apply');
                              }
                            },
                            onMessage: () async {
                              if (user == null) return;
                              try {
                                final conv = await ref
                                    .read(chatRepositoryProvider)
                                    .getOrCreateConversation(
                                      jobId: job.id,
                                      freelancerId: user.id,
                                      clientId: job.clientId,
                                    );
                                if (context.mounted) {
                                  context.push('/chat/${conv.id}');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Erro ao abrir chat: ${friendlyError(e)}',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        }

                        if (constraints.maxWidth > 650) {
                          return GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400,
                                  mainAxisExtent:
                                      540, // altura fixa (cabe título e descrição longos + 2 botões)
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                cardFor(filtered[index], fillHeight: true),
                          );
                        }

                        // Celular: cada card tem a altura do próprio conteúdo.
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              cardFor(filtered[index]),
                        );
                      },
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
}
