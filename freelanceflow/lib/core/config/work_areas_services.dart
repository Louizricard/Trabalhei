// Dados do catálogo de áreas (ver work_categories.dart). Divididos em dois
// arquivos só pelo tamanho.
part of 'work_categories.dart';

const _serviceAreas = <WorkArea>[
  WorkArea(
    'Administração e Assistência',
    'Assistente virtual, dados e gestão',
    [
      WorkSubcategory('Assistente virtual', [
        'Agenda',
        'E-mails',
        'Organização',
        'Google Workspace',
      ]),
      WorkSubcategory('Digitação e dados', [
        'Excel',
        'Planilhas',
        'Cadastro de dados',
      ]),
      WorkSubcategory('Atendimento ao cliente', [
        'Atendimento por chat',
        'WhatsApp Business',
        'Suporte por e-mail',
      ]),
      WorkSubcategory('Gestão de projetos', [
        'Trello',
        'Notion',
        'Cronogramas',
      ]),
      WorkSubcategory('Recursos humanos', [
        'Recrutamento',
        'Triagem de currículos',
        'Departamento pessoal',
      ]),
    ],
  ),
  WorkArea('Vendas e Comercial', 'Prospecção, propostas e CRM', [
    WorkSubcategory('Prospecção', [
      'Prospecção ativa',
      'Geração de leads',
      'LinkedIn',
    ]),
    WorkSubcategory('Pré-vendas', [
      'Qualificação de leads',
      'Propostas comerciais',
    ]),
    WorkSubcategory('Gestão de CRM', ['CRM', 'HubSpot', 'Pipedrive']),
  ]),
  WorkArea('Finanças e Jurídico', 'Contabilidade, planilhas e contratos', [
    WorkSubcategory('Contabilidade', [
      'Abertura de MEI',
      'Imposto de renda',
      'Escrituração',
    ]),
    WorkSubcategory('Consultoria financeira', [
      'Fluxo de caixa',
      'Planejamento financeiro',
      'Precificação',
    ]),
    WorkSubcategory('Assessoria jurídica', [
      'Contratos',
      'Direito digital',
      'LGPD',
    ]),
  ]),
  WorkArea('Educação', 'Aulas, cursos e mentoria', [
    WorkSubcategory('Aulas particulares', [
      'Matemática',
      'Reforço escolar',
      'Preparação para vestibular',
    ]),
    WorkSubcategory('Idiomas', [
      'Aulas de inglês',
      'Aulas de espanhol',
      'Conversação',
    ]),
    WorkSubcategory('Cursos e treinamentos', [
      'Criação de cursos',
      'Material didático',
      'Treinamento corporativo',
    ]),
    WorkSubcategory('Mentoria', ['Carreira', 'Mentoria de negócios']),
  ]),
  WorkArea(
    'Engenharia e Arquitetura',
    'Projetos, desenho técnico e interiores',
    [
      WorkSubcategory('Projetos arquitetônicos', [
        'Planta baixa',
        'AutoCAD',
        'Revit',
      ]),
      WorkSubcategory('Design de interiores', [
        'SketchUp',
        'Projeto de interiores',
        'Renderização',
      ]),
      WorkSubcategory('Engenharia civil', [
        'Orçamento de obra',
        'Projeto estrutural',
        'Laudos',
      ]),
      WorkSubcategory('Engenharia elétrica', [
        'Projeto elétrico',
        'Energia solar',
      ]),
    ],
  ),
  WorkArea(
    WorkCategories.other,
    'Serviços que não se encaixam nas áreas acima',
    [],
  ),
];
