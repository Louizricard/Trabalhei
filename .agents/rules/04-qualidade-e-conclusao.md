# Qualidade Obrigatória e Critérios de Conclusão

## Antes de considerar qualquer tarefa concluída, revise procurando

- Código duplicado
- Arquivos mortos (não referenciados em lugar nenhum)
- Imports não utilizados
- Widgets gigantes que deveriam ser divididos
- Possíveis memory leaks (streams/controllers/listeners não descartados em `dispose()`)
- Problemas de performance óbvios (ver `09-performance.md`)
- Erros de responsividade entre tamanhos de tela (mobile estreito, tablet, desktop/Web largo)
- Violações da arquitetura definida em `02-arquitetura.md`

## Uma feature só é considerada pronta quando, ao mesmo tempo

1. Compila sem erro
2. Roda sem crash
3. Não gera nenhum warning no `flutter analyze`
4. Funciona no Android
5. Funciona na Web
6. Segue a arquitetura obrigatória
7. Atualiza a documentação relevante, se a mudança afetar algo já documentado (README, comentário de arquitetura, etc.)

Se qualquer um desses sete pontos falhar, a tarefa não está pronta — não relate como concluída, relate o que ainda falta.
