# FreelanceFlow — Especificação de Produto e Arquitetura Técnica

> **Decisão de produto (atualização):** o escrow descrito nas seções 2.8 e 3 foi **descartado** por custo
> regulatório e de implementação. O FreelanceFlow não custodia pagamentos: cliente e freelancer combinam o
> pagamento fora da plataforma, e a receita vem de **assinatura Pro do freelancer** e **destaque pago de vagas**
> (seção 10), cobrados via Asaas. As seções 2.8 e 3 permanecem apenas como registro do plano original; a
> disputa financeira e o saque deixam de existir.

## Visão Geral

FreelanceFlow é um marketplace de dois lados que conecta clientes a freelancers. O maior desafio de qualquer plataforma assim não são as telas — é resolver três problemas de confiança ao mesmo tempo: (1) o cliente confia que o freelancer vai entregar, (2) o freelancer confia que vai receber, e (3) ambos confiam que a plataforma vai mediar bem quando algo der errado. Boa parte do que foi acrescentado abaixo gira em torno de fortalecer exatamente esses três pontos, que no plano original ainda estavam rasos — principalmente pagamentos, avaliações e moderação.

Diferenciais possíveis frente a concorrentes como Workana, 99Freelas e Upwork:
- Foco em nicho (ex.: só tech, só design, ou um setor específico) em vez de marketplace genérico
- Comissão mais baixa ou mais transparente
- Experiência mobile-first e minimalista, com menos ruído visual que os concorrentes

## 1. Perfis de Usuário (expandido)

### Cliente
Original + adições:
- Verificação de conta (pessoa física vs. empresa/CNPJ)
- Favoritar freelancers e convidá-los diretamente para uma vaga, sem precisar publicar
- Modelos de vaga reutilizáveis, para publicações recorrentes
- Método de pagamento pré-cadastrado, pra agilizar o aceite de propostas

### Freelancer
Original + adições:
- Portfólio com imagens/links de trabalhos anteriores
- Tags de habilidades e nível de experiência (júnior/pleno/sênior)
- Status de disponibilidade ("disponível agora", "ocupado até dd/mm")
- Preferência de modelo de cobrança (fixo vs. por hora)
- Vagas salvas/favoritas

### Administrador / Moderador (papel novo, essencial)
Sem esse papel não existe como resolver disputas, banir contas fraudulentas ou fazer conciliação financeira:
- Gerenciamento de usuários (suspender, banir, verificar documentos)
- Mediação de disputas entre cliente e freelancer
- Moderação de vagas e perfis denunciados
- Painel de métricas financeiras (volume transacionado, taxas arrecadadas)

## 2. Funcionalidades Detalhadas

### 2.1 Mural e Busca de Vagas — `/jobs`
- Filtros combináveis: faixa de orçamento, prazo, nível de experiência exigido, nota mínima do cliente
- Ordenação por mais recentes, maior orçamento, ou menos propostas recebidas (ajuda o freelancer a achar vagas menos disputadas)
- Alertas salvos: freelancer salva um filtro e recebe e-mail quando surge vaga compatível
- Selo "urgente" (prazo curto) e "destaque" (pago pelo cliente)
- Vagas por convite, que não aparecem no mural público
- Paginação ou scroll infinito para performance com muitas vagas

### 2.2 Publicação de Projetos — `/jobs/create`
- Tipo de contrato: preço fixo ou valor por hora
- Faixa de orçamento (mínimo–máximo) em vez de valor único, dando espaço pra negociação
- Tags de habilidades obrigatórias, que alimentam busca e recomendação
- Upload de anexos de briefing
- Salvar como rascunho antes de publicar
- Perguntas de triagem (ex.: "quantos anos de experiência com X você tem?") respondidas na candidatura
- Divisão em marcos (milestones) para projetos com escopo maior
- Regra de edição: depois que a vaga recebe propostas, mudanças relevantes (orçamento, escopo) notificam quem já se candidatou

### 2.3 Propostas — `/jobs/:id/apply` e `/jobs/:id`
- Contraproposta: cliente responde com valor diferente, sem precisar rejeitar
- Modelos de proposta salvos, pro freelancer não reescrever do zero toda vez
- Limite de propostas por vaga, evitando que o cliente fique com centenas de candidaturas
- Prévia do perfil no painel do cliente: nota média, jobs concluídos, taxa de resposta, ao lado de cada proposta
- Propostas com marcos, espelhando o modelo da vaga quando ela tem escopo maior
- Expiração automática de proposta sem resposta após X dias

### 2.4 Chat em Tempo Real — `/chat`
- Mensagens de sistema automáticas na própria conversa (proposta aceita, marco entregue, pagamento liberado), mantendo o histórico do contrato em um só lugar
- Indicador de "digitando..." e confirmação de leitura
- Restrição de tipo e tamanho de arquivo nos anexos, com verificação antivírus antes do download
- Bloquear e denunciar usuário direto pelo chat
- Busca dentro do histórico de mensagens
- Conversa atrelada ao contrato, não a um chat genérico — importante se o mesmo cliente e freelancer trabalharem juntos em projetos diferentes

