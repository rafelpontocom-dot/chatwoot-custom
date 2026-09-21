# A · Consultório — a direção aprovada

**Aprovada em 19/09/2026.** Substitui **H · Sereno** como alvo de desenho do Raevo.

Isto não é uma proposta. É o sistema que vale para **tudo o que for desenhado a partir
de agora** — tela nova, componente novo, diálogo novo. As telas que já existem migram
uma a uma, e cada uma precisa de aprovação antes de ser mexida: a fila está em
[`docs/raevo-aprovacao.md`](../../docs/raevo-aprovacao.md).

| Ficheiro | O que é |
| --- | --- |
| `consultorio.tokens.json` | **a fonte da verdade** — o sistema como dado |
| `consultorio.scss` | gerado: a folha que o produto importa quando a tela migrar |
| `consultorio.html` | gerado: a referência viva (abra no browser) |
| `consultorio-mockup.html` | gerado: componentes e telas nesta pele |
| `scripts/author-consultorio.mjs` | como o JSON é derivado da referência — **é aqui que se muda** |

## De onde vem cada valor

Nada foi escolhido de cabeça. O gerador lê duas fontes, por esta ordem:

1. **`design-system/referencia/traducao.json`** — o repositório
   `arhamkhnz/next-shadcn-admin-dashboard`, lido do código e convertido de OKLCH.
   Manda em cor, forma e densidade.
2. **`design-system/raevo.tokens.json`** — o sistema vigente. Manda no que é dado do
   produto e não da referência: a paleta de etapas, os matizes de estado, o tipo.

Se um nome mudar na referência, o gerador **rebenta** em vez de inventar um valor.

## As sete decisões que esta direção trava

### 1. A base não tem cor

Todo o `oklch` da base da referência tem croma **zero**, e os valores resolvem
exatamente para a escala `neutral` do Tailwind. A rampa do Raevo passa a ser
acromática. Consequência: **toda a cor que aparece no ecrã significa alguma coisa** —
etapa do funil, cobrança vencida, conversa por responder.

### 2. A ação é quase preta, não azul

`--brand-color` passa a `#171717`. No shadcn a cor de marca não ocupa o primário.

Isto liberta o azul `#2563EB` para ser **só etapa**. Era esta a decisão que estava em
aberto, e é a que mais muda a cara do produto.

O que isto obriga: **ligação de texto deixa de se distinguir por ser azul.** Passa a
sublinhado. Estado nunca se comunica só por cor continua a valer (regra 5 do
`AGENTS.md`) — e fica mais fácil de cumprir, não mais difícil.

### 3. O modo escuro é desta direção, não da proposta C

O Chatwoot já troca de tema; o que faltava era o escuro **desta** direção. Ele sai do
bloco `.dark` da referência, medido:

| | claro | escuro |
| --- | --- | --- |
| fundo | `#FFFFFF` | `#0A0A0A` |
| cartão / barra lateral | `#FFFFFF` / `#FAFAFA` | `#171717` |
| **ação** | `#171717` sobre `#FAFAFA` | **`#E5E5E5` sobre `#171717`** |
| fio | `#E5E5E5` | branco a 10% — composto em `#2E2E2E` |
| gráfico | os mesmos cinco cinzentos | os mesmos cinco cinzentos |

O primário **inverte**: um botão quase preto sobre fundo quase preto não se vê.

A proposta C (Órbita) **não** entra como modo escuro. C é violeta com primário
`#6E8CFF`; A é acromática com primário quase preto. Adotar C como escuro de A dava
dois produtos diferentes conforme a hora do dia. O que se aproveita de C é a técnica
— separar por degrau de luz em vez de contorno, que no escuro é obrigatório porque um
fio de 1px desaparece —, não o matiz.

### 4. O raio é fórmula

`--radius: 10px`, e o resto em `calc()`: `sm` −4 · `md` −2 · `lg` = base · `xl` +4 ·
`2xl` +8. Mudar um número muda o produto inteiro de forma coerente.

**Isto altera a regra 4 do `AGENTS.md`.** No Sereno o controlo era pílula. Em
Consultório a pílula fica para o selo e para a barra de pesquisa; botão e campo são
`lg` (10px), cartão é `xl` (14px). A densidade alta tira largura ao controlo, e dois
botões-pílula adjacentes ficam ambíguos.

