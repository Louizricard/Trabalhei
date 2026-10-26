# Checklist de produção

Itens que dependem de painel, conta ou decisão do responsável. O que é código já está no repositório.

## 1. Supabase › Authentication

Feito: URL Configuration e *Minimum password length* = 8 conferidos no painel.

**URL Configuration** (Authentication › URL Configuration)

- Site URL: `https://trabalhei.site`
- Redirect URLs: `https://trabalhei.site/**`, `https://trabalhei.vercel.app/**` e, para
  desenvolvimento, `http://localhost:*/**`

O app não envia `emailRedirectTo`, então os links de confirmação e de redefinição de senha usam a Site URL.

**Senhas** (Authentication › Providers › Email)

- Minimum password length: **8**, o mesmo valor de `minPasswordLength` em
  `freelanceflow/lib/features/auth/domain/password_policy.dart`.
- *Prevent use of leaked passwords*: só existe no plano Pro do Supabase. O projeto está no plano
  gratuito, então o advisor continua acusando o item até um upgrade.

## 2. E-mail (SMTP próprio)

Feito em 25/10/2026 com o domínio `trabalhei.site` (registrado na Hostinger, DNS no Vercel) e o **Resend**:

- Domínio verificado no Resend (região São Paulo, `sa-east-1`, sem rastreamento de abertura/clique).
  Registros no DNS do Vercel: `TXT resend._domainkey` (DKIM), `MX send` →
  `feedback-smtp.sa-east-1.amazonses.com` (prioridade 10), `TXT send` → `v=spf1 include:amazonses.com ~all`,
  `CNAME rsend` → `send.forge.rmta.net` e `TXT _dmarc` → `v=DMARC1; p=none;`.
- SMTP do Supabase configurado pela integração do Resend: `smtp.resend.com:465`, remetente
  `Trabalhei <no-reply@trabalhei.site>`.
- Modelos em português de `supabase/templates/` aplicados em Authentication › Emails › Templates
  (assuntos em `supabase/config.toml`).
- **Confirm email ligado** de novo. Site URL: `https://trabalhei.site`.
- Limite: 25 e-mails por hora no Supabase (Rate Limits); o plano gratuito do Resend permite 100 por
  dia e 3.000 por mês. Se o volume crescer, suba os dois juntos.

## 2.1 Notificações por e-mail e push

Toda notificação criada no banco chama a Edge Function `dispatch-notification`
(trigger `notifications_dispatch`, via `pg_net`). Ela envia o e-mail pelo Resend
e o Web Push para os navegadores inscritos, conforme `notification_settings`.
As chaves ficam no **Vault** do Supabase (Project Settings › Vault), não no código:

| Segredo | Conteúdo |
|---|---|
| `notification_dispatch_url` | URL da função `dispatch-notification`. Sem ele, nada é enviado. |
| `resend_api_key` | Chave do Resend só de envio, restrita ao domínio trabalhei.site. |
| `vapid_public_key` / `vapid_private_key` | Par VAPID do Web Push (base64url). Trocar o par invalida as inscrições. |
| `app_url` | Endereço do app usado nos links (`https://trabalhei.site/app`). |

- Para conferir um envio: `select status_code, content from net._http_response order by created desc limit 5;`
  (`email_skipped` explica quando o e-mail não sai).
- Push no Android e no Windows instalados ainda não existe: precisa de um projeto
  no Firebase (FCM). Hoje esses apps mostram os avisos no sino e o e-mail cobre o resto.

## 2.2 Moderação

Administradores ficam na tabela `public.admins` (só o banco altera):
`insert into public.admins (user_id) values ('<id do usuário>');`
O painel fica em Perfil › Moderação. Suspender bloqueia o login (`banned_until`),
encerra as sessões, encerra as vagas abertas e registra em `moderation_actions`.

## 3. Vercel

- O build do app web já está configurado (`vercel.json`), com `SUPABASE_URL` e `SUPABASE_ANON_KEY`
  definidas em Production e Preview.
- A produção é recompilada a cada merge na `main` e responde em `https://trabalhei.site`
  (`www.trabalhei.site` redireciona para ele) e em `https://trabalhei.vercel.app`.
- O DNS de `trabalhei.site` fica no Vercel (Domains › trabalhei.site): é lá que se criam registros.
- Os previews exigem login no Vercel (Deployment Protection). A produção é pública.

## 4. Sentry

Configurado: projetos `app` (Flutter) e `edge-functions` (Deno) na organização `louizvolution`;
`SENTRY_DSN` do app no Vercel (Production e Preview) e o das funções em Edge Functions › Secrets do
Supabase. Os dois projetos receberam erro de teste e o alerta *high priority issues* envia e-mail.
Para trocar o DSN, atualize os dois lugares e refaça o deploy do Vercel (as funções leem o secret na
próxima execução).

## 5. Asaas

Pendente.

- No cadastro do webhook, preencha o e-mail de notificação. O Asaas avisa quando a fila de webhooks
  é interrompida depois de falhas seguidas.
- Antes de produção, troque `ASAAS_BASE_URL` e `ASAAS_API_KEY` para os valores de produção.

## 6. Termos de uso

- Nome, documento e e-mail do responsável estão em `freelanceflow/lib/core/config/legal.dart` e
  aparecem publicamente na tela de termos.
- Peça uma revisão jurídica, em especial dos trechos sobre arrependimento e reembolso, foro e prazo
  de guarda dos registros de acesso. O Marco Civil exige 6 meses, e o plano gratuito do Supabase
  guarda logs por bem menos tempo.
- Ao publicar mudanças relevantes, altere `termsVersion`. A versão aceita fica registrada no
  cadastro de cada usuário.

## 7. Limpeza

Feita em 24/10/2026: as Edge Functions do modelo antigo (`create-payment-intent`, `mercadopago-webhook`,
`process-pix-payout`, `check-payment-status`) foram excluídas, e a tabela
`supabase_migrations.legacy_history_backup` foi apagada. O código delas segue no histórico do git
(commit `56b46f9`).

## 8. Android (APK)

- O APK de release é assinado com a chave `trabalhei-release.jks`, guardada fora do repositório em
  `C:\Users\luizr\Documents\trabalhei\android-release-key\`, junto com uma cópia do `key.properties`
  (senha e alias).
- **Faça backup desses dois arquivos** (pen drive, cofre de senhas). Sem eles não é possível publicar
  uma atualização que instale por cima da versão anterior, nem usar o mesmo app na Play Store.
- Para gerar uma versão nova: suba `version` no `pubspec.yaml`, copie o `key.properties` para
  `freelanceflow/android/` e rode, dentro de `freelanceflow/`:
  `flutter build apk --release --dart-define-from-file=dart_defines.json --dart-define=SENTRY_DSN=<DSN do app> --dart-define=SENTRY_ENVIRONMENT=production`
- Sem o `key.properties`, o build de release usa a chave de debug da máquina (serve para testes,
  não para publicar).
