import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/legal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/back_or_exit_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';

/// Rascunho revisado; ainda precisa de revisão jurídica antes de publicar.
const _sections = <(String, String)>[
  (
    '1. Quem somos',
    'O Trabalhei é operado por ${LegalInfo.controllerName}. Contato para '
        'suporte e para '
        'assuntos de dados pessoais: ${LegalInfo.contactEmail}.\n\n'
        'Ao criar uma conta, você declara ter 18 anos ou mais e aceita estes '
        'Termos de Uso e a Política de Privacidade abaixo.',
  ),
  (
    '2. O que a plataforma faz',
    'O Trabalhei conecta clientes a freelancers: publicação de vagas, '
        'propostas, chat, acompanhamento de entregas por marcos e avaliações.\n\n'
        'O Trabalhei não é parte dos contratos entre clientes e freelancers e '
        'não intermedeia nem retém pagamentos de projetos: valores, prazos e '
        'forma de pagamento são combinados diretamente entre as partes, que '
        'respondem pelo cumprimento do que acordaram. Não garantimos a '
        'execução, a qualidade das entregas nem o pagamento. Recomendamos '
        'registrar o acordo por escrito no chat.',
  ),
  (
    '3. Sua conta',
    'Você deve informar dados verdadeiros, manter sua senha em sigilo e '
        'responder pelo uso da sua conta. Cada conta é pessoal.',
  ),
  (
    '4. Conduta',
    'É proibido publicar conteúdo ilegal, ofensivo, discriminatório ou '
        'enganoso; praticar fraude ou spam; violar direitos de terceiros; '
        'coletar dados de outros usuários; ou tentar burlar limites e regras '
        'da plataforma. Podemos remover conteúdo e suspender ou encerrar contas '
        'que descumpram estes Termos, avisando o usuário quando possível.',
  ),
  (
    '5. Avaliações',
    'A avaliação é liberada às duas partes quando o contrato é concluído e '
        'deve refletir a experiência real. Podemos remover avaliações '
        'abusivas, falsas ou que violem estes Termos.',
  ),
  (
    '6. Conteúdo e propriedade intelectual',
    'O que você publica continua sendo seu. Você nos autoriza a armazenar e '
        'exibir esse conteúdo dentro da plataforma, na medida necessária para '
        'o serviço funcionar. Os direitos sobre as entregas de cada projeto '
        'são definidos entre cliente e freelancer.',
  ),
  (
    '7. Planos, destaque de projeto e cupons',
    'Clientes usam o Trabalhei de graça para publicar projetos, receber '
        'propostas, conversar e acompanhar entregas. Freelancers têm um plano '
        'grátis, com um número de propostas por mês, e o Plano Pro, assinatura '
        'mensal opcional com mais propostas e ferramentas de organização. '
        'Clientes podem contratar o destaque de projeto por 7 dias. Os preços e '
        'limites atuais aparecem na tela Planos antes de qualquer cobrança.\n\n'
        'O pagamento é feito pelo Asaas, por Pix (dentro do app) ou cartão (na '
        'página segura do Asaas). Não vemos nem armazenamos dados de cartão. '
        'O Plano Pro renova a cada mês e pode ser cancelado a qualquer momento '
        'no app; os benefícios seguem até o fim do período já pago.\n\n'
        'Projetos destacados aparecem em um espaço identificado como '
        'patrocinado. Quando há mais projetos destacados que espaços, eles se '
        'revezam, e todos recebem o mesmo tempo. A ordem normal do mural e da '
        'busca não depende de pagamento, e o selo PRO indica apenas a '
        'assinatura, não avaliação ou experiência.\n\n'
        'Para manter a qualidade, há um limite de propostas a cada 24 horas em '
        'todos os planos. Propostas para vagas canceladas, removidas pela '
        'moderação ou sem resposta do cliente no prazo informado em Planos '
        'voltam ao saldo do mês.\n\n'
        'Cupons de desconto valem para a primeira cobrança (o primeiro mês do '
        'Pro ou o destaque), uma vez por pessoa, dentro da validade e do limite '
        'de usos de cada promoção, e não podem ser trocados por dinheiro.\n\n'
        'Você pode desistir da contratação em até 7 dias (direito de '
        'arrependimento, art. 49 do Código de Defesa do Consumidor) e receber '
        'o valor pago de volta, pedindo pelo e-mail ${LegalInfo.contactEmail}.',
  ),
  (
    '8. Dados pessoais que tratamos',
    '• Cadastro: nome, e-mail, papel (cliente ou freelancer), foto, empresa, '
        'biografia, habilidades, valor por hora e disponibilidade.\n'
        '• Uso da plataforma: vagas, propostas, contratos, mensagens, arquivos '
        'enviados e avaliações.\n'
        '• Cobrança: CPF ou CNPJ e histórico de pagamentos do Plano Pro e de '
        'destaques.\n'
        '• Técnicos: registros de acesso e registros de erros do app.',
  ),
  (
    '9. Para que usamos e com que base legal (LGPD)',
    '• Prestar o serviço que você contratou ao criar a conta (execução de '
        'contrato, art. 7º, V).\n'
        '• Cobrar assinaturas e destaques e cumprir obrigações fiscais '
        '(cumprimento de obrigação legal, art. 7º, II).\n'
        '• Manter a plataforma segura, prevenir fraudes e corrigir falhas '
        '(legítimo interesse, art. 7º, IX).\n\n'
        'Não vendemos dados pessoais e não os usamos para publicidade de '
        'terceiros.',
  ),
  (
    '10. Quem vê seus dados',
    'Seu perfil público, suas avaliações e suas vagas abertas ficam visíveis '
        'para outros usuários e para visitantes do site, mesmo sem conta. O '
        'currículo em PDF só abre para usuários logados. Mensagens e arquivos '
        'do chat, entregas e pedidos de '
        'revisão só são acessíveis às partes da conversa ou do contrato.\n\n'
        'Usamos fornecedores que tratam dados em nosso nome: Supabase (banco '
        'de dados, arquivos e login; servidores em São Paulo), Vercel '
        '(hospedagem do site), Asaas (pagamentos) e Sentry (registro de '
        'erros). Alguns têm sede ou servidores fora do Brasil; nesses casos a '
        'transferência segue as salvaguardas do art. 33 da LGPD.',
  ),
  (
    '11. Por quanto tempo guardamos',
    'Enquanto sua conta existir. Ao excluí-la, apagamos ou anonimizamos os '
        'dados conforme o item 13. Registros de cobrança são mantidos pelo '
        'prazo exigido pela legislação fiscal, e registros de acesso, pelo '
        'prazo do Marco Civil da Internet (6 meses).',
  ),
  (
    '12. Seus direitos',
    'Você pode pedir confirmação e acesso aos seus dados, correção, '
        'portabilidade, anonimização ou eliminação, informação sobre com quem '
        'compartilhamos e revogação de consentimento (art. 18 da LGPD). '
        'Corrija dados no seu perfil e exclua a conta em Perfil > Excluir '
        'minha conta; os demais pedidos podem ser feitos pelo e-mail '
        '${LegalInfo.contactEmail}, com resposta em até 15 dias. Você também '
        'pode reclamar à Autoridade Nacional de Proteção de Dados (ANPD).',
  ),
  (
    '13. Exclusão de conta',
    'Ao excluir a conta, apagamos perfil, portfólio, vagas abertas, '
        'propostas pendentes, notificações e arquivos, e a assinatura Pro, se '
        'houver, é cancelada. Contratos já concluídos permanecem no histórico '
        'da outra parte, com seu nome anonimizado. Com contratos em andamento, '
        'conclua-os antes ou fale com o suporte.',
  ),
  (
    '14. Segurança e armazenamento no navegador',
    'Os dados trafegam criptografados, o acesso é controlado por usuário e '
        'as senhas são guardadas apenas em forma de hash. Na versão web, a '
        'sessão fica no armazenamento local do navegador para manter você '
        'conectado; não usamos cookies de publicidade.',
  ),
  (
    '15. Alterações e foro',
    'Podemos atualizar estes Termos; mudanças relevantes serão avisadas no '
        'app. Aplica-se a lei brasileira, e fica eleito o foro do domicílio do '
        'usuário consumidor.',
  ),
];

class TermsAndPrivacyScreen extends ConsumerWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authProvider).valueOrNull != null;
    return Scaffold(
      appBar: AppBar(
        // Aberta direto pela homepage não há tela anterior no app.
        leading: BackOrExitButton(
          fallbackRoute: loggedIn ? '/profile' : '/login',
        ),
        title: const Text('Termos e Privacidade'),
      ),
      body: ResponsiveLayout(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Termos de Uso e Política de Privacidade',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Última atualização: ${LegalInfo.termsUpdatedAt}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, (title, body)) in _sections.indexed) ...[
                      if (index > 0) const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
