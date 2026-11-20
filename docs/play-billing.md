# Google Play Billing (app Android)

No Android, o Pro e o Destaque são vendidos pelo Google Play Billing, como exige a política de
pagamentos do Google Play para recursos digitais. No web, a cobrança continua pelo Asaas
(Pix/cartão, ver `checkout-asaas.md`). Um mesmo usuário pode ter Pro pelas duas vias; vale o prazo
mais longo.

## Como funciona

```
app Android                         Google Play                  Supabase
  buyPro / buyFeature ───────────▶ compra (conta Google)
    obfuscatedAccountId = id do usuário
    obfuscatedProfileId = id da vaga (Destaque)
  purchaseStream: comprado ──────────────────────────────────▶ play-billing (JWT do usuário)
                                   ◀── GET purchase na API ──── confere produto, dono e vaga
                                                                apply_play_subscription / apply_play_feature
                                   ◀── acknowledge / consume ── só depois de gravar
  Pub/Sub (RTDN) ───── renovação, cancelamento, estorno ─────▶ play-rtdn?token=…
```

- O benefício só é concedido pelo servidor, depois de ler a compra na API do Google. Usuário e vaga
  vêm do Google (`obfuscatedExternalAccountId`/`obfuscatedExternalProfileId`), nunca do corpo da
  requisição; um token fica preso ao primeiro usuário que o registrou (`PURCHASE_OWNED_BY_OTHER`).
- Sem reconhecimento (acknowledge) em 3 dias o Google estorna sozinho. O servidor reconhece/consome
  só depois de gravar. Se o app fechar no meio, a notificação do Google (`play-rtdn`) confirma.
- Assinatura: `active` e `cancelled` (renovação desligada) valem até `expires_at`; `expired` e
  `pending` não dão Pro; estorno (`voidedPurchaseNotification`) vira `refunded` e tira o Pro.
- Destaque: soma 7 dias (`billing_products.job_feature.period_days`) ao destaque atual da vaga; o
  estorno remove o período que ainda faltava.
- Excluir a conta cancela a renovação da assinatura do Google (`delete-account`).
- Cupons não valem no Android. Para promoções use os códigos promocionais do Play Console.

Código: `supabase/migrations/20261117120000_play_billing.sql` (tabela `play_purchases` e funções),
`supabase/functions/_shared/google_play.ts`, `_shared/play_purchases.ts`, `play-billing/`,
`play-rtdn/`, `freelanceflow/lib/features/billing/data/play_billing_service.dart`. Testes:
`supabase/tests/play/` (banco e regras) e `freelanceflow/test/features/billing/`.

## Configuração (uma vez)

1. **Perfil de pagamentos** no Play Console (Configurações › Perfil de pagamentos). Sem ele não dá
   para criar produtos pagos.
2. **Enviar um AAB** para um teste interno (o Console só libera produtos depois de um envio com a
   biblioteca de faturamento; o `in_app_purchase` já a inclui).
3. **Produtos** (Monetizar › Produtos), ids exatamente iguais:
   - Assinatura `pro_monthly`, com um plano básico mensal com renovação automática, preço
     R$ 14,90. Pode ter período de carência (o app trata como ativo).
   - Produto avulso `job_feature`, R$ 9,90.
   - Mantenha os preços iguais aos de `public.billing_products` (o app mostra esses).
4. **Conta de serviço**: no Google Cloud do projeto vinculado ao Play Console, crie uma conta de
   serviço e uma chave JSON. No Play Console › Usuários e permissões, convide o e-mail da conta com
   "Ver dados financeiros" e "Gerenciar pedidos e assinaturas". Guarde o JSON no cofre de senhas.
5. **Segredos das Edge Functions** (Supabase › Edge Functions › Secrets):
   - `GOOGLE_PLAY_SERVICE_ACCOUNT`: o conteúdo do JSON.
   - `PLAY_RTDN_TOKEN`: um valor aleatório longo (`openssl rand -hex 32`).
6. **Aplicar a migration e publicar as funções** `play-billing`, `play-rtdn` e `delete-account`
   (a `play-rtdn` sobe sem verificação de JWT, ver `supabase/config.toml`).
7. **Notificações em tempo real (RTDN)**: no Google Cloud crie um tópico Pub/Sub, dê ao
   `google-play-developer-notifications@system.gserviceaccount.com` o papel de Publicador nele e
   crie uma inscrição *push* para
   `https://<projeto>.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>`. No Play Console ›
   Monetizar › Configuração de monetização, informe o tópico e clique em "Enviar notificação de
   teste" (a função responde `{"result":"test"}`).
8. **Testadores de licença** (Configurações › Teste de licença): contas que compram sem cobrança
   real, com renovação acelerada da assinatura. Use-as para testar antes da produção.

## Verificação antes de liberar

Com uma conta de teste de licença, no app instalado pela faixa de teste interno:

- Assinar o Pro → plano vira Pro; `play_purchases` com `state='active'`.
- Desligar a renovação em Google Play › Assinaturas → `state='cancelled'`, Pro até o fim do prazo.
- Destacar uma vaga → `jobs.featured_until` +7 dias; comprar de novo soma mais 7.
- Reembolsar um pedido no Play Console (Pedidos) → `state='refunded'` e benefício removido.
- Excluir uma conta com assinatura ativa → assinatura cancelada no Google.

## Taxas

O Google retém 15% das assinaturas e 15% do primeiro US$ 1 milhão por ano dos produtos avulsos
(programa de taxa reduzida, precisa de inscrição no Console). O preço no Play é bruto.
