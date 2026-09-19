/**
 * Gera `design-system/aprovado/consultorio.tokens.json` — a direção A · Consultório,
 * aprovada em 19/09/2026, como DADO.
 *
 * Nada aqui é escolhido de cabeça. Os valores saem de duas fontes, nesta ordem:
 *
 *   1. `design-system/referencia/traducao.json` — a referência shadcn/ui lida do
 *      código e convertida de OKLCH. É o que manda em cor, forma e densidade.
 *   2. `design-system/raevo.tokens.json` — o sistema vigente (H · Sereno). Manda
 *      naquilo que é DADO do produto e não da referência: a paleta de etapas, os
 *      matizes de estado, o tipo carregado.
 *
 * Onde as duas se cruzam e a referência perde, está escrito porquê, no token.
 *
 * Uso: node scripts/author-consultorio.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const ler = p => JSON.parse(readFileSync(resolve(RAIZ, p), 'utf8'));

const ref = ler('design-system/referencia/traducao.json');
const base = ler('design-system/raevo.tokens.json');

// --- utilitários de cor ---------------------------------------------------------

const paraRgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const paraHex = ([r, g, b]) =>
  `#${[r, g, b].map(x => Math.round(x).toString(16).padStart(2, '0')).join('').toUpperCase()}`;
const trio = h => paraRgb(h).join(' ');
const tok = h => ({ value: trio(h), hex: h });

/** Mistura `frente` a `alfa` sobre `fundo` — é o que o browser faz com rgb()/alpha. */
const sobre = (frente, fundo, alfa) =>
  paraHex(paraRgb(frente).map((c, i) => c * alfa + paraRgb(fundo)[i] * (1 - alfa)));

const lum = h =>
  paraRgb(h)
    .map(c => c / 255)
    .map(c => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
    .reduce((a, c, i) => a + c * [0.2126, 0.7152, 0.0722][i], 0);
/** Contraste WCAG entre dois hexadecimais, arredondado a duas casas. */
const contraste = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return Math.round(((x + 0.05) / (y + 0.05)) * 100) / 100;
};

/** O valor da referência, pelo nome que ela usa. Falha alto se o nome mudou. */
const R = (modo, nome) => {
  const v = ref[modo]?.[nome];
  if (!v?.hex)
    throw new Error(
      `a referência não tem "${nome}" em ${modo} — reextraia com scripts/extract-reference.mjs`
    );
  return v.hex;
};

// --- rampa neutra ---------------------------------------------------------------
//
// A referência é acromática: todo o `oklch` da base tem croma ZERO, e os valores
// resolvem exatamente para a escala `neutral` do Tailwind. Os passos marcados com
// `R(...)` vêm dela; os outros são os degraus do Tailwind que preenchem o intervalo,
// para a rampa do Raevo continuar a ter doze passos.

const rampaClara = [
  R('light', 'background'), //  1  #FFFFFF  fundo e cartão
  R('light', 'sidebar'), //     2  #FAFAFA  barra lateral
  R('light', 'muted'), //       3  #F5F5F5  superfície discreta, hover
  '#EFEFEF', //                 4           hover mais fundo (neutral 100→200)
  R('light', 'border'), //      5  #E5E5E5  fio
  '#DCDCDC', //                 6
  '#D4D4D4', //                 7           neutral-300, fio forte
  '#C2C2C2', //                 8           desativado
  R('light', 'ring'), //        9  #A1A1A1  marcador de posição
  R('light', 'muted-foreground'), // 10 #737373  texto secundário
  '#525252', //                11           neutral-600
  R('light', 'foreground'), // 12  #0A0A0A  texto
];

const rampaEscura = [
  R('dark', 'background'), //   1  #0A0A0A
  '#141414', //                 2
  R('dark', 'card'), //         3  #171717  cartão e barra lateral
  '#1F1F1F', //                 4
  R('dark', 'muted'), //        5  #262626
  '#303030', //                 6
  '#3D3D3D', //                 7
  '#525252', //                 8
  R('dark', 'ring'), //         9  #737373
  R('dark', 'muted-foreground'), // 10 #A1A1A1
  '#D4D4D4', //                11
  R('dark', 'foreground'), //  12  #FAFAFA
];

const rampa = (arr, herdada) => {
  const out = {};
  for (const fam of ['slate', 'gray']) arr.forEach((h, i) => (out[`${fam}-${i + 1}`] = tok(h)));
  // Os matizes — azul, âmbar, vermelho, roxo — ficam como estão: são cor de
  // significado, já validada, e a referência não tem equivalente (croma zero).
  for (const [k, v] of Object.entries(herdada)) if (!/^(slate|gray)-/.test(k)) out[k] = v;
  return out;
};

