# Raevo Design System — padrões de tela e checklist

> ### ⚠︎ A direção é A · Consultório, e já está no código
>
> Aprovada a **19/09/2026**, migrada para o código a **21/09/2026**:
> **[A · Consultório](../design-system/aprovado/README.md)**. Este documento nasceu para
> H · Sereno e o cabeçalho ainda dizia que o código estava em Sereno — **não está**, e
> essa frase custou retrabalho: foi com ela que a pílula do campo sobreviveu cinco meses
> à migração, porque quem a lia concluía que `rounded-full` continuava a ser o padrão.
>
> O que aqui continua a valer: **os padrões de tela, os primitivos, a acessibilidade e o
> checklist de PR**. Onde a direção diverge — cor de ação, raio do controlo, separação
> por anel, modo escuro — manda o `README.md` da direção aprovada, e o resumo executável
> é o `AGENTS.md`.
>
> **Correção de 25/09/2026 — a tabela de forma.** O §3 descrevia a escala de Sereno
> (7 · 9 · 11 · 13px) e dava pílula a todo o botão e a todo o campo de uma linha. Ficou
> assim quatro dias depois de o código migrar, com um aviso em cima em vez de uma
> correção — e foi o aviso que falhou: quem lia a tabela concluía que `rounded-full`
> era o padrão. A tabela está agora nos valores que o `tailwind.config.js` tem.

**Status:** aprovado em 29/08/2026 · é o que o código tem, até cada tela migrar
**Fonte da verdade em código:** `app/javascript/dashboard/assets/scss/_raevo-tokens.scss`
**O sistema como dado:** [`design-system/raevo.tokens.json`](../design-system/raevo.tokens.json) — extraído do código e verificado em CI por `pnpm raevo:tokens` ([como mudar um valor](../design-system/README.md))
**Referência viva:** `design-system/reference.html` — gerada dos tokens, com alternador de tema
**Mockups de referência:** `output/raevo-design-2026-v2/index.html` (direção "H · Sereno")
**Como chegamos aqui:** [raevo-crm-design-directions-2026-v2.md](./raevo-crm-design-directions-2026-v2.md)

> **Regra única e inegociável:** nenhum componente escreve cor, raio, sombra ou fonte
> literal. Tudo vem de token. Se falta um token, crie em `_raevo-tokens.scss` — não
> resolva no componente.

---

## 1. Como a identidade chega ao produto

O Chatwoot não escreve cor nos componentes. Ele monta assim:

```
_next-colors.scss   define  :root { --slate-12: 28 32 36; ... }
theme/colors.js     mapeia  n-slate-12 -> rgb(var(--slate-12))
componentes .vue    usam    class="text-n-slate-12 bg-n-solid-1 border-n-weak"
```

O Raevo entra **depois**, sem editar nada do upstream:

| Arquivo | Papel | Upstream mexe? |
| --- | --- | --- |
| `app/javascript/dashboard/assets/scss/_raevo-tokens.scss` | redefine os tokens de cor | nunca |
| `app/javascript/dashboard/assets/scss/_raevo-components.scss` | o que token não alcança | nunca |
| `app/javascript/dashboard/assets/scss/_woot.scss` | 3 linhas de import | raramente |
| `tailwind.config.js` | raio, borda, sombra, fonte | raramente |
| `theme/colors.js` | 1 linha: brand vira token | raramente |

`_raevo-tokens.scss` fica **fora de `@layer base`** de propósito. CSS sem layer sempre
vence CSS em layer, então um `git pull` do Chatwoot pode reescrever a paleta inteira
dele que a nossa continua valendo.

**Consequência:** trocar um valor em `_raevo-tokens.scss` muda o produto inteiro —
Conversas, Contatos, Relatórios, Campanhas, Central de Ajuda e as telas do Raevo.

---

## 2. Cor

### Neutros
| Token | Valor | Uso |
| --- | --- | --- |
| `bg-n-background` | `#F7F8FA` | fundo da aplicação |
| `bg-n-solid-1` / `bg-n-card` | `#FFFFFF` | card, painel, linha de tabela |
| `bg-n-slate-3` | `#F2F4F7` | chip, faixa alternada, campo desabilitado |
| `border-n-weak` | `#E9EBEF` | contorno padrão de card |
| `border-n-strong` | `#DCDFE5` | contorno de controle |
| `text-n-slate-12` | `#111827` | tinta, títulos, valores |
| `text-n-slate-11` | `#4B5563` | corpo |
| `text-n-slate-10` | `#7A828F` | secundário (4,6:1 no branco) |
| `text-n-slate-9` | `#98A0AE` | placeholder, apoio decorativo |

