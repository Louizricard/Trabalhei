# Exclusão de conta

`delete-account` autentica o JWT e sempre usa o ID da sessão. O corpo enviado
por um usuário comum não escolhe outra conta. Somente o operador com
`service_role`, exclusivamente no servidor, pode enviar `{"user_id":"<uuid>"}`
para retomar um pedido depois que o Auth já tiver sido removido.

## Dados e arquivos

Contrato ativo impede o início, antes de alterar o perfil. Um checkout em
andamento ou POST financeiro inconclusivo também exige conclusão/conciliação.
Sem histórico contratual, a remoção do Auth é definitiva e as FKs limpam os
dados vinculados. Com histórico, o Auth é excluído com `should_soft_delete=true`:
o Supabase remove credenciais, metadados e sessões, preservando o ID usado nas FKs.

Em ambos os casos, o perfil é fechado para escrita e anonimizado antes das
operações externas. São limpos nome, avatar, empresa, bio, habilidades, preço,
disponibilidade, verificação, plano, validade, título, cidade, site, LinkedIn,
GitHub e currículo. Contadores e histórico contratual permanecem no tombstone.
Preferências de notificação, push, alertas, modelos de proposta, notas privadas
criadas pelo freelancer, portfólio, notificações, vínculo local de cobrança e
privilégios administrativos são removidos. A assinatura aberta é cancelada no Asaas.

O manifesto considera `owner`, `owner_id` e o prefixo `<user_id>/`, incluindo
pastas aninhadas e objetos sem owner. Os arquivos são removidos fisicamente
pela API de Storage, em lotes de até 100, sempre reconsultando o primeiro lote.
Nunca se usa SQL DELETE em `storage.objects` em produção.

- `resumes`, `avatars` e `portfolio` são limpos também quando há contratos.
- Sem contratos, todos os buckets com objetos vinculados são limpos.
- Com contratos, mantém-se a política anterior de retenção dos buckets
  `job_attachments`, `job_covers` e `chat_attachments`. A propriedade desses
  arquivos é desvinculada do Auth; as policies de conversa/contrato continuam
  determinando o acesso. Essa retenção abrange os anexos desses buckets, mesmo
  quando não existe uma referência individual a cada objeto no contrato.

Texto livre e anexos retidos em contratos, mensagens e registros financeiros
não são reescritos por esta rotina. Registros do provedor de pagamento e logs
de auditoria do Auth seguem as respectivas políticas de retenção.

## Falhas e retomada

`account_deletion_requests` é privada do servidor. A lease de 120 segundos
impede dois workers simultâneos; cada consulta do manifesto renova a lease.
Uma falha em cobrança, listagem, remoção, SQL, Auth ou conclusão retorna 503 e
registra somente o código da etapa. A conta continua fechada, com perfil
anonimizado; não há retorno de sucesso com currículo pendente.

O usuário pode repetir a exclusão enquanto o Auth ainda existe. Se o Auth já
foi removido e houve falha ao confirmar a conclusão, o suporte retoma o mesmo
endpoint com credencial de servidor. Em caso de timeout sem liberação da lease,
aguardar 120 segundos antes de retomar. Para localizar pedidos pendentes:

```sql
select user_id,phase,last_error_code,lease_until,updated_at
from public.account_deletion_requests where phase<>'completed';
```

Não reabrir o perfil nem restaurar seus dados pessoais para repetir a operação.
Não remover a linha de controle. Um pedido concluído é idempotente; na remoção
definitiva, a FK apaga a linha junto com o Auth.

## Proteções e publicação

As migrations `account_deletion_state`, `account_deletion_cleanup`,
`account_deletion_access` e `account_deletion_storage` têm rollbacks testados.
O rollback recusa execução depois de um pedido real, pois reabrir acesso a uma
conta fechada seria inseguro. Dados pessoais já apagados não são restaurados.

RLS restritiva e triggers impedem escrita com JWT antigo, inclusive dentro das
RPCs SECURITY DEFINER. Perfis removidos só são lidos pelo próprio usuário para
retomada e pela contraparte contratual. O schema `account_private` não é exposto
na Data API. Checkout e cancelamento também verificam o estado atual do perfil.
Novas tabelas e campos pessoais devem estender a limpeza e essas proteções.

Antes da publicação: salvar as funções atuais; colocar `delete-account`,
`asaas-create-subscription`, `asaas-feature-job` e `asaas-cancel-subscription`
em manutenção 503; drenar requisições antigas por pelo menos 170 segundos;
conferir operações ativas; aplicar as quatro migrations na ordem; publicar
essas quatro funções com o novo `_shared/common.ts`, mantendo JWT obrigatório.
Em falha anterior à aplicação, restaurar as funções salvas.

Validação local: `deno task test:webhook`, PostgreSQL 17 descartável. São 80
cenários SQL e 13 testes HTTP/adapter, incluindo rollback, 205 arquivos,
contratos, falhas em todas as etapas, lease, upload concorrente, checkout
concorrente, isolamento de contas e JWT antigo. A API Auth/Storage é simulada
nos testes de falhas; as RPCs e policies usam PostgreSQL real. Não se exclui
conta real em produção como teste.

Referências: [Auth e dados do usuário](https://supabase.com/docs/guides/auth/managing-user-data),
[Admin deleteUser](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser),
[implementação da exclusão e repetição no Auth](https://github.com/supabase/auth/blob/master/internal/api/admin.go).

## Publicação verificada em 29/10/2026 (BRT)

[PR #24](https://github.com/Louizricard/Trabalhei/pull/24) mergeada após CI de
banco, análise estática, testes Flutter, APK debug e preview Web aprovados.
Versões registradas no projeto `wmfsjitjqltzbbgynwfb`:

| Migration | Versão UTC |
| --- | --- |
| account_deletion_state | 20261029213257 |
| account_deletion_cleanup | 20261030020108 |
| account_deletion_access | 20261030020119 |
| account_deletion_storage | 20261030020131 |

Funções ACTIVE e com `verify_jwt=true`: `delete-account` v10,
`asaas-create-subscription` v18, `asaas-feature-job` v18 e
`asaas-cancel-subscription` v11. Os arquivos publicados e os corpos das 12
funções SQL coincidem com os fontes testados.

A publicação foi retomada após falha de autenticação da integração: a primeira
migration já estava aplicada; as funções anteriores foram restauradas antes da
reconexão. Depois, houve nova manutenção, drenagem e aplicação das três restantes.
Nenhum endpoint ficou em manutenção ao final.

Verificados em produção: HTTP 401 sem sessão, OPTIONS 200, métodos bloqueados,
permissões privadas, 33 triggers de conta ativa, 32 policies restritivas e dois
guards de ciclo de vida. Uma sessão simulada por SQL manteve leitura do próprio
perfil ativo e continuou sem acesso às RPCs de exclusão. Os hashes de perfis e
estado financeiro ficaram inalterados durante a publicação. Não havia perfis
excluídos, pedidos de exclusão nem currículos a sanear; nenhuma conta real foi
apagada para testar. A suíte local foi repetida com os nomes remotos das migrations:
80 cenários SQL e 13 testes HTTP/adapter aprovados.
