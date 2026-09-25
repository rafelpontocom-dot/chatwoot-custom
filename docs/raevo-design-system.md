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

### Campo: dois contextos, duas regras

Campo tem **duas** aparências, e só duas. Qualquer terceira é regressão.

| Contexto | Onde | Rótulo | Controle |
| --- | --- | --- | --- |
| **Formulário** | criar, configurar, diálogo de ação | `text-xs`, acima do campo | `rounded-lg` (10px), fundo `bg-n-surface-1`, contorno `border-n-strong` |
| **Ficha densa** | ler e preencher registro — ficha da oportunidade, aba de contato | `text-sm`, à esquerda, na mesma linha | sem casca: `bg-transparent`, `border-0`, mesma tipografia do valor; foco por anel |

A ficha densa é a exceção deliberada à casca do controlo e ao rótulo de 12px acima. Motivo: ali
ler e preencher são o mesmo gesto, repetido dezenas de vezes por dia. A casca do formulário não
informa nada que o `hover` da linha e o próprio `button` já não digam, e cobra por isso um salto
de geometria a cada clique — o rótulo encolhia de 14px para 12px e o campo saltava para baixo dele.

Ambas vivem em `raevoControl.js` (`RAEVO_*_CLASS` e `RAEVO_INLINE_*_CLASS`) e chegam à tela pelo
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
