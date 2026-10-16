# FreelanceFlow — Contexto do Projeto para Agentes de IA

Este arquivo é o ponto de entrada para qualquer agente de IA (Gemini 3.1 Pro no Antigravity, ou qualquer outro) trabalhando neste repositório. Leia isto e os arquivos em `.agents/rules/` **antes** de escrever qualquer código.

## O que é o FreelanceFlow

Marketplace de dois lados conectando clientes a freelancers: publicação de vagas, propostas, contratação com marcos de entrega, chat e avaliações. Sem custódia de pagamentos; monetização por assinatura Pro e destaque de vaga. App mobile-first em Flutter, rodando simultaneamente em Android, iOS e Web a partir da mesma base de código.

## Stack e decisões de arquitetura (fixas para esta fase do projeto)

| Camada | Escolha | Por quê |
|---|---|---|
| Linguagem/Framework | Flutter + Dart | Um único código-fonte pra mobile e Web |
| Gerenciamento de estado | Riverpod (`flutter_riverpod` + `riverpod_generator`) | Menos boilerplate que Bloc, integra bem com streams assíncronos (chat em tempo real), seguro em tempo de compilação |
| Arquitetura | Clean Architecture (domain / data / presentation), organizada feature-first | Isola a regra de negócio do Flutter e do backend, é testável e escala por feature |
| Navegação | `go_router` | Recomendado oficialmente pelo time do Flutter; suporta deep link e URLs reais na Web |
| Injeção de dependência | Providers do próprio Riverpod (sem `get_it` em paralelo) | Riverpod já é o grafo de DI; duplicar com outro sistema gera dois grafos concorrentes |
| Backend | Supabase (Postgres + Auth + Storage + Realtime) | Realtime resolve o chat, SDK oficial em Dart, evita construir um backend do zero |
| Cobrança | Asaas (Pix e cartão) via faturas hospedadas, Edge Functions e webhook idempotente | Assinatura Pro e destaque de vaga sem tocar em dados de cartão e sem custódia de valores |

Detalhes de cada ponto, incluindo a estrutura de pastas completa: ver `.agents/rules/02-arquitetura.md`.

## Regras de ouro (resumo — detalhes em `.agents/rules/01-regras-permanentes.md`)

Nunca remover funcionalidade sem autorização. Nunca mudar schema sem migration. Nunca fazer hardcode de chave/token/URL. Sempre manter Android, iOS e Web funcionando.

## Antes de qualquer tarefa

Leia, nesta ordem: `01-regras-permanentes.md`, `02-arquitetura.md`, e o arquivo de regra específico do tipo de tarefa em questão (banco de dados, git, segurança, performance, etc.) dentro de `.agents/rules/`.
