# Banco de Dados

O projeto usa Postgres via Supabase. Regras obrigatórias:

- Nunca apagar tabelas automaticamente.
- Nunca fazer uma alteração que possa causar perda de dados existentes sem confirmação explícita e um plano de rollback testado antes de rodar.
- Toda alteração de schema é uma migration versionada e reversível (ida e volta), nunca uma alteração manual direta no banco.
- Usar chaves estrangeiras para relações entre tabelas (ex.: `proposals.job_id` → `jobs.id`), nunca IDs soltos sem constraint.
- Criar índices em colunas usadas com frequência em filtros e joins (ex.: `jobs.status`, `proposals.job_id`, `messages.conversation_id`).
- Toda política de RLS (Row Level Security) do Supabase precisa estar documentada: o que ela permite, para qual papel de usuário, e por quê — em comentário na própria migration ou em `docs/rls.md`.
- Antes de rodar qualquer migration em produção, confirmar que existe uma migration de rollback testada.