### Ação
Um acento só. `bg-n-brand` = `#2563EB`. Fundo suave = `bg-n-blue-3` (`#EFF4FF`).

### Estados de negócio — nunca para decoração
| Estado | Fundo | Texto | Regra |
| --- | --- | --- | --- |
| Sucesso / pago | `n-teal-3` `#E6F6EE` | `n-teal-11` `#0B6B4B` | sempre com ícone |
| Atenção / a vencer | `n-amber-3` `#FEF4E2` | `n-amber-11` `#93610A` | sempre com ícone |
| Erro / vencido | `n-ruby-3` `#FEECEC` | `n-ruby-11` `#B42318` | sempre com ícone |

> **WCAG 2.2:** estado nunca se comunica só por cor. Cor + ícone + texto, sempre.

### Etapas do funil — paleta travada
```
--raevo-stage-1  #2563EB   --raevo-stage-4  #A21CAF
--raevo-stage-2  #0F9D8F   --raevo-stage-5  #98A0AE  (terminal, sem matiz)
--raevo-stage-3  #B45309
```

Esta paleta passou no validador de daltonismo: pior par **ΔE 9,7** em deuteranopia,
**ΔE 22,6** em visão normal, contraste ≥ 3:1. **Não troque sem revalidar:**

```bash
node scripts/validate_palette.js "#2563EB,#0F9D8F,#B45309,#A21CAF" --mode light --pairs all
```

Duas combinações já reprovaram e estão proibidas:
- **azul + roxo claro** (`#2563EB` ↔ `#7C3AED`) — ΔE 0,4 em deuteranopia
- **a paleta do Google Calendar** — Tangerine ↔ Basil em ΔE 3,4

---

## 3. Forma

O raio sai de uma fórmula sobre `--radius: 10px`, não de gosto: `sm` = base−4,
`md` = base−2, `lg` = base, `xl` = base+4.

| Token Tailwind | Valor | Uso |
| --- | --- | --- |
| `rounded-sm` | 6px | chip pequeno |
| `rounded-md` | 8px | textarea, item de lista. É também o valor de `rounded` sem sufixo |
| `rounded-lg` | **10px** | **botão, input, select** — o controlo |
| `rounded-xl` | 14px | card, painel, modal |
| `rounded-full` | pílula | **só o selo e a barra de pesquisa** (`type="search"`) |
| `.raevo-card` | mantém o raio declarado | o que é botão só por ser clicável — o chip de um agendamento. Um card alto com raio de pílula desenha uma elipse. |
| `border` | 1px | contorno padrão |

`pnpm raevo:pairs` recusa `rounded-full` em `<input>`, `<select>` e `<textarea>`, e
recusa `rounded-[Npx]`. O que ele não vê — pílula em `<button>` — está declarado no
topo do script.

### Campo: três contextos, três regras

Campo tem **três** aparências, cada uma presa a um contexto. Uma quarta é regressão — e a
terceira só entrou a 08/10 por decisão registada em `docs/raevo-aprovacao.md`, não por gosto.

| Contexto | Onde | Rótulo | Controle |
| --- | --- | --- | --- |
| **Formulário** | criar, configurar, diálogo de ação | `text-xs`, acima do campo | `rounded-lg` (10px), fundo `bg-n-surface-1`, contorno `border-n-strong` |
| **Ficha densa** | ler e preencher registro — aba de contato, tabelas de registo | `text-sm`, à esquerda, na mesma linha | sem casca: `bg-transparent`, `border-0`, mesma tipografia do valor; foco por anel |
| **Ficha empilhada** | a ficha da oportunidade (Pipeline e conversa), desde 08/10 | `text-sm font-medium`, **em cima**, como o painel de contacto do Chatwoot | a mesma da ficha densa: sem casca, foco por anel |

A ficha densa é a exceção deliberada à casca do controlo e ao rótulo de 12px acima. Motivo: ali
ler e preencher são o mesmo gesto, repetido dezenas de vezes por dia. A casca do formulário não
informa nada que o `hover` da linha e o próprio `button` já não digam, e cobra por isso um salto
de geometria a cada clique — o rótulo encolhia de 14px para 12px e o campo saltava para baixo dele.

