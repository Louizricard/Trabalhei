// Dados do catálogo de áreas (ver work_categories.dart). Divididos em dois
// arquivos só pelo tamanho.
part of 'work_categories.dart';

const _creativeAreas = <WorkArea>[
  WorkArea('Tecnologia', 'Sites, apps, sistemas, dados e suporte', [
    WorkSubcategory('Frontend', [
      'HTML e CSS',
      'JavaScript',
      'React',
      'Sites responsivos',
    ]),
    WorkSubcategory('Backend', [
      'APIs',
      'Banco de dados',
      'Node.js',
      'Python',
      'Java',
    ]),
    WorkSubcategory('Fullstack', [
      'JavaScript',
      'APIs',
      'Banco de dados',
      'React',
      'Node.js',
    ]),
    WorkSubcategory('Mobile', ['Android', 'iOS', 'Flutter', 'React Native']),
    WorkSubcategory('DevOps', ['Nuvem', 'Docker', 'CI/CD', 'Linux']),
    WorkSubcategory('Dados e IA', [
      'Análise de dados',
      'SQL',
      'Power BI',
      'Automação',
      'Inteligência artificial',
    ]),
    WorkSubcategory('WordPress e e-commerce', [
      'WordPress',
      'Lojas virtuais',
      'Shopify',
      'WooCommerce',
    ]),
    WorkSubcategory('Suporte de TI', [
      'Redes',
      'Manutenção de computadores',
      'Microsoft 365',
    ]),
    WorkSubcategory('Testes e QA', [
      'Testes manuais',
      'Testes automatizados',
      'Documentação de testes',
    ]),
  ]),
  WorkArea('Design', 'Identidade visual, interfaces e peças gráficas', [
    WorkSubcategory('UI/UX', [
      'Figma',
      'Prototipação',
      'Pesquisa com usuários',
      'Design de interfaces',
    ]),
    WorkSubcategory('Identidade visual', [
      'Logotipo',
      'Manual de marca',
      'Tipografia',
    ]),
    WorkSubcategory('Design gráfico', [
      'Canva',
      'Photoshop',
      'Illustrator',
      'Peças para redes sociais',
    ]),
    WorkSubcategory('Ilustração', [
      'Ilustração digital',
      'Personagens',
      'Infográficos',
    ]),
    WorkSubcategory('Apresentações', [
      'PowerPoint',
      'Google Slides',
      'Pitch deck',
    ]),
    WorkSubcategory('3D e modelagem', [
      'Blender',
      'Modelagem 3D',
      'Renderização',
    ]),
  ]),
  WorkArea('Marketing', 'Redes sociais, anúncios e estratégia', [
    WorkSubcategory('Social media', [
      'Planejamento de conteúdo',
      'Instagram',
      'TikTok',
      'LinkedIn',
    ]),
    WorkSubcategory('Tráfego pago', [
      'Meta Ads',
      'Google Ads',
      'Gestão de campanhas',
    ]),
    WorkSubcategory('SEO', [
      'SEO on-page',
      'Palavras-chave',
      'Google Analytics',
    ]),
    WorkSubcategory('E-mail marketing', [
      'Automação de e-mail',
      'Newsletters',
      'RD Station',
    ]),
    WorkSubcategory('Estratégia e branding', [
      'Posicionamento',
      'Pesquisa de mercado',
      'Plano de marketing',
    ]),
  ]),
  WorkArea('Redação e Conteúdo', 'Textos, roteiros e revisão', [
    WorkSubcategory('Copywriting', [
      'Copy para anúncios',
      'Páginas de venda',
      'Storytelling',
    ]),
    WorkSubcategory('Artigos e blog', [
      'Redação SEO',
      'Pesquisa',
      'Artigos técnicos',
    ]),
    WorkSubcategory('Roteiros', ['Roteiro para vídeo', 'Roteiro para podcast']),
    WorkSubcategory('Revisão de texto', [
      'Revisão ortográfica',
      'Normas ABNT',
      'Edição de texto',
    ]),
    WorkSubcategory('Conteúdo para redes', [
      'Legendas',
      'Calendário editorial',
    ]),
  ]),
  WorkArea('Tradução', 'Tradução, legendas e transcrição', [
    WorkSubcategory('Inglês', [
      'Tradução inglês-português',
      'Versão português-inglês',
    ]),
    WorkSubcategory('Espanhol', [
      'Tradução espanhol-português',
      'Versão português-espanhol',
    ]),
    WorkSubcategory('Outros idiomas', ['Francês', 'Alemão', 'Italiano']),
    WorkSubcategory('Legendagem', ['Legendas', 'Sincronização de legendas']),
    WorkSubcategory('Transcrição', ['Transcrição de áudio', 'Ata de reunião']),
  ]),
  WorkArea('Audiovisual e Foto', 'Vídeo, animação, fotografia e áudio', [
    WorkSubcategory('Edição de vídeo', [
      'Premiere',
      'CapCut',
      'DaVinci Resolve',
      'Vídeos curtos',
    ]),
    WorkSubcategory('Motion design', [
      'After Effects',
      'Animação 2D',
      'Vinhetas',
    ]),
    WorkSubcategory('Fotografia', [
      'Fotografia de produto',
      'Ensaios',
      'Eventos',
    ]),
    WorkSubcategory('Edição de foto', [
      'Lightroom',
      'Tratamento de imagem',
      'Remoção de fundo',
    ]),
    WorkSubcategory('Áudio e locução', [
      'Locução',
      'Edição de podcast',
      'Mixagem',
    ]),
  ]),
];
