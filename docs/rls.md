# Trabalhei — Segurança (RLS e permissões)

Fonte da verdade: `supabase/migrations/` (schema inicial em `20261015211818_initial_schema.sql` e as migrations seguintes).

Princípios:

1. **RLS ligado em todas as tabelas.**
2. **Escrita só por onde deve:** o papel `authenticated` tem `GRANT` apenas nas colunas editáveis;
   plano, rating, status, destaque e contratos são alterados exclusivamente por funções `SECURITY DEFINER`.
3. **Billing é do servidor:** tabelas de cobrança só são escritas pelo `service_role` (Edge Functions).

| Tabela | Leitura | Escrita direta (cliente) | Escrita via RPC / servidor |
|---|---|---|---|
| `profiles` | Qualquer usuário autenticado | `UPDATE` do próprio perfil, só `full_name, avatar_url, company_name, bio, hourly_rate, skills, availability_status` | Criação por trigger em `auth.users`; papel via `switch_role` (nunca `admin`); plano via webhook |
| `portfolio_items` | Autenticados | `INSERT`/`DELETE` dos próprios itens | — |
| `jobs` | Autenticados | `INSERT` (somente clientes) e `UPDATE` de campos de conteúdo em vagas **abertas** próprias | Status via `cancel_job`/contratos; `featured_until` via webhook |
| `proposals` | Freelancer autor e cliente dono da vaga | Nenhuma | `submit_proposal` (cota do plano), `accept_proposal`, `reject_proposal`, `make_counter_offer`, `accept_counter_offer`, `reject_counter_offer` |
| `contracts`, `milestones`, `milestone_revisions` | Apenas as partes do contrato | Nenhuma | `accept_*` cria o contrato; `submit_deliverable`, `request_revision`, `approve_milestone` |
| `conversations` | Apenas os dois participantes | Nenhuma | `get_or_create_conversation` |
| `messages` | Apenas os participantes da conversa | `INSERT` como remetente próprio e tipos não-sistema | Mensagens de sistema geradas pelas RPCs; `mark_conversation_read` |
| `notifications` | Somente o dono | `UPDATE is_read` e `DELETE` do dono | Criadas por `notify()` (triggers/RPCs) |
| `reviews` | Autenticados | `INSERT` pelas partes do contrato, uma por contrato, **só com o contrato `completed`** | Rating do perfil recalculado por trigger |
| `subscriptions`, `job_featurings` | Somente o dono | Nenhuma | Edge Functions (service_role) |
| `billing_customers`, `billing_events` | Ninguém (cliente) | Nenhuma | Edge Functions (service_role) |

## Storage

Buckets públicos para leitura: `avatars`, `portfolio`, `job_attachments`, `job_covers`, `chat_attachments`.
Escrita/remoção apenas na pasta do próprio usuário: o primeiro segmento do caminho deve ser o `auth.uid()`
(`<bucket>/<user_id>/...`). O app já prefixa uploads com o id do usuário.

> Atenção: arquivos de chat/entregas ficam em buckets públicos (URL difícil de adivinhar, porém sem
> autenticação). Para conteúdo confidencial, migre `chat_attachments` para bucket privado com URLs assinadas.

## Testando as políticas

Com `supabase start`, use o SQL Editor/`psql` simulando usuários:

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub": "<uuid-do-usuario>", "role": "authenticated"}';
select * from proposals;                       -- só as propostas visíveis a esse usuário
update profiles set plan = 'pro' where id = '<uuid>';   -- deve falhar (permission denied)
```
