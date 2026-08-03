# Convenções de Código

- Máximo de 250 linhas por arquivo. Se um arquivo passar disso, é sinal de que ele deve ser dividido (extrair widget, extrair classe).
- Máximo de 40 linhas por método/função. Métodos maiores devem ser quebrados em métodos privados menores e nomeados.
- Widgets reutilizáveis: qualquer trecho de UI usado em mais de uma tela vira um widget próprio em `core/widgets/` (se genérico) ou dentro da própria feature (se específico dela).
- Nomes de variáveis, classes, métodos e arquivos em inglês, mesmo que a documentação e os commits estejam em português.
- Comentários apenas quando o "porquê" não é óbvio pelo código — não comentar o óbvio (ex.: `// incrementa contador` acima de `contador++`). Prefira nomes claros a comentários explicativos.
- Formatação: sempre rodar `dart format` antes de considerar um arquivo pronto.
- Análise estática: o código deve passar em `flutter analyze` sem nenhum warning ou erro antes de ser entregue.