A ficha empilhada é a ficha densa com o rótulo em cima (`RaevoFieldRow stacked`, que leva
`RaevoField inline stacked`). Decisão do Pedro sobre a maquete de 07/10: a ficha da oportunidade
lê-se como o painel do Chatwoot. Custa altura — ≈58px por campo contra ≈36px — e por isso a ficha
esconde os campos vazios atrás de «Mostrar mais N campos»: fica à vista o que tem valor gravado, o
que a etapa exige, o que é importante e o que uma condição acabou de revelar. O rótulo tem o mesmo
degrau e peso em repouso e em edição: abrir o campo não mexe na geometria.

Todas vivem em `raevoControl.js` (`RAEVO_*_CLASS` e `RAEVO_INLINE_*_CLASS`) e chegam à tela pelo
slot do `RaevoField`. **Nenhuma tela escreve classe de campo à mão** — foi assim que o produto
acumulou três tratamentos diferentes dentro do mesmo diálogo.

**Sombra:** em repouso, nenhuma. O ar separa.
- `shadow-sm` = `none` (deliberado)
- `shadow` / `shadow-md` = `--raevo-shadow-hover`, só no hover
- `shadow-lg` = `--raevo-shadow-float`, só para o que flutua: modal, menu, drawer

---

## 4. Tipografia

**Plus Jakarta Sans**, auto-hospedada — nenhuma chamada ao Google. A fonte variável cobre os
pesos 200–800 num arquivo de 27 KB (`_raevo-fonts.scss`, pacote
`@fontsource-variable/plus-jakarta-sans`). Só os subsets latin e latin-ext são carregados.

A pilha vive no token **`--raevo-font-sans`** e em lugar nenhum mais: `tailwind.config.js` lê
dele, o CSS lê dele. Trocar de fonte é mexer em uma linha.

A auditoria de conformidade de 30/08/2026 contou **27 degraus distintos** em uso — cada tela
inventava o seu tamanho e o seu peso. A escala abaixo tem **cinco degraus e um piso**, e é a única
permitida. Nada de `text-[Npx]`: se o tamanho não está aqui, ou se usa a classe nomeada, ou a
escala muda aqui primeiro.

| Papel | Classe | Valor | Uso |
| --- | --- | --- | --- |
| Micro | `text-micro` | 11px | selo, contador, cabeçalho de tabela, eyebrow — **o piso** |
| Apoio | `text-xs` | 12px | metadado secundário, rótulo de campo **em formulário**, texto de ajuda |
| Corpo | `text-sm` | 14px | padrão de leitura, valor de campo, rótulo de campo **em ficha densa** |
| Título de item | `text-base` | 16px | nome de card, título de seção |
| Título de tela | `text-xl` | 20px | cabeçalho de página |
| Destaque | `text-3xl` | 30px | número grande, pergunta do formulário guiado |

**Nada abaixo de 11px, nunca.** `text-micro` existe só para caixa alta e números curtos; texto
corrido em 11px não passa numa jornada de oito horas.

Todo número que se alinha em coluna usa figuras tabulares. Já é global para `table`.

---

## 5. Padrões de tela

### Cabeçalho de página
Não mora na barra do topo. Mora **num card branco dentro do corpo**:

```
trilha (Início › CRM)                      ← barra fina do topo
┌─────────────────────────────────────────┐
│ EYEBROW                                 │
│ Título da página  [selo]      [ações]   │
│ subtítulo explicativo                   │
│ [busca larga]        [filtro] [filtro]  │
│ Aba  Aba                        dica    │
└─────────────────────────────────────────┘
```

### Indicador — três densidades, e a escolha é uma regra

O cartão de número é a peça mais repetida do sistema: seis das oito telas abrem com uma fila
de quatro. Vive inteiro em **`RaevoKpiCard`** e em lugar nenhum mais — foi por cada tela
desenhar o seu que a auditoria encontrou três tratamentos de número no mesmo produto.

**A anatomia, e a ordem importa:**

```
┌─────────────────────────────┐
│ RÓTULO                  [↗] │  ← o que se mede · ação no canto, só se houver `to`
│ 30px  [↑ 12%]               │  ← o número, com a variação ao lado
│ ─────────────────────────── │  ← filete
│ rodapé: o contexto          │  ← «R$ 54,7k no mês passado», «6 fechadas»
└─────────────────────────────┘
```