// --- fios do modo escuro --------------------------------------------------------
//
// A referência escreve a borda escura como `oklch(1 0 0 / 10%)` — branco a 10%,
// não branco. Triplete não transporta alfa, por isso o valor é composto aqui
// sobre a superfície onde o fio vive de facto: o cartão.

const fioEscuro = sobre('#FFFFFF', rampaEscura[2], ref.dark.border.alfa ?? 0.1);
const fioEscuroForte = sobre('#FFFFFF', rampaEscura[2], ref.dark.input.alfa ?? 0.15);
// O cartão da referência não tem borda nem sombra: tem `ring-1 ring-foreground/10`.
const anelClaro = sobre(R('light', 'foreground'), rampaClara[0], 0.1);

// --- foco: o único sítio onde a referência é recusada ---------------------------
//
// `--ring` da referência é #A1A1A1. Sobre branco dá 2,68:1 — abaixo dos 3:1 que a
// WCAG 2.2 (1.4.11 e 2.4.11) exige para indicador de foco. O AGENTS.md manda a
// acessibilidade ganhar, por isso o anel de foco passa a ser o próprio texto.

const focoClaro = R('light', 'foreground');
const focoEscuro = R('dark', 'foreground');
const focoRecusado = {
  referencia: R('light', 'ring'),
  contrasteNoFundo: contraste(R('light', 'ring'), rampaClara[0]),
  minimo: 3,
  adotado: focoClaro,
  contrasteAdotado: contraste(focoClaro, rampaClara[0]),
  razao:
    'O anel de foco da referência não chega aos 3:1 da WCAG 2.2. Onde a referência ' +
    'e o AGENTS.md se cruzam, ganha o AGENTS.md.',
};

// --- semânticos -----------------------------------------------------------------

const semantico = (herdado, mapa) => {
  const out = { ...herdado };
  for (const [k, h] of Object.entries(mapa)) out[k] = /^#/.test(h) ? tok(h) : { value: h };
  return out;
};

const claro = semantico(base.color.semantic.light, {
  // A ação deixa de ter cor de marca. No shadcn `--primary` é quase preto: a cor
  // fica toda para significado — etapa, cobrança vencida, conversa por responder.
  'brand-color': R('light', 'primary'),
  'brand-foreground': R('light', 'primary-foreground'),
  'background-color': rampaClara[0],
  'surface-1': rampaClara[0],
  'surface-2': rampaClara[1],
  'surface-active': R('light', 'accent'),
  'solid-1': R('light', 'popover'),
  'solid-2': rampaClara[2],
  'solid-3': rampaClara[3],
  'card-color': R('light', 'card'),
  'card-ring': anelClaro,
  'sidebar-color': R('light', 'sidebar'),
  'border-weak': rampaClara[4],
  'border-strong': rampaClara[6],
  'border-container': rampaClara[4],
  'focus-ring': focoClaro,
  'label-background': rampaClara[2],
  'label-border': '10, 10, 10, 0.08',
  overlay: '10, 10, 10, 0.4',
});

const escuro = semantico(base.color.semantic.dark, {
  // O primário INVERTE no escuro — na referência passa a #E5E5E5 sobre texto
  // escuro. Um botão quase preto sobre fundo quase preto não se vê.
  'brand-color': R('dark', 'primary'),
  'brand-foreground': R('dark', 'primary-foreground'),
  'background-color': rampaEscura[0],
  'surface-1': rampaEscura[2],
  'surface-2': rampaEscura[3],
  'surface-active': R('dark', 'accent'),
  'solid-1': R('dark', 'popover'),
  'solid-2': rampaEscura[4],
  'solid-3': rampaEscura[5],
  'card-color': R('dark', 'card'),
  'card-ring': fioEscuro,
  'sidebar-color': R('dark', 'sidebar'),
  'border-weak': fioEscuro,
  'border-strong': fioEscuroForte,
  'border-container': fioEscuro,
  'focus-ring': focoEscuro,
  'label-background': rampaEscura[4],
  'label-border': '250, 250, 250, 0.10',
  overlay: '0, 0, 0, 0.6',
});

// --- paleta de etapas: medida, não recordada ------------------------------------

const medirPaleta = hexes => {
  const args = [
    resolve(RAIZ, 'scripts/validate_palette.js'),
    hexes.join(','),
    '--mode',
    'light',
    '--pairs',
    'all',
  ];
  let saida;
  let passou = true;
  try {
    saida = execFileSync(process.execPath, args, { encoding: 'utf8' });
  } catch (erro) {
    saida = `${erro.stdout ?? ''}${erro.stderr ?? ''}`;
    passou = false;
  }
  return { passou, saida };
};

