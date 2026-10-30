# Chargebacks e estornos de assinatura

## Regras

O recibo identifica pagamento, assinatura, usuário e prazo original do Pro.
As confirmações continuam usando a janela existente de 33 dias, sem somar outra
mensalidade no reenvio. O Pro é calculado pelo maior prazo entre pagamentos
válidos e concessões gratuitas. Cupons/admin têm registros privados separados
em `billing_pro_grants`, com o prazo que foi prometido ao concedê-los.

Estorno total revoga apenas o recibo correspondente. Outra cobrança válida,
outra assinatura e concessões gratuitas continuam valendo. Uma fatura estornada
não cancela a recorrência no Asaas: só o evento real de cancelamento/inativação
altera esse status. Uma confirmação tardia também não reabre uma assinatura
cancelada. O cancelamento voluntário continua preservando o período já pago.

| Evento | Efeito no pagamento |
| --- | --- |
| PAYMENT_CHARGEBACK_REQUESTED | Suspende o benefício correspondente |
| PAYMENT_CHARGEBACK_DISPUTE | Mantém a suspensão, sem descontar duas vezes |
| PAYMENT_AWAITING_CHARGEBACK_REVERSAL | Mantém suspenso até confirmação do repasse |
| PAYMENT_CONFIRMED / PAYMENT_RECEIVED após vitória | Restaura o saldo válido uma vez |
| PAYMENT_REFUNDED total | Revogação definitiva; não restaura com confirmação atrasada |
| Estorno parcial, pendente ou negado | Não retira o benefício inteiro |

O estado `REVERSED` do objeto `chargeback`, ou `DONE` acompanhado do status
financeiro confirmado/recebido, permite identificar a recuperação. Sem esse
indicador, uma confirmação precisa ter `dateCreated` posterior ao evento de
espera pelo repasse. Confirmações antigas não liberam uma cobrança em disputa.
Uma confirmação ambígua e estados desconhecidos ficam pendentes para conciliação,
com HTTP 503 e alerta, sem concessão silenciosa. O payload original fica na inbox.

Na assinatura, a restauração conserva a data original: um período vencido não
ganha outros 33 dias. No destaque, recupera-se no máximo o saldo retirado que
ainda não venceu, acrescentado após outros destaques válidos. O período de
outras compras não é perdido. Se a disputa antecedeu qualquer concessão local,
o primeiro repasse confirmado concede o período uma vez.

Os estados por recibo são `none`, `held`, `awaiting`, `restored` e `refunded`.
Eventos antigos não rebaixam um estado mais recente. Estorno definitivo é
terminal. Nenhum desses eventos inicia cobrança, estorno ou disputa no Asaas.

## Histórico e privacidade

A migração vincula recibos Pro antigos pelo evento original. A janela individual
é limitada a `applied_at + 33 days`, evitando copiar o fim agregado da assinatura
para todas as faturas antigas. Prazos atuais dos perfis não são alterados na
migração. Concessões que excedam os recibos conhecidos são preservadas como
legado. Um recibo ativo sem referência verificável bloqueia a migração para
conciliação; ela não adivinha quem é o dono.

Recibos e concessões são privados do servidor, com RLS e acesso negado a
`anon`/`authenticated`. Auxiliares em `billing_private` negam execução direta
inclusive a `service_role`; entram apenas pelas RPCs autorizadas. Não se grava
cartão, CPF ou e-mail nas novas estruturas. A limpeza definitiva do perfil
apaga concessões por FK e desvincula os recibos. Contas em exclusão não recebem
Pro novamente por um webhook atrasado.

## Testes e operação

`deno task test:webhook` usa PostgreSQL 17 local descartável, sem Asaas,
pg_net, e-mail ou push. Cobre 124 cenários SQL e 13 testes HTTP/adapter,
incluindo os fluxos anteriores. Há falhas injetadas em recibos, planos,
assinaturas, vagas, compras e notificações, tanto ao suspender quanto ao restaurar.
Também cobre concorrência, eventos fora de ordem, vínculo tardio, legado,
permissões e rollback. Uma falha ao retomar estorno pendente também desfaz a
confirmação que criou o vínculo, sem conceder benefício intermediário.
Nenhum pagamento real é criado para testar.

Antes de publicar: salvar as funções e o estado financeiro, conferir os advisors
e os vínculos legados; passar pelo CI; colocar webhook, checkout, cancelamento e
exclusão em manutenção 503 e drenar workers por pelo menos 170 segundos. Aplicar:

1. `billing_reversal_ledger`;
2. `billing_subscription_credits`;
3. `billing_feature_reversals`;
4. `billing_reversal_state`;
5. `billing_reversal_routing`.

Publicar o webhook com o token atual e `verify_jwt=false`; os demais endpoints
continuam com JWT obrigatório. Conferir também no Asaas os três eventos de
chargeback, confirmações/recebimentos, estorno, atraso e cancelamento de assinatura.
Se faltar algum, adicionar ao mesmo webhook, preservando token, URL e demais
eventos. Uma fila interrompida só deve ser reativada depois da correção publicada.
Não criar outro webhook, pois isso duplicaria as entregas.

Comparar fontes e funções SQL, permissões, hashes financeiros, HTTP e inbox.
Sincronizar os nomes locais ao histórico remoto. Os rollbacks são testados na
ordem inversa, com tráfego suspenso, e recusam remover registros após novas
revogações ou concessões (`BILLING_REVERSAL_DATA_PRESENT`). Depois disso, corrigir
para frente, preservando o histórico financeiro.

Referências: [eventos e fluxo de chargeback](https://docs.asaas.com/docs/webhook-para-cobrancas),
[estados da disputa](https://docs.asaas.com/docs/chargeback-en),
[estornos concluídos e parciais](https://docs.asaas.com/docs/estornos),
[atualização do webhook](https://docs.asaas.com/reference/atualizar-webhook-existente).
