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

## Exclusão de conta (LGPD)

A Edge Function `delete-account` (autenticada) recusa a exclusão se houver contrato `active`, cancela a
assinatura no Asaas e chama `delete_account_data(user)`, executável **só pelo `service_role`**:

- **Sem histórico de contratos:** o `auth.users` é apagado e o `ON DELETE CASCADE` remove todo o resto.
- **Com histórico de contratos:** contratos, marcos, mensagens e avaliações ficam para a outra parte;
  o perfil é anonimizado (`deleted_at` preenchido, nome "Usuário removido"), portfólio, notificações,
  propostas sem contrato e vínculo de cobrança são apagados, vagas abertas são canceladas e o
  `auth.users` recebe soft delete (e-mail e identidades descartados).

Arquivos do usuário no Storage também são removidos (só avatar e portfólio quando há contratos).
A busca de freelancers ignora perfis com `deleted_at`.

## Storage

Buckets públicos para leitura: `avatars`, `portfolio`, `job_attachments`, `job_covers`.
Escrita/remoção apenas na pasta do próprio usuário: o primeiro segmento do caminho deve ser o `auth.uid()`
(`<bucket>/<user_id>/...`). O app já prefixa uploads com o id do usuário.

`chat_attachments` (arquivos do chat, entregas e revisões) é **privado**. A leitura é liberada ao dono e
às partes envolvidas, conforme o caminho:

| Caminho | Quem lê |
|---|---|
| `<dono>/<conversation_id>/<arquivo>` | Dono e as duas partes da conversa |
| `<dono>/deliverables/<milestone_id>/<arquivo>` | Dono e as partes do contrato do marco |
| `<dono>/revisions/<milestone_id>/<arquivo>` | Dono e as partes do contrato do marco |

O app guarda a URL no formato público como identificador do arquivo e, ao exibir ou abrir, troca por
uma URL assinada válida por 1 hora (`StorageService.resolveUrl` e o widget `StorageImage`).

## Testando as políticas

`billing_checkout_locks`, `billing_checkouts`, `billing_checkout_steps` e
`billing_checkout_requests` têm RLS habilitada, sem políticas públicas e com privilégios
apenas para `service_role`. Todas as RPCs de reserva, preço, vínculo e finalização do
checkout são `SECURITY INVOKER`, com execução revogada de `PUBLIC`, `anon` e
`authenticated`. `billing_private.lock_checkout` só é acessível ao servidor.
O endpoint autentica o usuário e a reserva valida a propriedade da vaga.
Ver [checkout-asaas.md](checkout-asaas.md) para concorrência e conciliação.

`billing_payment_receipts` e a inbox `billing_events` são exclusivas do servidor.
As RPCs `receive_asaas_billing_event(jsonb)` e `process_asaas_billing_event(text)`
só são executáveis pelo `service_role`. Os auxiliares ficam no schema não exposto
`billing_private`, sem acesso para `anon`/`authenticated`. Ver [webhook-asaas.md](webhook-asaas.md)
para transações, deduplicação e recuperação de eventos pendentes.

Os campos de intervalo e revogação do destaque continuam privados em
`billing_payment_receipts`. `billing_private.apply_feature_refund` e
`billing_private.remove_feature_period` também negam execução direta a
`service_role`; são acionados apenas dentro da RPC do webhook (`SECURITY DEFINER`).
Ver [estornos-destaque.md](estornos-destaque.md).

`account_deletion_requests` só admite acesso de `service_role`; as RPCs de
início, manifesto, preparação, falha e conclusão também são exclusivas do servidor.
`account_private.active_actor()` apenas responde se o usuário da sessão está ativo;
os demais auxiliares privados negam execução direta até para `service_role`.
Uma policy restritiva nas tabelas públicas existentes com RLS (exceto o próprio
perfil e a fila privada) e em Storage impede acesso de contas em exclusão.
Triggers bloqueiam mutações com JWT antigo, inclusive via SECURITY DEFINER.
O perfil anonimizado só é visível ao próprio usuário e à contraparte contratual;
currículos de contas fechadas não são legíveis. Novas tabelas precisam incluir
essas proteções. Ver [exclusao-conta.md](exclusao-conta.md).

`billing_pro_grants` e os vínculos/estados adicionais de `billing_payment_receipts`
também são exclusivos do servidor. Não há policy nem privilégio para leitura ou
escrita por clientes. O usuário consulta seu plano através do perfil, sem acesso
ao ledger. Os auxiliares de reversão são privados e não executáveis diretamente.
Ver [reversoes-cobranca.md](reversoes-cobranca.md).

Com `supabase start`, use o SQL Editor/`psql` simulando usuários:

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub": "<uuid-do-usuario>", "role": "authenticated"}';
select * from proposals;                       -- só as propostas visíveis a esse usuário
update profiles set plan = 'pro' where id = '<uuid>';   -- deve falhar (permission denied)
```
