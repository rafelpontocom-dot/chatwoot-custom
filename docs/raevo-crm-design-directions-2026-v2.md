# Direcoes de Design Raevo CRM — v2

Data: 29 de agosto de 2026
Escopo: Kanban, Agenda e Financeiro
Mockups navegaveis: `output/raevo-design-2026-v2/index.html` (15 telas, deep link por hash — ex.: `#papel/agenda`)
Substitui: [raevo-crm-design-directions-2026.md](./raevo-crm-design-directions-2026.md) e [raevo-crm-experience-proposals.md](./raevo-crm-experience-proposals.md)

## Por que uma v2

As cinco direcoes anteriores (Sala de Operacoes, Mesa Clinica, Terminal de Receita, Atlas,
Estudio Modular) variaram **arquitetura de informacao** e mantiveram a mesma linguagem visual.
Por isso pareciam a mesma coisa e nenhuma resolveu a insatisfacao. O problema nunca foi onde
ficam as coisas — foi de que material elas sao feitas.

Evidencia no codigo. As tres telas reclamadas usam a mesma unidade visual herdada do upstream:

| Arquivo | Classe |
| --- | --- |
| `app/javascript/dashboard/routes/dashboard/finance/FinanceView.vue` | `rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-sm` |
| `app/javascript/dashboard/routes/dashboard/calendar/CalendarView.vue` | `rounded-lg border border-n-weak bg-n-solid-1` |
| `app/javascript/dashboard/routes/dashboard/kanban/KanbanConversationCard.vue` | `rounded-lg border border-n-weak bg-n-surface-1 shadow-none hover:shadow-sm` |

Uma caixa branca com borda cinza de 1px, raio 8px e sombra fraca resolve card, painel, tabela,
filtro e KPI. E `tailwind.config.js` importa as cores Radix `slateDark` direto do upstream — a
paleta Raevo (Pedra, Areia, Taupe, Carvao, Champagne, Ciano) nunca chegou a interface.

## Premissas desta rodada

- Liberdade total de paleta e tipografia por direcao. Nenhuma usa Sora/Inter.
- Tres telas cheias por direcao: Kanban, Agenda, Financeiro.
- Tema misto: cada direcao nasce clara ou escura conforme a propria tese.
- Cor validada por ferramenta, nao no olho.
- Os mesmos dados nas cinco telas — clinica de dermatologia, 15 oportunidades, 12 consultas,
  10 cobrancas — para a comparacao ser honesta.

## Tendencias de 2026 aplicadas

| Tendencia | Traducao pratica | Direcoes |
| --- | --- | --- |
| Calm design ("parece o Linear") | ornamento removido, cor so para estado | A, B |
| Densidade espacial, tabela como produto (Attio, Retool, Twenty) | edicao inline, teclado, numeros tabulares | A, E |
| Divulgacao progressiva | fim do painel-cockpit | todas |
| Dark-first de verdade | profundidade por luminancia, nao por sombra | A, C |
| Liquid Glass | translucidez com brilho de borda e eixo Z | C |
| Tipografia editorial e fontes variaveis | peso e largura no lugar de cor | B, E |
| Bento com camadas em Z | KPI modular sem mural de cartoes | C, D |
| Design orientado a decisao | a tela responde "o que faco agora" | todas |
| Design emocional retem | personalidade como requisito, nao enfeite | D |
| WCAG 2.2 | foco visivel, alvo >= 24px, alternativa a arrastar | todas |

