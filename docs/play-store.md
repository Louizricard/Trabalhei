# Play Store: checklist de publicação

App: **Trabalhei**, pacote `com.trabalhei.app`. Este documento lista cada exigência do Play Console,
o que já está pronto no repositório e o que o responsável precisa fazer no Console. Revisado em
17/11/2026. As regras do Google mudam; confira no Console o texto em vigor antes de enviar.

Como gerar e assinar o pacote: [producao.md, seção 8](producao.md#8-android-play-store-e-apk).
Cobrança no Android: [play-billing.md](play-billing.md).

## Resumo

| Item | Situação no repositório | Ação no Console |
|---|---|---|
| Conta de desenvolvedor verificada | Fora do repositório | Concluir a verificação de identidade e do contato |
| Teste fechado (12 testadores, 14 dias) | Fora do repositório | Rodar antes de pedir produção, se a conta exigir |
| API de destino | `targetSdk` 36 (padrão do Flutter 3.47.9), `compileSdk` 36 | Nada |
| Formato AAB | `flutter build appbundle` | Enviar o `.aab` |
| Assinatura | Chave de upload `trabalhei-release.jks` | Ativar o Play App Signing |
| Permissões | `INTERNET`, `ACCESS_NETWORK_STATE` e `BILLING` | Nada (sem declaração de permissão sensível) |
| Política de privacidade | https://trabalhei.site/privacidade/ | Informar a URL |
| Exclusão de conta | No app e em https://trabalhei.site/excluir-conta/ | Informar a URL na Segurança dos dados |
| Segurança dos dados | Respostas abaixo | Preencher o formulário |
| Classificação indicativa | Respostas abaixo | Responder o questionário IARC |
| Público-alvo | 18+ | Marcar só 18 anos ou mais |
| Anúncios | Sem SDK de anúncios; há vagas "Patrocinado" | Responder **Sim** (decidido; ver a seção Anúncios) |
| Acesso ao app | Login necessário | Criar conta de revisão e informar no Console |
| Ficha da loja | Textos abaixo; imagens em `store-listing/play/` | Subir as imagens e colar os textos no Console |
| Pagamentos | Google Play Billing no Android | Criar os produtos (ver play-billing.md) |

## 1. Conta de desenvolvedor

- Conclua a **verificação de identidade** (documento) e a **verificação do contato** (e-mail e
  telefone) em Play Console › Configurações › Detalhes da conta. Sem isso não é possível publicar.
- Se a conta é **pessoal e foi criada depois de 13/11/2023**, o Google exige um **teste fechado com
  pelo menos 12 testadores que permaneçam inscritos por 14 dias seguidos** antes de liberar o pedido
  de acesso à produção. Confira em Painel › "Publicar o app no Google Play" se o requisito aparece
  para esta conta (contas de organização não têm essa exigência).
  - Crie a faixa de **Teste fechado**, envie o AAB, adicione os e-mails (Lista de e-mails ou Grupo do
    Google) e mande o link de inscrição. Cada testador precisa aceitar o convite e instalar pelo link.
  - A contagem de 14 dias só vale enquanto os 12 continuam inscritos. Convide alguns a mais.
  - Depois, o pedido de produção pergunta como o teste foi feito e o que mudou. Anote o retorno dos
    testadores durante o período.

## 2. Pacote, API de destino e assinatura

- **API de destino**: desde 31/08/2026 apps novos precisam mirar a API 36 ou mais nova.
  `freelanceflow/android/app/build.gradle.kts` usa `targetSdk = flutter.targetSdkVersion`, que é
  **36** no Flutter 3.47.9 (`FlutterExtension.kt` do `flutter_tools`), e `compileSdk = 36`. Ao
  trocar a versão do Flutter, confira esse valor de novo.
- **Formato**: apps novos só aceitam **Android App Bundle (.aab)**. Comando em
  [producao.md](producao.md#8-android-play-store-e-apk).
- **Play App Signing**: na primeira versão, aceite o Play App Signing. O Google gera e guarda a
  chave que assina o app instalado; a `trabalhei-release.jks` passa a ser a **chave de upload**.
  - Nesta máquina, o `freelanceflow/android/key.properties` deve ter
    `storeFile=/home/louizricard/Documentos/Projetos/trabalhei/android-release-key/trabalhei-release.jks`.
  - O APK baixado do site é assinado com a chave de upload, e o da Play Store com a chave do Google.
    Por isso um não instala por cima do outro: quem trocar de origem precisa desinstalar antes (os
    dados ficam na conta, não no aparelho).
- **Versão**: suba `version` no `pubspec.yaml` antes de cada envio (o `versionCode` não pode repetir).

## 3. Permissões

Manifesto final (`flutter build apk --debug`, conferido em 17/11/2026):

- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- `com.android.vending.BILLING` (trazida pela biblioteca do Google Play Billing; não exige
  declaração)
- `com.trabalhei.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (interna do AndroidX, nível
  assinatura; não aparece para o usuário)

Saíram `CAMERA`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`, `POST_NOTIFICATIONS`, `VIBRATE` e
`RECEIVE_BOOT_COMPLETED`, que nenhum código usava. Fotos e arquivos vêm do seletor do sistema
(`image_picker` / `file_picker`) e a câmera abre pelo app de câmera do sistema. Com isso o app não
precisa da declaração de "Permissões de fotos e vídeos" do Play Console, e a foto pela câmera deixa
de falhar (declarar `CAMERA` sem pedi-la faz o Android bloquear o app de câmera).

Nenhum plugin traz de volta permissões de câmera ou de armazenamento.

## 4. Política de privacidade e exclusão de conta

- **Política de privacidade**: `https://trabalhei.site/privacidade/` (Play Console › Política e
  programas › Conteúdo do app › Política de privacidade). O texto também está dentro do app
  (Perfil › Termos de Uso e Privacidade).
- **Exclusão de conta**: o app permite criar conta, então o Google exige
  - exclusão **dentro do app**: Perfil › Zona de risco › Excluir minha conta (já existe);
  - um **link na web** que explique como pedir a exclusão sem o app:
    `https://trabalhei.site/excluir-conta/` (informar em Segurança dos dados › Exclusão de dados).
- Termos de Uso públicos: `https://trabalhei.site/termos/`.

## 5. Segurança dos dados (Data safety)

Respostas gerais:

| Pergunta | Resposta |
|---|---|
| O app coleta ou compartilha algum dos tipos de dados obrigatórios? | Sim |
| Todos os dados coletados são criptografados em trânsito? | Sim |
| Os usuários podem pedir a exclusão dos dados? | Sim (no app e em trabalhei.site/excluir-conta) |
| Formas de login | Nome de usuário e senha (e-mail e senha) |
| Exclusão de dados sem excluir a conta (opcional) | Sim: o usuário remove foto, currículo, portfólio, alertas e notificações no app, e pode pedir por e-mail |

"Compartilhar", para o Google, é enviar dados a terceiros. Envio a prestadores de serviço que tratam
os dados em nome do Trabalhei (Supabase, Resend, Sentry, Google Play) **não conta como
compartilhamento**. Por isso todas as linhas abaixo ficam como **coletado, não compartilhado**.

| Categoria › tipo | Coletado | Obrigatório? | Finalidades | Observação |
|---|---|---|---|---|
| Informações pessoais › Nome | Sim | Obrigatório | Funcionalidade do app, Gerenciamento da conta | Nome do perfil |
| Informações pessoais › Endereço de e-mail | Sim | Obrigatório | Funcionalidade do app, Gerenciamento da conta, Comunicações do desenvolvedor | Login e avisos por e-mail |
| Informações pessoais › IDs do usuário | Sim | Obrigatório | Funcionalidade do app, Gerenciamento da conta | ID interno da conta |
| Informações pessoais › Outras informações | Sim | Opcional | Funcionalidade do app | Bio, habilidades, empresa, cidade, links, valor por hora |
| Informações financeiras › Histórico de compras | Sim | Opcional | Funcionalidade do app, Gerenciamento da conta | Compras do Pro e do destaque |
| Mensagens › Outras mensagens no app | Sim | Opcional | Funcionalidade do app | Chat entre usuários |
| Fotos e vídeos › Fotos | Sim | Opcional | Funcionalidade do app | Foto de perfil, portfólio, capa de vaga, fotos no chat, captura em relatório de bug |
| Arquivos e documentos › Arquivos e documentos | Sim | Opcional | Funcionalidade do app | Currículo, anexos de vaga e do chat, entregas |
| Atividade no app › Outros conteúdos gerados pelo usuário | Sim | Opcional | Funcionalidade do app | Vagas, propostas, avaliações, denúncias, relatórios de bug |
| Atividade no app › Outras ações | Sim | Opcional | Funcionalidade do app | Alertas de vagas salvos |
| Informações e desempenho do app › Registros de falhas | Sim | Obrigatório | Análise | Sentry |
| Informações e desempenho do app › Diagnóstico | Sim | Obrigatório | Análise | Sentry (aparelho, sistema, versão do app) |
| IDs do dispositivo ou outros | Sim | Obrigatório | Análise | ID aleatório de instalação do Sentry (sem ID de publicidade) |

Responda **Não** para: localização, contatos, agenda, áudio, saúde e condicionamento físico,
SMS/e-mail do aparelho, histórico de navegação, informações de pagamento (cartão e conta bancária
ficam com a Google Play ou o Asaas), raça, religião, orientação sexual, opiniões políticas,
CPF/CNPJ (no Android a compra é pela Google Play; o CPF só é pedido no checkout do Asaas, na versão
web).

Os dados são processados de forma temporária? **Não**. Para "Fotos" e "Arquivos": o app só recebe o
item que o usuário escolhe.

Se a versão Android ainda mostrar o checkout do Asaas (Pix/cartão) ao entrar na Play Store, o CPF
passa a ser coletado no Android: marque Informações pessoais › Outras informações também para essa
finalidade. Pela política de pagamentos isso não deve acontecer; veja a seção 11.

## 6. Classificação do conteúdo (questionário IARC)

- Categoria: **Todos os outros tipos de app** (não é jogo).
- Violência, sexo/nudez, linguagem imprópria, drogas, álcool, tabaco, apostas, terror: **Não**.
- **Os usuários podem interagir ou trocar conteúdo entre si?** **Sim** (chat, perfis, vagas e
  propostas públicas).
- O app compartilha a localização atual do usuário com outros usuários? **Não** (a cidade do perfil é
  texto digitado, não localização do aparelho).
- O app permite compras de produtos digitais? **Sim** (Pro e destaque).
- O app é um navegador ou mecanismo de pesquisa da web? **Não**.

Resultado esperado: classificação baixa com os descritores "Interação entre usuários" e "Compras
no app". Conteúdo gerado por usuários exige, pela política do Google, termos que proíbam conteúdo
impróprio (item 4 dos [Termos](https://trabalhei.site/termos/)), denúncia dentro do app (perfis,
vagas e mensagens do chat), bloqueio de usuário no chat e moderação ativa (painel Perfil ›
Moderação). Detalhes em [moderacao-chat.md](moderacao-chat.md).

## 7. Público-alvo e conteúdo

- **Faixa etária**: marque apenas **18 anos ou mais**. O app não é para crianças, e os Termos
  exigem 18+. Não participe do programa "Aprovado por professores" nem da seção Família.
- "O app pode atrair crianças sem querer?" **Não** (marketplace de serviços profissionais, sem
  personagens ou conteúdo infantil).
- **Apps de notícias**: Não. **Saúde**: nenhum recurso de saúde. **Recursos financeiros**: "Meu app
  não oferece nenhum recurso financeiro" (o pagamento dos projetos é feito direto entre as partes,
  fora do app; Pro e destaque são compras de produto digital). **Governo**: Não. **COVID-19**:
  Não. **Rastreamento de ID de publicidade**: o app não usa o ID de publicidade (não declara
  `AD_ID`).

## 8. Anúncios

O app **não tem SDK de anúncios** nem usa ID de publicidade. Ele tem o **destaque de projeto**: o
cliente paga para a própria vaga aparecer no topo do mural, identificada como "Patrocinado".

O Google considera anúncio qualquer conteúdo promovido em troca de pagamento, inclusive anúncio
vendido diretamente. Como o destaque é exatamente isso (outro usuário paga pela exibição), a resposta
mais segura em "O app contém anúncios?" é **Sim**. O efeito é o rótulo "Contém anúncios" na loja.
Responder "Não" é defensável (é uma listagem do próprio marketplace, sem rede de anúncios), mas, se o
revisor discordar, o app pode ser rejeitado por declaração incorreta.

**Decisão (17/11/2026): responder Sim.**

Na Segurança dos dados, a finalidade "Publicidade ou marketing" continua **sem marcar**: o destaque
não usa dados do usuário para segmentar.

## 9. Acesso ao app para a revisão

Quase tudo exige login, então o Google pede credenciais de teste (Conteúdo do app › Acesso ao app ›
"Todas ou algumas funcionalidades estão restritas").

1. Crie uma conta nova só para a revisão, com um e-mail que você controla (por exemplo um alias
   do seu e-mail), confirme o e-mail e escolha o papel **freelancer**.
2. Deixe dados de exemplo: perfil preenchido, uma vaga publicada por outra conta sua e uma
   proposta, para o revisor ver chat e contrato.
3. No Console, informe o e-mail e a senha dessa conta e as instruções: "Entre com e-mail e senha.
   Em Perfil › Usar como contratante a conta muda para o papel de cliente. A exclusão de conta fica
   em Perfil › Zona de risco." Não use senha de outra conta sua.
4. Não ative nada que bloqueie o revisor (o login não tem código por SMS nem autenticação em duas
   etapas). Não exclua nem altere a senha dessa conta enquanto houver revisão pendente.

## 10. Ficha da loja

**Contato** (obrigatório): e-mail `louizvolution@gmail.com`; site
`https://trabalhei.site`. Telefone é opcional.

**Imagens**: prontas em [`store-listing/play/`](../store-listing/play/), feitas de telas reais do
app de demonstração. O [README](../store-listing/play/README.md) de lá traz o título de cada
captura e como regenerar tudo (`store.mjs` captura as telas, `generate.py` monta as imagens).

| Item | Exigência | Arquivo |
|---|---|---|
| Ícone | PNG 512×512, até 1 MB | `store-listing/play/icon-512.png` (quadrado cheio, sem os cantos brancos da arte original) |
| Gráfico de recursos | JPEG ou PNG 1024×500, sem transparência | `store-listing/play/feature-graphic.png` |
| Capturas de celular | 2 a 8, PNG ou JPEG, lado de 320 a 3840 px, proporção até 2:1 | `store-listing/play/01-vagas.png` a `06-talentos.png` (1080×1920), enviar nessa ordem |
| Capturas de tablet | Opcional | Não existem; recomendadas se quiser aparecer bem em tablets |

**Nome do app** (até 30 caracteres): `Trabalhei: freelancers e vagas`

**Descrição curta** (80 de 80 caracteres):

```text
Contrate freelancers ou ache projetos: propostas, chat e entregas, sem comissão.
```

**Descrição completa** (cerca de 1.700 de 4.000 caracteres):

```text
O Trabalhei conecta quem precisa de um serviço a freelancers de todas as áreas. Encontre profissionais e conduza o trabalho em um só lugar: propostas, chat e entregas por marcos.

SEM COMISSÃO SOBRE O PROJETO
O valor combinado é pago diretamente entre cliente e freelancer e vai inteiro para quem trabalha. O Trabalhei não retém nem intermedia esse pagamento.

PARA QUEM CONTRATA
• Publique a vaga com área, especialidade, orçamento, prazo e habilidades.
• Receba propostas e compare valores e prazos na mesma tela.
• Negocie com uma contraproposta ou converse antes de contratar.
• Acompanhe as entregas pelo chat e aprove cada marco ou peça revisão.
• Opcional: destaque o projeto por 7 dias no topo do mural.

PARA FREELANCERS
• Mural de vagas com busca por título, habilidade ou área.
• Envie propostas com valor, prazo, carta de apresentação e amostras do portfólio.
• Propostas grátis todo mês. No plano Pro: mais propostas, modelos reutilizáveis, organização de clientes, estatísticas e arquivos maiores.
• Entregue arquivos pelo chat e receba a avaliação do cliente.
• Painel com contratos ativos, propostas pendentes e projetos concluídos.

AVALIAÇÕES DE VERDADE
Só quem concluiu um contrato pode avaliar. A nota do perfil vem de projetos reais.

ÁREAS
Tecnologia, Design, Marketing, Redação e Conteúdo, Tradução, Audiovisual e Foto, Administração e Assistência, Vendas e Comercial, Finanças e Jurídico, Educação, Engenharia e Arquitetura e outras.

A MESMA CONTA EM TODO LUGAR
Use no Android, no Windows ou no navegador em trabalhei.site, com as mesmas vagas, propostas e conversas.

Para maiores de 18 anos. O plano Pro é uma assinatura mensal opcional, renovada automaticamente e cancelável a qualquer momento na Google Play.

Termos de Uso: https://trabalhei.site/termos/
Privacidade: https://trabalhei.site/privacidade/
```

Evite preços na descrição: na Google Play o preço exibido é o da loja e pode mudar. A categoria
sugerida é **Empresas** (ou **Produtividade**). Tags: freelancer, trabalho, vagas, serviços.

## 11. Pagamentos

- O **Plano Pro** (assinatura mensal) e o **destaque de projeto** (compra única de 7 dias) são
  produtos digitais. **No Android** são vendidos pelo **Google Play Billing**; **na versão web e no
  Windows**, pelo **Asaas** (Pix e cartão). Detalhes e configuração dos produtos no Console em
  [play-billing.md](play-billing.md).
- Pela política de pagamentos, a versão Android não pode oferecer o checkout do Asaas nem levar o
  usuário a comprar na web. Confira isso no build enviado.
- O texto de pagamentos dentro do app (seção 7 de
  `freelanceflow/lib/features/profile/presentation/screens/terms_and_privacy_screen.dart`) ainda cita
  só o Asaas. Atualize junto com a integração para refletir a Google Play no Android, como já está
  em https://trabalhei.site/termos/.
- Assinaturas exigem, na ficha e no app, informação clara de preço, renovação e cancelamento: a
  tela de compra da Google Play mostra preço e período, e os Termos (itens 8 e 9) explicam
  renovação, cancelamento e reembolso.

## 12. Itens da lista do responsável

| Item | Situação |
|---|---|
| Termos de Uso | Feito: no app (Perfil › Termos de Uso e Privacidade) e em https://trabalhei.site/termos/ |
| Política de privacidade | Feito: https://trabalhei.site/privacidade/ (LGPD e exigências do Google) |
| Consentimento de cookies | **Não precisa de banner.** O site não usa analytics, pixels nem cookies. O app web guarda no navegador só a sessão de login e um cadastro em andamento (estritamente necessários). O site carrega a fonte do Google Fonts e consulta a API do GitHub (lista de downloads), o que envia o IP do visitante a esses serviços; isso está descrito na política. Se um dia entrar analytics ou pixel de anúncio, aí sim será preciso banner com opção de recusar. Para eliminar até o envio de IP ao Google, dá para hospedar a fonte junto com o site |
| Consentimento para dados sensíveis | **Não se aplica.** O app não pede dado sensível (saúde, religião, biometria etc.). A política orienta a não enviar esse tipo de dado |
| Política de assinaturas e cancelamento | Feito: Termos, itens 8 (renovação e como cancelar na web e na Google Play) e 9 (arrependimento de 7 dias do CDC na web; reembolso pela política da Google Play no Android) |
| Regras para crianças | Feito: o serviço é só para maiores de 18 anos (Termos item 3, Política item 12); público-alvo 18+ no Console |

Antes de publicar, peça uma revisão jurídica dos Termos e da Política, em especial reembolso,
foro, prazos de guarda e a classificação do destaque como anúncio.