### 2.5 Dashboards — `/dashboard/client` e `/dashboard/freelancer`
Cliente, além do original:
- Gráfico de gastos ao longo do tempo
- Prazos de projetos em andamento organizados por urgência
- Atalho rápido para publicar nova vaga

Freelancer, além do original:
- Gráfico de ganhos ao longo do tempo
- Taxa de sucesso de propostas (aceitas ÷ enviadas)
- Percentual de perfil completo, com incentivo pra preencher — perfis completos convertem mais
- Calendário com prazos de entregas

Ambos:
- Feed de atividade recente unificado

### 2.6 Conclusão de Trabalhos e Avaliações
- **Avaliação bidirecional**: o freelancer também avalia o cliente (prazo de pagamento, clareza do briefing, comunicação). Isso costuma ficar de fora de specs iniciais, mas é um dos pilares de confiança em qualquer marketplace de trabalho
- Avaliação só é possível dentro de um contrato realmente concluído, evitando reviews falsas
- Janela curta pra editar a review depois de publicada
- Resposta pública: a parte avaliada pode responder à review, sem poder deletá-la
- Fluxo de disputa: se cliente e freelancer discordam sobre a conclusão, existe uma etapa de mediação (via admin) antes de liberar ou reembolsar o pagamento

### 2.7 Perfil de Usuário — `/profile`
- Galeria de portfólio (freelancer)
- Selos de verificação: e-mail confirmado, telefone confirmado, documento verificado (KYC)
- Link público de perfil, bom para SEO e divulgação fora da plataforma
- Configurações de privacidade (o que fica visível pra visitantes não logados)

### 2.8 Pagamentos e Configurações — `/payments` e `/settings`
Essa era a parte mais rasa do plano original — ver a seção 3 abaixo. Pagamento em marketplace não é só "mostrar saldo", é o motor de confiança de toda a plataforma.

## 3. Sistema de Pagamentos e Escrow (aprofundamento)

Sem um mecanismo de **retenção de pagamento (escrow)**, a plataforma não resolve o problema central de confiança: o cliente não quer pagar antes de ver o trabalho, e o freelancer não quer entregar antes de garantir o pagamento. Fluxo recomendado:

1. Cliente aceita uma proposta → o valor combinado é debitado e **retido** pela plataforma
2. Freelancer executa e entrega (marco ou entrega final)
3. Cliente aprova → o valor é **liberado** para o saldo do freelancer, descontada a taxa da plataforma
4. Se o cliente não aprova nem contesta em X dias, a liberação pode ser automática
5. Em disputa, o valor fica retido até a mediação do admin decidir liberar ou reembolsar

Pontos adicionais:
- **Marcos (milestones)**: projetos maiores divididos em etapas, cada uma com seu próprio ciclo de retenção/liberação, reduzindo o risco pros dois lados
- **Métodos de pagamento no Brasil**: Pix (essencial, é o mais usado hoje), boleto e cartão de crédito
- **Gateways com split de marketplace no Brasil**: Mercado Pago, Pagar.me e Asaas têm APIs de "split de pagamento" pensadas pra esse modelo — retêm, dividem entre plataforma e freelancer, e permitem saque. Pra mercado internacional, o equivalente é o Stripe Connect
- **Nunca armazenar dado de cartão bruto** — sempre usar tokenização do gateway (requisito de conformidade PCI)
- **Saque do freelancer**: via Pix ou transferência bancária, com prazo de processamento claro
- **Nota fiscal**: freelancer brasileiro geralmente precisa emitir nota (como MEI ou autônomo) — a plataforma pode gerar um recibo simples, mas isso não substitui a obrigação fiscal do freelancer; vale deixar isso explícito nos termos de uso
- **Histórico de transações**: filtrável por tipo (depósito, liberação, saque, taxa) e exportável em CSV para contabilidade

## 4. Notificações

Canais: in-app (sempre) + e-mail (eventos importantes); push fica pra quando houver app mobile.

Eventos que devem disparar notificação:
- Nova proposta recebida (cliente)
- Proposta aceita/rejeitada (freelancer)
- Nova mensagem no chat
- Marco entregue / aprovado / pago
- Prazo de entrega se aproximando
- Nova avaliação recebida
- Vaga salva com novo resultado compatível

## 5. Confiança, Segurança e Moderação

- Verificação de identidade (documento) antes de liberar saques acima de um certo valor
- Sistema de denúncia em vagas, perfis, mensagens e reviews
- Detecção de padrões suspeitos (mesma pessoa com várias contas, tentativas de pagamento fora da plataforma pra escapar da taxa)
- Painel de administração com fila de denúncias e ações (advertir, suspender, banir)
- Política clara contra "pagamento por fora", explicando por que isso enfraquece a proteção de ambos os lados

## 6. Aspectos Legais (essencial pra operar no Brasil)

