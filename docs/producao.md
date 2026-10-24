# Checklist de produção

Itens que dependem de painel, conta ou decisão do responsável. O que é código já está no repositório.

## 1. Supabase › Authentication

**URL Configuration** (Authentication › URL Configuration)

- Site URL: `https://trabalhei.vercel.app`
- Redirect URLs: `https://trabalhei.vercel.app/**` e, para desenvolvimento, `http://localhost:*/**`

O app não envia `emailRedirectTo`, então os links de confirmação e de redefinição de senha usam a Site URL.

**Senhas** (Authentication › Providers › Email)

- Minimum password length: **8**, o mesmo valor de `minPasswordLength` em
  `freelanceflow/lib/features/auth/domain/password_policy.dart`.
- *Prevent use of leaked passwords*: só existe no plano Pro do Supabase. O projeto está no plano
  gratuito, então o advisor continua acusando o item até um upgrade.

## 2. E-mail (SMTP próprio)

O remetente padrão do Supabase só envia para membros da organização: para qualquer outro endereço o
cadastro falha com *Email address not authorized*. Ele também tem um limite baixo de envios por hora.
Para cadastros reais é preciso um SMTP próprio, em Authentication › Emails › SMTP Settings.

- Provedores com plano gratuito: Resend, Brevo ou Amazon SES.
- Todos exigem um **domínio próprio verificado** (registros SPF/DKIM no DNS). Não dá para verificar
  `vercel.app`, então o SMTP próprio depende de registrar um domínio, por exemplo `trabalhei.com.br`.
- Com o domínio registrado, ele também pode virar o endereço do app no Vercel. Nesse caso, atualize a
  Site URL do item 1.
- Com o SMTP próprio configurado, o Supabase começa limitando a 30 e-mails por hora. Ajuste esse
  valor em Authentication › Rate Limits e teste o cadastro com um e-mail de fora da organização.

## 3. Vercel

- O build do app web já está configurado (`vercel.json`), com `SUPABASE_URL` e `SUPABASE_ANON_KEY`
  definidas em Production e Preview.
- A produção (`trabalhei.vercel.app`) só passa a ter o app compilado depois do merge na `main`.
- Os previews exigem login no Vercel (Deployment Protection). A produção é pública.

## 4. Sentry

1. Crie uma conta em sentry.io e dois projetos: um **Flutter** (app) e um **Deno** (Edge Functions).
2. App: adicione `SENTRY_DSN` (DSN do projeto Flutter) nas variáveis do Vercel, em Production e
   Preview, e faça um novo deploy.
3. Funções: `supabase secrets set SENTRY_DSN=<DSN do projeto Deno>`. As funções leem o valor na
   próxima execução, sem novo deploy.
4. Em Alerts, confirme que o alerta de novo tipo de erro (*new issue*) envia e-mail.

Sem o DSN, nada é enviado e os erros ficam só no console e nos logs das funções.

## 5. Asaas

- No cadastro do webhook, preencha o e-mail de notificação. O Asaas avisa quando a fila de webhooks
  é interrompida depois de falhas seguidas.
- Antes de produção, troque `ASAAS_BASE_URL` e `ASAAS_API_KEY` para os valores de produção.

## 6. Termos de uso

- Preencha nome ou razão social, CPF ou CNPJ e e-mail em `freelanceflow/lib/core/config/legal.dart`.
  Hoje esses campos aparecem entre colchetes na tela.
- Peça uma revisão jurídica, em especial dos trechos sobre arrependimento e reembolso, foro e prazo
  de guarda dos registros de acesso. O Marco Civil exige 6 meses, e o plano gratuito do Supabase
  guarda logs por bem menos tempo.
- Ao publicar mudanças relevantes, altere `termsVersion`. A versão aceita fica registrada no
  cadastro de cada usuário.

## 7. Limpeza

- Edge Functions do modelo antigo ainda publicadas e sem login:
  `supabase functions delete create-payment-intent mercadopago-webhook process-pix-payout check-payment-status`
- Tabela `supabase_migrations.legacy_history_backup`: pode ser apagada quando não for mais útil.
