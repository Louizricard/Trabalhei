# Estorno total de destaque

O webhook correlaciona `PAYMENT_REFUNDED` ao `payment.id` de `job_featurings`,
mesmo sem `payment.subscription` ou `externalReference`. O efeito é transacional
com o recibo, o status da compra e a notificação; qualquer falha preserva a inbox
para reenvio, sem retirada parcial.

## Regra de prazo

Cada recibo de destaque registra `feature_starts_at`, `expires_at` corrente e
`feature_original_expires_at` imutável. Uma compra acrescenta `days` ao fim do
período que já existe. O estorno retira somente a parte **ainda não consumida**
do intervalo daquela compra. Os recibos posteriores são antecipados pela mesma
quantidade, mantendo suas durações. O prazo de cupons gratuitos é preservado.

Exemplo: restam 4 dias da compra A, seguidos por 7 dias da compra B. Estornar A
deixa os 7 dias de B. Estornar um período já vencido não reduz B.

`revoked_at`, `revocation_event_id` e `revoked_seconds` preservam a trilha da retirada.
Reenvios do estorno são inofensivos. Uma confirmação tardia do mesmo pagamento
não concede novamente o benefício. Se o estorno vier antes do vínculo local,
permanece pendente; o INSERT do checkout o retoma. Se vier antes da confirmação,
um recibo de bloqueio impede uma concessão posterior.

`PAYMENT_PARTIALLY_REFUNDED`, `PAYMENT_REFUND_IN_PROGRESS` e `PAYMENT_REFUND_DENIED`
não retiram o destaque inteiro. Esta correção usa o evento de estorno total, sem
transformar reembolso parcial em perda de todo o produto. Os estornos de assinatura
e o fluxo de disputa/chargeback mantêm suas regras anteriores e exigem análise própria.

Eventos de estorno sem `payment.id` são recusados com 400 antes da persistência.
Sem vínculo local, o webhook pede reenvio com 503. Uma referência externa de outro
produto, sem vínculo de destaque, é ignorada. Nenhuma decisão de estorno depende
apenas do array `refunds`, que também pode conter devoluções pendentes ou negadas.

## Histórico e permissões

A migration preenche apenas metadados dos recibos existentes e não muda prazos,
status de compras nem planos. O seed legado copiava o prazo agregado da vaga;
havendo vários períodos pagos ativos num recibo legado, a migration recusa avançar
com `RECONCILE_LEGACY_FEATURE_PERIODS`. Não estima a participação de cada compra.
Esse histórico precisa ser conciliado com o provedor antes de preparar um reparo.

Recibos continuam privados, protegidos por RLS. Os auxiliares em `billing_private`
não são executáveis por `anon`, `authenticated` nem `service_role`; só a RPC do
webhook, restrita ao servidor, os aciona com privilégios de seu proprietário.

Estornos anteriormente marcados `ignored`/`legacy` não são reaplicados automaticamente.
Confira se há algum antes da publicação e prepare um reparo auditado se necessário.
Não apague recibos nem force o replay de confirmações antigas.

## Publicação e rollback

1. Executar os testes locais e CI. Conferir histórico, recibos legados e eventos de estorno.
2. Colocar webhook e endpoints de criação em manutenção 503 e drenar workers antigos
   por pelo menos 170 segundos, sem alterar as configurações da fila no Asaas.
3. Aplicar, na ordem, `feature_refund_receipts`, `feature_refund_processing` e
   `feature_refund_routing`. Alinhar os timestamps locais ao histórico remoto.
4. Publicar o webhook incluindo `handler.ts`, com o token existente e `verify_jwt=false`.
   Restaurar os endpoints de criação com o código atual e `verify_jwt=true`.
5. Comparar fontes, permissões e estado financeiro; verificar HTTP e a retomada da inbox.
   Não é necessário emitir um estorno ou cobrança real para esses testes.

Os rollbacks ficam em `supabase/rollbacks/` e são executados na ordem inversa,
apenas com tráfego suspenso. Sem revogações, são reversíveis e reaplicáveis.
Após qualquer estorno tratado, recusam remover o histórico com
`FEATURE_REFUND_DATA_PRESENT`; nesse caso preserve os dados e corrija para frente.
Reabrir o código antigo deixaria futuros estornos sem tratamento.

## Verificação

`deno task test:webhook` também executa `supabase/tests/refunds/`, usando somente
PostgreSQL local descartável. Os cenários cobrem outros períodos pagos, consumo
parcial do prazo, cupons, eventos fora de ordem, concorrência, falhas em cada gravação,
permissões, legado ambíguo e rollbacks. Não acessam a API Asaas.

Referências: [eventos de pagamento](https://docs.asaas.com/docs/payment-events) e
[campos e estados de estornos](https://docs.asaas.com/docs/estornos).
