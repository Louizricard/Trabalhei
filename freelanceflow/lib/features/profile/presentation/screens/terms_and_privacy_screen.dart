import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos e Privacidade')),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Termos de Uso e Política de Privacidade',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Última atualização: Outubro de 2026',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              SizedBox(height: 20),
              GlassCard(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Visão Geral da Plataforma',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'O Trabalhei é um ecossistema digital que conecta clientes contratantes a profissionais freelancers independentes para prestação de serviços de tecnologia, design e desenvolvimento.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '2. Pagamentos e Planos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'O Trabalhei não intermedeia nem retém pagamentos entre clientes e freelancers: valores e formas de pagamento dos projetos são combinados diretamente entre as partes. A plataforma é mantida por planos de assinatura opcionais (Pro) e por destaque pago de vagas.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '3. Privacidade e Proteção de Dados (LGPD)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Seus dados pessoais, mensagens e dados cadastrais são protegidos com criptografia em trânsito e controle de acesso por usuário, e jamais serão comercializados para terceiros. Você pode excluir sua conta a qualquer momento em Perfil > Excluir minha conta. Perfil, portfólio, vagas abertas, propostas pendentes, notificações e arquivos são apagados e a assinatura Pro é cancelada. Contratos já concluídos permanecem no histórico da outra parte, com seu nome anonimizado. Com contratos em andamento, conclua-os antes ou fale com o suporte.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '4. Conduta e Denúncias',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Como o pagamento é combinado entre as partes, recomendamos formalizar o acordo por escrito no chat. Em caso de conduta inadequada, entre em contato com o suporte do Trabalhei.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
