# Raevo Design System — o sistema como dado

A direção **H · Sereno** foi aprovada em 29/08/2026 e não mudou. O que mudou é
**onde ela vive**.

Antes, a mesma decisão estava escrita à mão em quatro lugares:

| Onde | Em que forma |
| --- | --- |
| `_raevo-tokens.scss` | triplete RGB — `--raevo-stage-1: 37 99 235` |
| `raevoPalette.js` | hexadecimal — `'#2563EB'` |
| `package.json` | argumento do validador — `"#2563EB,#0F9D8F,..."` |
| `docs/raevo-design-system.md` | tabelas em Markdown |

Nada obrigava os quatro a concordarem. Um dígito trocado num deles passava em
silêncio — inclusive o caso que mais dói: mudar a paleta em `raevoPalette.js` e
esquecer o argumento do `package.json` faz `pnpm raevo:palette` **passar verde**
validando a paleta antiga, enquanto o produto entrega a nova, não validada.

Agora existe um arquivo só como fonte da verdade declarada — **`raevo.tokens.json`**
— e uma porta que falha quando o código discorda dele.

---

## Os três comandos

```bash
pnpm raevo:tokens             # falha se o código divergir do JSON
pnpm raevo:tokens:extract     # regrava o JSON a partir do código
pnpm raevo:tokens:reference   # regera reference.html
```

`pnpm raevo:tokens` roda em CI (`custom_checks.yml`, job `lint-frontend`), junto
com `pnpm raevo:design`, que verifica que nenhum componente do Raevo escreve cor
literal.

---

## Como mudar um valor

O JSON é a fonte da verdade **declarada**, não gerada. O SCSS continua escrito à
mão de propósito: os comentários dele explicam *por que* cada valor é aquele, e
gerar o arquivo apagaria a única memória dessas decisões. A porta é o que mantém
os dois honestos.

1. Edite o arquivo de origem (`_raevo-tokens.scss`, `tailwind.config.js`,
   `raevoPalette.js` — conforme o caso).
2. Rode `pnpm raevo:tokens`. Ela vai falhar e dizer exatamente o que divergiu.
3. Se a mudança é intencional, rode `pnpm raevo:tokens:extract` e **leia o diff
   do JSON**. É a revisão: o diff mostra tudo que a mudança moveu, inclusive o
   que você não pretendia mover.
4. Se mexeu em cor, rode `pnpm raevo:tokens:reference` para a referência não
   mentir.
5. Se mexeu na paleta de etapas, rode **também** `pnpm raevo:palette`.

## Se mudar a paleta de etapas

Ela está travada e validada para daltonismo — pior par **ΔE 9,7** em
deuteranopia. Trocar uma cor exige mudar **quatro** lugares e revalidar:

```bash
node scripts/validate_palette.js "<nova paleta>" --mode light --pairs all
```

Já reprovaram e estão proibidas: azul `#2563EB` + violeta `#7C3AED` (ΔE 0,4) e a
paleta do Google Calendar (ΔE 3,4).

A porta cobre justamente esse erro: se os quatro lugares deixarem de concordar,
`pnpm raevo:tokens` falha nomeando qual ficou para trás.

---

## O que tem aqui

| Arquivo | O que é |
| --- | --- |
| `raevo.tokens.json` | os tokens extraídos do código — cor (rampas e semânticos, claro e escuro), etapas, forma, sombra, tipografia |
| `reference.html` | referência viva, **gerada** do JSON. Abra no browser; tem alternador de tema |
| `directions/` | sistemas de design propostos, completos e vistos — hoje **N · Nitidez**. Ver [`directions/README.md`](./directions/README.md) |
| `../scripts/design-tokens.mjs` | extrai, verifica e gera |
| `../docs/raevo-design-system.md` | a especificação: padrões de tela, regras de uso, checklist de PR |

`reference.html` é gerado — não edite à mão. Se um valor lá está errado, o erro
está no sistema, não na página.

## Trocar de direção

Com o sistema em dado, uma identidade nova é um conjunto de tokens e dois
comandos — não uma arqueologia pelas quatro cópias de cada valor. A primeira
está em [`directions/`](./directions/README.md): **N · Nitidez**, completa,
gerada e medida. Trocar é um import; reverter é desfazê-lo.

## O que a extração **não** é

A extração não é um redesign. Nenhum pixel mudou: a extração foi conferida contra o código
e a porta passa limpa. É a arquitetura que faltava para que um redesign futuro
seja possível sem arqueologia — hoje trocar a identidade significa achar as
quatro cópias de cada valor à mão.