**A densidade não é gosto.** É a resposta a «nesta tela o número é o assunto, ou é a moldura
dele?» — e, quando é moldura, a quanto espaço tem direito.

| `density` | Caixa | Rótulo | Número | Variação | Rodapé | Fila de 4 | Onde |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `card` (omissão) | `rounded-xl` + `border-n-weak` + `bg-n-solid-1` + `p-card` | `text-xs` | `text-3xl` (30px) | selo ao lado | sob filete, `text-xs` | **139px** | Início, Financeiro, IA |
| `strip` | nenhuma | `text-micro` caixa alta | `text-base` (16px) | selo ao lado | por baixo, sem filete, `text-xs` | **76px** | — |
| `inline` | nenhuma | `text-micro` caixa alta | `text-sm` (14px) | selo ao lado | **não há** | **28px** | Pipeline, Agenda |

Medidas aferidas no browser a 1280×900, sobre a aplicação real — não estimadas.

**Cor, nas três:** rótulo e rodapé em `text-n-slate-10`, número em `text-n-slate-12`. Sobre
`bg-n-solid-1` (cartão, e a caixa do cabeçalho do Pipeline) e sobre `bg-n-background` (a banda
da Agenda) o par mais apertado é **4,74:1** no claro e **6,94:1** no escuro — passa os 4,5:1 da
WCAG 2.2 para texto. A porta `check-design-pairs.mjs` não vê este par (o fundo está no pai),
por isso ele está aferido aqui.

**Espaço:** `gap-control-gap` (6px) entre número e selo; `gap-x-5` entre indicadores na linha;
`p-card` (16px) só no cartão. O número usa `tabular-nums` e `whitespace-nowrap` — numa fila de
quatro, dígitos de larguras diferentes fazem os cartões dançarem quando os dados mudam.

**`inline` é a única que perde informação de propósito.** Fica o rótulo, o valor e o selo de
variação; o rodapé não é desenhado. É a troca que a faz caber no canto de um cabeçalho que já
existe, e quem a usa aceita que «R$ 54,7k no mês passado» e «33,3% do mês» deixem de aparecer.

**A exceção é `note`**, e tem regra própria. Um qualificador curto que anda colado ao número,
só em `inline`, e só onde a variação NÃO ocupa aquele lugar — «Marcações hoje» não compara com
mês nenhum. Existe para o caso em que o rodapé levava a única informação daquela fila sobre a
qual se **age**: «3 por confirmar» é o que faz alguém pegar no telefone, e não existe em mais
lado nenhum do produto (a Agenda não tem faixa de resumo). Separa-se do número por um ponto
que é elemento e não texto — um `·` literal acusa a regra de i18n, e um separador é forma, não
conteúdo.

**Não é o rodapé de volta.** O rodapé é contexto que explica o número; a nota é uma parte do
número que não cabe no número. E só aparece quando tem o que dizer: sem nenhuma por confirmar
não há nota, porque «todas confirmadas» era a mesma frase a desculpar-se que se tirou do resto
da fila. Cada nota custa largura, e a linha existe precisamente para não custar altura — se
alguém puser uma em cada indicador, a linha quebra e volta a ter duas alturas.

No Pipeline nenhum indicador leva nota, e é escolha: o que o rodapé lá levava (o valor fechado,
o denominador da taxa) está na faixa **Resumo**, a um clique no cabeçalho.

### A tira de abas numa coluna estreita — uma linha, e «+N mais»

> **Desde 08/10 nenhuma tela usa esta tira.** A ficha da oportunidade, que era o único
> consumidor, passou a lista (ver «Ficha empilhada» acima). As regras ficam porque os defeitos
> que as escreveram voltam com a próxima tira de abas numa coluna estreita.

**Duas linhas de navegação acima do conteúdo é um anti-padrão com nome.** Carbon («em
ecrãs estreitos as abas não devem quebrar para várias linhas nem empilhar-se; devem rolar»),
Material («linha única, e não umas por baixo das outras»), CMS Design System («evite abas a
transbordar para novas linhas; se não cabem, considere outro padrão») e ICDS («os rótulos
mostram-se sempre numa linha»). O que PatternFly e o Horizon mandam fazer quando não cabem é
passá-las uma a uma para um menu **«+N mais»**, sempre o último da direita.

