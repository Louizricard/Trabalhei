# Banco de Dados

O projeto usa Postgres via Supabase. Regras obrigatórias:

- Nunca apagar tabelas automaticamente.
- Nunca fazer uma alteração que possa causar perda de dados existentes sem confirmação explícita e um plano de rollback testado antes de rodar.
- Toda alteração de schema é uma migration versionada e reversível (ida e volta), nunca uma alteração manual direta no banco. A ida fica em `supabase/migrations/<versão>_<nome>.sql`; a volta, em `supabase/rollbacks/<versão>_<nome>_down.sql`. Nunca coloque o rollback na pasta `migrations/`: o Supabase CLI aplicaria os dois arquivos.
- A versão do arquivo local precisa ser igual à registrada no projeto remoto (`supabase migration list`). Se a migration for aplicada por outro meio (painel, MCP), renomeie o arquivo com a versão que o Supabase registrou.
- Usar chaves estrangeiras para relações entre tabelas (ex.: `proposals.job_id` → `jobs.id`), nunca IDs soltos sem constraint.
- Criar índices em colunas usadas com frequência em filtros e joins (ex.: `jobs.status`, `proposals.job_id`, `messages.conversation_id`).
- Toda política de RLS (Row Level Security) do Supabase precisa estar documentada: o que ela permite, para qual papel de usuário, e por quê — em comentário na própria migration ou em `docs/rls.md`.
- Antes de rodar qualquer migration em produção, confirmar que existe uma migration de rollback testada.
