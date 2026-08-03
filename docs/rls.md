# FreelanceFlow — Políticas de Row Level Security (RLS)

Este documento descreve detalhadamente cada política de segurança em nível de linha (RLS) configurada no Postgres do Supabase, conforme exigido pelas regras de arquitetura e banco de dados (`06-banco-de-dados.md` e `08-seguranca.md`).

---

## 1. Tabela `profiles`
- **Leitura (`SELECT`)**: Pública para qualquer usuário autenticado ou visitante (`true`). Necessário para que clientes vejam perfis de freelancers no mural e vice-versa.
- **Inserção (`INSERT`)**: Permitida apenas para o próprio usuário autenticado (`auth.uid() = id`), disparada após o cadastro no Auth.
- **Atualização (`UPDATE`)**: Exclusiva do proprietário (`auth.uid() = id`). Ninguém pode alterar o perfil de outro usuário.

---

## 2. Tabela `jobs`
- **Leitura (`SELECT`)**: Aberta para vagas com `visibility = 'public'` ou quando o usuário autenticado for o cliente criador (`auth.uid() = client_id`). Vagas privadas/por convite só são visíveis pelo criador e convidados.
- **Criação (`INSERT`)**: Permitida apenas se `auth.uid() = client_id`.
- **Edição/Exclusão (`UPDATE` / `DELETE`)**: Restrita ao cliente proprietário da vaga (`auth.uid() = client_id`).

---

## 3. Tabela `proposals`
- **Leitura (`SELECT`)**: Restrita ao freelancer autor (`auth.uid() = freelancer_id`) e ao cliente dono da respectiva vaga (`auth.uid() = jobs.client_id`). Garante sigilo nas propostas concorrentes.
- **Criação (`INSERT`)**: Apenas freelancers autenticados (`auth.uid() = freelancer_id`).
- **Atualização (`UPDATE`)**: Apenas pelo freelancer autor ou pelo cliente contratante (para aceitar/rejeitar).

---

## 4. Tabela `contracts` e `milestones`
- **Leitura (`SELECT`)**: Visível exclusivamente pelas partes envolvidas no contrato (`client_id` ou `freelancer_id`).
- **Criação (`INSERT`)**: Efetuada pelo cliente no ato do aceite da proposta.

---

## 5. Tabela `conversations` e `messages`
- **Leitura e Envio**: Totalmente isoladas entre os dois participantes (`participant_a` e `participant_b`). Nenhum terceiro tem acesso aos chats ou anexos.

---

## 6. Tabela `transactions` (Escrow e Pagamentos)
- **Leitura (`SELECT`)**: Privada ao usuário titular (`auth.uid() = user_id`).
- **Inserção (`INSERT`)**: Permitida ao usuário autenticado para registro de depósitos e pedidos de saque.

---

## 7. Tabela `reviews`
- **Leitura (`SELECT`)**: Pública para alimentar a reputação de clientes e freelancers.
- **Criação (`INSERT`)**: Apenas o autor de um contrato concluído pode avaliar (`auth.uid() = reviewer_id`).
- **Resposta (`UPDATE`)**: Apenas o destinatário avaliado pode preencher o campo `public_response`.
