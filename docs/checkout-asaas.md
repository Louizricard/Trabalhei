# Checkout Asaas: concorrência e recuperação

## Garantias e limites

`asaas-create-subscription` e `asaas-feature-job` usam os módulos
`checkout.ts`, `checkout_provider.ts` e `checkout_products.ts`.

- Antes de qualquer POST financeiro, o banco reserva uma intenção e uma etapa.
- A lease de 90 segundos serializa os produtos do mesmo usuário, inclusive a criação do cliente.
- O token impede que um worker vencido grave vínculos ou libere a lease de outro worker.
- A reserva do POST **não expira** com a lease. Timeout, falha de conexão e HTTP 5xx
  exigem conciliação; não autorizam repetir a criação.
- A referência externa é `sub:<checkout-id>` ou `feature:<checkout-id>`. Ela correlaciona
  registros; o Asaas não garante unicidade desse campo.
- Se o ID remoto não foi salvo, a retomada lista o recurso pela referência e só aceita
  uma correspondência exata. Zero, múltiplas correspondências ou paginação incompleta
  retornam 503, sem outra criação. Se o POST não chegou ao Asaas, pode ser necessário
  atendimento para liberar a operação após comprovar a ausência de cobrança.
- Uma rejeição HTTP 400/422 permite corrigir os dados e tentar novamente. A reserva do
  cupom e o preço permanecem ligados à mesma intenção. O diário não registra dados pessoais.
- Índices únicos impedem duas assinaturas abertas por usuário e dois destaques pendentes
  por vaga. O preflight deve resolver duplicidades antigas antes de aplicar a migration.
- A troca Pix/cartão atualiza a assinatura e a cobrança pendentes via PUT, sem criar
  outra assinatura ou cancelar silenciosamente a anterior.
- Uma cobrança pendente mantém o cupom original. Para trocar o cupom do Pro, cancele
  explicitamente a assinatura pendente antes; para destaque, concilie com o suporte.
  Isso evita cancelar uma cobrança que possa ter sido paga durante a troca.
- O desconto do Pro continua restrito à primeira cobrança; o preço normal fica na recorrência.
- Cupons gratuitos, gravação do uso e concessão do benefício são uma única transação.

O app envia `request_id` estável ao repetir a mesma tentativa na sessão. Reenviar esse
identificador após confirmação do destaque devolve o resultado sem outra compra. Após
confirmar o pagamento, uma nova compra recebe um identificador novo. Clientes antigos
continuam compatíveis: usam a reserva por escopo e reaproveitam cobranças pendentes.

## Pix dentro do app

O APK **1.0.3** abre `invoice_url` em navegador externo. O checkout Pix com QR Code,
cópia do código e confirmação no app entrou no commit `c5176ce`, distribuído em **1.0.4**.
Atualizar apenas a Edge Function não muda a interface de um APK já instalado.

O cliente atual recusa resposta Pix sem payload, em vez de abrir a fatura silenciosamente.
A confirmação de destaque consulta o `payment_id` exato, evitando usar um pagamento antigo
da mesma vaga. Cartão continua na página segura hospedada do Asaas; não há coleta de dados
de cartão no Flutter.

## Publicação coordenada

1. Execute `deno task test:webhook` em PostgreSQL local descartável e o CI completo.
   A suíte inclui os testes de checkout em `supabase/tests/checkout/`.
2. Confira duplicidades de assinaturas abertas e destaques pendentes, além dos eventos
   pendentes/falhos. Não cancele nem apague registros financeiros automaticamente.
3. Coloque **os dois endpoints de criação** em manutenção (503 + Retry-After).
   Mantenha o webhook recebendo eventos. Aguarde o limite de duração dos workers antigos
   (150 segundos no plano Free), com margem, e confirme ausência de operações antigas.
4. Aplique as migrations `billing_checkout_reservations` e `billing_checkout_effects`,
   nesta ordem. Alinhe os timestamps locais aos registrados pelo Supabase.
5. Publique ambos os endpoints com seus módulos compartilhados. Valide autenticação,
   métodos HTTP, privilégios das RPCs e compare o estado financeiro antes/depois.
6. Não é necessário criar cobranças reais para esses testes de publicação. A simulação
   ponta a ponta do provedor deve usar conta/projeto sandbox separado.

## Conciliação operacional

Somente o backend (`service_role`) lê/escreve o diário e executa as RPCs. RLS sem
política pública nessas quatro tabelas é intencional. Não conceda acesso ao app.

```sql
select s.id,s.user_id,s.step_key,s.created_at,s.provider_id
from public.billing_checkout_steps s
where s.provider_id is null
order by s.created_at;
```

Uma etapa `customer` pertence ao usuário, compartilhada entre produtos. As outras são
identificadas pelo checkout. Etapas `:method` e `:update` autorizam PUTs repetíveis e
não representam criação pendente. Para investigar criação, filtre `customer`,
`:subscription` e `:payment`.

Confirme na conta Asaas correta a referência externa e se há registros removidos.
Com exatamente um registro, a própria retomada salva o ID e conclui o vínculo. Se houver
mais de um, investigue o histórico e quais cobranças foram pagas antes de cancelar algo.
Não apague uma reserva inconclusiva por idade nem libere seu cupom como solução de timeout.

## Rollback

Interrompa ambos os endpoints e drene os workers antes de qualquer rollback.
Os arquivos em `supabase/rollbacks/` removem as RPCs/índices novos, preservando o diário
e as relações de request para não esquecer POSTs já enviados. A reversão da constraint
de destaque falha **antes de alterar schema** se existir benefício gratuito de valor zero.
Nesse caso, preserve o schema novo e corrija o código para frente.
Voltar o código antigo reintroduz o risco de duplicidade; não reabra o checkout sem proteção.

Referência: [retries e idempotência no Asaas](https://docs.asaas.com/docs/retries-and-idempotency).