A gaveta de conversa do Pipeline fazia a terceira coisa, que é pior do que as duas: **rolava
sem dizer que rolava.** Medido antes: 571px de abas em 197px úteis — 374px invisíveis, sem
seta, sem sombra, sem contagem, e «Financeiro» cortado a meio da palavra.

Regras, por ordem de importância:

- **Uma linha, sempre.** `overflow-hidden` na tira, nunca `flex-wrap`, nunca
  `overflow-x-auto`. Rolar escondido é o defeito; quebrar é o anti-padrão.
- **O que não cabe desce para «+N mais»**, e a contagem é o aviso. O defeito nunca foi haver
  abas escondidas: foi não haver nada a dizer que existem.
- **A ordem é fixa.** Promover a aba usada para a tira dá uma tira que muda de lugar debaixo
  de quem está a trabalhar.
- **O rótulo do botão não muda de largura.** Pôr lá o nome da secção activa parece melhor e
  não é: o botão é `shrink-0`, um rótulo mais largo encolhe a tira, o `ResizeObserver` dispara
  e mais uma aba desce — escolher uma secção escondida fazia desaparecer uma visível. Quem
  está onde lê-se pela marca no botão, pelo `title`, e pelo item em `n-brand` dentro do menu.
- **As setas atravessam o menu.** `ArrowLeft`/`ArrowRight` percorrem **todas** as secções,
  inclusive as escondidas; quando a próxima está no menu, o foco vai para o botão. Sem isto o
  teclado pára na primeira escondida.
- **Quantas cabem mede-se no browser**, com uma régua fora do ecrã e um `ResizeObserver`. Não
  é constante: muda com o idioma, com os nomes que a clínica der às secções e com a largura da
  gaveta. **E a medição espera pela ficha, não pela montagem** — o formulário só existe depois
  de `card` chegar, e medir em `onMounted` deixava a tira com todas as abas dentro de um
  `overflow-hidden`, cortadas e agora sem sequer rolar para lá chegar.
- **O `+` de criar secção vive no fim**: no fim da tira quando não há transbordo, no fim do
  menu quando há. No meio da tira lia-se como se pertencesse à aba seguinte.

### A quarta densidade: `list` — o indicador como caminho

`card`, `strip` e `inline` respondem a «o número é o assunto desta tela, ou a moldura
dele?». `list` responde a outra pergunta: **e se o número for o caminho?**

Numa coluna estreita ao lado da superfície de trabalho, um indicador não é conteúdo nem
moldura — é a porta para o recorte que ele conta. `list` é a anatomia da faixa dentro de
um `<button>`: rótulo em caixa alta em cima, número e variação por baixo, ≈45px.

| | `card` | `strip` | `inline` | `list` |
| --- | --- | --- | --- | --- |
| Caixa | própria | nenhuma | nenhuma | nenhuma |
| Número | 30px | 16px | 14px | 14px |
| Rodapé | sob filete | por baixo | não há | não há |
| Nota | — | — | sim | não |
| Elemento | `<div>` | `<div>` | `<div>` | **`<button>`** |
| Onde | Início, Financeiro, IA | — | cabeçalho do Pipeline | coluna da Agenda |

Três coisas que `list` traz e que não são gosto:

- **Empilha, e não rótulo-à-esquerda/número-à-direita.** Foi medido: a 199px de coluna,
  «Concluídas no mês» com selo parte em duas linhas e «Faltas no mês» não — filas de
  28/44/29/44px e quatro números em quatro posições diferentes. Empilhado, todas medem
  45px e os números alinham.
- **O rótulo é `text-n-slate-11`, não `-10` como as outras três.** `list` é a única com
  fundo em `hover` e no estado activo, e `-10` sobre `n-slate-3` mede **4,35:1** e sobre
  `n-slate-4` **4,12:1** — reprova a WCAG nos dois. A porta de pares não apanha isto:
  o fundo vem de quem chama e a cor do texto vem do primitivo, logo nunca coexistem no
  mesmo atributo. Mede-se à mão.
- **O rótulo é `<span>`, não `<p>`.** `_base.scss` dá `mb-2` e `leading-[1.65]` a todo o
  `<p>`, e um parágrafo dentro de um `<button>` não é conteúdo válido. As outras três
  ficam em `<p>`: trocá-lo mexia no ritmo vertical das seis telas que já as usam.

