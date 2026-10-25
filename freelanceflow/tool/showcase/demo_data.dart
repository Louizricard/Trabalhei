import 'package:trabalhei/features/auth/domain/entities/user_profile.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal.dart';

/// Dados fictícios para os prints de divulgação. Nenhum nome, e-mail ou valor
/// vem de contas reais.
final _now = DateTime.now();
DateTime ago({int days = 0, int hours = 0, int minutes = 0}) =>
    _now.subtract(Duration(days: days, hours: hours, minutes: minutes));

const mainJobId = 'demo-job-1';
const conversationId = 'demo-conv-1';

final demoClient = UserProfile(
  id: 'demo-client',
  email: 'cliente@exemplo.com',
  fullName: 'Carla Menezes',
  companyName: 'Clínica Patas & Cia',
  role: UserRole.client,
  rating: 4.9,
  reviewsCount: 12,
  isVerified: true,
  createdAt: ago(days: 210),
);

final demoFreelancer = UserProfile(
  id: 'demo-freelancer',
  email: 'freelancer@exemplo.com',
  fullName: 'Rafael Souza',
  role: UserRole.freelancer,
  bio:
      'Desenvolvedor mobile com foco em Flutter e experiência em apps de '
      'agendamento e e-commerce.',
  hourlyRate: 95,
  skills: const ['Flutter', 'Dart', 'Supabase', 'Firebase', 'UI/UX'],
  rating: 4.9,
  reviewsCount: 23,
  completedJobsCount: 31,
  isVerified: true,
  createdAt: ago(days: 400),
);

final demoFreelancers = [
  demoFreelancer,
  UserProfile(
    id: 'demo-f2',
    email: 'f2@exemplo.com',
    fullName: 'Juliana Prado',
    role: UserRole.freelancer,
    bio: 'Designer de produto. Interfaces, design systems e protótipos.',
    hourlyRate: 110,
    skills: const ['Figma', 'UI/UX', 'Design System'],
    rating: 5,
    reviewsCount: 17,
    completedJobsCount: 20,
    plan: 'pro',
    createdAt: ago(days: 300),
  ),
  UserProfile(
    id: 'demo-f3',
    email: 'f3@exemplo.com',
    fullName: 'Tiago Ramos',
    role: UserRole.freelancer,
    bio: 'Back-end em Node.js e Postgres. APIs, integrações e Pix.',
    hourlyRate: 85,
    skills: const ['Node.js', 'PostgreSQL', 'APIs'],
    rating: 4.7,
    reviewsCount: 9,
    completedJobsCount: 12,
    availabilityStatus: 'busy',
    createdAt: ago(days: 150),
  ),
];

final demoJobs = [
  Job(
    id: mainJobId,
    clientId: demoClient.id,
    clientName: 'Clínica Patas & Cia',
    clientRating: 4.9,
    title: 'App de agendamento para clínica veterinária',
    category: 'Mobile',
    description:
        'Precisamos de um app para os tutores marcarem consultas e banho e '
        'tosa, receberem lembretes e acompanharem o histórico de cada pet. '
        'Já temos a identidade visual; falta o app (Android e iOS) e um '
        'painel simples para a recepção confirmar os horários.',
    budgetMin: 4000,
    budgetMax: 6500,
    deadlineDays: 30,
    experienceLevel: ExperienceLevel.pleno,
    skillsRequired: const ['Flutter', 'Supabase', 'UI/UX'],
    proposalsCount: 3,
    featuredUntil: _now.add(const Duration(days: 5)),
    createdAt: ago(hours: 5),
  ),
  Job(
    id: 'demo-job-2',
    clientId: 'demo-c2',
    clientName: 'Café Grão Mineiro',
    clientRating: 4.8,
    title: 'Identidade visual para cafeteria',
    category: 'Design',
    description:
        'Logo, paleta, tipografia e aplicações em cardápio, sacola e redes '
        'sociais para uma cafeteria de bairro.',
    budgetMin: 1500,
    budgetMax: 2800,
    deadlineDays: 20,
    skillsRequired: const ['Branding', 'Illustrator', 'Figma'],
    proposalsCount: 7,
    createdAt: ago(hours: 9),
  ),
  Job(
    id: 'demo-job-3',
    clientId: 'demo-c3',
    clientName: 'Escola Online Saber+',
    clientRating: 4.6,
    title: 'Landing page para lançamento de curso',
    category: 'Frontend',
    description:
        'Página de vendas responsiva com seções de conteúdo, depoimentos dos '
        'alunos e integração com a plataforma de pagamento que já usamos.',
    budgetMin: 1200,
    budgetMax: 2000,
    deadlineDays: 10,
    isUrgent: true,
    skillsRequired: const ['HTML', 'CSS', 'JavaScript'],
    proposalsCount: 4,
    createdAt: ago(days: 1),
  ),
  Job(
    id: 'demo-job-4',
    clientId: 'demo-c4',
    clientName: 'Loja Verde Vivo',
    clientRating: 4.7,
    title: 'API de pedidos com pagamento via Pix',
    category: 'Backend',
    description:
        'Integração do nosso e-commerce com Pix, webhooks de confirmação e '
        'atualização automática do status dos pedidos.',
    contractType: ContractType.hourly,
    budgetMin: 80,
    budgetMax: 120,
    deadlineDays: 25,
    experienceLevel: ExperienceLevel.senior,
    skillsRequired: const ['Node.js', 'PostgreSQL', 'Pix'],
    proposalsCount: 2,
    createdAt: ago(days: 2),
  ),
];

final demoProposals = [
  Proposal(
    id: 'demo-prop-1',
    jobId: mainJobId,
    freelancerId: demoFreelancer.id,
    freelancerName: demoFreelancer.fullName,
    freelancerRating: 4.9,
    bidAmount: 5200,
    estimatedDays: 28,
    coverLetter:
        'Já entreguei dois apps de agendamento em Flutter. Posso começar '
        'esta semana e validar o fluxo com a recepção antes da publicação.',
    createdAt: ago(hours: 3),
  ),
  Proposal(
    id: 'demo-prop-2',
    jobId: mainJobId,
    freelancerId: 'demo-f2',
    freelancerName: 'Juliana Prado',
    freelancerRating: 5,
    bidAmount: 6200,
    estimatedDays: 35,
    coverLetter:
        'Faço o design completo e o app em parceria com um desenvolvedor da '
        'minha equipe, com testes de usabilidade com tutores.',
    createdAt: ago(hours: 2),
  ),
  Proposal(
    id: 'demo-prop-3',
    jobId: mainJobId,
    freelancerId: 'demo-f3',
    freelancerName: 'Tiago Ramos',
    freelancerRating: 4.7,
    bidAmount: 4800,
    estimatedDays: 30,
    coverLetter: 'Posso cuidar do app e do painel da recepção.',
    status: ProposalStatus.counterOffered,
    counterPrice: 4500,
    counterEstimatedDays: 30,
    counterMessage: 'Fechamos em R\$ 4.500 mantendo o prazo?',
    counterByUserId: demoClient.id,
    counterCreatedAt: ago(hours: 1),
    createdAt: ago(hours: 4),
  ),
];