- **LGPD**: consentimento explícito, política de privacidade clara, mecanismo pro usuário solicitar exclusão dos próprios dados
- **Termos de uso**: deixar explícito que a relação cliente-freelancer não é vínculo empregatício, evitando passivo trabalhista pra plataforma
- **Termos de pagamento**: taxas, prazos de liberação e política de reembolso descritos com clareza
- O ideal é revisar os termos com um advogado antes do lançamento — isso aqui é orientação de produto, não aconselhamento jurídico

## 7. Arquitetura Técnica Sugerida

**Opção A — MVP rápido (recomendada pra começar sozinho ou em dupla):**
- Frontend: Next.js + TypeScript + TailwindCSS
- Backend/Banco/Auth/Storage: Supabase (Postgres + Auth + Storage + Realtime — o Realtime já resolve o chat)
- Pagamentos: Mercado Pago ou Asaas (split de marketplace + Pix nativo)
- Hospedagem: Vercel (frontend) + Supabase Cloud

**Opção B — mais controle e escala:**
- Frontend: Next.js
- Backend: Node.js com NestJS (API REST)
- Banco: PostgreSQL gerenciado (Railway, Render ou RDS)
- Tempo real: Socket.IO ou Ably
- Storage: Cloudflare R2 ou AWS S3
- Pagamentos: Pagar.me/Asaas (Brasil) ou Stripe Connect (internacional)

A Opção A entrega um MVP funcional bem mais rápido, porque tira de você boa parte do trabalho de infraestrutura (auth, storage, tempo real já vêm prontos). A Opção B compensa se o volume crescer muito ou se surgirem regras de negócio muito específicas que o Supabase não cobre bem.

## 8. Modelo de Dados (visão geral)

Entidades principais e campos-chave:

- **users** — id, nome, e-mail, senha_hash, tipo (cliente/freelancer/admin), verificado, criado_em
- **client_profiles** — user_id, empresa (opcional), telefone
- **freelancer_profiles** — user_id, bio, habilidades[], taxa_hora, nota_media, jobs_concluidos
- **categories** — id, nome
- **skills** — id, nome
- **jobs** — id, client_id, titulo, categoria_id, descricao, tipo_contrato, orcamento_min, orcamento_max, prazo, status, visibilidade, criado_em
- **job_skills** — job_id, skill_id
- **proposals** — id, job_id, freelancer_id, valor, mensagem, status, criado_em
- **contracts** — id, job_id, proposal_id, client_id, freelancer_id, valor_total, status, iniciado_em, concluido_em
- **milestones** — id, contract_id, descricao, valor, status, prazo
- **conversations** — id, contract_id, participantes[]
- **messages** — id, conversation_id, sender_id, conteudo, anexo_url, lido, criado_em
- **reviews** — id, contract_id, autor_id, alvo_id, nota, comentario, criado_em
- **transactions** — id, contract_id, tipo, valor, status, gateway_ref, criado_em
- **notifications** — id, user_id, tipo, conteudo, lido, criado_em

## 9. Roadmap de Implementação

| Fase | Foco | Principais entregas |
|---|---|---|
| 1 — MVP | Núcleo funcional | Auth, perfis básicos, publicar/buscar vagas, enviar/aceitar/rejeitar propostas, dashboard simples, chat de texto |
| 2 — Confiança e Dinheiro | Transações reais | Escrow, marcos, avaliações bidirecionais, notificações, anexos no chat |
| 3 — Crescimento | Robustez e descoberta | Busca avançada, painel admin, disputas, verificação de identidade, SEO nas páginas públicas |
| 4 — Escala | Expansão | App mobile, analytics, programa de indicação, gamificação, internacionalização |

Começar pela Fase 1 é importante: ela já valida se cliente e freelancer completam o ciclo básico (publicar → propor → aceitar → conversar) antes de investir tempo em pagamento real, que é a parte mais cara e arriscada de construir.

## 10. Modelo de Monetização

| Modelo | Como funciona | Prós | Contras |
|---|---|---|---|
| Comissão por transação | % sobre o valor pago ao freelancer (ex.: 10-20%, decrescente por volume) | Alinhado ao sucesso da plataforma, sem barreira de entrada | Só gera receita quando há transação |
| Assinatura do freelancer | Mensalidade pra enviar mais propostas ou ter destaque | Receita recorrente previsível | Pode afastar freelancers novos |
| Destaques pagos | Cliente paga pra destacar vaga; freelancer paga pra aparecer no topo da busca | Monetiza sem taxar toda transação | Se mal balanceado, parece "pay to win" |
| Híbrido | Comissão baixa + destaques opcionais | Equilibra recorrência e volume | Mais complexo de administrar |

O modelo híbrido (comissão baixa + destaques opcionais) é o que a maioria dos marketplaces maduros converge, porque diversifica a receita sem depender só do volume transacionado.

## Próximos Passos

Esse documento cobre o "o quê" e o "por quê". O próximo passo natural é o "como": escolher a stack definitiva, desenhar o schema real do banco e começar a construir a Fase 1. Posso seguir com qualquer uma dessas frentes quando você quiser.
