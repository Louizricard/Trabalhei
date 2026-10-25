# Trabalhei

Marketplace de freelancers em **Flutter** (Android, iOS e Web) com backend **Supabase**.
Clientes publicam vagas, freelancers enviam propostas, as partes conversam em tempo real,
acompanham entregas por marcos e se avaliam ao final.

## Modelo de negócio

O Trabalhei **não custodia pagamentos**. O valor do projeto é combinado e pago diretamente
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
  tool/showcase/      App de demonstração e scripts que geram os prints da homepage
site/                 Homepage pública (raiz de trabalhei.site; o app fica em /app/)
supabase/
  migrations/         Schema, RLS e funções (RPC) do banco (só migrations de ida)
  rollbacks/          Rollback de cada migration (<versão>_<nome>_down.sql), fora do alcance do CLI
  functions/          Edge Functions (Deno): cobrança Asaas, webhook e exclusão de conta
  templates/          E-mails de autenticação em português (cadastro, senha, etc.)
    _shared/          Código comum (importado como ../_shared/common.ts)
docs/rls.md           Políticas de segurança por tabela
docs/producao.md      Checklist do que configurar nos painéis antes de produção
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
supabase functions deploy asaas-create-subscription asaas-cancel-subscription asaas-feature-job asaas-webhook delete-account
```

Antes do `db push`, `supabase migration list` deve mostrar as mesmas versões no local e no remoto.
Os rollbacks ficam em `supabase/rollbacks/` e são aplicados à mão (`psql -f`), nunca pelo CLI.

As funções importam o código comum de `../_shared/common.ts`; o CLI empacota isso sozinho. Se publicar
por outro meio (painel, MCP), envie os arquivos com o mesmo layout (`<função>/index.ts` e
`_shared/common.ts`, entrypoint `<função>/index.ts`) para o código publicado ser idêntico ao do repositório.

No painel do Asaas, cadastre o webhook em `https://<ref>.functions.supabase.co/asaas-webhook`
com o mesmo token de `ASAAS_WEBHOOK_TOKEN` e os eventos `PAYMENT_*` e `SUBSCRIPTION_*`.
Os preços exibidos no app (`BillingConfig`) devem espelhar `PRO_PRICE` e `FEATURE_PRICE`.
Comece pelo sandbox (`ASAAS_BASE_URL` padrão) e só troque para produção depois de testar o ciclo completo.

## App web no Vercel

O `vercel.json` chama `scripts/vercel-build.sh`, que baixa a versão fixada do Flutter e roda
`flutter build web`. Variáveis do projeto no Vercel (Production e Preview):

| Variável | Valor |
|---|---|
| `SUPABASE_URL` | URL do projeto Supabase |
| `SUPABASE_ANON_KEY` | Chave publicável do Supabase |
| `SENTRY_DSN` | Opcional; DSN do projeto Flutter no Sentry |

O ambiente enviado ao Sentry vem de `VERCEL_ENV` (production/preview). Produção: `https://trabalhei.site`
(DNS no Vercel; `www` redireciona para o domínio principal e `trabalhei.vercel.app` continua respondendo).

O build publica a pasta `dist/`: a homepage (`site/`) na raiz e o app Flutter em `/app/`
(`--base-href /app/`). Links antigos do app (`/#/login`, links de e-mail com `?code=...`) e o app
instalado como PWA são levados para `/app/` por um script no topo de `site/index.html`.

## Versões para Android e Windows

```bash
cd freelanceflow
flutter build apk --release --dart-define-from-file=dart_defines.json      # assinado com key.properties
flutter build windows --release --dart-define-from-file=dart_defines.json
cd ..
powershell -ExecutionPolicy Bypass -File scripts/windows-installer/build.ps1
```

O `build.ps1` gera em `release/` o ZIP portátil e o instalador `.exe`, montado pelo IExpress (já vem no
Windows). O instalador copia o app para `%LOCALAPPDATA%\Programs\Trabalhei` sem pedir administrador,
cria o atalho no menu Iniciar e registra a desinstalação em "Aplicativos instalados". O executável não
tem assinatura digital, então o Windows SmartScreen avisa na primeira execução.

## Homepage (`site/`)

HTML, CSS e JavaScript sem dependências nem etapa de build. Os botões de download leem a última
versão do GitHub Releases: o `.apk` vira o botão do Android, `*-windows-*-setup.exe` o instalador do
Windows e `*-windows-*.zip` o ZIP portátil. Se a consulta falhar, os botões levam à página de versões.
O aparelho em destaque muda com a tela (`html[data-mode]`, definido no `<head>`): notebook em telas
largas e deitadas, celular nas demais.
Preços citados no texto (Pro e destaque) devem acompanhar o `BillingConfig`.

SEO: `robots.txt`, `sitemap.xml` (atualize o `lastmod` ao mudar a página), `llms.txt` para buscadores de
IA e JSON-LD (organização, app e perguntas frequentes). O JSON-LD das perguntas é gerado no build por
`scripts/site-seo.mjs` a partir das próprias perguntas da página. O app em `/app/` tem `noindex`.

Os prints são telas reais do app com dados fictícios, gerados pelo app de demonstração em
`freelanceflow/tool/showcase` (mesmos widgets do app, repositórios em memória):

```bash
cd freelanceflow
flutter build web -t tool/showcase/main.dart -o build/showcase
python -m http.server 8091 --directory build/showcase   # em outro terminal
BROWSER="<caminho do Edge ou Chrome>" node tool/showcase/capture.mjs <pasta>
BROWSER="<caminho do Edge ou Chrome>" node tool/showcase/resize.mjs <pasta>/phone-jobs.png:../site/assets/screens/phone-jobs-sm.webp:585
```

Os destaques da demonstração guiada (`DEMO_STEPS` em `site/assets/js/site.js`) usam posições em %
de cada print; ao trocar um print, confira se continuam no lugar.

## Monitoramento (Sentry)

Erros não tratados do app e falhas 5xx das Edge Functions (incluindo o webhook do Asaas) vão para o
Sentry quando `SENTRY_DSN` está definido; sem ele, nada é enviado. No app, defina `SENTRY_DSN` no
Vercel (ou no `dart_defines.json`); nas funções, `supabase secrets set SENTRY_DSN=...`. O Sentry
avisa por e-mail a cada novo tipo de erro.

## Qualidade

```bash
cd freelanceflow
flutter analyze
flutter test
```

O CI (`.github/workflows/ci.yml`) roda os dois comandos a cada push e pull request.

## Convenções

Regras para contribuidores e agentes de IA: [AGENTS.md](AGENTS.md) e `.agents/rules/`.
