# Monetização: planos, limites, destaque e cupons

Promessa: encontrar profissionais e conduzir o trabalho em um só lugar, com pagamento direto entre
as partes (sem comissão e sem custódia). A plataforma ganha com o Pro e o destaque, que são
opcionais. Este documento é a referência para mudar preços, limites e regras sem caçar valores no
código.

## Modalidades

| Modalidade | Preço | O que inclui |
|---|---|---|
| Cliente | Grátis | Publicar projetos, receber propostas, conversar, acompanhar entregas e avaliar |
| Freelancer grátis | Grátis | Perfil, portfólio, `free_monthly_proposals` propostas/mês, chat e entregas, arquivos até `free_file_mb` |
| Freelancer Pro | `billing_products.pro_monthly` (R$ 14,90/mês) | `pro_monthly_proposals` propostas/mês, modelos de proposta, clientes e projetos, estatísticas das propostas, arquivos até `pro_file_mb` |
| Destaque de projeto | `billing_products.job_feature` (R$ 9,90 por 7 dias) | Espaço identificado como **Patrocinado** no topo do mural, em rodízio |

## Onde ficam os valores

Tudo no banco, lido pelo app (`pricingProvider`) e pelas Edge Functions. Mudar um valor vale na
hora, sem publicar app nem função.

- **`public.billing_products`**: preço e duração de cada produto (`pro_monthly`, `job_feature`).
- **`public.platform_settings`** (uma linha): limites.

| Coluna | Padrão | Efeito |
|---|---|---|
| `free_monthly_proposals` | 10 | Propostas novas por mês no grátis |
| `pro_monthly_proposals` | 50 | Propostas novas por mês no Pro (não é ilimitado de propósito) |
| `daily_proposals` | 15 | Teto a cada 24 h para **todos** os planos (freia envio em massa) |
| `min_cover_letter_chars` | 50 | Tamanho mínimo da carta de apresentação |
| `unanswered_refund_days` | 14 | Proposta pendente sem resposta por esse prazo volta ao saldo |
| `sponsored_slots` | 2 | Vagas patrocinadas no topo do mural ao mesmo tempo |
| `sponsored_rotation_minutes` | 60 | Duração de cada rodada do rodízio |
| `free_file_mb` / `pro_file_mb` | 10 / 50 | Tamanho máximo por arquivo (chat, entregas, anexos de vaga) |
| `max_proposal_templates` | 20 | Modelos de proposta por pessoa |

Exemplo, Pro com 60 propostas:

```sql
update public.platform_settings set pro_monthly_proposals = 60, updated_at = now();
```