Fontes: [saasui.design](https://www.saasui.design/blog/7-saas-ui-design-trends-2026),
[925studios](https://www.925studios.co/blog/saas-dashboard-design-examples-2026),
[ProCreator](https://procreator.design/blog/b2b-saas-design-trends-and-examples/),
[Pixelmatters](https://www.pixelmatters.com/insights/7-UI-design-trends-to-watch-in-2026),
[Midrocket](https://midrocket.com/en/guides/ui-design-trends-2026/),
[CRM Linear+Attio](https://salessheets.ai/blog/mobile-crm-linear-attio-design/),
[W3C WCAG 2.2](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/).

## As cinco direcoes

### A — Grafite · escuro, plano, de precisao

**Tese:** velocidade. Nada flutua, nada tem sombra; a profundidade vem de luminancia.

- Fundo `#0E1013`, superficies por clareamento, divisor = 1px de luz a 7% de branco. Zero sombra.
- Acento unico `#5B67E8`. Verde, ambar e vermelho **exclusivamente** estado de negocio.
- Inter Tight nos titulos, Inter nos dados, `tabular-nums` obrigatorio.
- Icone a traco 1,5px, 16px, sempre monocromatico.
- Kanban: colunas sem fundo, card de duas linhas com hairline de estado a esquerda.
- Agenda: grade de hairlines, evento chapado com barra de estado, linha do agora.
- Financeiro: tabela pura sem card, linha de 32px.
- **Risco:** frieza. Mitigacao — hierarquia tipografica forte.

### B — Papel · claro, editorial, sem caixas

**Tese:** um CRM que parece um documento bem impresso. Consultorio de alto padrao, nao SaaS.

- Off-white `#FAF7F1`, tinta `#17140F`. **Nenhum card**: hierarquia por filete, espaco e tipo.
- Cor quase ausente: verde-garrafa `#1F4D3D` e vermelho-tinta `#96271F`.
- Fraunces (serifa variavel) nos nomes e valores; IBM Plex Sans nos dados; versalete nos rotulos.
- Icone a traco 1px, quase gravura — texto quando couber.
- Kanban: filetes verticais, contador em serifa grande, card sem contorno.
- Agenda: o dia como pagina, hora em serifa de 26px na margem esquerda.
- Financeiro: extrato/balanco, total em regua dupla.
- **Risco:** menos densidade por tela. Mitigacao — modo compacto e Lista de primeira classe.

### C — Vidro · escuro profundo, liquid glass, premium

**Tese:** o produto de 2026 na mesa de demonstracao.

- Plano de fundo escuro com mesh (reaproveita o gesto do logo Raevo); paineis translucidos com
  blur 20px, brilho interno de borda e sombra difusa.
- Acento aqua `#19C7B7`.
- Manrope; icones solidos de 17px.
- Kanban: cada coluna e um painel de vidro. Agenda: linha do agora luminosa, eventos em vidro
  colorido. Financeiro: bento de 4 KPIs com sparkline + tabela solida abaixo.
- **Regra dura aplicada:** texto nunca sobre blur puro — todo painel tem placa solida atras.
- **Risco:** contraste e custo de GPU. Precisa de fallback sem `backdrop-filter`.

### D — Bloco · claro, neubrutalismo controlado, cor funcional

**Tese:** legibilidade a tres metros, para a secretaria em turno, sob pressao.

- Branco `#FCFBF7`, borda preta 1,5px, raio 4px, sombra **solida** deslocada `2px 2px 0`.
- Archivo pesada, rotulos em caixa alta com tracking.
- Icones solidos de 20px.
- Cor de etapa validada (ver abaixo). A etapa terminal usa a tinta preta — "encerrado" nao e
  categoria, e fim de trilha. Status reservados: pago `#047857`, a vencer `#B45309`, vencido `#DC2626`.
- Kanban: faixa de cor no topo, acao como botao de verdade dentro do card.
- Agenda: blocos chapados; **conflito de horario vira uma faixa tracejada vermelha rotulada**.
- Financeiro: status como selo (PAGO / VENCIDO / A VENCER).
- **Risco:** cansaco visual. Mitigacao — maximo de 6 cores no sistema, superficie de trabalho neutra.

### E — Trilho · claro, cronologico, sem containers

**Tese:** a tela nao e feita de caixas, e feita de tempo.

- Claro neutro-frio, superficies quase sem contorno, tudo ancorado em trilhos horizontais.
- **Cor = posicao no tempo**, nao categoria: frio `#8FB0F2` futuro, cinza `#6B7684` hoje,
  quente `#E0763A` atrasado, critico `#C0392B`.
- Roboto Flex como familia unica — hierarquia por peso e largura, nunca por cor.
- Kanban: etapas viram trilhos; o card e uma pilula posicionada por **tempo parado**. Atraso vira
  distancia fisica visivel; a altura do trilho conta quantos negocios estao parados ali.
- Agenda: um trilho por profissional, o dia como eixo; sobreposicao empilha em vez de cobrir.
- Financeiro: trilho de vencimentos — a inadimplencia aparece como acumulo a esquerda.
- **Risco:** quebra de convencao e ruim para operacao em lote. Mitigacao — Lista como alternativa
  de primeira classe nas tres telas.

## Cor verificada, nao escolhida no olho

A paleta categorica da direcao D passou pelo validador de daltonismo e contraste
(`validate_palette.js`, todos os pares, superficie clara).

O primeiro conjunto **reprovou**: azul `#2563EB` e violeta `#7C3AED` ficam a ΔE 0,4 em
deuteranopia — indistinguiveis. Descartado.

Conjunto final:

```
#2563EB  #0F9D8F  #B45309  #A21CAF

[PASS] faixa de luminosidade      todos dentro de L 0,43–0,77
[PASS] croma                      todos >= 0,1
[PASS] separacao CVD              pior par ΔE 9,7 (deuteranopia)
[PASS] visao normal               pior par ΔE 22,6
[PASS] contraste vs. superficie   todos >= 3:1
→ ALL CHECKS PASS
```

Nas direcoes A e C a cor e **estado**, nao categoria: a regra aplicavel e contraste WCAG por cor,
com icone e rotulo sempre acompanhando. Em E a escala e **divergente de tempo**, verificada por
monotonia de luminosidade em cada braco.

## Ate onde o design vai — Conversas e o miolo do Kanban

### Conversas: nao e escolha, e consequencia

Contagem no codigo: **60 dos 81 arquivos** `.vue` da tela de Conversas ja consomem os tokens `n-*`,
e existem apenas duas cores fixas fora deles (`#5E6AD2`, `#2781F6`). No dia em que os tokens mudam,
Conversas muda junto — nao ha como trocar a linguagem so nas outras telas.

O que se escolhe e **ate onde ir**:

| Nivel | O que muda | Esforco | Risco de merge |
| --- | --- | --- | --- |
| 0 · Herdado | paleta, tipografia e foco em toda a tela | zero, vem de graca | nenhum |
| 1 · Chrome | lista, cabecalho, filtros, composer | medio | contido |
| 2 · Miolo | baloes, editor, painel de contato, anexos | alto | conflito eterno |

Conversas e **upstream quase puro**: dos commits Raevo, so quatro arquivos a tocaram, e dois sao
i18n. Mexer no miolo significa conflito em todo `git pull` do Chatwoot.
**Recomendacao: parar no nivel 1.**

### O Kanban nao e so o quadro

| Superficie | Linhas | Natureza |
| --- | --- | --- |
| `KanbanBoardSettings.vue` | 6.574 | configuracoes do funil, 100% Raevo |
| `KanbanAutomations.vue` | 4.090 | fluxos, cadencias, execucoes, 100% Raevo |
| `KanbanView.vue` | 3.054 | o quadro |
| `KanbanOpportunityDetailsModal.vue` | 2.646 | drawer com abas, 100% Raevo |

Cerca de **16 mil linhas**, todas codigo Raevo — zero risco de merge, custo puro de trabalho. Abas
do drawer hoje: Geral, Agenda, Marketing, Historico, mais as criadas pelo cliente. Abas de
Automacoes: Fluxos, Cadencias, Lembretes, Conexoes, Execucoes.

### A regra do peso — o que resolve o "cansa"

O problema nunca e peso visual em si; e **peso em superficie de leitura longa**. Um quadro Kanban
se varre em tres segundos e a borda forte ajuda. Uma conversa de 200 mensagens se le por vinte
minutos e a mesma borda vira ruido.

Regra adotada pelo sistema, valida para qualquer direcao escolhida:

> **O peso vive no chrome. A leitura fica leve.**

Em Conversas na direcao D: cabecalho, lista, filtros e composer mantem borda preta de 1,5px e
sombra solida; os baloes perdem as duas e viram superficies chapadas (`#F1EFE8` recebido,
`#DCE9FF` enviado, `#FEF6DC` com tracejado para nota da Elis). Mesma direcao, mesma paleta, sem
fadiga.

Observacao da comparacao lado a lado: **C · Vidro cansa menos em Conversas do que no Kanban** —
ali existem poucos paineis de vidro competindo. O cansaco do C aparece quando ha cinco colunas
translucidas simultaneas.

## A costura com o Chatwoot — como o D pega o produto inteiro

### O mecanismo que ja existe

O Chatwoot nao escreve cor nos componentes. Ele monta assim:

1. `app/javascript/dashboard/assets/scss/_next-colors.scss` (308 linhas) define
   `:root { --slate-1..12, --blue-*, --iris-*, --ruby-*, ... }` como triplets RGB, dentro de `@layer base`.
2. `theme/colors.js` mapeia as classes Tailwind: `n-slate-12` -> `rgb(var(--slate-12) / <alpha-value>)`.
3. Os componentes usam `bg-n-solid-1`, `text-n-slate-12`, `border-n-weak`.
4. `_woot.scss` importa `next-colors` na ordem.

**Consequencia:** um arquivo novo `_raevo-tokens.scss`, importado depois de `next-colors`,
redefine `:root { --slate-*: ... }` e **repinta o produto inteiro** — Caixa de entrada, Conversas,
Contatos, Relatorios, Campanhas, Central de Ajuda e Configuracoes — sem editar um unico arquivo
upstream. `git pull` pode reescrever `_next-colors.scss` por completo; o arquivo Raevo continua
vencendo por vir depois na cascata.

### Forma segue o mesmo caminho

Raio, espessura de borda, sombra e fonte nao estao espalhados pelos componentes: vivem na escala do
Tailwind. Redefinir em `tailwind.config.js`:

| Chave | De | Para (D · Bloco) | Efeito |
| --- | --- | --- | --- |
| `borderRadius.lg` | 8px | 4px | todo `rounded-lg` do produto |
| `borderWidth.DEFAULT` | 1px | 1.5px | toda `border` do produto |
| `boxShadow.sm` | difusa | `2px 2px 0` | todo `shadow-sm` do produto |
| `fontFamily.inter` | Inter | Archivo | toda `font-inter` do produto |

### Custo total de merge

| O que muda | Onde | Linhas | Conflito |
| --- | --- | --- | --- |
| Paleta inteira | `_raevo-tokens.scss` (**novo**) | ~60 | nenhum |
| Import do arquivo | `_woot.scss` | 1 | trivial |
| Raio, borda, sombra, fonte | `tailwind.config.js` | ~15 | pequeno |
| Ajustes por componente | `_raevo-overrides.scss` (**novo**) | ~120 | nenhum |

**Dois arquivos novos e cerca de 16 linhas em dois arquivos existentes.** Nao ha nada para refazer
a cada atualizacao do Chatwoot: conflito so acontece se o upstream mexer exatamente nessas 16
linhas, e a resolucao e de minutos.

### O que token nao resolve

Token resolve **cor, tipo e forma**. Nao resolve **estrutura**: se o Chatwoot poe um filtro dentro
de um modal e o Kanban poe numa barra, a diferenca permanece. Tres desvios previsiveis e a decisao
para cada um:

1. **Sombra solida em modais e dropdowns** fica estranha em menu flutuante. Restringir o
   `2px 2px 0` a cards e paineis; menus mantem sombra difusa. Regra no arquivo de overrides.
2. **Caixa alta nos rotulos** e marca do D, mas o Chatwoot tem texto longo em `.text-label`.
   Aplicar so em cabecalho de tabela e chip, nunca em rotulo de formulario.
3. **Central de Ajuda** e conteudo editorial, nao operacao. Herda so paleta e fonte; sem borda
   preta e sem sombra solida.

Estimativa: o produto fica coerente em cerca de **90% por heranca automatica**; os 10% restantes sao
uma lista curta de regras num arquivo que o upstream nunca toca.

### Prova

Os mockups incluem Contatos, Relatorios e Campanhas — telas que o Raevo nao escreveu — renderizadas
com os dois conjuntos de tokens. **A marcacao e identica nas duas versoes.** O que muda e so o
arquivo de tokens.

## Comparativo

| Direcao | Rotina de clinica | Volume comercial | Demonstracao | Acessibilidade | Custo |
| --- | --- | --- | --- | --- | --- |
| A Grafite | media | **otima** | media | **otima** | **baixo** |
| B Papel | **otima** | fraca | **otima** | **otima** | medio |
| C Vidro | media | media | **otima** | atencao | alto |
| D Bloco | **otima** | media | media | **otima** | medio |
| E Trilho | **otima** | media | **otima** | media | alto |

## Recomendacao

**B · Papel como base, com o Financeiro de E · Trilho.**

Papel e a unica direcao que resolve os dois problemas de uma vez: nao parece software generico e
e a mais calma para quem passa oito horas na tela. O preco e densidade, e paga-se mantendo a Lista
compacta como alternativa de primeira classe. Do Trilho vem so o Financeiro: cobranca acontece no
tempo, e ver a inadimplencia se acumular a esquerda ensina mais que qualquer tabela.

Se a prioridade for **fechar contrato em demonstracao**, a resposta muda para C · Vidro. Se for
**produtividade de equipe comercial em volume**, muda para A · Grafite. As tres sao defensaveis.

### Atualizacao apos a prova de resistencia

D · Bloco passou nas quatro superficies dificeis (Conversas, drawer, automacoes, configuracoes) com
a regra do peso aplicada. O risco que eu tinha apontado — "cansaco visual" — tem mitigacao concreta
e verificavel, nao apenas teorica. **D deixa de ser a aposta arriscada e vira alternativa de
primeira linha**, especialmente porque o Kanban em D e o que melhor resolve leitura rapida sob
pressao.

Se a escolha for D, o unico ajuste que eu ainda recomendo e emprestar o Financeiro de E · Trilho,
pelo mesmo motivo de antes: cobranca acontece no tempo.

## Decisoes a aprovar

1. Uma direcao principal e no maximo dois emprestimos de outra.
2. O papel do escuro: so navegacao ou superficie de trabalho inteira.
3. Densidade padrao do card: compacto sempre, detalhe so no painel lateral.
4. Se a marca Raevo (Champagne e Ciano) entra agora, dentro da direcao escolhida, ou depois.
5. Se `Hoje` vira visao transversal das tres telas ou continua dentro do Kanban.

## Caminho de implementacao (apos a escolha)

Trocar tokens, nao reescrever telas:

1. `theme/colors` e `tailwind.config.js` passam a definir os `n-*` com os valores da direcao.
2. As tres views consomem tokens semanticos novos (`--surface-work`, `--rail-overdue`,
   `--stamp-paid`) no lugar do `rounded-lg border border-n-weak bg-n-solid-1 shadow-sm` repetido.
3. Isso troca a aparencia do produto inteiro mexendo em poucos arquivos e mantem o upstream do
   Chatwoot mergeavel — ver [raevo-chatwoot-upstream-maintenance.md](./raevo-chatwoot-upstream-maintenance.md).

## Porta de qualidade

1. Prototipo aprovado por secretaria, medico e gestor antes de codificar a tela real.
2. Cada modulo recebe especificacao de estados: vazio, carregando, erro, sucesso, permissao
   insuficiente e alto volume.
3. Teste visual em 1280px e 1024px; teste de teclado em todas as acoes primarias.
4. Foco visivel, alvos de pelo menos 24px e alternativa a arrastar (WCAG 2.2).
5. Nenhum componente novo entra sem token semantico, rotulo acessivel, tooltip para icone e
   verificacao de contraste.
