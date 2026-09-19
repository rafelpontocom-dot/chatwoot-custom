# Referência shadcn/ui — extraída, traduzida e as barreiras

O que está aqui é o design system de
[`arhamkhnz/next-shadcn-admin-dashboard`](https://github.com/arhamkhnz/next-shadcn-admin-dashboard)
**lido do código**, convertido para a língua do Raevo, com o que não atravessa
escrito à frente.

| Ficheiro | O que é |
| --- | --- |
| `shadcn.tokens.json` | a extração crua: tokens, presets, 60 componentes e as suas variantes |
| `traducao.json` | as cores convertidas de OKLCH para triplete RGB, com hexadecimal |
| `raevo-shadcn.scss` | folha pronta a importar — os tokens na forma que o Chatwoot consome |
| `tailwind-fragment.js` | o mesmo mapeamento para `tailwind.config.js` (v3) |

Regenerar:

```bash
node scripts/extract-reference.mjs  <caminho-do-repo-da-referencia>
node scripts/translate-reference.mjs
```

---

## A aferição que valida a conversão

A referência escreve cor em OKLCH. O conversor foi verificado contra valores
conhecidos, e o resultado prova que os OKLCH dela **são a paleta do Tailwind**:

| OKLCH na referência | Convertido | É |
| --- | --- | --- |
| `oklch(1 0 0)` | `#FFFFFF` | branco |
| `oklch(0.922 0 0)` | `#E5E5E5` | neutral-200 |
| `oklch(0.205 0 0)` | `#171717` | neutral-900 |
| `oklch(0.5106 0.2301 276.97)` | `#4F46E5` | indigo-600 |
| `oklch(0.7038 0.123 182.50)` | `#14B8A6` | teal-500 |
| `oklch(0.7227 0.192 149.58)` | `#22C55E` | green-500 |

Bate certo ao dígito. A conversão não é aproximação.

---

## O desvio que mais muda a cara

**`--primary` da referência é `#171717` — quase preto, não uma cor de marca.**

No shadcn por omissão, o botão primário é preto com texto branco. Foi por isso
que as minhas propostas continuavam a parecer "outra coisa": eu punha o azul da
marca no primário, e a referência não põe cor nenhuma ali.

Isto é uma decisão a tomar, não um detalhe:

- **Fiel ao shadcn** — primário preto. A cor fica reservada para significado:
  etapa do funil, cobrança vencida, estado. É o que dá o ar sóbrio da referência.
- **Fiel ao Raevo** — primário `#2563EB`. Mas esse azul é também a etapa 1 do
  funil, e é **dado gravado em banco**. Usá-lo como cor de ação faz a ação e a
  primeira etapa partilharem a mesma cor.

**Decidido em 19/09/2026: vai o preto.** `--brand-color` passa a `#171717` e o azul
fica reservado a etapa do funil. Está gravado em
[`design-system/aprovado/`](../aprovado/README.md).

O que isso obriga a tratar em cada tela que migrar: a ligação de texto deixa de se
distinguir por ser azul e passa a sublinhado.

---

## Barreiras: o que não atravessa tal e qual

### 1. Tailwind v4 → v3 · **bloqueante, tem solução**

A referência usa Tailwind **v4**; o Raevo usa **v3**. O que muda:

| Na referência (v4) | No Raevo (v3) |
| --- | --- |
| `@theme inline { --color-card: var(--card) }` | não existe — vai para `theme.extend.colors` no `tailwind.config.js` |
| `@custom-variant dark (&:is(.dark *))` | já temos `.dark` por `darkMode: 'class'` |
| `size-8` | `h-8 w-8` |
| `in-data-[slot=button-group]:…` | sem equivalente direto; usar seletor no SCSS |
| `has-data-[icon=inline-end]:pr-2` | `:has()` funciona em CSS, mas a variante não existe em v3 |
| `@container/card-header` | precisa do plugin `@tailwindcss/container-queries` |
| `p-(--card-spacing)` | `p-[var(--card-spacing)]` |

`tailwind-fragment.js` já traz a parte mecânica (cores e raios) traduzida.

### 2. OKLCH → triplete RGB · **resolvido, com uma perda**

O Chatwoot consome `rgb(var(--x) / <alpha-value>)`. OKLCH não entra ali. A
conversão está feita e aferida, mas **perde-se o gamut largo**: num ecrã P3, a
referência mostra cores que o sRGB não alcança. Na prática, para uma clínica, não
tem consequência.

### 3. React + CVA → Vue · **é reescrita, não port**

`class-variance-authority` é JavaScript puro e **funciona em Vue**. O que não
funciona é o corpo dos componentes: são JSX com `React.ComponentProps`,
`asChild`, `forwardRef`. Cada componente tem de ser reescrito em
`<script setup>`. As *variantes* — que é o que interessa — estão todas extraídas
em `shadcn.tokens.json` e são copiáveis tal e qual.

### 4. Radix UI → reka-ui · **quase 1:1, mas não é**

O shadcn/ui assenta em Radix (React). Em Vue o equivalente é **reka-ui**
(ex-radix-vue). A maioria dos primitivos existe com a mesma API mental, mas não
todos, e os nomes dos slots divergem. Comportamento de foco e de portal tem de
ser testado, não assumido.

### 5. Recharts → outra coisa · **não atravessa**

Recharts 3 é React. Os **tokens** de gráfico (`--chart-1..5`) atravessam; os
componentes não. O Raevo precisa de escolher uma biblioteca Vue à parte. Até lá,
gráficos simples em SVG resolvem — foi o que os mockups fizeram.

### 6. Preferências guardadas em cookie de servidor · **muda de sítio**

A referência guarda casca, colapso e largura em cookie lido pelo servidor Next.
O Raevo não tem Next: isto passa a preferência de conta ou `localStorage`.
O comportamento é replicável; o mecanismo não.

### 7. Lucide · **atravessa**

`lucide-react` → `lucide-vue-next`. Mesmos ícones, mesmos nomes. O `AGENTS.md`
já manda usar Lucide.

### 8. As regras travadas do Raevo · **ganham sempre**

Onde a referência e o `AGENTS.md` se cruzam, o `AGENTS.md` decide:

- **Nenhum componente escreve cor literal.** As classes do shadcn escrevem
  (`bg-green-500/10`, `border-green-200`). Ao traduzir, isso vira token.
- **A paleta de etapas não se mexe.** É dado em produção, ΔE 9,7 em
  deuteranopia. Os `--chart-1..5` da referência **não** servem para etapa.
- **Estado nunca só por cor.** O shadcn usa selos só com cor em vários sítios;
  no Raevo cada um leva ícone e texto.

---

## O modo escuro, e o alfa que quase se perdeu

Duas correções de 19/09/2026, ambas encontradas ao tentar responder "e o escuro?".

**O `.dark` vinha errado.** O recortador de blocos procurava o seletor com um
`indexOf` cru, e a primeira ocorrência de `.dark` no `globals.css` está dentro de
`@custom-variant dark (&:is(.dark *))`, na linha 10 — quatro linhas antes do bloco
seguinte. Resultado: o que ficava gravado como "escuro" eram os 40 nomes do
`@theme inline`, não os 31 valores do `.dark`. Passava despercebido porque o número
parecia plausível. Agora o seletor tem de estar imediatamente antes da chaveta.

**A referência escreve cor com alfa; o triplete não o transporta.** A borda do modo
escuro é `oklch(1 0 0 / 10%)` — branco a 10%, não branco. O Chatwoot consome
`rgb(var(--x) / <alpha-value>)`, onde o alfa vem do Tailwind, não do token. Sem
tratamento, um fio subtil virava uma linha branca berrante.

O tradutor passa a emitir o alfa à parte:

```scss
--shadcn-border: 255 255 255;   // #FFFFFF a 10%
--shadcn-border-alpha: 0.1;
```

E a direção aprovada **compõe** o valor sobre a superfície onde o fio vive de facto
(o cartão, `#171717`), gravando o resultado opaco: `#2E2E2E`. Ver
`scripts/author-consultorio.mjs`.

O que o `.dark` da referência diz, agora que se lê:

| | claro | escuro |
| --- | --- | --- |
| `--primary` | `#171717` | **`#E5E5E5`** — inverte |
| `--primary-foreground` | `#FAFAFA` | `#171717` |
| `--background` | `#FFFFFF` | `#0A0A0A` |
| `--card` / `--sidebar` | `#FFFFFF` / `#FAFAFA` | `#171717` |
| `--chart-1..5` | cinco cinzentos | **os mesmos cinco** |

O primário inverter não é detalhe: um botão quase preto sobre fundo quase preto não
se vê. E os cinco tons de gráfico não mudam entre modos — o que confirma que a
escolha acromática é deliberada, não um esquecimento.

Há uma incoerência na própria referência, que **não** atravessa: `--sidebar-primary`
no escuro é `#1447E6`, azul, sozinho num sistema de croma zero. Fica de fora.

## Aplicar

1. Importar `raevo-shadcn.scss` **depois** de `_raevo-tokens.scss` em `_woot.scss`.
2. Juntar `tailwind-fragment.js` ao `theme.extend` do `tailwind.config.js`.
3. Instalar `@tailwindcss/container-queries` se quiser a anatomia de cartão da
   referência.
4. Reescrever os componentes por ordem de uso: `button`, `card`, `badge`,
   `field`, `table`, `empty`, `item` — as variantes estão em `shadcn.tokens.json`.
5. Correr `pnpm raevo:design` e `pnpm raevo:tokens`.

Reverter é tirar o import e o fragmento.

## O que isto ainda não é

Não é uma implementação: nenhum componente Vue foi escrito. É a extração
completa, a tradução aferida e o mapa das barreiras — o que faz falta para que
implementar deixe de ser adivinhação.
