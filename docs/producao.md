# Checklist de produção

Itens que dependem de painel, conta ou decisão do responsável. O que é código já está no repositório.

## 1. Supabase › Authentication

Feito: URL Configuration e *Minimum password length* = 8 conferidos no painel.

**URL Configuration** (Authentication › URL Configuration)

- Site URL: `https://trabalhei.vercel.app` (passa a ser `https://trabalhei.site` quando o domínio
  estiver no ar)
- Redirect URLs: `https://trabalhei.site/**`, `https://trabalhei.vercel.app/**` e, para
  desenvolvimento, `http://localhost:*/**`

O app não envia `emailRedirectTo`, então os links de confirmação e de redefinição de senha usam a Site URL.

**Senhas** (Authentication › Providers › Email)

- Minimum password length: **8**, o mesmo valor de `minPasswordLength` em
  `freelanceflow/lib/features/auth/domain/password_policy.dart`.
- *Prevent use of leaked passwords*: só existe no plano Pro do Supabase. O projeto está no plano
  gratuito, então o advisor continua acusando o item até um upgrade.

## 2. E-mail (SMTP próprio)

Em andamento com o domínio `trabalhei.site` (registrado na Hostinger) e o **Resend**:

- [x] Domínio adicionado no Resend, região São Paulo (`sa-east-1`), sem rastreamento de abertura/clique.
- [x] Nameservers da Hostinger trocados para `ns1.vercel-dns.com` e `ns2.vercel-dns.com`.
- [ ] Registros de DNS do Resend criados no Vercel (assim que os nameservers propagarem):
  `TXT resend._domainkey` (DKIM), `MX send` → `feedback-smtp.sa-east-1.amazonses.com` (prioridade 10),
  `TXT send` → `v=spf1 include:amazonses.com ~all`, `CNAME rsend` → `send.forge.rmta.net` e
  `TXT _dmarc` → `v=DMARC1; p=none;`.
- [ ] Domínio verificado no Resend.
- [ ] Resend conectado ao Supabase (Resend › Integrations › Supabase), remetente
  `Trabalhei <no-reply@trabalhei.site>`.
- [ ] Modelos em português de `supabase/templates/` colados em Authentication › Emails › Templates
  (o painel só libera a edição depois do SMTP próprio). Assuntos em `supabase/config.toml`.
- [ ] Rate limit de e-mails ajustado (o padrão com SMTP próprio é 30 por hora).
- [ ] Site URL trocada para `https://trabalhei.site`.
- [ ] **Confirm email religado** e cadastro testado com um e-mail de fora da organização.

Enquanto isso, **Confirm email está desligado** (Authentication › Sign In / Providers › User Signups,
desde 25/10/2026): o cadastro já entra logado, sem verificar o e-mail.

Por que é necessário: o remetente padrão do Supabase só envia para membros da organização (para
qualquer outro endereço o cadastro falha com *Email address not authorized*) e tem limite baixo de
envios por hora.

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
