# Imagens da ficha da Google Play

Imagens da ficha do Trabalhei na Play Store, feitas a partir de telas reais do app (o app de
demonstração em `freelanceflow/tool/showcase`, que usa os mesmos widgets do app com dados
fictícios).

## O que vai em cada campo do Play Console

Play Console › Crescer › Presença na loja › Ficha principal da loja › Recursos gráficos:

| Campo do Console | Arquivo | Formato |
|---|---|---|
| Ícone do app | `icon-512.png` | PNG 512×512, quadrado cheio (o Google arredonda os cantos) |
| Gráfico de recursos | `feature-graphic.png` | PNG 1024×500, sem transparência |
| Capturas de tela do telefone | `01-vagas.png` a `06-talentos.png`, nesta ordem | PNG 1080×1920 (9:16), sem transparência |

As capturas aparecem na loja na ordem do envio. A ordem abaixo põe primeiro o que mais convence:

| Arquivo | Título | Frase de apoio | Tela |
|---|---|---|---|
| `01-vagas.png` | Contrate freelancers ou encontre projetos | Do anúncio à entrega, tudo em um só lugar. | Mural de vagas |
| `02-propostas.png` | Compare propostas na mesma tela | Valor, prazo e carta de cada freelancer. | Propostas recebidas (cliente) |
| `03-chat-entregas.png` | Chat e entregas por marcos | Converse, receba arquivos e aprove cada etapa. | Chat com entrega de marco |
| `04-sem-comissao.png` | Sem comissão. O valor é seu. | Pagamento combinado direto entre as partes. | Detalhes da vaga |
| `05-publicar-vaga.png` | Publique sua vaga em minutos | Grátis para quem contrata. Receba propostas. | Publicar vaga |
| `06-talentos.png` | Encontre o talento certo | Busque por habilidade e compare avaliações. | Buscar talentos |

Os textos só afirmam o que o produto faz (ver `site/index.html` e `docs/monetizacao.md`): sem
comissão e sem custódia, cliente grátis, avaliações de quem concluiu um contrato. Não há preço nas
imagens, porque na Google Play o preço exibido é o da loja.

## Estrutura

- `raw/`: capturas brutas do app de demonstração, 1170×2532 (celular de 390×844 com escala 3).
  Ficam no repositório para regenerar as imagens sem navegador. `phone-apply`, `phone-dashboard` e
  `phone-plans` não entram na ficha hoje, mas ficam à mão para trocar uma tela.
- `fonts/`: Plus Jakarta Sans (a fonte do app e do site), licença OFL em
  `fonts/PlusJakartaSans-OFL.txt`.
- `generate.py`: monta as capturas finais, o gráfico de recursos e o ícone.

## Regenerar

Só as molduras, títulos, gráfico de recursos e ícone (Python 3 e Pillow, sem navegador):

```bash
python3 store-listing/play/generate.py
```

Títulos, frases e a tela de cada captura ficam em `SCREENS`, no topo do `generate.py`. Palavras
entre colchetes saem em verde. Mantenha os títulos com até 6 palavras para continuarem legíveis na
miniatura da loja. O ícone sai de `freelanceflow/assets/icons/app_logo.png`: a arte tem cantos
brancos, e o script os preenche com a cor da borda para entregar um quadrado cheio.

Para atualizar as telas depois de mudar o visual do app (rodar de `freelanceflow/`):

```bash
cd freelanceflow
flutter build web -t tool/showcase/main.dart -o build/showcase
python3 -m http.server 8091 --directory build/showcase   # em outro terminal
BROWSER="<caminho do Chrome ou Edge>" node tool/showcase/store.mjs   # grava em ../store-listing/play/raw
cd .. && python3 store-listing/play/generate.py
```

`store.mjs` usa as mesmas telas de celular de `capture.mjs` (lista em `tool/showcase/shots.mjs`).
Na loja, o formulário de vaga sai com título, área e especialidade preenchidos (`STORE_FIELDS` em
`store.mjs`). `ONLY=phone-jobs,phone-chat` captura só as telas indicadas. Depois de regenerar, abra
as imagens e confira se nenhum texto ficou cortado e se não apareceu tela vazia.