### 5. A densidade vem da caixa, não do tipo

Medido no código da referência: botão `h-8 px-2.5 gap-1.5`, tabela `th h-10 px-2` e
`td p-2`, cartão `--card-spacing: spacing(4)`, barra lateral 16rem com rail de 3rem.

E o achado que poupa a migração inteira da tipografia: **a referência não redefine um
único degrau de tipo.** Usa `text-sm`, `text-xs`, `text-base` — a escala do Tailwind,
que é exatamente a que o Raevo já tem. A regra 6 do `AGENTS.md` fica como está, e o
corpo continua em 14px.

### 6. Em repouso separa o anel, não a sombra

O cartão da referência não tem borda nem sombra: tem `ring-1 ring-foreground/10`.
A regra 3 do `AGENTS.md` — `shadow-sm` é `none` — **sobrevive intacta**. Sombra só
para o que flutua: modal, menu, drawer.

### 7. O anel de foco recusa a referência

`--ring` da referência é `#A1A1A1`. Sobre branco dá **2,58:1** — abaixo dos 3:1 que a
WCAG 2.2 exige para indicador de foco. O anel passa a ser o próprio texto (`#0A0A0A`
no claro, `#FAFAFA` no escuro): **19,8:1**.

Onde a referência e o `AGENTS.md` se cruzam, **ganha o `AGENTS.md`**.

## O que não muda

- **A paleta de etapas.** `#2563EB` `#0F9D8F` `#B45309` `#A21CAF` + `#98A0AE`. É dado
  gravado em banco de produção e mede ΔE 9,7 no pior par em deuteranopia. Os cinco
  tons de gráfico da referência são cinzentos — não servem para distinguir etapa. A
  porta recusa qualquer direção que traga outra paleta.
- **A escala tipográfica.** Ver decisão 5.
- **O tipo.** Plus Jakarta Sans já está carregada. Trocar de tipo é decisão de
  infraestrutura, não de token.
- **A arquitetura.** Os tokens continuam a viver fora de `@layer`, importados depois
  dos do Chatwoot. Zero ficheiros do upstream editados.

## Contrastes aferidos

Medidos pelo gerador a cada execução, não recordados:

| Par | Rácio |
| --- | --- |
| texto sobre fundo | 19,80:1 |
| texto secundário sobre fundo | 4,74:1 |
| ação: texto sobre primário | 17,18:1 |
| anel de foco sobre fundo | 19,80:1 |
| escuro: texto sobre fundo | 18,97:1 |
| escuro: texto secundário sobre cartão | 6,94:1 |
| escuro: texto sobre primário | 14,23:1 |

O passo 9 (`#A1A1A1`, 2,58:1) é fio de desativado, **não texto**. Marcador de posição
usa o passo 10, como na referência.

## O que está no JSON e ainda não está no SCSS

Os cinco tokens de gráfico (`chart.light` / `chart.dark`) estão gravados, mas a folha
SCSS não os emite: o Raevo ainda não escolheu biblioteca de gráficos para Vue — o
Recharts da referência é React e não atravessa. Ficam no JSON à espera dessa decisão.
Ver `design-system/referencia/README.md`, barreira 5.

## Como mudar isto

O JSON é gerado. Editar o JSON à mão faz a porta acusar divergência na execução
seguinte.

```bash
# 1. mude scripts/author-consultorio.mjs
# 2. regenere tudo (JSON + SCSS + referência + mockup)
pnpm raevo:aprovado
# 3. LEIA O DIFF DO JSON — mostra tudo o que a mudança moveu, inclusive o que não queria
git diff design-system/aprovado/consultorio.tokens.json
# 4. a porta
pnpm raevo:tokens
pnpm raevo:palette
```

`pnpm raevo:tokens` corre em CI e falha se:

- o SCSS, a referência ou o mockup ficarem para trás do JSON;
- a direção trouxer uma paleta de etapas diferente da do produto;
- o código divergir de `design-system/raevo.tokens.json`.

## O que isto ainda não é

**Nenhum ficheiro `.vue` foi tocado.** O produto continua em Sereno. Consultório é o
alvo: vale para desenho novo já, e as telas existentes migram pela fila de
[`docs/raevo-aprovacao.md`](../../docs/raevo-aprovacao.md), uma aprovação de cada vez.