**O estado activo vem de fora**, por `aria-pressed` e por classe: quem filtra sabe o que
está filtrado, o cartão não. E vem por dois canais, não um — filete de 2px à esquerda em
`border-n-brand` **e** fundo `n-slate-4` —, porque `n-slate-3` (hover) e `n-slate-4`
(activo) diferem em seis pontos de luz e ninguém distingue os dois a olho.

### O indicador que filtra — a Agenda

Os quatro indicadores da Agenda moram na coluna, debaixo de «Situação», e **cada um é um
botão que filtra**:

| Indicador | Leva a |
| --- | --- |
| Marcações hoje | vista de dia, hoje, todas as situações |
| Concluídas no mês | vista de mês, situação «Concluído» |
| Faltas no mês | vista de mês, situação «Faltou» |
| Canceladas no mês | vista de mês, situação «Cancelado» |

**O período do destino é o período que o número conta.** «Concluídas no mês 2» leva ao
mês; se levasse à semana corrente, o número no botão e a grelha discordavam — que é a
forma mais rápida de alguém deixar de confiar nos dois.

**Segundo clique desfaz.** Sem isso, um filtro posto daqui só se tirava no selector de
situação — que fica acima, não diz que foi ele, e deixava a vista de mês para trás.

**A banda do cabeçalho não morreu: ficou `lg:hidden`.** A coluna é `lg:flex` e não existe
abaixo dos 1024px; sem a banda, em tablet e telemóvel os quatro números deixavam de
existir. É a mesma fonte (`agendaIndicators`) em duas densidades, uma por largura — que é
para o que as densidades servem. Medido: coluna 210px a 1280px, banda 73px a 900px.

### A coluna lateral da Agenda — o que fica no fundo

A barra lateral da Agenda (`w-56`, 224px, com `px-3`) tem o mini-mês, as agendas e o filtro de
situação, e depois disso **acabava**: uns 400px de nada até ao fundo do ecrã.

O que vai para lá **não são os agregados do mês.** Duas razões, e a primeira é factual: a barra
é `hidden … lg:flex`, ou seja **não existe abaixo dos 1024px** — mover os indicadores para lá
apagava-os em portátil pequeno, tablet e telemóvel. A segunda é de leitura: o fundo de uma
coluna de filtros é o sítio mais frio da tela, e misturar leitura com filtro convida a clicar
num número à espera de que filtre.

O que vai para lá é a **lista accionável**: as marcações de hoje ainda por confirmar, uma por
linha, com a hora e o nome, cada uma um `<button>` que abre o diálogo da marcação. O contador
continua na linha do cabeçalho — diz que há três; a lista diz **quais**, e chega-se lá num
clique.

Três regras que a lista segue, e que valem para o que vier a ocupar aquele espaço:

- **Pedido próprio.** `appointments` é o que a vista carregou: do período no ecrã, filtrado pela
  situação e pela pesquisa. Derivar dali daria uma lista que fica vazia mal alguém navegue para
  outra semana — uma lista que mente é pior do que nenhuma.
- **Só aparece quando tem o que dizer.** Sem nada por confirmar a coluna fica calada: não há
  secção vazia nem «tudo confirmado» a ocupar espaço.
- **Nada depende de `truncate`.** O nome quebra por palavra; a hora é `tabular-nums` e não
  encolhe. Par mais apertado medido: 7,17:1 em `hover`, 7,81:1 em repouso.
- **Ordena quem mostra.** `AppointmentsIndexQuery` não tem `ORDER BY` — devolve o que o
  Postgres der, e com `.distinct` a ordem é mesmo indefinida. A grelha não se importa, porque
  posiciona cada marcação pela hora; uma **lista** fora de ordem é um defeito que se lê à
  primeira. Ordena-se no cliente, não no `query`: mudar o `scope` mexia na grelha, que não
  pediu nada.

**O que muda de estado, recarrega tudo o que o mostra.** Confirmar uma marcação recarrega a
grelha, as contagens **e** a lista. Antes só a grelha recarregava, e o contador do cabeçalho
ficava a dizer o valor de quando a tela abriu.

**O selo de variação custa 1px.** Medido: 27px sem ele, 28px com ele — cabe na linha do número.
Não é por espaço que se tira uma seta, e tirá-la faz a tela deixar de dizer se uma taxa de
fecho de 50% veio de 30% ou de 70%.

