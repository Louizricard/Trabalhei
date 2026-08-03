# Arquitetura Obrigatória

Esta arquitetura é fixa para o projeto inteiro. Não proponha nem migre para outra abordagem no meio do desenvolvimento — se algo parecer não caber bem, pare e explique o problema em vez de substituir a arquitetura por conta própria.

## Gerenciamento de estado

Riverpod (`flutter_riverpod` + `riverpod_generator` + `riverpod_annotation`). Toda lógica de apresentação (loading, erro, dados) passa por um `Notifier`/`AsyncNotifier` exposto via provider gerado com `@riverpod`. Não usar `setState` para estado que atravessa mais de um widget.

## Padrão arquitetural

Clean Architecture em três camadas, repetida dentro de cada feature:

- `domain/` — entidades (classes Dart puras, sem Flutter nem Supabase), contratos de repositório (interfaces abstratas), e casos de uso quando a lógica for mais complexa que um repositório simples.
- `data/` — implementação dos repositórios, data sources (remoto via Supabase, local se houver cache), e modelos de dados (DTOs) com conversão de/para entidade.
- `presentation/` — telas, widgets e providers/controllers Riverpod.

A camada `domain` nunca importa Flutter nem Supabase diretamente — é isso que garante que a regra de negócio seja testável sem precisar subir o app.

## Navegação

`go_router`. Rotas nomeadas e declarativas, espelhando as rotas já definidas na especificação de produto: `/jobs`, `/jobs/create`, `/jobs/:id`, `/jobs/:id/apply`, `/chat`, `/dashboard/client`, `/dashboard/freelancer`, `/profile`, `/payments`, `/settings`. Suporte a deep link é obrigatório, já que a versão Web precisa de URLs reais e navegáveis.

## Injeção de dependência

Feita pelos próprios providers do Riverpod. Não introduzir `get_it`, `injectable` ou outro service locator em paralelo — isso cria dois grafos de dependência concorrentes.

## Estrutura de pastas (feature-first)

```
lib/
  core/
    config/          # variáveis de ambiente, constantes
    router/           # configuração do go_router
    theme/
    errors/           # exceptions e failures compartilhados
    widgets/          # widgets reutilizáveis genéricos
  features/
    auth/
      data/
      domain/
      presentation/
    jobs/
      data/
      domain/
      presentation/
    proposals/
    chat/
    dashboard/
    profile/
    payments/
  main.dart
```

Toda feature nova segue essa mesma subdivisão (`data/domain/presentation`) dentro de `features/<nome_da_feature>/`. Não criar pastas soltas fora desse padrão.
