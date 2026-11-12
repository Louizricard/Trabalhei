# Revisão da jornada de contratação — 12/11/2026

Escopo: publicar vaga → proposta → contraproposta → contratação → marcos → conclusão/avaliação,
no app Flutter e no banco. Achados por leitura de código e confirmados com testes. A migration
foi publicada em produção em 12/11/2026 (ver "Publicação"). Regras resultantes: [`docs/contratacao.md`](contratacao.md).

**Método de prova:** cada defeito do banco tem um cenário em `supabase/tests/hiring/` escrito antes
da correção e executado **sem** a migration (vermelho) e **com** ela (verde), contra PostgreSQL 17.
Defeitos do app têm testes unitários/de widget quando a lógica é isolável.

## Corrigidos — banco

| # | Defeito (antes) | Prova sem a correção | Correção |
|---|---|---|---|
| B1 | `approve_milestone` contava marcos pendentes sem travar o contrato. **Na prática**, a corrida só aparece quando o contrato não tem conversa vinculada: com conversa, o `UPDATE` da mensagem de sistema serializava as aprovações por acidente. Freelancer não era avisado da conclusão. Marco podia ser aprovado em contrato não ativo. | "conversa ausente": contrato ficou `active` com todos os marcos aprovados; "conversa vinculada": faltou aviso ao freelancer | Trava explícita do contrato `active`; aviso às duas partes |
| B2 | Não existia encerramento de contrato: freelancer sumido travava a vaga e a exclusão de conta | função inexistente | `cancel_contract` com motivo |
| B3 | Marcos malformados (objeto, texto, negativo, prazo inválido) eram aceitos e tornavam a proposta impossível de contratar | 9 formatos aceitos sem erro | Validação → `INVALID_MILESTONES` |
| B4 | Recusa/contraproposta concorrente sobrescrevia proposta recém-aceita | proposta terminou `rejected` com contrato criado | Trava + atualização condicionada ao estado |
| B5 | Cota mensal furada por envios paralelos (COUNT e depois INSERT) | 2 propostas com limite 1 | Trava por freelancer antes de contar |
| B6 | Cliente contratado por valor que não viu (freelancer editava entre a leitura e o clique) | contrato criado com o valor novo | `p_expected_amount` → `PROPOSAL_CHANGED` |
| B7 | Botão "Contratar" em proposta com contraproposta sempre falhava (`PROPOSAL_NOT_PENDING`) | erro ao contratar | Contrata pelo valor original |
| B8 | Reenviar proposta apagava a contraproposta do cliente em silêncio | contraproposta sumiu | `COUNTER_OFFER_PENDING` |
| B9 | Aceitar contraproposta descartava os marcos propostos | marco único "Entrega do projeto" | Redimensionamento proporcional |

## Corrigidos — app

| # | Defeito (antes) | Correção | Prova |
|---|---|---|---|
| A1 | Aceite mostrava erro mesmo com contrato criado (2ª chamada redundante); sem confirmação | Confirmação com valor/prazo; usa a conversa devolvida; envia valor esperado | `flutter analyze`; regra B6 testada no banco |
| A2 | "Minhas Vagas" só listava vagas abertas | `clientJobsProvider` com todos os status | `flutter analyze` |
| A3 | "1500,50" salvava o padrão 1000/5000; "1.500" virava 1,5 (vaga, proposta, contraproposta) | `CurrencyFormatter.parse/toInput` | `test/core/currency_parse_test.dart` (22 casos) |
| A4 | Aprovar/Solicitar ajustes em marco `in_revision` (servidor recusava) | Ações só com `submitted` e contrato ativo | `test/features/chat/contract_actions_test.dart` |
| A5 | "Enviar/Editar proposta" em vaga fechada ou proposta decidida | `ProposalAction` espelha as regras do servidor | `test/features/proposals_action_test.dart` |
| A6 | Editar vaga descartava anexos novos e deixava telas velhas | Mescla anexos e invalida detalhe/listas | `flutter analyze` |
| A7 | Concluir último marco não atualizava vaga/listas | Invalidações após aprovar | `flutter analyze` |
| A8 | Sem UI de encerramento | "Encerrar contrato" + banner de contrato encerrado | `contract_actions_test.dart` (motivo, sucesso, erro do servidor, banner) |

