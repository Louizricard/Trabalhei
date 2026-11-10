# Trabalhei

Marketplace de freelancers (vagas, propostas, marcos, chat, avaliações). Flutter + Dart (Android, iOS e Web), Riverpod, go_router, Supabase (Postgres, Auth, Storage, Realtime, Edge Functions em Deno) e cobrança via Asaas (Pix/cartão, webhook idempotente).

Contexto completo: `AGENTS.md` e `.agents/rules/01..09`. Leia `01-regras-permanentes.md`, `02-arquitetura.md` e a regra do tipo de tarefa antes de escrever código.

## Layout

- `freelanceflow/` — app Flutter (`lib/` em Clean Architecture feature-first: domain / data / presentation)
- `supabase/` — `migrations/`, `rollbacks/`, `functions/`, `tests/` (Deno)
- `docs/` — checkout, webhook, estornos, RLS, produção
- `site/`, `scripts/`, `vercel.json` — site e deploy

## Comandos de verificação (os mesmos do CI)

```bash
cd freelanceflow && flutter pub get && flutter analyze && flutter test
cd freelanceflow && flutter build apk --debug
cd supabase && deno task test:webhook
```

## Regras permanentes

1. Não remover funcionalidade sem autorização explícita.
2. Mudança de schema só com migration versionada e reversível (com rollback em `supabase/rollbacks/`).
3. Dependência nova no `pubspec.yaml` só com justificativa.
4. Sem código duplicado nem código comentado morto.
5. Sem `print()` em produção; usar logger estruturado.
6. Sem URL, token ou chave hardcoded; usar `--dart-define` / env. Nunca commitar segredos.
7. Android, iOS e Web precisam continuar funcionando.
8. Se uma regra conflitar com o pedido, pare e explique antes de prosseguir.

## Definição de pronto

Compila, roda sem crash, `flutter analyze` sem warnings, funciona em Android e Web, segue a arquitetura e atualiza a documentação afetada. Se algo falhar, relate o que falta em vez de dizer que concluiu.

## Git

Conventional Commits (`tipo(escopo): descrição no imperativo`), um commit por unidade lógica. Ao fim de cada tarefa, sugira a mensagem de commit.

## Produção — cuidado extra

O checkout/cobrança é financeiro e já teve incidente de duplicidade. Não rodar `supabase db push`, `functions deploy` nem `git push` sem pedido explícito. Não ler `android-release-key/`, `*-production-backup.json` nem `dart_defines.json`.
