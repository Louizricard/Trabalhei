# Denúncia e bloqueio no chat

Exigência da política de conteúdo gerado por usuários do Google Play: quem conversa precisa poder
denunciar conteúdo e bloquear outra pessoa dentro do app. Migration:
`supabase/migrations/20261120172423_chat_safety.sql` (volta em `supabase/rollbacks/`).

## No app

| Onde | Ação |
|---|---|
| Menu ⋮ da conversa | **Denunciar perfil** (mesma denúncia da tela de perfil) e **Bloquear/Desbloquear** |
| Toque longo numa mensagem da outra pessoa | **Denunciar mensagem** (motivo + detalhes opcionais) |
| Conversa com alguém que você bloqueou | O campo de mensagem vira o aviso "Você bloqueou …" com **Desbloquear** |

Código: `freelanceflow/lib/features/chat/presentation/widgets/chat_safety.dart`; testes em
`freelanceflow/test/features/chat/chat_safety_test.dart`.

## Regras do servidor

- **Bloqueio** (`block_user`, `unblock_user`, tabela `user_blocks`): vale nos dois sentidos. Recusa
  mensagens de pessoa (texto e anexos) com `USER_BLOCKED` (gatilho `messages_block_guard`) e a
  abertura de conversa nova (`get_or_create_conversation`). Mensagens de sistema do contrato
  continuam, para o contrato poder ser concluído ou encerrado. Só quem bloqueou vê o bloqueio; a outra
  pessoa não é avisada e, ao tentar enviar, recebe "Não é possível conversar com esta pessoa".
- **Denúncia de mensagem** (`report_message`): só participante da conversa denuncia mensagem da
  outra parte. O conteúdo, o remetente e o horário são copiados para `reports.evidence`; a moderação
  vê apenas a mensagem denunciada, não a conversa inteira. Uma denúncia aberta por pessoa e mensagem.
  Inserir denúncia de mensagem direto na tabela é bloqueado pela RLS.
- **Moderação** (Perfil › Moderação): denúncia de mensagem aparece como "Mensagem: Nome: "trecho"".
  O alvo das ações é quem enviou a mensagem (ver perfil, suspender conta). Resolver/descartar como as
  demais denúncias.

## Não coberto

- Bloquear não impede propostas nem contratação entre as mesmas pessoas fora do chat; o cliente pode
  simplesmente recusar a proposta. Se virar abuso, a moderação suspende a conta.
- Sem filtro automático de palavras; tudo depende de denúncia.
