# Direções

Uma **direção** é um sistema de design completo — cor, forma, elevação,
tipografia — expresso no mesmo formato que o sistema vigente. Fica aqui como
proposta: desenhada, gerada, vista e medida, mas **não adotada**.

| Direção | Estado | Ficheiros |
| --- | --- | --- |
| **A · Consultório** | **aprovada 19/09/2026** — o alvo | [`../aprovado/`](../aprovado/README.md) |
| **H · Sereno** | no código, até cada tela migrar | `../raevo.tokens.json` · `../reference.html` · **`../mockup.html`** |
| **N · Nitidez** | proposta, não escolhida | `nitidez.tokens.json` · `nitidez.html` · `nitidez.scss` · **`nitidez-mockup.html`** |

> **A direção aprovada é A · Consultório.** O que está aqui é o histórico: Sereno é o
> que o código ainda tem, Nitidez foi explorada e não foi escolhida. Para desenhar
> qualquer coisa nova, use [`../aprovado/`](../aprovado/README.md).

Cada direção tem duas páginas, e são coisas diferentes:

- **`*-mockup.html` — é aqui que se decide.** Os componentes (botão, campo, selo,
  cartão, tabela, abas, menu, diálogo, estados vazio/carregando/erro) e as telas
  do produto (Pipeline, Financeiro, Agenda) desenhados com aquele conjunto.
- **`reference.html` / `nitidez.html`** — o inventário de tokens: rampas,
  semânticos, escala de forma, sombra e tipografia.

Ambas estão desenhadas **com os próprios tokens que descrevem**, por isso o que
se vê é o sistema a funcionar, não uma amostra dele.

### A prova

Os dois mockups são **a mesma marcação**. O gerador é um só
(`scripts/design-mockup.mjs`), e nenhuma regra de CSS dele escreve cor, raio ou
sombra literal — tudo sai de `var()`. Abra os dois lado a lado: muda a cara,
não muda um componente.

É essa a razão de a regra 1 existir. Se um componente escrevesse `bg-[#2563EB]`,
esta comparação seria impossível e trocar de direção seria reescrever o produto.

---

## N · Nitidez

### A tese

Sereno otimiza para **calma**. Um posto de trabalho clínico otimiza para
**varrer densidade e ler estado**.

A regra 3 do Sereno — *"em repouso o espaço separa, não a sombra"* — é bonita e
funciona num ecrã com poucos objetos. A quarenta cartões num quadro de Pipeline,
ou sessenta faixas numa Agenda, separar só por espaço tem dois custos: gasta
altura que não sobra, e deixa a fronteira do objeto por conta do intervalo —
que ao varrer depressa se perde.

Nitidez troca isso por **fio de contorno mais elevação mínima**, aperta os
raios, aquece os neutros e assume 13px como corpo do trabalho operacional.

### O que muda, e porquê

| Decisão | Sereno | Nitidez | Razão |
| --- | --- | --- | --- |
| Neutros | ardósia fria (`#F7F8FA` → `#111827`) | pedra quente (`#F6F6F4` → `#1C1917`) | O frio somado ao azul dá ar de utilitário. O neutro quente devolve calor sem introduzir segundo acento, e faz o azul ler como decisão, não como temperatura do ecrã. |
| Sombra em repouso | `shadow-sm: none` | `shadow-sm: 0 1px 2px / 5%` | O cartão volta a ser objeto discreto sem precisar de intervalo grande. Ganha-se altura de lista. |
| Raio do cartão | 13px | **10px** | Raio grande pede respiro grande à volta. Apertar o raio deixa alinhar mais perto sem parecer apertado. |
| Raio do controle | pílula | **8px** | A pílula desperdiça largura e, em dois controles adjacentes, borra onde acaba um e começa o outro. Fica reservada ao selo (`--raevo-radius-pill`), onde diz *"isto é rótulo, não botão"*. |
| Corpo | 14px | **13px** (`text-sm`) | O Sereno já tinha `ui: 13px`, mas **proibido fora da agenda densa**. Nitidez assume o que a prática já mostrava: o produto é operacional, e 13px é a medida dele. A escala inteira aperta (11 · 12 · 13 · 15 · 19 · 28). |
| Paleta de etapas | `#2563EB #0F9D8F #B45309 #A21CAF` | **igual** | Ver abaixo. |

### Porque a paleta de etapas não muda

Procurei substituta e **todas mediram pior**. Treze candidatas passaram pelo
`scripts/validate_palette.js`:

- verde + magenta colapsa em **ΔE 1,1** em deuteranopia (`#059669` ↔ `#DB2777`);
- `#0E7490` tem croma 0,094 — abaixo do piso, lê cinzento;
- `#3730A3` cai fora da banda de luminosidade (L 0,398);
- as duas melhores alternativas completas ficaram em **ΔE 6,9 e 7,2** — dentro
  da faixa de piso 6–8, que o validador só aceita com codificação secundária.

A paleta vigente mede **ΔE 9,7**. O par que a limita é sempre
`#A21CAF ↔ #2563EB`: azul e magenta são as âncoras, e mexer no teal ou no âmbar
não move o pior par. Acrescente-se que estas cores são **dado gravado em banco
de produção** — trocá-las é migração, não decisão de estilo.

Manter foi a escolha medida, não a preguiçosa.

### Ver

```bash
# os componentes e as telas — é aqui que se decide
open design-system/directions/nitidez-mockup.html
open design-system/mockup.html                  # a vigente, mesma marcação

# o inventário de tokens
open design-system/directions/nitidez.html
open design-system/reference.html
```

### Adotar

`nitidez.scss` é **drop-in**: redefine as mesmas custom properties que
`_raevo-tokens.scss`, fica fora de `@layer` pela mesma razão, e por isso um
`git pull` do Chatwoot continua sem desfazer a identidade.

1. Em `_woot.scss`, troque o import de `_raevo-tokens` por esta folha.
2. Em `tailwind.config.js`, aplique `shape.radius.tailwind`, `shadow.tailwind` e
   `typography.extras` do JSON da direção.
3. Rode `pnpm raevo:design` e `pnpm raevo:tokens`.
4. Percorra Pipeline, Agenda, Financeiro e Formulários a 1280px, claro e escuro.

Reverter é desfazer os passos 1 e 2. Nenhum componente precisa de mudar: é essa
a razão de a regra 1 existir.

> **Nota sobre tipo.** Plus Jakarta Sans mantém-se. Trocar de tipo é decisão de
> infraestrutura — ficheiros, licença, peso de carregamento — e não pertence a
> uma camada de tokens. Fica por decidir à parte.

---

## Criar outra direção

```bash
# 1. escreva o conjunto de tokens
cp nitidez.tokens.json outra.tokens.json && $EDITOR outra.tokens.json

# 2. gere os artefactos
node scripts/design-tokens.mjs scss      outra.tokens.json design-system/directions/outra.scss
node scripts/design-tokens.mjs reference outra.tokens.json design-system/directions/outra.html
node scripts/design-mockup.mjs            outra.tokens.json design-system/directions/outra-mockup.html

# 3. se mexeu na paleta de etapas, meça
pnpm raevo:palette
```

`pnpm raevo:tokens` falha se o `.scss` ou o `.html` de qualquer direção ficar
para trás do seu JSON — uma direção desatualizada mostra um sistema que já não
existe, e isso é pior do que não a mostrar.