## Registrados, não corrigidos

| Achado | Risco | Onde |
|---|---|---|
| `get_or_create_conversation` deixa qualquer usuário abrir conversa com qualquer outro e vincular vaga alheia; cada vaga diferente gera nova notificação (e-mail/push) | spam/phishing | `20261015211818_initial_schema.sql:576` |
| Efeitos de notificação: `net.http_post` dentro da transação pode derrubar a ação de negócio; entrega marcada antes do envio | perda/bloqueio | P1-06 da auditoria de 29/10 |
| `rating`/`reviews_count` recalculados com snapshot; avaliações simultâneas podem divergir | baixo | `initial_schema.sql:481` |
| `proposals_count(jobs)` executável por visitante revela contagem de qualquer vaga | baixo | `20261026104955_guest_browsing.sql:44` |
| Cliente altera orçamento/escopo com propostas pendentes sem aviso | regra de produto | `initial_schema.sql:185` |
| Formulário de vaga nunca preenche `contract_type`/`experience_level`; filtros correspondentes nunca casam | busca | `create_job_screen.dart` |
| Listas sem paginação (vagas, propostas, conversas, notificações) | escala | P1-10 da auditoria |
| Stream de notificações captura o usuário uma vez; erros só em `debugPrint` | UX | `notification_provider.dart` |
| `/jobs/:id/proposals` aberto a qualquer logado mostra "nenhuma proposta" em vez de acesso negado | UX | `job_proposals_screen.dart` |
| FKs sem índice usadas em RLS/joins: `conversations.contract_id`, `conversations.job_id`, `contracts.job_id`, `milestone_revisions.contract_id` | desempenho | migrations iniciais |
| Sem UI para criar marcos na proposta: todo contrato nasce com um marco | produto | `apply_job_screen.dart` |

## Evidências de verificação

| Verificação | Resultado |
|---|---|
| `deno task test:webhook` (PostgreSQL 17 local) antes | 14 testes, 124 passos, 0 falhas |
| Suíte `tests/hiring` sem a migration | 10 de 11 cenários falharam (só a regressão já correta passou) |
| `deno task test:webhook` depois | 14 testes, **137 passos**, 0 falhas |
| Rollback | aplica, reverte e reaplica limpo; recusa com contratos encerrados |
| `flutter analyze` | sem problemas (antes e depois) |
| `flutter test` | 96 → **126** testes, todos aprovados |
| `flutter build web` | compila (`✓ Built build/web`) |

Não verificado: fluxo manual ponta a ponta no app contra um Supabase local (o Supabase CLI não está
instalado nesta máquina) e build Android local (coberto pelo CI com `flutter build apk --debug`).

## Publicação

Migration aplicada em produção em 12/11/2026, depois do CI verde (run 43310755499, commit
`c184f3b`: jobs `flutter` e `webhook` aprovados). Versão remota `20261112213744_hiring_journey_fixes`;
os arquivos locais foram renomeados para a mesma versão.

| Verificação em produção | Resultado |
|---|---|
| `list_migrations` | `20261112213744 hiring_journey_fixes` registrada |
| Funções novas/alteradas | nenhuma executável por `anon`; `accept_proposal(uuid, numeric)`, `cancel_contract` e demais RPCs executáveis por `authenticated`; `_create_contract` e `_proposed_milestones_total` não |
| Funções `security definer` em `public` | 34 executáveis por `authenticated`, 1 por `anon` (`proposals_count`) — igual à linha de base |
| Colunas novas | `cancelled_at`, `cancelled_by`, `cancel_reason` presentes |
| Validação de marcos | soma válida aceita; formatos malformados recusados |
| Dados | inalterados: 1 contrato (0 ativos, 0 encerrados), 2 propostas abertas |
| Advisor de desempenho | novo aviso INFO: FK `contracts_cancelled_by_fkey` sem índice (tabela pequena; somar ao item de índices de FK acima) |

Falta: publicar o app novo (só depois da migration, o que já vale) e fazer merge da PR.
