import 'package:trabalhei/core/utils/rating_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/add_portfolio_modal.dart';
import '../widgets/invite_to_job_modal.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isStartingChat = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleStartDirectChat(
    UserProfile targetUser,
    UserProfile currentUser,
  ) async {
    setState(() => _isStartingChat = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      // Cria ou recupera conversa direta
      final isClient = currentUser.role == UserRole.client;
      final conversation = await chatRepo.getOrCreateConversation(
        jobId: '00000000-0000-0000-0000-000000000000', // conversa direta
        freelancerId: isClient ? targetUser.id : currentUser.id,
        clientId: isClient ? currentUser.id : targetUser.id,
      );

      if (mounted) {
        context.push('/chat/${conversation.id}');
      }
    } catch (_) {
      if (mounted) {
        // Fallback: abrir modal de convite para vaga se for cliente
        if (currentUser.role == UserRole.client) {
          InviteToJobModal.show(context, targetUser);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Para iniciar conversa, selecione uma proposta ou projeto.',
              ),
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProfileProvider(widget.userId));
    final portfolioAsync = ref.watch(userPortfolioProvider(widget.userId));
    final reviewsAsync = ref.watch(publicReviewsProvider(widget.userId));
    final currentUser = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Profissional'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartilhar Perfil',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Link do perfil copiado para a área de transferência!',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: EmptyStateWidget(
            icon: Icons.person_off_outlined,
            title: 'Perfil não encontrado',
            description: 'O perfil solicitado não existe ou está indisponível.',
            actionText: 'Voltar',
            onAction: () => context.pop(),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: EmptyStateWidget(
                icon: Icons.person_off_outlined,
                title: 'Perfil não encontrado',
                description: 'Não encontramos o usuário especificado.',
                actionText: 'Voltar',
                onAction: () => context.pop(),
              ),
            );
          }

          final isOwner = currentUser?.id == profile.id;
          final isClient = currentUser?.role == UserRole.client;
          final isAvailable = profile.availabilityStatus == 'available';

          return ResponsiveLayout(
            child: Column(
              children: [
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              children: [
                                // Header: Avatar Grande + Glow
                                Center(
                                  child: Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary.withAlpha(
                                              204,
                                            ),
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withAlpha(51),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 46,
                                          backgroundColor:
                                              AppColors.surfaceElevatedDark,
                                          backgroundImage:
                                              profile.avatarUrl != null &&
                                                  profile.avatarUrl!.isNotEmpty
                                              ? NetworkImage(profile.avatarUrl!)
                                              : null,
                                          child:
                                              profile.avatarUrl == null ||
                                                  profile.avatarUrl!.isEmpty
                                              ? Text(
                                                  profile.fullName
                                                          .trim()
                                                          .isNotEmpty
                                                      ? profile.fullName
                                                            .trim()[0]
                                                            .toUpperCase()
                                                      : 'U',
                                                  style: const TextStyle(
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                      if (profile.isVerified)
                                        const Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor:
                                                AppColors.surfaceDark,
                                            child: Icon(
                                              Icons.verified_rounded,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Nome & Cargo
                                Text(
                                  profile.fullName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimaryDark,
                                    letterSpacing: -0.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),

                                Text(
                                  profile.role == UserRole.client
                                      ? (profile.companyName ??
                                            'Empresa Contratante')
                                      : (profile.skills.isNotEmpty
                                            ? profile.skills.take(3).join(' • ')
                                            : 'Profissional Freelancer'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),

                                // Badge de Disponibilidade
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isAvailable
                                                ? AppColors.success
                                                : AppColors.warning)
                                            .withAlpha(30),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          (isAvailable
                                                  ? AppColors.success
                                                  : AppColors.warning)
                                              .withAlpha(100),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? AppColors.success
                                              : AppColors.warning,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isAvailable
                                            ? 'Disponível para novos projetos'
                                            : 'Ocupado no momento',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isAvailable
                                              ? AppColors.success
                                              : AppColors.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Cards de Métricas Rápidas
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        icon: Icons.star_rounded,
                                        iconColor: AppColors.warning,
                                        value: RatingFormatter.format(profile.rating),
                                        label: 'Avaliação',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildMetricCard(
                                        icon: Icons.workspace_premium_rounded,
                                        iconColor: AppColors.primary,
                                        value: '${profile.completedJobsCount}',
                                        label: 'Entregas',
                                      ),
                                    ),
                                    if (profile.role != UserRole.client) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildMetricCard(
                                          icon: Icons.payments_outlined,
                                          iconColor: AppColors.primary,
                                          value: CurrencyFormatter.format(
                                            profile.hourlyRate,
                                          ),
                                          label: 'por hora',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarDelegate(
                            TabBar(
                              controller: _tabController,
                              labelColor: AppColors.primary,
                              unselectedLabelColor: AppColors.textSecondaryDark,
                              indicatorColor: AppColors.primary,
                              indicatorWeight: 3,
                              tabs: const [
                                Tab(text: 'Sobre & Skills'),
                                Tab(text: 'Portfólio'),
                                Tab(text: 'Avaliações'),
                              ],
                            ),
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Sobre & Skills
                        _buildAboutTab(profile),

                        // Tab 2: Portfólio
                        _buildPortfolioTab(portfolioAsync, isOwner),

                        // Tab 3: Avaliações
                        _buildReviewsTab(reviewsAsync),
                      ],
                    ),
                  ),
                ),

                // Barra Inferior de Ação (Apenas para outros usuários logados)
                if (!isOwner && currentUser != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceDark,
                      border: Border(
                        top: BorderSide(color: AppColors.borderDark, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Mensagem',
                            variant: ButtonVariant.secondary,
                            icon: Icons.chat_bubble_outline_rounded,
                            isLoading: _isStartingChat,
                            onPressed: () =>
                                _handleStartDirectChat(profile, currentUser),
                          ),
                        ),
                        if (isClient) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: CustomButton(
                              text: 'Convidar para Vaga',
                              variant: ButtonVariant.primary,
                              icon: Icons.send_rounded,
                              onPressed: () =>
                                  InviteToJobModal.show(context, profile),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 14,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMutedDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab(UserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio
          const Text(
            'Sobre o Profissional',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Text(
              profile.bio != null && profile.bio!.trim().isNotEmpty
                  ? profile.bio!
                  : 'Nenhuma biografia detalhada informada ainda.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Habilidades
          const Text(
            'Habilidades & Especialidades',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          if (profile.skills.isEmpty)
            const Text(
              'Nenhuma habilidade cadastrada.',
              style: TextStyle(color: AppColors.textMutedDark, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.skills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withAlpha(76)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // Segurança e Garantia Trabalhei
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contrate com tranquilidade',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Converse, alinhe entregas por marcos e avalie o freelancer ao final do projeto.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab(
    AsyncValue<List<dynamic>> portfolioAsync,
    bool isOwner,
  ) {
    return portfolioAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) =>
          Center(child: Text('Erro ao carregar portfólio: $err')),
      data: (items) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOwner) ...[
                CustomButton(
                  text: 'Adicionar Projeto ao Portfólio',
                  icon: Icons.add_photo_alternate_outlined,
                  variant: ButtonVariant.primary,
                  onPressed: () => AddPortfolioModal.show(context),
                ),
                const SizedBox(height: 16),
              ],
              if (items.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: EmptyStateWidget(
                      icon: Icons.photo_library_outlined,
                      title: 'Nenhum projeto no portfólio',
                      description: isOwner
                          ? 'Adicione seus melhores trabalhos para atrair mais contratantes!'
                          : 'Este profissional ainda não adicionou projetos ao portfólio.',
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderRadius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                item.imageUrl,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 120,
                                      color: AppColors.surfaceElevatedDark,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: AppColors.textMutedDark,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryDark,
                                  ),
                                ),
                              ),
                              if (isOwner)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final deleteFn = ref.read(
                                      deletePortfolioItemProvider,
                                    );
                                    await deleteFn(item.id);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          if (item.tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: (item.tags as List<dynamic>).map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevatedDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.borderDark,
                                    ),
                                  ),
                                  child: Text(
                                    tag.toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(AsyncValue<List<dynamic>> reviewsAsync) {
    return reviewsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) =>
          Center(child: Text('Erro ao carregar avaliações: $err')),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: EmptyStateWidget(
                icon: Icons.rate_review_outlined,
                title: 'Nenhuma avaliação ainda',
                description:
                    'As avaliações aparecerão aqui conforme os contratos forem concluídos.',
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final review = reviews[index];
            return GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              review.authorName.isNotEmpty
                                  ? review.authorName[0].toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.authorName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimaryDark,
                                ),
                              ),
                              Text(
                                review.projectTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMutedDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (review.comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      review.comment,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryDark,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.surfaceDark, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
