# Fila de aprovação de telas — Raevo

A direção **A · Consultório** está aprovada (19/09/2026). O sistema está gravado em
[`design-system/aprovado/`](../design-system/aprovado/README.md).

Este documento é a outra metade: **nenhuma tela existente muda sem passar por aqui.**

---

## O processo

Por tela, sempre nesta ordem:

| # | Passo | Sai daqui |
| --- | --- | --- |
| 1 | **Apresentar** — mockup da tela na pele Consultório, desktop 1280px e telemóvel, com estado cheio, vazio, a carregar e com erro | um artefacto para ver |
| 2 | **Aprovar** — decisão registada na tabela abaixo, com data | uma linha de `aprovada` |
| 3 | **Implementar** — só depois do passo 2, e só a tela aprovada | um PR que toca nessa tela |
| 4 | **Porta visual** — os cinco passos do `AGENTS.md` (`ui-ux-pro-max`, `frappe-ui-patterns`, `accessibility-compliance`, `agentic-browser-testing`, `visual-testing`), com screenshots antes/depois | prova de que ficou como o mockup |

Um passo 3 sem passo 2 é retrabalho à espera de acontecer. Um passo 4 sem browser a
correr não está feito — os passos 4 e 5 da porta visual não são análise de código.

### O que "aprovada" quer dizer

Que a **estrutura** está decidida: o que fica no ecrã, onde, com que hierarquia e que
ações. Não é aprovação de pixel — cor, raio e densidade vêm dos tokens e mudam
sozinhos quando o sistema muda.

### O que não precisa de aprovação

- **Tela nova.** Nasce em Consultório por omissão. É esse o ponto de ter o sistema
  gravado.
- **Correção de bug visual** que aproxima a tela do sistema (cor literal que virou
  token, degrau de tipo fora da escala, controlo sem rótulo acessível).
- **As telas nativas do Chatwoot.** Ver abaixo — e é de propósito.

---

## O que não entra na fila, e porquê

Esta é a parte que custa dinheiro se for decidida ao contrário.

O Raevo é um fork. **Cada ficheiro do upstream que editamos vira conflito em cada
`git pull` do Chatwoot — para sempre.** Por isso as telas dividem-se em duas classes
com tratamento diferente:

| Classe | Telas | Tratamento | Custo por atualização |
| --- | --- | --- | --- |
| **Nossas** | Kanban/CRM, Agenda, Financeiro, Formulários, IA, Automação, Marketing, Início | mockup → aprovação → implementação | nenhum |
| **Do Chatwoot** | Conversas, Contactos, Caixas de entrada, Definições, Central de ajuda | **só tokens** — markup intocado | nenhum |

As telas do Chatwoot **mudam de aparência na mesma**, porque a cor delas também sai
dos nossos tokens. O que não fazemos é redesenhá-las tela a tela: isso é exatamente o
que encarece o próximo upgrade, e foi a restrição posta desde o início.

Exceção prevista: acrescentar um painel **nosso** dentro de uma tela do Chatwoot
(oportunidade, cobrança ou IA na barra lateral da conversa) é componente nosso e entra
na fila normal. Não é o mesmo que redesenhar a conversa.

---

## A fila

Ordem por dependência: o que ensina mais vem primeiro, e o que depende de decisões
ainda por tomar vem no fim.

