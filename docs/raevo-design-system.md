# Raevo Design System — direção H · Sereno

**Status:** aprovado em 29/08/2026 · vigente
**Fonte da verdade em código:** `app/javascript/dashboard/assets/scss/_raevo-tokens.scss`
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

| Token Tailwind | Valor | Uso |
| --- | --- | --- |
| `rounded-sm` | 7px | selo, chip pequeno |
| `rounded-md` | 9px | campo, item de lista |
| `rounded-lg` | 11px | card de lead, item de coluna |
| `rounded-xl` | 13px | card de página, painel, modal |
| `rounded-full` | pílula | **todo botão e todo campo de uma linha** |
| `border` | 1px | contorno padrão |

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

| Papel | Tamanho / peso | Observação |
| --- | --- | --- |
| Título de página | 19px / 800, tracking −0,025em | dentro do card de cabeçalho |
| Título de seção | 14px / 700 | |
| Corpo | 12,5px / 400–500 | |
| Rótulo de campo | 11px / 500, `text-n-slate-10` | |
| Rótulo minúsculo | 9px / 700, tracking 0,13em, CAIXA ALTA | eyebrow, cabeçalho de tabela |
| Valor monetário | 12,5–25px / 800, tabular | sempre `font-variant-numeric: tabular-nums` |

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

### Primitivos prontos — use, não recrie

| Componente | Quando |
| --- | --- |
| `dashboard/components-next/raevo/RaevoPageHeader.vue` | cabeçalho de qualquer tela: eyebrow, título, selo, subtítulo, ações, filtros e abas |
| `dashboard/components-next/raevo/RaevoStamp.vue` | qualquer situação/estado. Garante cor + ícone + texto por construção — não escreva selo na mão |

### Tabela
Cabeçalho `bg-n-slate-1`, rótulo 9px caixa alta. Linha de 52px. Situação como pílula
com ícone. Valor à direita, tabular.

---

## 6. Acessibilidade — requisito, não acabamento

- Contraste de texto ≥ 4,5:1. Ícone e borda ≥ 3:1.
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
| Botão retangular | a pílula é a assinatura | `rounded-full` (já é padrão) |
| Nova cor de etapa sem validar | risco de daltonismo | rode o validador |
| Cor sozinha para estado | falha WCAG | cor + ícone + texto |
| Editar `_next-colors.scss` | conflito em todo `git pull` | edite `_raevo-tokens.scss` |
| Sombra sólida deslocada | é da direção D, descartada | `--raevo-shadow-hover` |

---

## 8. Verificação antes de abrir PR

```bash
# nenhum componente do Raevo escreve cor literal?
pnpm raevo:design

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
