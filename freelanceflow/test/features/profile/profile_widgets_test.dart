import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:trabalhei/features/profile/presentation/widgets/profile_settings.dart';

void main() {
  testWidgets('cabeçalho e opções do perfil cabem em tela de 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final user = UserProfile(
      id: 'u1',
      email: 'um.email.bem.comprido.para.testar@exemplo.com.br',
      fullName: 'Nome Completo Bastante Comprido da Silva',
      role: UserRole.freelancer,
      rating: 4.8,
      reviewsCount: 12,
      completedJobsCount: 7,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ProfileHeaderCard(
                  user: user,
                  isUploadingAvatar: false,
                  onPickAvatar: () {},
                  onEditProfile: () {},
                  onViewPublicProfile: () {},
                ),
                const ProfileSettingsGroup(
                  title: 'Conta',
                  children: [
                    ProfileSettingsTile(
                      icon: Icons.policy_outlined,
                      title: 'Termos de Uso e Privacidade',
                    ),
                    ProfileSettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Excluir minha conta',
                      subtitle: 'Apaga seu perfil e seus dados de forma permanente',
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Projetos concluídos'), findsOneWidget);
    expect(find.text('Excluir minha conta'), findsOneWidget);
  });
}
