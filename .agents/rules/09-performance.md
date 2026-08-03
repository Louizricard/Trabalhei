# Performance

Evitar ativamente:

- Consultas repetidas ao banco/API que poderiam ser uma única consulta (ex.: buscar cada proposta separadamente em vez de uma query com join).
- Rebuilds desnecessários de widgets — usar `const` sempre que possível e escopar providers/`Consumer` no menor widget possível, não na tela inteira.
- Listas sem paginação — qualquer lista que pode crescer sem limite (vagas, propostas, mensagens) usa paginação ou scroll infinito com carregamento sob demanda, nunca carrega tudo de uma vez.
- Imagens gigantes sem redimensionamento — avatar e anexos de imagem são redimensionados/comprimidos antes ou depois do upload, nunca servidos no tamanho original de câmera.
- Chamadas duplicadas à API — checar se o dado já está em cache/estado antes de disparar uma nova chamada equivalente.