**Onde a linha mora.** No Pipeline, no canto inferior direito da caixa do cabeçalho, com a
legenda de saúde das etapas **por baixo dela e também à direita**: a legenda explica a barra
das colunas, é apoio, e apoio vem depois do dado. Na Agenda, que tem barra de uma linha e não
caixa, é a banda logo abaixo dela, com o mesmo `px-4` e o mesmo filete. **Não flutua sobre a
superfície de trabalho** — ali taparia os cartões da última coluna e o «Adicionar item», que é
para onde se arrasta.

**Sem base de comparação, nada de seta e nada de frase.** Numa conta nova três dos quatro
indicadores diziam «sem mês para comparar», e a fila gastava a sua linha mais larga a
desculpar-se. A ausência de seta já o diz.

A variação é sempre `RaevoStamp` — cor **e** ícone **e** texto, como manda a regra 5. E se a
variação é boa não é o sinal do número: em «Ciclo médio», «Faltas» e «Canceladas», descer é
bom, e é quem chama que sabe (`deltaIsGood`).

### Card de lead — a unidade que mais se repete
Avatar quadrado com gradiente · nome 12,5px/700 · procedimento 10,5px cinza ·
rodapé separado por linha com selo de tempo à esquerda e valor à direita.
Estados: repouso (sem sombra) · hover (borda escurece + sombra suave + sobe 1px) ·
selecionado (contorno azul 2px **substituindo** a borda) · arrastado (inclina 1,6°).

### Telas já convertidas
| Tela | Cabeçalho | Observação |
| --- | --- | --- |
| Financeiro | `RaevoPageHeader` | selo de estado via `RaevoStamp` |
| Configurações do funil | `RaevoPageHeader` | ações no slot `#actions` |
| Automações | `RaevoPageHeader` | botão voltar + novo fluxo no `#actions` |
| Quadro Kanban | shell Sereno, grade preservada | título é editável inline — **não** trocar por `RaevoPageHeader` |

> **Atenção ao testar:** specs que usam `shallowMount` stubam `RaevoPageHeader` e o conteúdo
> dos slots some. Adicione o stub que renderiza slots — há exemplos em
> `KanbanAutomations.spec.js` e `KanbanBoardSettings.spec.js`.

### Cores de etapa em código
`dashboard/helper/kanbanStageColors.js` expõe variantes, não uma classe só:

| Variante | Onde |
| --- | --- |
| `barClass` | barra de 5px no topo da coluna |
| `dotClass` | ponto ao lado do nome da etapa |
| `inkClass` | cor do ícone da etapa |
| `softClass` | fundo suave para contagem e realce |
| `swatchClass` | amostra no seletor de cor |

Etapa sem cor cai em `slate` — cinza é ausência, não categoria.

### Estado de consulta na agenda
Preenchimento suave + **régua de 3px à esquerda** na cor do estado
(`APPOINTMENT_TONES` em `CalendarView.vue`): confirmada/concluída em teal, presente em azul,
falta em ruby, cancelada em cinza com opacidade. Nunca só preenchimento.

### Coluna do funil
Barra de cor de 5px arredondada no topo · cabeçalho com ponto + ícone + nome + contagem ·
corpo em card branco · rodapé com afordance tracejado "Novo lead aqui".

### Armadilhas que já custaram retrabalho

**`size-4.5` não existe.** A escala do Tailwind vai de `size-4` para `size-5`; valores `.5`
existem só até `3.5`. Uma classe inválida não avisa: o elemento fica **sem dimensão**. Rode
`pnpm raevo:design` e confira no navegador — o compilador não pega isso.

**Não reserve espaço para controle que só aparece no hover.** O card do lead tinha
`pl-6 pr-16` para caber caixa de seleção e botões de hover; o conteúdo virava um bloco estreito
no meio de um card largo. Controle de hover **flutua por cima** com fundo sólido; o conteúdo usa
a largura inteira.

**Cinza não é cor de etapa.** Barra cinza no topo da coluna lê como barra de rolagem. Etapa sem
cor definida (`slate`) não desenha barra — ver `isNeutralStageColor`.

**Um marcador por rótulo.** O cabeçalho da etapa tinha ponto colorido *e* ícone antes do nome.
Dois marcadores para a mesma informação; ficou só o ícone, a 14px.