Ao mudar um preço, atualize também os textos fixos da homepage (`site/index.html`: seções "Para
quem", FAQ e JSON-LD de ofertas) e `site/llms.txt`. O app já lê os valores do banco.

Os valores padrão do app (`Pricing.fallback` em
`freelanceflow/lib/features/billing/domain/entities/pricing.dart`) só valem se a leitura do banco
falhar. Mantenha-os iguais aos da migração.

## Regras de propostas (função `submit_proposal`)

- **Saldo do mês** (`counted_proposals`): não contam propostas para vagas canceladas (pelo cliente
  ou pela moderação, `jobs.moderated_at`) nem as pendentes sem resposta há mais de
  `unanswered_refund_days`. O app mostra quantas voltaram ao saldo.
- **Teto de 24 h**: vale para todos, inclusive o Pro (`DAILY_PROPOSAL_LIMIT`).
- **Carta mínima**: `COVER_LETTER_TOO_SHORT`.
- Editar uma proposta já enviada não gasta saldo.

## Busca e destaque

- O mural ordena por **Mais relevantes** (`rankByRelevance` em
  `freelanceflow/lib/features/jobs/domain/job_ranking.dart`), que combina:
  - compatibilidade com as habilidades de quem procura;
  - qualidade da vaga: nota do cliente, descrição completa e orçamento informado;
  - data de publicação.
- Pagamento não entra na conta.
- Projetos destacados vão para o espaço **Patrocinadas** (`splitSponsored`):
  - até `sponsored_slots` vagas por vez;
  - com mais vagas, a fila anda a cada rodada (igual para todos), e todas ficam o mesmo tempo no topo;
  - fora do topo, a vaga segue na posição normal, com a etiqueta.
- A busca de freelancers usa **Mais relevantes** (`rankFreelancers`): nota ponderada pelo número de
  avaliações, trabalhos concluídos, compatibilidade com a busca e perfil completo. O Pro não tem
  prioridade.
- O selo PRO é discreto e neutro (`ProBadge`): indica a assinatura, não competência. Confiança vem
  das avaliações e dos trabalhos concluídos.

## Ferramentas Pro

| Recurso | Onde | Banco |
|---|---|---|
| Modelos de proposta | Botão "Modelos" ao enviar proposta; Painel › Ferramentas Pro | `proposal_templates` (criar/editar exige Pro na RLS) |
| Clientes e projetos | Painel › Ferramentas Pro | `freelancer_clients()` + `client_notes` (anotações privadas) |
| Estatísticas das propostas | Painel › Ferramentas Pro | `proposal_stats(dias)` |
| Arquivos maiores | Chat, entregas e anexos | `pro_file_mb` (limite verificado no app; o bucket aceita até o limite do Pro) |

Quem deixa de ser Pro continua vendo e apagando os próprios modelos e anotações, mas não cria nem
edita.

## Pagamento

- **Pix dentro do app**: a função devolve o QR Code e o código copia e cola. O app consulta o banco a
  cada 4 s, e o webhook do Asaas confirma o pagamento.
- **Cartão**: a página segura do Asaas abre no navegador do próprio app. O Trabalhei nunca recebe
  dados de cartão.
- Checkout transparente com cartão (campos de cartão no app) não foi feito de propósito: exigiria
  tratar dados de cartão e conformidade PCI.
- Edge Functions:
  - `asaas-create-subscription`: Pro;
  - `asaas-feature-job`: destaque. Uma cobrança pendente da mesma vaga (24 h, mesma forma de
    pagamento) é reaproveitada, sem cobrar duas vezes;
  - `asaas-webhook`: confirmações.

## Cupons

- Criados em **Perfil › Moderação › Cupons** (somente admin) ou por SQL
  (`admin_create_coupon`).
- Regras:
  - percentual (1 a 100%) ou valor fixo;
  - vale para `pro_monthly` (1º mês), `job_feature` ou `any`;
  - limite total de usos opcional, validade opcional e uma vez por pessoa.
- O desconto vale para a **primeira cobrança**:
  - no Pro, o 1º mês (a assinatura segue no preço cheio);
  - 100% libera sem cobrança: o Pro (`grant_pro`) ou o destaque.
- O Asaas não cobra menos de R$ 5,00. Um desconto que deixaria o valor entre zero e R$ 5,00 para em
  R$ 5,00.
- O uso é registrado na criação da cobrança (`redeem_coupon`, com trava contra limite estourado) e
  desfeito se a cobrança não chegar a ser criada (`release_coupon`). Cobrança criada e não paga
  continua contando como uso.
- Exemplo de lançamento:

```sql
-- 50% no primeiro mês do Pro, 200 usos, até 31/12/2026
select public.admin_create_coupon('LANCAMENTO50', 'pro_monthly', 50, null, 200,
  '2026-12-31 23:59:59-03', 'Promoção de lançamento');
```

(Pelo SQL Editor, `admin_create_coupon` exige sessão de admin; sem isso, insira direto em
`public.coupons`.)

## Riscos e decisões em aberto

- **10 propostas grátis por mês**: com poucas vagas, o limite quase não pesa. Com vagas fracas, a
  devolução do saldo (canceladas, removidas e sem resposta) reduz o desperdício. Acompanhe pelas
  estatísticas e ajuste `free_monthly_proposals` se necessário.
- **Limite de arquivo do grátis**: verificado no app (o bucket aceita até 50 MB). Quem usar a API
  diretamente consegue enviar até o limite do Pro. Exigir no servidor pede upload por Edge Function.
