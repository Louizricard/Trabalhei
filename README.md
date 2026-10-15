# FreelanceFlow

Marketplace de freelancers em **Flutter** (Android, iOS e Web) com backend **Supabase**.
Clientes publicam vagas, freelancers enviam propostas, as partes conversam em tempo real,
acompanham entregas por marcos e se avaliam ao final.

## Modelo de negócio

O FreelanceFlow **não custodia pagamentos**. O valor do projeto é combinado e pago diretamente
entre cliente e freelancer. A plataforma monetiza com:

| Produto | Quem paga | Como funciona |
|---|---|---|
| **Plano Pro** (assinatura mensal) | Freelancer | Propostas ilimitadas, selo PRO e prioridade na busca. No plano grátis são 5 propostas por mês |
| **Destaque de vaga** (avulso, 7 dias) | Cliente | A vaga aparece no topo do mural |

A cobrança é feita pelo **Asaas** (Pix e cartão) por meio de faturas hospedadas: o app e o banco
nunca tocam em dados de cartão. O plano/destaque só é aplicado quando o webhook do Asaas confirma
o pagamento.

## Estrutura

```
freelanceflow/        App Flutter (lib/, test/, android/, ios/, web/ ...)
supabase/
  migrations/         Schema, RLS e funções (RPC) do banco
  functions/          Edge Functions (Deno): cobrança Asaas e webhook
docs/rls.md           Políticas de segurança por tabela
```

O app segue Clean Architecture por feature (`domain` / `data` / `presentation`) com Riverpod e go_router.
Toda mudança de estado sensível (aceitar proposta, entregar/aprovar marco, cota do plano) acontece em
funções do banco (`SECURITY DEFINER`); o cliente só tem permissão de escrita nas colunas que pode editar.

## Rodando localmente

Pré-requisitos: Flutter estável, [Supabase CLI](https://supabase.com/docs/guides/local-development) e Docker.

```bash
# 1. Backend local (aplica supabase/migrations)
supabase start

# 2. App (use a URL e a chave exibidas pelo `supabase start`)
cd freelanceflow
cp dart_defines.example.json dart_defines.json   # edite SUPABASE_URL e SUPABASE_ANON_KEY
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

O app não lê arquivos `.env`: a configuração entra em tempo de compilação via `--dart-define`.

## Projeto Supabase na nuvem

```bash
supabase link --project-ref <ref>
supabase db push                                  # aplica as migrations
cp supabase/.env.example supabase/.env           # preencha os segredos do Asaas
supabase secrets set --env-file supabase/.env
supabase functions deploy asaas-create-subscription asaas-cancel-subscription asaas-feature-job asaas-webhook
```

No painel do Asaas, cadastre o webhook em `https://<ref>.functions.supabase.co/asaas-webhook`
com o mesmo token de `ASAAS_WEBHOOK_TOKEN` e os eventos `PAYMENT_*` e `SUBSCRIPTION_*`.
Os preços exibidos no app (`BillingConfig`) devem espelhar `PRO_PRICE` e `FEATURE_PRICE`.
Comece pelo sandbox (`ASAAS_BASE_URL` padrão) e só troque para produção depois de testar o ciclo completo.

## Qualidade

```bash
cd freelanceflow
flutter analyze
flutter test
```

O CI (`.github/workflows/ci.yml`) roda os dois comandos a cada push e pull request.

## Convenções

Regras para contribuidores e agentes de IA: [AGENTS.md](AGENTS.md) e `.agents/rules/`.