**Régua interna vira prateleira vazia.** No Sereno o ar separa, não a linha. Uma `border-t` no
rodapé do card criava uma faixa vazia quando não havia valor à direita.

### Primitivos prontos — use, não recrie

| Componente | Quando |
| --- | --- |
| `dashboard/components-next/raevo/RaevoPageHeader.vue` | cabeçalho de qualquer tela: eyebrow, título, selo, subtítulo, ações, filtros e abas |
| `dashboard/components-next/raevo/RaevoStamp.vue` | qualquer situação/estado. Garante cor + ícone + texto por construção — não escreva selo na mão |
| `dashboard/components-next/raevo/RaevoKpiCard.vue` | qualquer número medido, nas três densidades. **Nunca** desenhe um cartão ou uma linha de números à mão |
| `dashboard/components-next/raevo/RaevoField.vue` | qualquer campo de formulário. Rótulo acima, campo abaixo, mesma borda esquerda (regra 7) |

### Tabela
Cabeçalho `bg-n-slate-1`, rótulo `text-micro` (11px) em caixa alta — 9px está abaixo do
piso da escala (regra 6). Linha de 52px. Situação como selo com ícone, que é um dos dois
sítios onde a pílula fica. Valor à direita, tabular.

---

## 6. Acessibilidade — requisito, não acabamento

- Contraste de texto ≥ 4,5:1. Ícone e borda ≥ 3:1. Texto grande (≥ `text-xl`) ≥ 3:1.
- **O contraste é do par, não do token.** `--brand-color` inverte para `#E5E5E5`
  no escuro por decisão; `text-white` não inverte. Os dois valores estavam certos
  e o botão primário do produto inteiro ficou a **1,26:1**. Emparelhe com o token
  que inverte: `n-solid-1` ou `--brand-foreground`.
  `pnpm raevo:pairs` mede isto nos dois modos e recusa o que reprova.
- Foco sempre visível: contorno de 2px na cor de ação, deslocado 2px. Já é global.
- Alvo de toque ≥ 24px (WCAG 2.2 · 2.5.8). Já é global para `button`.
- Nenhuma ação crítica só por arrastar — sempre um caminho por teclado ou menu.
- Estado nunca por cor sozinha.
- `prefers-reduced-motion` respeitado globalmente.

---

## 7. O que NÃO fazer

| Não | Por quê | Em vez disso |
| --- | --- | --- |
| `class="bg-[#2563EB]"` ou `style="color:#111"` | quebra tema escuro e o próximo redesign | `bg-n-brand`, `text-n-slate-12` |
| `shadow-sm` esperando sombra | é `none` de propósito | deixe o espaço separar |
| `rounded-full` em campo, select ou botão | era a assinatura de Sereno; **deixou de ser a 21/09/2026** — a densidade alta tira largura ao controlo | `rounded-lg` (10px). A pílula fica para o selo e para a barra de pesquisa |
| `bg-n-brand text-white` | o fundo inverte no escuro, o branco não: dá 1,26:1 | `text-n-solid-1`, que inverte com ele |
| Nova cor de etapa sem validar | risco de daltonismo | rode o validador |
| Cor sozinha para estado | falha WCAG | cor + ícone + texto |
| Editar `_next-colors.scss` | conflito em todo `git pull` | edite `_raevo-tokens.scss` |
| Sombra sólida deslocada | é da direção D, descartada | `--raevo-shadow-hover` |

---

## 8. Verificação antes de abrir PR

```bash
# cor literal, tamanho fora da escala, par de contraste e geometria?
# (corre check-design-tokens.mjs e check-design-pairs.mjs)
pnpm raevo:design

# código e design-system/raevo.tokens.json continuam de acordo?
pnpm raevo:tokens

# a paleta de etapas continua acessível?
pnpm raevo:palette

# a folha compila?
node_modules/.bin/sass --no-source-map \
  app/javascript/dashboard/assets/scss/_raevo-tokens.scss /tmp/t.css

# os tokens chegam nas classes?
node_modules/.bin/tailwindcss -c tailwind.config.js -i /tmp/in.css -o /tmp/out.css \
  --content "app/javascript/dashboard/**/*.vue"

# a paleta de etapas continua acessível?
node scripts/validate_palette.js "#2563EB,#0F9D8F,#B45309,#A21CAF" --mode light --pairs all
```

Olhe a tela em **1280px e 1024px**, no claro e no escuro, e navegue por teclado.
