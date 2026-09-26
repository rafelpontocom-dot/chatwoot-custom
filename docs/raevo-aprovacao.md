# Fila de aprovação de telas — Raevo

A direção **A · Consultório** está aprovada (19/09/2026). O sistema está gravado em
[`design-system/aprovado/`](../design-system/aprovado/README.md).

Este documento é a outra metade: **nenhuma tela existente muda sem passar por aqui.**

---

## O demonstrador do sistema aprovado · 26/09/2026

O artefacto [`2ACSDXn19DZKFWUos9pnaA`](https://claude.ai/artifact/2ACSDXn19DZKFWUos9pnaA)
mostra catorze telas na direção aprovada. Ele **não** era um plano de
implementação — a fila abaixo trata tela a tela, e o artefacto tem ecrãs que não
têm linha nenhuma nela. Isso custou confiança: o produto ficou com a cor e o raio
certos e sem a caixa, sem os indicadores, e a distância era estrutural e não um
atraso de backlog.

Decisão do produto a 26/09: **o demonstrador passa a ser especificação**, sem
aprovação tela a tela, exceto a Conversa, que sai de âmbito (é tela nativa do
Chatwoot e redesenhá-la encarece cada `git pull`).

### O que está implementado

| Tela | Estado | Nota |
| --- | --- | --- |
| **A caixa** (densidade) | ✅ | `density` da direção aprovada nunca tinha chegado ao código. Treze valores em `_raevo-tokens.scss`, utilitárias nomeadas no Tailwind, e uma invariante em `raevo:tokens` que compara o código com a direção |
| **Primitivos** | ✅ | `RaevoKpiCard` (abre cinco telas) e `RaevoTimeline` (histórico em trilho) |
| **Financeiro** | ✅ | fila de quatro; `PaymentsSummary` ganhou o recorte mês-a-mês por `paid_at` e a idade da mais antiga em atraso |
| **Oportunidade** | ✅ | valor como manchete a 30px, assunto a 20px, últimos três eventos em linha |
| **Início** | ✅ | fila de quatro, opt-in por módulo. Sem variação: o servidor desta tela não guarda histórico |
| **Pipeline** | ✅ | fila de quatro; `KanbanBoards::CommercialSummary` novo |
| **Agenda** | ✅ | fila de quatro por contagem de `status` |
| **Visão de funil** | ✅ | tela própria, `KanbanBoards::FunnelSummary` novo. Quatro contagens por etapa, nunca somadas: entraram e avançaram são fluxo na janela, perdidas é fecho na janela, abertas é agora |
| **IA** | ✅ | a fila passou a `RaevoKpiCard` e ganhou as conversas, que eram o denominador das outras três e viviam só dentro das legendas |

### O que falta, e o que impede

| Tela | O que falta | Porquê não está feito |
| --- | --- | --- |
| **Marketing** | custo por lead, receita atribuída | **Bloqueado por falta de dados.** Não existe schema para custo de campanha nem para atribuição de receita. Implementar exige decidir como a clínica introduz esses dados — é produto, não frontend |
| **Agenda · ocupação** | taxa de ocupação | Exige cruzar regras de disponibilidade por dia e por recurso, sobreposições de data, blocos externos e durações. Uma ocupação errada é pior do que nenhuma |

### A regra que atravessa tudo o que foi implementado

**Nenhum número inventado.** Onde o servidor sabe comparar, o cartão tem seta;
onde não sabe, não tem. Onde a métrica não existe no modelo, foi substituída por
uma derivável e isso está escrito:

- «A receber hoje» → **Cobranças vencidas** (o servidor não sabe a primeira)
- «Taxa de qualificação» → **Taxa de fecho** (`KanbanStage::CATEGORIES` é
  `open · won · lost`; não há qualificação no modelo)
- «Taxa de ocupação» → não substituída; fica de fora com a razão acima

Há testes que afirmam a **ausência** de setas onde não há base de comparação. Se
alguém puser lá um delta, o teste cai. Na IA a ausência é por a ponte devolver uma
janela e não a anterior; na Visão de funil, a conversão de uma etapa onde nada
entrou vem `nil` e sai como travessão.

### Uma correcção a este documento · 26/09/2026

A linha que estava aqui sobre a IA dizia que ela «precisa de agregações novas
sobre conversas e mensagens». **Estava errada.** As métricas já existiam:
`RaevoAi::OverviewClient` traz `conversations`, `responses_delivered`,
`first_response_seconds`, `handoffs`, `pre_scheduled`, `appointments` e
`payments` da ponte, e `RaevoAi::FunnelMetrics` acrescenta
`opportunities_created` desta base. O que faltava era a **anatomia**: a tela
desenhava-as num `<dl>` empilhado — o quarto tratamento de cartão de número no
produto — em vez do `RaevoKpiCard` que serve as outras cinco. A dívida era de
apresentação, não de dados, e ficou mais pequena do que este documento dizia.

### A fila de indicadores tinha uma densidade só · 26/09/2026

O dono do produto viu a fila no Pipeline e na Agenda e disse o mesmo das duas:
«ficou muito grande». Tinha razão, e a causa não era o tamanho dos cartões — era
o **papel** deles. Nas duas telas o assunto não é o número: é o quadro de
colunas, é a grelha de horas. Quatro cartões de 139px empurravam a superfície de
trabalho para fora do ecrã, e era isso que se sentia.

Havia um segundo defeito, que o texto colado pelo dono do produto mostra melhor
do que qualquer descrição: numa conta sem histórico, **três dos quatro rodapés
diziam «sem mês para comparar»**. A fila gastava a sua linha mais larga a
desculpar-se, exatamente no caso em que há menos para mostrar.

**Decisão.** `RaevoKpiCard` passa a ter duas densidades, e a escolha entre elas é
uma regra e não um gosto:

- `density="card"` — caixa própria, número a 30px, rodapé sob um filete. Para o
  Início, o Financeiro e a IA, onde a fila **é** o topo da tela.
- `density="strip"` — a mesma anatomia sem caixa, rótulo em caixa alta, número a
  16px. Para o Pipeline e a Agenda, onde a superfície de trabalho tem de aparecer
  sem rolar.

No Pipeline a faixa mora **dentro da caixa do cabeçalho**, separada por um
filete: era o que o dono do produto tinha pedido. A Agenda não tem caixa de
cabeçalho — a barra é de uma linha, ao estilo Google — por isso ali a faixa é a
banda logo abaixo dela, com o mesmo `px-4` e o mesmo filete, e lê-se como
continuação do cabeçalho. É a mesma forma no sítio que cada tela tem.

O rodapé passa a ficar **vazio** onde não há base de comparação, em vez de trazer
a frase. A ausência de seta já diz que não há mês anterior; a chave `NO_BASELINE`
de `KANBAN.INDICATORS` e de `CALENDAR.INDICATORS` deixou de ser usada e saiu dos
três catálogos. (A de `FINANCE` fica: essa tela continua a usá-la, e mantém a
densidade de cartão.)

**O que a porta visual mediu**, a 1280×900, na aplicação real com dados semeados:

| | Pipeline | Agenda |
| --- | --- | --- |
| Fila, antes | 139px | 151px |
| Fila, depois | **76px** | **84px** |
| Superfície de trabalho começa a | 362px → **311px** | 240px → **176px** |
| Efeito visível | — | a semana abria às 8:00 e parava nas 15:00; agora chega às 16:00 |

Capturas de claro e de escuro nas duas telas. No escuro o rótulo e o rodapé ficam
a 6,94:1 sobre a caixa do cabeçalho e a 7,66:1 sobre o fundo da Agenda; no claro,
4,74:1 nos dois — o par mais apertado, e passa os 4,5:1 da WCAG 2.2. O rodapé usa
`text-xs` e não `text-micro`: `micro` está reservado a selo, contador e cabeçalho
em caixa alta, e o rodapé é texto corrido.

**O que NÃO mudou, e porquê.** O Financeiro e a IA abrem também com uma fila de
quatro cartões sobre uma lista, e a mesma leitura aplica-se-lhes. Ficaram como
estavam porque o pedido nomeou duas telas, e mudar as outras duas sem o dizer é
alargar âmbito por conta própria. Com a densidade já no primitivo, aplicá-la a
cada uma é uma linha por tela.

**Duas coisas que as capturas mostram e esta mudança não resolve.** O «Ciclo
médio» aparece como **−6 dias** nos dados semeados: um ciclo negativo é possível
quando `won_at` antecede `created_at`, e o importador não impede. E
`CALENDAR.INDICATORS.LAST_MONTH` já não era usada por tela nenhuma antes desta
mudança — a Agenda compara por percentagem do mês. Ficam registadas em vez de
corrigidas de passagem: nenhuma das duas é desta mudança.

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
| 1 | Pipeline (quadro) | Kanban | 37 `.vue` no módulo | **aprovada 20/09, fechada 21/09** — [ver](https://claude.ai/artifact/8QXUMLHhsJDUSdMsjPgJbw) | quadro, lista, filtros e gaveta implementados; o atalho de teclado do cartão também |
| 2 | Oportunidade aberta (gaveta) | Kanban | `KanbanOpportunityDetailsModal.vue` | **aprovada 20/09, implementada 26/09** — [ver](https://claude.ai/artifact/QcWYpjBJq9kKkjGCFEiqxx) | manchete do valor, assunto a 20px e histórico em trilho. A coluna fixa do demonstrador não entrou: dois testes travam a gaveta em uma coluna, «so the commercial context cannot overlap fields» |
| 3 | Início | Home | 1 | **apresentada 20/09, indicadores em 26/09** — [ver](https://claude.ai/artifact/DLSQZn7N2pW3xmWwuUKCr1) | não é painel: é fila de trabalho. A fila de quatro indicadores entrou; sem setas, porque o controlador não guarda histórico |
| 4 | Financeiro | Finance | 3 | **sem artefacto, corrigida 21/09, indicadores em 25/09** | a permissão limitada foi adiada por decisão do produto. O estado com cor+ícone faltava no detalhe; a fila de quatro substituiu a faixa de três células |
| 5 | Agenda | Calendar | 30 | **decidido — ver abaixo** | vista atual fica; a nova é alternativa |
| 6 | Formulários | Forms | 10 | **sem artefacto, migrados 21–25/09** | os 81 controlos passam pelo primitivo; teal deixou de ser cor de ação |
| 7 | Automação (Vue Flow) | Kanban | — | **aprovada 21/09** em três partes: [cartão de nó](https://claude.ai/artifact/U17sPjtbUM9v3fDZjwEZCH) · [painel do nó](https://claude.ai/artifact/32yjwdj7RykSaQjrLX6RZr) · lista sem artefacto | implementada; falta só o deslocamento da tela — ver abaixo |
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
| ~~**Vista de lista**~~ | `KanbanListView.vue` | **aprovada 20/09** e **implementada 21/09** — as quatro correções, ver abaixo. [Artefacto](https://claude.ai/artifact/Fz5vKHs88RxhmUZFh8Fnmm) |
| ~~**Painel de filtros**~~ | dentro de `KanbanView.vue` | **aprovada 20/09** e já no código, no mesmo artefacto |
| ~~**Definições — navegação**~~ | `KanbanBoardSettings.vue` | **aprovada 21/09** e implementada — ver abaixo. Apresentada a 20/09 como «oito separadores» — [ver](https://claude.ai/artifact/QhRFTYWLU4zqbepe4pR3dy) |
| ~~**Definições — Comercial**~~ | `KanbanBoardSettings.vue` | **aprovada 21/09** e implementada — «Comercial» deixou de existir, ver abaixo. Apresentada a 20/09 — [ver](https://claude.ai/artifact/BffGSQm15W3rGxhh2vWM6g) |
| ~~**Automações**~~ | `KanbanAutomations.vue`, `KanbanWorkflowNode.vue`, `KanbanWorkflowInspector.vue` | **aprovada e implementada 21/09**, em três partes — ver abaixo |
| ~~**Visão de funis**~~ | `KanbanOverview.vue` | **sem artefacto, corrigida 21/09** — a «ordenação própria» são botões de subir/descer para administrador, o mesmo padrão já aprovado nas etapas. Não havia decisão para tomar, só três títulos a depender de corte |

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

### Financeiro — a vista limitada foi adiada, e a tela encolheu · 21/09/2026

A tela 4 estava na fila por duas razões: «estado de cobrança sem depender de
cor», e decidir o que a secretária vê sem permissão financeira. **Ambas caíram**,
por razões diferentes.

**A permissão limitada foi adiada por decisão do produto.** Todos veem, e a
estratégia fica para quando houver uso real a observar. Fica registado o que
tinha sido proposto e porquê, para não se repetir a análise:

- A janela de 3–5 dias **não serve como permissão**. Uma paciente que ligue ao
  8.º dia deixa a secretária sem resposta para um sim/não, obrigando-a a
  interromper quem tem permissão financeira. E 3–5 dias não cobre um fim de
  semana: pagamento à sexta, pergunta à segunda.
- O corte que faria sentido não é a **idade** do registo, é o **detalhe
  financeiro**: estado e data para toda a gente; valores, taxas, meio de
  pagamento, tentativas e IDs de provedor atrás de permissão. Esse corte não
  expira.
- A janela **serve como filtro por omissão** — sete dias, não três — com um
  controlo visível para alargar.
- **Decidido a 21/09: a secretária vê o valor.** Era a única pergunta em aberto,
  e a razão que ganha é a operacional — ela é quem diz à paciente «são 450
  reais», e escondê-lo obrigava-a a perguntar a alguém para fazer o trabalho
  básico dela. Se um dia se retomar a vista limitada, o valor fica do lado de cá
  do corte.

**O estado com cor e ícone já existia — na lista.** Os nove estados tinham tom e
ícone, com o raciocínio escrito no ficheiro. Faltava no **diálogo de detalhe**,
que mostrava o estado como texto cinzento — o pior sítio possível, porque o
detalhe é onde se confirma «isto foi pago?» antes de o dizer a alguém. A causa é
a de sempre: o tratamento vivia dentro do `FinanceView.vue`, e o diálogo não lhe
chegava. Passou para `helper/financePaymentStatus.js` e serve os dois.

Mais três desvios: o **nome do contacto** e o **assunto da oportunidade**
dependiam de corte (quarta vez que o assunto aparece assim), e quatro
`shadow-sm` mortos em cartões que já se separam pela borda.

### Visão de funis — o Kanban fecha mesmo · 21/09/2026

Estava na lista do que «precisa de aprovação própria», por causa da «ordenação
própria». Fui ver: são botões de subir e descer visíveis só para administrador,
que chamam `reorderBoard`. É o mesmo padrão já aprovado para as etapas — não é
uma ordenação nova, é a mesma. **Não havia decisão para tomar**, e apresentá-la
teria sido o caminho caro de que este documento avisa.

O que havia eram três títulos a depender de corte:

| Onde | Ficou |
| --- | --- |
| nome do funil arquivado | quebra de palavra |
| **nome da etapa** no selo do funil | quebra de palavra — o `AGENTS.md` nomeia «títulos de etapa» entre os proibidos, e o selo é `max-w-full` |
| nome da caixa de entrada | continua cortado, porque o selo é estreito de propósito, mas ganhou `title` — sem ele não havia como ler o resto |

Com isto o Kanban fecha: quadro, lista, filtros, gaveta, Configurações,
Automação e visão de funis.

### Automação — três partes em vez de um artefacto só · 21/09/2026

A tela mais construída do produto: 26 tipos de nó em 8 categorias, 147 KB na
lista e 76 KB no construtor. Um artefacto a cobrir tudo isto ficava superficial —
o mesmo argumento que já se tinha usado para os separadores das Configurações.
Partiu-se em três, e a terceira não precisou de artefacto nenhum.

**O risco desta tela nunca foi visual.** É que acrescentar o 27.º nó é mais
barato do que organizar os 26. A paleta já tem pesquisa e categorias
colapsáveis — a arquitetura Node-RED que o `AGENTS.md` pede já estava feita.

**7a · Cartão de nó** — cinco defeitos, todos verificáveis:

| Estava | Ficou |
| --- | --- |
| `text-2xs` em 9 sítios | a classe **não existia** em lado nenhum; oito passam a `text-micro`, uma a `text-xs` |
| oito matizes de categoria | a categoria é o **ícone**; a cor fica para o estado |
| selo de estado só com cor | cada estado com ícone próprio |
| `shadow-sm` + `hover:shadow-md` | anel de 1px em repouso |
| altura entre ~56px e ~120px | nome em duas linhas fixas, resumo numa, rodapé sempre presente |

A decisão que pesou foi tirar a cor às categorias. Oito matizes nunca passaram
pelo validador de daltonismo, e azul, iris e violeta são três vizinhos — o
`AGENTS.md` proíbe azul + roxo claro por ΔE 0,4. Mais fundo do que isso: neste
produto a cor já quer dizer «etapa do funil», e duas gramáticas de cor na mesma
cabeça não funcionam. A alternativa registada, se um dia se quiser cor de
categoria, é **quatro** matizes da paleta validada, com as oito categorias
fundidas em quatro grupos primeiro.

**7b · Painel do nó** — era um modal centrado de 44rem com véu sobre toda a
tela. Configurar um nó é decidir sobre o grafo, e o véu apagava exatamente isso.
A mesma doença que as Configurações tiveram, e já descrita no próprio código.
Passa a painel encostado à direita, 320px, sem véu, com a tela clicável por trás.
`aria-modal` acompanha o formato — no telemóvel continua folha com véu, e aí o
véu diz a verdade.

Duas coisas que só apareceram a implementar:

- As três grelhas de condição do Router empilhavam pela largura do **ecrã**, não
  da caixa. Num monitor grande com um painel de 320px tentavam as cinco colunas
  — que precisam de ~490px — e ficavam ilegíveis. Empilham sempre.
- Havia uma **segunda cópia** das oito matizes de categoria, no construtor, a
  alimentar o cabeçalho do painel. Saiu com a do cartão, senão o painel
  contradizia o nó que está a configurar.

**Por fazer, deliberadamente:** a tela não se desloca para trazer à vista um nó
que fique por baixo do painel. É matemática de viewport que não se consegue ver
a funcionar sem a aplicação a correr, e errá-la faz a tela saltar a cada
seleção — pior do que um nó ocasionalmente tapado.

**7c · Lista de automações** — sem artefacto, por herdar primitivos já
aprovados. A auditoria das 4123 linhas deu sete desvios das regras e nenhuma
decisão de arquitetura: quatro títulos que dependiam de corte (nome da
automação, da conexão, da execução e dos modelos), duas sombras que não
separavam nada porque `shadow-sm` é `none`, um raio de pílula num botão, um
`shadow-xl` onde a regra pede `lg`, e um `min-h-[54px]` fora de escala que o
conteúdo já resolvia em 48.

### Vista de lista — as quatro correções, implementadas · 21/09/2026

Aprovada a 20/09, implementada a 21/09. Com ela o **Pipeline fecha**: quadro,
lista, painel de filtros e gaveta da oportunidade estão todos no código.

| Elemento | Estava | Ficou |
| --- | --- | --- |
| Assunto da oportunidade | `truncate`, uma linha | duas linhas com quebra de palavra |
| Etapa | texto simples, sem cor | selo com a cor da etapa e um ponto |
| Próxima ação | só cor de texto | selo com cor + ícone + texto |
| Sem resultados | uma frase centrada | ícone, título, explicação e saída |

Duas notas que não estavam no artefacto e que a implementação obrigou a decidir:

- **As ações do vazio só aparecem com filtros ativos.** O artefacto mostrava
  «Limpar filtros» e «Rever filtros» sempre. Oferecer uma saída quando não há
  filtro nenhum é prometer o que não existe: a lista passa a distinguir «ainda
  não há oportunidades» de «nenhuma com estes filtros», e só a segunda tem
  botões.
- **A tabela de estados da próxima ação passou a ser partilhada.** Estava dentro
  do `KanbanConversationCard.vue`; a lista precisava da mesma e copiá-la ia
  divergir. Vive agora em `app/javascript/dashboard/helper/kanbanNextAction.js`
  e serve as duas superfícies. O assunto cortado apareceu três vezes neste
  produto precisamente porque cada tela resolvia o seu.

### Definições — «Comercial» morreu e repartiu-se · 21/09/2026

Decidido e implementado no mesmo dia. A contagem de chaves acima (141, 62,4% do
ecrã) já não descreve o código: os campos saíram para a entrada «Campos» antes
desta decisão, e agora sai o resto.

O diagnóstico: **«Comercial» não era uma categoria, era o resto.** Sobraram lá
quatro coisas sem nada em comum — layout do cartão, um segundo editor de campos
em JSON, alertas de oportunidade parada e lembretes de agendamento. Nenhum nome
honesto cobre as quatro, e um rótulo de navegação que não prevê o conteúdo
obriga a abrir para saber o que lá está.

| Estava em «Comercial» | Foi para | Porquê |
| --- | --- | --- |
| Layout do cartão compacto e pré-visualização | **«Cartão»** (`i-lucide-credit-card`) | é o que se vê no quadro, não é comercial |
| JSON avançado | **«Campos»**, dobrado num `<details>` «Editar em JSON» | editava o mesmo `custom_field_definitions` que «Campos» edita com UI — dois editores para o mesmo dado |
| Alertas de oportunidade parada | **«Avisos»** (`i-lucide-bell-ring`) | é uma regra de aviso |
| Lembretes de agendamento | **«Avisos»** | é a mesma regra: «se X, avisa a equipa» |

Navegação final, oito entradas: Geral · Acesso · **Cartão** · Campos ·
**Avisos** · Agenda · Automação · — Apagar funil.

Duas decisões que ficam registadas porque são contra-intuitivas:

- **Os dois avisos ficam declarativos, não vão para o Vue Flow.** Formalmente são
  automações, e o `AGENTS.md` diz que automação vive no Vue Flow. Um interruptor e
  um número é a forma certa para quem trabalha na recepção; uma tela não é. Para
  «Avisos» não crescer até ser um segundo motor, a secção diz em texto que são
  estas duas regras e que o resto vive em Automação.
- **O JSON não foi apagado.** É saída de emergência para o que a UI de campos
  ainda não alcança. Dobrado, e num sítio cujo nome o anuncia.

O que acelerou a decisão: o rail «Oportunidades paradas» do Início lê
`kanban_board.stale_days_for_stage` — a definição que o alimenta estava enterrada
debaixo de uma entrada chamada «Comercial», onde ninguém a ia procurar.

**Duas propostas de 20/09 que o código resolveu de outra maneira**, e que ficam
corrigidas aqui:

- «Apagar funil sai da navegação, para uma zona de perigo no fim de Geral» —
  **não foi isso**. Ficou na navegação, no fim, separado por um filete e em rubi.
  Enterrá-lo dentro de Geral resolvia o peso visual e estragava a descoberta: quem
  procura como apagar um funil percorre a lista da navegação.
- «Agentes e Caixas de entrada são o mesmo componente, um primitivo só» — **já
  está feito**, fundidos na entrada «Acesso».

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
