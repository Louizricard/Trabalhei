# Segurança

Antes de considerar pronta qualquer feature que toque dado sensível, verificar:

- **Autenticação**: toda rota que exige usuário logado de fato valida a sessão/token antes de responder.
- **Autorização**: além de "está logado", checar se o usuário logado tem permissão sobre aquele recurso específico (ex.: só o cliente dono da vaga pode aceitar/rejeitar proposta nela; só as duas partes de um contrato acessam aquele chat).
- **Validação de inputs**: todo dado vindo de formulário ou API é validado (tipo, formato, limites) antes de ser usado ou persistido — nunca confiar em validação feita só no client.
- **Sanitização**: dados exibidos de volta na UI (ex.: mensagens de chat, descrição de vaga) são tratados para não permitir injeção de conteúdo malicioso.
- **Upload seguro**: arquivos enviados (anexos de chat, avatar, briefing) têm tipo e tamanho restritos e são verificados antes de ficarem acessíveis por link.
- **Rate limiting**: aplicar em endpoints sensíveis a abuso (login, envio de proposta, envio de mensagem) quando o backend suportar.
- **Proteção contra SQL Injection**: qualquer consulta customizada (fora do client padrão do Supabase) usa parâmetros/prepared statements, nunca concatenação de string.
- **Proteção contra XSS na versão Web**: nenhum conteúdo vindo do usuário é renderizado como HTML bruto sem escape.
- Nunca logar dado sensível (senha, token, dado de pagamento) em texto plano, nem em desenvolvimento.
