# Webhook Asaas: processamento e recuperação

O endpoint autentica o token Asaas e chama `receive_asaas_billing_event`.
O banco conserva a inbox e aplica os efeitos em transação. Não há chamadas
ao Asaas dentro dessa transação; as notificações usam o mecanismo já existente.

## Garantias

O estorno total de destaque avulso também é transacional e retira somente o
período não consumido daquela compra, preservando outros pagamentos e cupons.
Veja [estornos-destaque.md](estornos-destaque.md) para prazos, legado e rollback.

- A PK de `billing_events` impede processar o mesmo evento duas vezes.
- `billing_payment_receipts.payment_id` impede que CONFIRMED e RECEIVED do mesmo
  pagamento renovem/notifiquem a assinatura duas vezes.
- Travas no evento, assinatura/destaque e vaga serializam requisições concorrentes.
  Compras diferentes da mesma vaga somam seus dias sem perder atualizações.
- Benefício, recibo, status da cobrança e notificação confirmam juntos. Se qualquer
  escrita falhar, todos esses efeitos são desfeitos e o evento fica `failed`.
- Se faltar assinatura/destaque local, o evento fica `pending`, sem `processed_at`.
  O INSERT do vínculo retoma os eventos automaticamente; o reenvio do Asaas também
  tenta processá-los novamente. Não é necessário esperar outro pagamento.
- Se uma conexão cair antes do commit, o Asaas recebe falha e pode reenviar;
  se cair depois do commit, o reenvio encontra o resultado já concluído.

`legacy` identifica eventos do processador anterior. O upgrade não reaplica seu
payload: isso poderia conceder benefícios outra vez. Recibos são preenchidos a
partir de destaques já pagos e assinaturas com período já registrado. Qualquer
suspeita no histórico legado exige reconciliação com o provedor antes de reparar.

## Respostas HTTP

| Resposta | Significado |
|---|---|
| 200 | Processado, duplicado já concluído ou evento explicitamente ignorado |
| 400 | Corpo/id de evento inválido |
| 401 | Token ausente ou inválido |
| 405 | Método diferente de POST/OPTIONS |
| 503 | Evento conservado, mas sem vínculo local ou com processamento falho |
| 500 | Falha de infraestrutura/RPC; a confirmação não é enviada |

O Asaas só confirma entrega com 200. Reenvios têm limite: acompanhar falhas e
reativar a fila no painel se ela for interrompida. Um evento persistido não deve
ser apagado para forçar nova tentativa.

## Inspeção e reparo operacional

Somente operador do banco/service_role executa as RPCs. Nunca disponibilizar essas
operações no app nem usar uma chave privilegiada em cliente público.

```sql
select id, event, received_at, processing_status, attempts, last_error_code
from public.billing_events
where processing_status in ('pending', 'failed')
order by received_at;

-- Depois de corrigir a causa (ou confirmar que o vínculo agora existe):
select public.process_asaas_billing_event('<id-do-evento>');
```

`last_error_code` contém SQLSTATE ou MISSING_BILLING_REFERENCE, sem payload/dados
pessoais. A consulta deve terminar em `processed`/`ignored`; erro continua
registrado e pode ser tentado outra vez. Não editar status/recibos à mão.

## Publicação e rollback

1. Suspender temporariamente a fila do webhook no painel Asaas e aguardar
   requisições antigas em andamento terminarem. Evitar misturar os dois processadores.
2. Conferir versões e aplicar as migrations `asaas_webhook_receipts` e
   `asaas_webhook_processing`, nessa ordem. Elas não alteram preços nem benefícios.
3. Publicar `asaas-webhook` incluindo `index.ts`, `handler.ts` e
   `../_shared/common.ts`, mantendo `verify_jwt=false` e o token existente.
4. Reativar a fila; conferir eventos/recibos e que reenvio de um pagamento
   confirmado não muda o benefício nem gera outra notificação.

Alternativa quando o painel Asaas não estiver disponível: publicar temporariamente
um handler que só responde HTTP 503 com `Retry-After`, sem ler/processar o payload,
e confirmar a resposta antes de alterar o banco. Aguardar o limite de duração das
instâncias antigas do plano vigente (150 s no Free) e conferir ausência de queries
do webhook; então aplicar as migrations e publicar o handler definitivo. O Asaas
mantém as entregas sujeitas a reenvio. Essa janela deve ser curta; não confundir
manutenção do endpoint com desativação ou reativação da fila no painel.

### Publicação de 29/10/2026

- Migrations registradas em produção: `20261029154221_asaas_webhook_receipts` e
  `20261029154230_asaas_webhook_processing`.
- `asaas-webhook` v10 ativo, com código conferido contra esta versão do repositório.
- A janela usou handler temporário 503 (v9), encerrado às 12:42 no horário de São
  Paulo. O painel Asaas não foi alterado.
- Verificados: GET 405, POST sem token 401, OPTIONS 200; replay de evento legado
  retornando `duplicate=true`, sem reaplicar benefício.
- Os 14 eventos antigos foram preservados e 3 recibos históricos preenchidos;
  nenhum evento pending/failed na conferência. Planos, assinaturas e destaques
  mantiveram os mesmos hashes antes/depois. Nenhuma cobrança real foi criada.

Os dois rollbacks foram preparados para teste em banco descartável. Antes de
tráfego novo, ambos podem desfazer o schema na ordem inversa. Depois de receber
eventos novos, o rollback de schema **recusa apagar** inbox/recibos: usar apenas
o rollback operacional de `asaas_webhook_processing`, preservando os registros,
e coordenar a versão da função com a fila suspensa. Não executar o SQL completo
de testes contra produção.

## Testes

Requer Deno 2.9.6 e PostgreSQL 17 descartável em localhost, banco com sufixo
`_test`, sem schemas/tabelas preexistentes. O teste cria estruturas mínimas de
Auth/Storage e usa as migrations reais de schema/planos/cupons; não instala
pg_net nem dispara e-mails, push ou cobranças. O cliente SQL só é dependência
de teste, sem pacote novo no app.

```sh
cd supabase
# Configure TEST_DATABASE_URL para o banco local descartável.
deno task test:webhook
```

O CI sobe seu próprio PostgreSQL. São exercitados reenvio, eventos distintos do
mesmo pagamento, chamadas concorrentes, compras da mesma vaga, vínculo tardio,
falha em cada escrita crítica, interrupção da transação, histórico legado,
permissões e aplicação/rollback das migrations.

As correções posteriores de checkout estão em [checkout-asaas.md](checkout-asaas.md).
Estorno total de destaque: [estornos-destaque.md](estornos-destaque.md).
Chargebacks, recuperação de disputa e estornos de períodos da assinatura:
[reversoes-cobranca.md](reversoes-cobranca.md).
