# Jornada de contratação

Regras do servidor para proposta → contrato → marcos → conclusão ou encerramento. Todas as
mudanças de estado passam por funções `security definer`; as tabelas não aceitam escrita direta
(ver `docs/rls.md`). Migration: `supabase/migrations/20261112213744_hiring_journey_fixes.sql`;
volta em `supabase/rollbacks/20261112213744_hiring_journey_fixes_down.sql`.

## Estados

```
proposta:  pending ──make_counter_offer──▶ counter_offered
              │  ▲                              │
              │  └────reject_counter_offer──────┤
              │                                 │
   accept_proposal (cliente)      accept_counter_offer (freelancer)
              │                     accept_proposal (cliente, valor original)
              ▼                                 ▼
           accepted  ◀──────────────────────────┘     reject_proposal ─▶ rejected

contrato:  active ──approve_milestone (último marco)──▶ completed
              └────cancel_contract (qualquer parte)───▶ cancelled

vaga:      open ─(contrato criado)─▶ in_progress ─▶ completed | cancelled
```

## Regras

| Função | Quem | Regra |
|---|---|---|
| `submit_proposal` | freelancer | Vaga `open`, não própria, carta ≥ mínimo. Trava por freelancer (`pg_advisory_xact_lock`) antes de contar as cotas diária/mensal: envios paralelos não furam o limite. Marcos opcionais: array de até 20 objetos `{title, amount, days}`, valor positivo com até 2 casas, prazo inteiro de 1 a 3650 dias, soma igual ao valor da proposta; senão `INVALID_MILESTONES`. Editar só com a proposta `pending`; com contraproposta aberta, `COUNTER_OFFER_PENDING` (responder antes). |
| `accept_proposal(p_proposal_id, p_expected_amount)` | cliente dono | Proposta `pending` ou `counter_offered`, travada. Se `p_expected_amount` (valor que o cliente viu) diferir do atual, `PROPOSAL_CHANGED`. Com contraproposta do cliente, contrata pelo valor original e registra no chat que a contraproposta foi descartada. `p_expected_amount` nulo mantém compatibilidade com versões antigas do app. |
| `reject_proposal`, `make_counter_offer` | cliente dono | Proposta travada antes de checar o estado; a atualização só vale se continuar `pending`/`counter_offered` (não sobrescreve aceite concorrente). |
| `accept_counter_offer` | freelancer | Valor e prazo passam a ser os da contraproposta. Marcos propostos são redimensionados proporcionalmente ao novo valor; o último absorve o arredondamento. |
| `approve_milestone`, `request_revision` | cliente | Contrato travado e `active` (`CONTRACT_NOT_ACTIVE` caso contrário); marco em `submitted`. O último marco aprovado conclui contrato e vaga e avisa **as duas partes** para avaliar. |
| `cancel_contract(p_contract_id, p_reason)` | cliente ou freelancer | Contrato `active`, travado. Motivo de 10 a 500 caracteres (`CANCEL_REASON_REQUIRED`). Grava `cancelled_at`, `cancelled_by`, `cancel_reason`; vaga vai para `cancelled`; mensagem de sistema no chat e notificação à outra parte. Sem custódia de valores, não há reembolso a tratar. |

Efeitos a conhecer:

- Contrato encerrado não aceita entregas, revisões, aprovações nem avaliações (avaliação exige
  `completed`).
- Vaga cancelada devolve ao saldo do mês as propostas enviadas a ela (`counted_proposals`), inclusive a
  do freelancer contratado.
- Encerrar o contrato libera a exclusão de conta, que recusa contratos `active`.

## Erros novos

| Código | Mensagem no app (`core/errors/error_catalog.dart`) |
|---|---|
| `PROPOSAL_CHANGED` | O freelancer alterou esta proposta. Confira o novo valor antes de contratar. |
| `COUNTER_OFFER_PENDING` | Há uma contraproposta aguardando resposta. Aceite ou recuse antes de alterar. |
| `INVALID_MILESTONES` | Marcos precisam de título, valor e prazo válidos e somar o total. |
| `CONTRACT_NOT_FOUND` | Contrato não encontrado. |
| `CANCEL_REASON_REQUIRED` | Explique o motivo do encerramento (de 10 a 500 caracteres). |

## Testes

`supabase/tests/hiring/` roda no CI com `deno task test:webhook` contra PostgreSQL 17 descartável.
As corridas usam duas transações reais: a primeira mantém os locks até a segunda começar. Cobre os
cenários acima, regressões (contratação dupla, vaga própria, vaga fechada), rollback limpo e o
bloqueio do rollback quando já há contratos encerrados.

## Publicação

1. Aplicar a migration no Supabase **antes** (feito em 12/11/2026, versão `20261112213744`) de publicar o app novo: o app passa a enviar
   `p_expected_amount` e a chamar `cancel_contract`. Apps antigos continuam funcionando com a
   migration aplicada.
2. Rollback só antes de existir contrato encerrado pela função nova; depois disso ele recusa com
   `CANCELLED_CONTRACTS_PRESENT` para não apagar os motivos.