const etapas = base.stage.palette;
const { passou } = medirPaleta(etapas);
if (!passou)
  throw new Error('a paleta de etapas reprovou no validador — não gero uma direção que reprova');

// --- contrastes aferidos --------------------------------------------------------

// O passo 9 (#A1A1A1) é fio de desativado, não texto: 2,58:1 não serve para ler.
// Marcador de posição usa o passo 10, como na referência (`placeholder:text-muted-foreground`).
const aferido = {
  'texto sobre fundo': contraste(rampaClara[11], rampaClara[0]),
  'texto secundário sobre fundo': contraste(rampaClara[9], rampaClara[0]),
  'desativado (passo 9) sobre fundo': contraste(rampaClara[8], rampaClara[0]),
  'ação: texto sobre primário': contraste(R('light', 'primary-foreground'), R('light', 'primary')),
  'anel de foco sobre fundo': contraste(focoClaro, rampaClara[0]),
  'escuro: texto sobre fundo': contraste(rampaEscura[11], rampaEscura[0]),
  'escuro: texto secundário sobre cartão': contraste(rampaEscura[9], rampaEscura[2]),
  'escuro: texto sobre primário': contraste(R('dark', 'primary-foreground'), R('dark', 'primary')),
};

// --- o documento ----------------------------------------------------------------

