import 'entities/pricing.dart';

/// Textos da página de planos montados a partir do [Pricing] do servidor.
/// Cada afirmação aqui precisa ter linha na conferência de
/// docs/monetizacao.md ("o que é prometido × onde é aplicado").

List<String> freeBenefits(PlatformSettings s) => [
  'Perfil e portfólio públicos para os clientes encontrarem você',
  'Envie até ${s.freeMonthlyProposals} propostas por mês',
  'Chat, contratos, marcos e entregas sem custo',
  'Envie arquivos de até ${s.freeFileMb} MB',
];

List<String> proBenefits(PlatformSettings s) => [
  'Envie até ${s.proMonthlyProposals} propostas por mês',
  'Responda mais rápido com até ${s.maxProposalTemplates} modelos de proposta',
  'Organize clientes e anotações em um só lugar',
  'Veja quais propostas são aceitas com as estatísticas',
  'Envie arquivos de até ${s.proFileMb} MB',
  'Selo PRO no perfil e nas propostas enviadas',
];

List<String> hiringBenefits() => const [
  'Publique vagas e receba propostas sem pagar nada',
  'Converse, negocie e combine marcos no chat',
  'Acompanhe entregas e aprove cada etapa',
  'Avalie o profissional ao concluir',
];

List<String> sponsoredBenefits(PlatformSettings s) => [
  'Sua vaga aparece no topo do mural com a etiqueta "Patrocinado"',
  'Até ${s.sponsoredSlots} vagas patrocinadas por vez; com mais, elas se '
      'revezam a cada ${rotationText(s.sponsoredRotationMinutes)}',
  'A busca e a ordem das demais vagas não mudam',
  'Contratado na página da vaga, quando você quiser',
];

/// Uma linha da tabela comparativa Grátis × Pro.
typedef PlanRow = ({String label, String free, String pro});

const planIncluded = '✓';
const planNotIncluded = '—';

List<PlanRow> planComparison(PlatformSettings s) => [
  (
    label: 'Propostas por mês',
    free: '${s.freeMonthlyProposals}',
    pro: '${s.proMonthlyProposals}',
  ),
  (
    label: 'Propostas a cada 24 h',
    free: '${s.dailyProposals}',
    pro: '${s.dailyProposals}',
  ),
  (
    label: 'Tamanho por arquivo',
    free: '${s.freeFileMb} MB',
    pro: '${s.proFileMb} MB',
  ),
  (
    label: 'Modelos de proposta',
    free: planNotIncluded,
    pro: '${s.maxProposalTemplates}',
  ),
  (label: 'Organização de clientes', free: planNotIncluded, pro: planIncluded),
  (label: 'Estatísticas', free: planNotIncluded, pro: planIncluded),
  (label: 'Selo PRO', free: planNotIncluded, pro: planIncluded),
  (label: 'Chat, contratos e entregas', free: planIncluded, pro: planIncluded),
];

List<String> planRules(PlatformSettings s) => [
  'Propostas para vagas canceladas, removidas pela moderação ou sem resposta '
      'do cliente em ${s.unansweredRefundDays} dias voltam ao seu saldo.',
  'Para evitar envio em massa, cada conta envia até ${s.dailyProposals} '
      'propostas a cada 24 horas, em qualquer plano.',
  'A busca não favorece quem paga: a ordem considera compatibilidade, '
      'avaliações e trabalhos concluídos.',
  'O selo PRO mostra que a pessoa assina o plano. Confiança vem das '
      'avaliações e dos trabalhos concluídos.',
];

/// Perguntas frequentes (pergunta, resposta).
List<(String, String)> planFaq(Pricing p) => [
  (
    'Posso cancelar o Pro quando quiser?',
    'Sim. Você mantém os benefícios até o fim do período já pago.',
  ),
  (
    'Como pago?',
    'Por Pix ou cartão. Com cupom, o desconto vale para o primeiro mês.',
  ),
  (
    'A plataforma cobra comissão sobre o trabalho?',
    'Não. O valor do trabalho é combinado e pago diretamente entre as partes.',
  ),
  (
    'Qual a diferença entre "Prazo urgente" e o destaque?',
    '"Prazo urgente" é grátis e só avisa que o trabalho precisa começar logo; '
        'não muda a posição da vaga. O destaque patrocinado coloca a vaga no '
        'topo do mural por ${p.feature.periodDays} dias.',
  ),
];

String rotationText(int minutes) => minutes % 60 == 0
    ? (minutes == 60 ? 'hora' : '${minutes ~/ 60} horas')
    : '$minutes minutos';
