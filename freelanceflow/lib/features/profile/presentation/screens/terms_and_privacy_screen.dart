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
                'Última atualização: Agosto de 2026',
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
                      '2. Sistema de Pagamento em Escrow',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Para garantir a segurança financeira de ambas as partes, todos os valores acordados são retidos em conta de custódia (Escrow) e liberados apenas após a aprovação expressa dos marcos pelo contratante.',
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
                      'Seus dados pessoais, mensagens e dados cadastrais são protegidos com criptografia de ponta a ponta e jamais serão comercializados para terceiros. Você pode solicitar a exclusão de sua conta a qualquer momento através do suporte.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '4. Resolução de Disputas e Mediação',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Em caso de divergências na entrega dos marcos de um projeto, qualquer uma das partes poderá acionar o botão "Abrir Mediação" para intervenção imparcial da equipe de suporte do Trabalhei.',
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