const a = {
  name: 'Raevo',
  direction: 'A · Consultório',
  status: 'aprovada — 19/09/2026',
  basedOn: base.direction,
  reference: {
    repo: 'arhamkhnz/next-shadcn-admin-dashboard',
    extraido: 'design-system/referencia/shadcn.tokens.json',
    traduzido: 'design-system/referencia/traducao.json',
  },
  thesis:
    'A base não tem cor nenhuma, e por isso toda a cor que aparece no ecrã significa ' +
    'alguma coisa: etapa do funil, cobrança vencida, conversa por responder. A ação ' +
    'é quase preta, não azul — no shadcn a cor de marca não ocupa o primário. A ' +
    'densidade vem da caixa, não do tipo: botão de 32px, célula de 8px, cartão com ' +
    'anel de 1px em vez de sombra. O tipo fica onde já estava.',
  spec: 'design-system/aprovado/README.md',
  color: {
    ramp: { light: rampa(rampaClara, base.color.ramp.light), dark: rampa(rampaEscura, base.color.ramp.dark) },
    semantic: { light: claro, dark: escuro },
    accessibility: { contrast: aferido, focus: focoRecusado },
  },
  stage: {
    ...base.stage,
    note:
      'A paleta de etapas NÃO vem da referência: os cinco tons de gráfico dela são ' +
      'cinzentos de croma zero, que não servem para distinguir etapa. Fica a do ' +
      'Raevo, que é dado gravado em produção e mede ΔE 9,7 no pior par.',
  },
  chart: {
    // Cinco cinzentos, croma zero. O gráfico não compete com a etapa.
    light: Object.fromEntries(
      [1, 2, 3, 4, 5].map(i => [`chart-${i}`, tok(R('light', `chart-${i}`))])
    ),
    dark: Object.fromEntries([1, 2, 3, 4, 5].map(i => [`chart-${i}`, tok(R('dark', `chart-${i}`))])),
    note:
      'Série de um tom por omissão, com rótulo direto. Cor no gráfico só quando a ' +
      'série É uma etapa do funil — aí usa a paleta de etapas, não estes cinzentos.',
  },
  shape: {
    // Raio por FÓRMULA, como na referência: uma base e o resto em calc().
    radius: {
      base: '10px',
      formula: { sm: 'base - 4px', md: 'base - 2px', lg: 'base', xl: 'base + 4px', '2xl': 'base + 8px', '3xl': 'base + 12px' },
      tailwind: { DEFAULT: '8px', sm: '6px', md: '8px', lg: '10px', xl: '14px', '2xl': '18px', '3xl': '22px' },
      token: {
        'radius-card': { value: '14px' },
        'radius-item': { value: '8px' },
        'radius-control': { value: '10px' },
        'radius-pill': { value: '9999px' },
      },
      note:
        'Muda a regra 4 do AGENTS.md: no Sereno o controlo era pílula. Em Consultório ' +
        'a pílula fica para o selo e para a barra de pesquisa; botão e campo são 10px. ' +
        'A densidade alta tira largura ao controlo e dois botões-pílula adjacentes ' +
        'ficam ambíguos.',
    },
    borderWidth: { DEFAULT: '1px' },
  },
  density: {
    // Medido no código da referência. É daqui que vem a densidade — não do tipo.
    control: { xs: '24px', sm: '28px', DEFAULT: '32px', lg: '36px' },
    controlPaddingX: '10px',
    controlGap: '6px',
    iconSize: '16px',
    tableCell: '8px',
    tableHead: '40px',
    cardSpacing: '16px',
    cardSpacingSm: '12px',
    sidebar: { DEFAULT: '256px', rail: '48px', mobile: '288px' },
    note:
      'botão h-8 px-2.5 gap-1.5 · tabela th h-10 px-2, td p-2 · cartão --card-spacing ' +
      '= spacing(4) · barra lateral 16rem, rail 3rem, 18rem em telemóvel.',
  },
  shadow: {
    // A referência praticamente não usa sombra: o cartão separa-se por `ring-1
    // ring-foreground/10`. A regra 3 do Sereno — `shadow-sm` é `none` — sobrevive.
    tailwind: {
      none: 'none',
      sm: 'none',
      DEFAULT: 'var(--raevo-shadow-hover)',
      md: 'var(--raevo-shadow-hover)',
      lg: 'var(--raevo-shadow-float)',
      xl: 'var(--raevo-shadow-float)',
      '2xl': 'var(--raevo-shadow-float)',
    },
    token: {
      light: {
        'shadow-rest': { value: 'none' },
        'shadow-hover': { value: '0 4px 16px rgb(10 10 10 / 9%)' },
        'shadow-float': { value: '0 16px 40px rgb(10 10 10 / 14%)' },
      },
      dark: {
        'shadow-rest': { value: 'none' },
        'shadow-hover': { value: '0 4px 16px rgb(0 0 0 / 50%)' },
        'shadow-float': { value: '0 16px 40px rgb(0 0 0 / 65%)' },
      },
    },
    note: 'Em repouso separa o anel, não a sombra. Sombra só para o que flutua: modal, menu, drawer.',
  },
  typography: {
    // Aferido no código da referência: `globals.css` não redefine nenhum degrau, e
    // os componentes usam text-sm/text-xs/text-base. É a escala do Tailwind — que
    // é EXATAMENTE a que o Raevo já tem. Tipografia não muda nada.
    scale: base.typography.scale,
    extras: base.typography.extras,
    fontStack: base.typography.fontStack,
    roles: {
      body: 'text-sm (14px)',
      control: 'text-sm (14px) · xs: text-xs (12px)',
      tableCell: 'text-sm (14px)',
      cardTitle: 'text-base (16px), leading-snug, 500',
      pageTitle: 'text-xl (20px)',
      kpi: 'text-3xl (30px), tabular-nums',
    },
    note:
      'A referência não mexe na escala tipográfica: a densidade dela vem da caixa. ' +
      'Isto poupa a migração inteira da tipografia — a escala de seis degraus do ' +
      'AGENTS.md fica como está.',
  },
  motion: {
    // O AGENTS.md pede 150–250 ms em superfície operacional. A referência usa
    // `transition-all` sem duração, o que dá os 150 ms do Tailwind.
    instant: '100ms',
    DEFAULT: '150ms',
    panel: '200ms',
    overlay: '250ms',
    easing: 'cubic-bezier(0.2, 0, 0, 1)',
    note:
      'Nada se move sem explicar estado ou transição. `prefers-reduced-motion: reduce` ' +
      'desliga tudo — é obrigatório, não opcional.',
  },
  plate: {
    plate: tok(rampaClara[11]),
    'plate-soft': tok(rampaEscura[4]),
    'plate-fg': tok(rampaClara[0]),
    'plate-muted': tok(rampaClara[8]),
  },
};

writeFileSync(
  resolve(RAIZ, 'design-system/aprovado/consultorio.tokens.json'),
  `${JSON.stringify(a, null, 2)}\n`
);

console.log('✓ design-system/aprovado/consultorio.tokens.json');
console.log(`  rampa: ${Object.keys(a.color.ramp.light).length} claros · ${Object.keys(a.color.ramp.dark).length} escuros`);
console.log(`  semânticos: ${Object.keys(claro).length}`);
console.log(`  etapas: ${etapas.join(' ')} + ${base.stage.terminal} (validador: passa)`);
console.log('  contrastes aferidos:');
for (const [k, v] of Object.entries(aferido)) console.log(`    ${v.toFixed(2)}:1  ${k}`);
console.log(`  foco: referência ${focoRecusado.referencia} dá ${focoRecusado.contrasteNoFundo}:1 — recusado, adotado ${focoRecusado.adotado} (${focoRecusado.contrasteAdotado}:1)`);
