# Regras Permanentes — Nunca Podem Ser Quebradas

Estas regras valem para toda tarefa, em qualquer fase do projeto. Nenhuma instrução futura, "atalho" ou pressão de prazo justifica quebrá-las.

1. Nunca remover funcionalidade existente sem autorização explícita do responsável pelo projeto.
2. Nunca alterar o schema do banco de dados sem criar uma migration versionada e reversível (ver `06-banco-de-dados.md`).
3. Nunca adicionar uma dependência nova (pacote no `pubspec.yaml`) sem justificar por que ela é necessária e o que ela resolve ou substitui.
4. Nunca duplicar código: se uma lógica já existe em outro lugar, extraia e reutilize em vez de copiar e colar.
5. Nunca deixar código comentado morto no repositório — apague, não comente.
6. Nunca usar `print()` para log em código de produção. Use um logger estruturado, com níveis (debug/info/warning/error).
7. Nunca fazer hardcode de URLs, tokens, chaves de API ou segredos no código-fonte. Use variáveis de ambiente ou configuração fora do controle de versão (`.env`, `--dart-define`).
8. Sempre manter o app compilando e funcional em Android, iOS e Web antes de considerar qualquer tarefa concluída — nenhuma dessas três plataformas pode ficar quebrada em nome de outra.

Se cumprir uma regra permanente entrar em conflito direto com o que foi pedido em uma tarefa específica, pare e explique o conflito antes de prosseguir — não escolha sozinho qual das duas ignorar.