| # | Tela | Módulo | Ficheiros | Estado | Nota |
| --- | --- | --- | --- | --- | --- |
| 1 | Pipeline (quadro) | Kanban | 37 `.vue` no módulo | **aprovada 20/09** — [ver](https://claude.ai/artifact/8QXUMLHhsJDUSdMsjPgJbw) | pronta a implementar; a lacuna do teclado fica em separado |
| 2 | Oportunidade aberta (gaveta) | Kanban | `KanbanOpportunityDetailsModal.vue` | **aprovada 20/09** — [ver](https://claude.ai/artifact/QcWYpjBJq9kKkjGCFEiqxx) | pronta a implementar; `truncate` do assunto e tira de abas ficam em separado |
| 3 | Início | Home | 1 | **apresentada 20/09** — [ver](https://claude.ai/artifact/DLSQZn7N2pW3xmWwuUKCr1) | não é painel: é fila de trabalho. Três achados de dados abertos — ver abaixo |
| 4 | Financeiro | Finance | 3 | por apresentar | estado de cobrança sem depender de cor |
| 5 | Agenda | Calendar | 30 | **decidido — ver abaixo** | vista atual fica; a nova é alternativa |
| 6 | Formulários | Forms | 10 | por apresentar | `RaevoField` é o único tratamento de campo |
| 7 | Automação (Vue Flow) | Kanban | — | por apresentar | cartão de nó com dimensão estável |
| 8 | Painel de conversa (nosso) | Conversation | componente novo | por apresentar | entra dentro de tela do Chatwoot |
| 9 | Entrada (login) | — | upstream | por decidir | mexer aqui é mexer no upstream: avaliar o custo primeiro |

Quando uma linha for aprovada, escreva a data e quem aprovou. Quando for implementada,
ponha o link do PR.

---

## O que falta para fechar o Kanban

Inventário feito em 20/09, depois de aprovadas as telas 1 e 2.

**O que precisa de aprovação própria** — tem arquitetura de informação que não se
deduz do que já foi aprovado:

| Superfície | Ficheiro | Porquê precisa |
| --- | --- | --- |
| ~~**Vista de lista**~~ | `KanbanListView.vue` (8 KB) | **aprovada 20/09** com o painel de filtros — [ver](https://claude.ai/artifact/Fz5vKHs88RxhmUZFh8Fnmm) |
| ~~**Painel de filtros**~~ | dentro de `KanbanView.vue` | **aprovada 20/09**, no mesmo artefacto |
| **Definições — oito separadores** | `KanbanBoardSettings.vue` | **apresentada 20/09** — [ver](https://claude.ai/artifact/QhRFTYWLU4zqbepe4pR3dy) |
| **Definições — Comercial** | `KanbanBoardSettings.vue` | **apresentada 20/09** — [ver](https://claude.ai/artifact/BffGSQm15W3rGxhh2vWM6g) |
| **Automações** | `KanbanAutomations.vue` (146 KB) | é a tela 7 da fila; tela de canvas, com regras próprias no `AGENTS.md` |
| **Visão de funis** | `KanbanOverview.vue` (17 KB) | lista de quadros com ordenação própria |

**O que herda e não precisa de aprovação** — composto de primitivos já aprovados
(campo, botão, selo, tabela, estado vazio, gaveta):

`KanbanActivityCenter` · `KanbanImportDialog` · `KanbanOpportunityPicker` ·
`KanbanConversationDrawer` · `KanbanCreateBoardDialog` · `KanbanCalendarBookingDialog` ·
cartões arquivados · movimento assistido · resumo comercial · criação rápida.

Aprovar cada um destes à parte é o caminho caro de que este documento avisa. Entram
na implementação com os tokens, e a porta visual valida o resultado.

### Vista de lista — `truncate` outra vez, e a etapa sem cor · 20/09/2026

Terceira aparição da mesma regra quebrada. Na lista, o assunto da oportunidade leva
`truncate` numa linha só — e é pior aqui do que na gaveta, porque a lista existe para
**comparar**: compara-se o que não se consegue ler. Proposta: até duas linhas, com
altura de linha estável.

Dois achados menores no mesmo ecrã:

- A etapa aparece como texto simples, sem cor. A mesma etapa tem cor no quadro e na
  gaveta; perdê-la aqui obriga a ler onde noutro sítio se reconhecia. Proposta: o
  mesmo selo com a cor da etapa.
- O estado sem resultados é uma frase centrada, sem saída. Quase sempre é filtro a
  mais. Proposta: dizer quantos grupos estão ativos e oferecer *Limpar filtros*.

### Início — a fila prometia um painel que o servidor não alimenta · 20/09/2026

A nota desta linha dizia *«KPI, cartão com anel, gráfico de um tom»*. O
`RaevoHomeController#show` devolve duas listas cortadas a oito (`MAX_ITEMS`), um
contador e os filtros. **Não há série temporal e não há KPI.** Desenhar um painel aqui
era desenhar um backend que ninguém pediu. A nota da fila foi corrigida: o Início é uma
fila de trabalho.

Três achados que não são de desenho e que a apresentação mede:

- **A ordenação «quem espera há mais tempo» mente acima de 25 conversas.** O
  controlador pede ao `ConversationFinder` a página 1 com `sort_by: 'unread'` — 25 por
  omissão (`CONVERSATION_RESULTS_PER_PAGE`) — e só depois reordena *essa página* por
  `last_activity_at`. Com 26 conversas abertas ou mais, quem espera há mais tempo pode
  estar na página 2 e nunca aparecer. Numa clínica com o WhatsApp aberto, 25 é uma manhã.
- **O emblema do cabeçalho soma um total verdadeiro a um total truncado.**
  `totalAttention = open_conversations_count + overdueActions.length`: a primeira
  parcela é o total real, a segunda é o comprimento da lista já cortada a oito. Quanto
  pior está a operação, mais o número mente — e mente sempre para menos.
- **Dois controlos com o mesmo nome acessível.** Os dois `select` de ordenação usam
  `HOME.SORT` («Order») como `aria-label`. Um leitor de ecrã anuncia dois combo boxes
  chamados «Order», sem nada que os distinga.

E quatro campos que o servidor serializa em todos os pedidos e o template deita fora:
`unread_count`, `priority`, `owner_name`, `next_action_type`. O `unread_count` custa um
`COUNT` por conversa — oito consultas por carregamento para um número que ninguém vê. O
`next_action_type` é exatamente o que faria a linha dizer *Ligar* ou *Enviar mensagem*
em vez de um relógio genérico. Desenhá-los não acrescenta trabalho ao servidor: deixa de
o desperdiçar.

**Por responder:** corrigir a ordenação antes de implementar? O servidor passa a contar
as ações antes de cortar? A barra de filtro única serve? Falta algum cartão (agenda do
dia, cobranças vencidas)?

### Definições — «Comercial» não é um separador · 20/09/2026

Contagem de chaves de tradução por separador, em 20/09:

| Separador | Chaves | % do ecrã |
| --- | --- | --- |
| **Comercial** | **141** | **62,4%** |
| Etapas | 18 | 8,0% |
| Agenda | 18 | 8,0% |
| Automações | 17 | 7,5% |
| Campos de contacto | 14 | 6,2% |
| Agentes | 6 | 2,7% |
| Caixas de entrada | 6 | 2,7% |
| Geral | 3 | 1,3% |
| Apagar funil | 3 | 1,3% |

Comercial sozinho é **1,66× os outros oito somados**. Contém seis ferramentas numa
página: construtor de campos (abas, grupos, tipos, opções, largura, obrigatório por
etapa, condições e fórmulas), layout do cartão, alertas de cartão parado, lembretes de
marcação, tipos de próxima ação e motivos de perda.

Isto corrige o plano anterior, que propunha apresentar «Etapas e Comercial» juntos:
Etapas são 18 chaves e cabem com folga; juntá-las ao Comercial fá-las-ia rodapé.

Mais duas propostas de arquitetura no mesmo ecrã:

- **«Apagar funil» sai da navegação.** É uma ação destrutiva com o mesmo peso visual de
  uma definição, e não se navega para apagar. Proposta: zona de perigo no fim de Geral.
- **«Agentes» e «Caixas de entrada» são o mesmo componente.** Têm as mesmas seis chaves
  — é o mesmo seletor múltiplo com pesquisa. Proposta: um primitivo só, usado duas vezes.

### Quantos grupos de campos existem — respondido pelo código · 20/09/2026

Perguntei duas vezes ao utilizador e fui buscar a resposta ao repositório.
`KanbanBoards::CreateFromTemplateService` define o arranque de um funil:

| | Valor |
| --- | --- |
| Campos de um funil de clínica novo | **6** |
| Campos de um funil B2B novo | **4** |
| Secções (abas) no arranque | **1** — `details` |
| Largura no arranque | total, em todos |
| Campos no cartão compacto | **3**, os primeiros da ordem |
| Campos do preset de marketing | **28** |
| Tipos de campo | **12**, incluindo fórmula |
| Campos padrão não removíveis | **8** |

**Isto fecha o risco da tira de abas** registado na tela 2: no arranque são no máximo
duas abas, a de campos e — se ligarem marketing — a de marketing. Fica como nota.

**E abre um maior: o preset de marketing tem 28 campos, não 8.** `gclid`, `fbclid`,
`fbp`, `ttclid`, identificadores de campanha, conjunto e anúncio, página de entrada.
Nenhum é escrito à mão — são preenchidos pelo rastreio. Proposta: mostrá-los como
**tabela de leitura**, não como 28 campos de formulário. Um campo editável promete uma
edição que não existe.

### Comercial — seis ferramentas numa página · 20/09/2026

Proposta central da apresentação: Comercial ganha sub-navegação própria — Campos ·
Cartão · Marketing · Alertas e lembretes · Listas. Configurar um campo e definir dias
de alerta são trabalhos sem relação, feitos em alturas diferentes; tê-los no mesmo
*scroll* obriga a passar por um para chegar ao outro.

Mais duas, menores: o editor de campo passa a lista à esquerda e detalhe à direita, com
*Mais opções* recolhido (chave estável e posição mudam-se quase nunca); e remover um
campo com dados passa a dizer **quantos cartões** têm valor gravado, em vez de só
avisar que os valores ficam na base.

### A direção migrou: o código é Consultório · 21/09/2026

`--brand-color` passou de `#2563EB` a `#171717` no claro, e inverte para `#E5E5E5`
no escuro. A base é acromática e o controlo deixou de ser pílula. **82 tokens**
migrados no `_raevo-tokens.scss`, mais a escala de raio no `tailwind.config.js`.

Isto muda o produto inteiro de uma vez, e é o desenhado: as telas nativas do
Chatwoot herdam a identidade pelos tokens **sem serem editadas**, que é a razão de
o `AGENTS.md` proibir redesenhá-las tela a tela.

**A paleta de etapas não migrou.** É dado do produto, validada para daltonismo, e o
diff do JSON gravado confirma: zero linhas de `stage`.

Duas coisas que as portas apanharam:

- **A invariante do raio quebrou, e com razão.** O par raio-token ↔ degrau do
  Tailwind era de Sereno (`radius-item = lg`). Em Consultório `item = md` e `lg`
  passa a ser o controlo. Corrigido o par, e a verificação passa a cobrir três em
  vez de dois. Correr `extract` com a invariante quebrada teria gravado o erro como
  verdade — é exatamente o que o script avisa.
- **A identidade gravada não migrava com os valores.** O mockup gerado anunciava
  «H · Sereno» com tokens de Consultório. A direção passa a sair do extractor.

Verificado: 4789/4789 testes, `raevo:tokens`, `raevo:design` e `raevo:palette`
limpos, e o mockup renderizado nos dois temas.

**Nota de infraestrutura:** o hook de pre-commit chama `scss-lint`, um gem de Ruby
descontinuado que não está instalado. Falha com `ENOENT` em qualquer commit que
toque num `.scss` — não só nos nossos. O CI não o corre; a porta real desses
ficheiros é o `raevo:tokens`. Fica por corrigir no `lint-staged`.

### Dez respostas · 21/09/2026

Respondidas as dez perguntas em aberto. Duas das respostas valem mais do que a
pergunta que responderam.

| # | Pergunta | Resposta |
| --- | --- | --- |
| 1 | Os oito separadores servem? | **sim** |
| 2 | «Apagar funil» sai da navegação? | indiferente — decidido abaixo |
| 3 | «Agentes» e «Caixas» são o mesmo primitivo? | mal formulada — ver abaixo |
| 4 | Comercial ganha sub-navegação? | **não compreendida — o nome é o problema** |
| 5 | Marketing vira tabela de leitura? | **não. Fica editável** |
| 6 | A clínica usa o preset de marketing? | por responder — reformulada abaixo |
| 7 | Corrigir a ordenação falsa? | **sim** |
| 8 | O servidor conta as ações antes de cortar? | **sim** |
| 9 | Barra de filtro única no Início? | **sim** |
| 10 | Acrescentar cartões ao Início? | **sim — agenda, cobranças, oportunidades paradas** |

A **v2 do Início** está publicada com os cinco cartões: [ver](https://claude.ai/artifact/DLSQZn7N2pW3xmWwuUKCr1).

#### 4 — «Comercial» é um nome que o dono do produto não reconhece

A pergunta foi *«o que seria o comercial?»*. É o separador que vale **62,4% do ecrã de
definições**. Se quem manda no produto não reconhece o nome, nenhuma secretária vai
reconhecer.

A chave é `KANBAN.SETTINGS.SALES` — «Sales» em inglês, «Comercial» em português. O que
lá está dentro não é comercial: são **os campos da oportunidade e as regras deles**.

| O que lá está | Chaves |
| --- | --- |
| Construtor de campos — abas, grupos, 12 tipos, opções, largura, obrigatório por etapa, condições, fórmulas | a maioria das 141 |
| Layout do cartão compacto | `CARD_LAYOUT_*` |
| Preset de marketing (28 campos de rastreio) | `MARKETING_*` |
| Alertas de cartão parado | `STALE_ALERTS_*` |
| Lembretes de marcação | `APPOINTMENT_REMINDERS_*` |
| Listas: tipos de próxima ação, motivos de perda | `NEXT_ACTION_TYPES`, `LOST_REASON_OPTIONS` |

**Proposta: o separador passa a chamar-se «Campos da oportunidade».** É o que faz. A
sub-navegação proposta na apresentação deixa de precisar de explicação: Campos ·
Cartão · Marketing · Alertas · Listas.

#### 3 — a pergunta estava mal feita

Não proponho juntar Agentes com Caixas de entrada. São coisas diferentes: agentes são
pessoas, caixas de entrada são canais (WhatsApp, Instagram, e-mail). **Os separadores
ficam separados.**

O que é igual é o **controlo**: os dois ecrãs são uma lista com pesquisa onde se marcam
vários. Hoje esse controlo está escrito duas vezes. Proposta: escrever uma vez e usar
duas. É invisível para quem usa — **decidido, não precisa de aprovação.**

#### 2 — decidido, e corrige a minha própria proposta

«Apagar funil» **fica na navegação, no fim**, como hoje. O problema que apontei não era
a posição: era ter o mesmo peso visual de uma definição. Passa a estar separado por um
filete e marcado como destrutivo. Enterrá-lo no fim de Geral resolvia o peso visual e
estragava a descoberta — quem procura como apagar um funil percorre a navegação.

#### 5 — a largura total já está feita

O requisito «todos os campos nascem em largura total» **já está cumprido em quatro
lugares**, e foi verificado:

| Caminho | Onde | Valor |
| --- | --- | --- |
| Campo novo criado na interface | `KanbanBoardSettings.vue:1371` | `layoutWidth = 'full'` |
| Preset de marketing | `KanbanBoardSettings.vue:747` | `layoutWidth: 'full'` |
| Funil novo a partir de modelo | `create_from_template_service.rb:82` | `'width' => 'full'` |
| Campo sem largura gravada | `KanbanBoardSettings.vue:1163` | cai em `'full'` |

Meia largura continua a ser escolha de quem configura. A proposta de tornar o marketing
uma tabela de leitura **cai**: os 28 campos ficam editáveis como estão.

#### 6 — reformulada

A pergunta não era clara. O preset de marketing são **28 campos de rastreio** —
`origem_do_lead`, `utm_source`, `gclid`, `fbclid`, `fbp`, `ttclid`, `campaign_id`,
`adset_id`, `ad_id`, `landing_page` e mais — preenchidos automaticamente por
`Marketing::UrlAttributionParser` quando o contacto chega por um link com parâmetros.

A pergunta, agora concreta: **a clínica faz anúncios pagos (Google, Meta, TikTok)?**
Se faz, estes campos enchem-se sozinhos e a aba faz sentido. Se não faz, são 28 campos
sempre vazios a ocupar uma aba. Não muda nada do que já foi decidido — muda só se a aba
Marketing aparece ligada ou desligada num funil novo.

#### O achado da v2 — «de quem é a vez» já existe e a tela não o usa

Ao confirmar que os três cartões novos tinham dados, apareceu um sinal melhor do que
os três. `KanbanCard#reply_state` lê `conversation.waiting_since`: posto quando o
paciente escreve, limpo quando alguém da clínica responde. Presente significa que **a
bola está connosco**. O comentário no próprio modelo diz-lhe o nome certo — *«o sinal
que nenhum CRM do mercado mostra, porque nenhum tem a conversa por baixo»*.

A coluna está indexada (`index_conversations_on_waiting_since`) e já existe
`Conversation.scope :unattended`. Custa nada.

**E isto corrige a resposta 7.** Eu tinha dito que bastava empurrar a ordenação para a
base de dados. Estava incompleto: a **coluna também estava errada**.
`last_activity_at` mexe quando qualquer um age — incluindo quando *nós* respondemos.
Ordenar «quem espera há mais tempo» por essa coluna põe no topo uma conversa a que
acabámos de responder. O certo é `waiting_since`, e o controlo passa a dizer **«É a
nossa vez»**, que é o que a consulta faz.

#### 10 — aprovado, e deixa de ser migração

Acrescentar agenda do dia, cobranças vencidas e oportunidades paradas ao Início **não é
migrar uma tela: é construir três cartões novos**. Consequências registadas:

- O `RaevoHomeController` devolve hoje duas listas. Passa a precisar de três consultas
  novas, mais a contagem das ações (resposta 8).
- **Financeiro é opt-in por conta** e a Agenda pode não estar em uso. Os cartões têm de
  aparecer condicionalmente — um cartão vazio de um módulo desligado é pior que nenhum.
- Cinco cartões não cabem na grelha de duas colunas da apresentação. O Início precisa de
  uma **v2** antes de ser implementado.

### A base mexeu em telas já aprovadas · 20/09/2026

A base avançou cinco commits enquanto as apresentações decorriam. **Sem conflito** — o
ramo do design system e a base não tocam num único ficheiro em comum. Mas dois desses
commits mexem em telas que já passaram por aqui:

- **`795dd0b` — iniciar conversa a partir de uma oportunidade que nunca teve uma.** O
  cartão do quadro ganha um terceiro estado no canto: em vez de *abrir conversa*, uma
  oportunidade criada pela equipa oferece **iniciar**, que abre o compositor de mensagem
  nova. A apresentação da tela 1 foi atualizada para o mostrar.
- **`8ef0c69` — Início passa a filtrar por caixa ou funil, e a escolher a ordem.** São
  107 linhas novas em `RaevoHomeView.vue`. A tela 3 ainda não foi apresentada; quando o
  for, tem de incluir estes filtros.

**A lição, para ficar escrita:** uma apresentação aprovada envelhece. Entre aprovar e
implementar, a base mexe-se. Antes de implementar uma tela aprovada, comparar sempre com
o código do dia — não com o mockup.

## Achados abertos

### Pipeline — arrastar não tem alternativa por teclado · 20/09/2026

Confirmado no código ao preparar a apresentação da tela 1: mover um cartão entre
etapas faz-se **só** por arrastar. O caminho mais próximo é selecionar o cartão e usar
*Mover para etapa* na barra de ações em lote — que é acessível por teclado, mas obriga a
passar por uma seleção para mover um cartão só.

O `AGENTS.md` exige alternativa por teclado para todo o gesto de arrastar, por isso esta
tela não cumpre hoje. A proposta: com o cartão em foco, `Ctrl` + `←`/`→` move de etapa e
anuncia o destino.

**Isto não são tokens — é comportamento novo.** Por isso vai à parte da aprovação do
aspeto: pode entrar no mesmo PR da migração da tela ou num PR próprio.

### Oportunidade aberta — o assunto depende de `truncate` · 20/09/2026

O `<h2>` do cabeçalho da gaveta tem `truncate`. O `AGENTS.md` é explícito: título de etapa,
oportunidade, procedimento e campo **nunca** podem depender de corte para caber. Um assunto
como «Implante múltiplo — três elementos no maxilar superior» fica cortado a meio e obriga a
abrir o campo para saber de que se trata.

Proposta, já na apresentação: quebra em duas linhas. A gaveta tem 576px, há espaço.

### Oportunidade aberta — as abas crescem sem limite · 20/09/2026

A tira de abas é Geral + Contacto + Agenda (se ligada) + Financeiro (se ligado) + Formulários
(se houver permissão) + **uma aba por cada grupo de campos personalizados** + Histórico, mais um
`+` para criar outra. Com quatro grupos são dez abas em 576px e a tira passa a rolar.

**Não resolvido de propósito.** É desenho de informação, não token, e depende de um dado que
não tenho: quantos grupos de campos tem o funil Comercial hoje. Com dois ou três não há
problema; com seis, a tira precisa de outra ideia.

## Decisões já tomadas

### Agenda — 19/09/2026

A vista atual **fica como está**. A vista que apareceu no mockup entra como **uma
alternativa que se alterna**, não como substituição.

Motivo: a vista atual já resolve o trabalho de marcar e ler o dia. Trocar uma vista que
funciona por outra não é ganho — ter as duas é.

Por implementar: o seletor de vista, com a vista atual em primeiro e por omissão. Vale
para as duas a mesma regra do `AGENTS.md`: todo o controlo só por ícone precisa de
rótulo acessível e tooltip, e qualquer gesto de arrastar precisa de alternativa por
teclado.

### Modo escuro — 19/09/2026

O Chatwoot já troca de tema em Definições. **Não se cria interruptor novo.** O que
faltava era o escuro da direção A, e esse está gravado em
`design-system/aprovado/consultorio.tokens.json` (bloco `dark`), tirado da referência.

A proposta **C · Órbita não é o modo escuro**. C é violeta com primário `#6E8CFF`; A é
acromática com primário quase preto que inverte para quase branco. Usar C como escuro
de A dava dois produtos diferentes conforme a hora do dia. O que se aproveita de C é a
técnica — no escuro separa-se por degrau de luz, porque um fio de 1px desaparece —, e
isso já está nos tokens escuros de A.

### Campos do cartão e da oportunidade — 20/09/2026

Ficam como estão. A escolha de que campos aparecem **já é configuração**: *Comercial › Layout do
cartão* para o quadro (com pré-visualização), e *Gerir campos da oportunidade* para a gaveta.
«Procedimento» e «Profissional» nas apresentações são exemplos do que uma clínica configurou,
não campos fixos.

### Cor de ação — 19/09/2026

`--brand-color` passa a `#171717`. O azul `#2563EB` fica reservado a **etapa do funil**.
Consequência a tratar em cada tela que migrar: ligação de texto passa a distinguir-se
por sublinhado, não por ser azul.

---

## Antes de marcar uma tela como implementada

```bash
pnpm raevo:design    # nenhuma cor literal
pnpm raevo:tokens    # código de acordo com o sistema gravado
pnpm raevo:palette   # a paleta de etapas ainda valida
pnpm test            # os testes da tela
```

E a porta visual do `AGENTS.md`, com screenshot de desktop 1280px antes e depois.
