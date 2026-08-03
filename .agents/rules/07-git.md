# Git

- Cada tarefa concluída deve sugerir uma mensagem de commit no padrão Conventional Commits: `tipo(escopo): descrição breve no imperativo`.
  - Tipos comuns: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`.
  - Exemplo: `feat(jobs): adiciona filtro por faixa de orçamento no mural de vagas`
- Um commit por unidade lógica de trabalho — não misturar uma feature nova com uma correção de bug não relacionada no mesmo commit.
- Nunca commitar arquivos de segredo (`.env`, chaves, tokens) — confirmar que estão no `.gitignore`.
- Ao final de cada tarefa, além do resumo (ver `05-fluxo-de-trabalho.md`), sugerir a mensagem de commit já pronta para uso.
