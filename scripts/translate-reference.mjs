#!/usr/bin/env node
/**
 * Raevo — traduz o design system extraído da referência para a nossa língua.
 *
 * A referência fala OKLCH + Tailwind v4 (`@theme inline`) + CVA. O Raevo fala
 * tripletos RGB em custom properties + Tailwind v3 (`tailwind.config.js`) + Vue.
 * As cores têm de ser convertidas, não copiadas: `oklch(.145 0 0)` não entra num
 * `rgb(var(--x) / <alpha-value>)`.
 *
 *   node scripts/translate-reference.mjs [entrada.json] [pasta-de-saida]
 *
 * Escreve a folha SCSS pronta a importar, o fragmento do tailwind.config.js e o
 * mapa de correspondência — incluindo o que não atravessa.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const entrada = process.argv[2] ?? 'design-system/referencia/shadcn.tokens.json';
const saida = process.argv[3] ?? 'design-system/referencia';
const d = JSON.parse(readFileSync(resolve(process.cwd(), entrada), 'utf8'));

// --- OKLCH -> sRGB -------------------------------------------------------------

const gama = c => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055);
const lim = x => Math.max(0, Math.min(255, Math.round(x * 255)));

/** `oklch(L C H)` ou `oklch(L C H / a)` -> [r,g,b] 0-255, ou null. */
const oklchParaRgb = txt => {
  const m = txt.match(/oklch\(\s*([\d.]+%?)\s+([\d.]+)\s+([\d.]+)/i);
  if (!m) return null;
  const L = m[1].endsWith('%') ? parseFloat(m[1]) / 100 : parseFloat(m[1]);
  const C = parseFloat(m[2]);
  const H = (parseFloat(m[3]) * Math.PI) / 180;
  const a = C * Math.cos(H);
  const b = C * Math.sin(H);
  const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = L - 0.0894841775 * a - 1.291485548 * b;
  const l3 = l_ ** 3;
  const m3 = m_ ** 3;
  const s3 = s_ ** 3;
  return [
    lim(gama(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3)),
    lim(gama(-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3)),
    lim(gama(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.707614701 * s3)),
  ];
};

const hex = ([r, g, b]) =>
  `#${[r, g, b].map(x => x.toString(16).padStart(2, '0')).join('').toUpperCase()}`;

// --- tradução dos tokens -------------------------------------------------------

/** Nomes que o Chatwoot/Raevo já consome — a ponte com o que existe. */
const PONTE = {
  background: 'background-color',
  card: 'card-color',
  border: 'border-weak',
  input: 'border-strong',
  primary: 'brand-color',
  foreground: 'slate-12',
  'muted-foreground': 'slate-10',
  muted: 'slate-3',
  accent: 'surface-active',
  popover: 'solid-1',
};

const converte = mapa => {
  const out = {};
  for (const [k, v] of Object.entries(mapa)) {
    const rgb = oklchParaRgb(v);
    if (rgb) out[k] = { oklch: v, rgb: rgb.join(' '), hex: hex(rgb), raevo: PONTE[k] ?? null };
    else out[k] = { raw: v, raevo: PONTE[k] ?? null };
  }
  return out;
};

const claro = converte(d.tokens.light);
const escuro = converte(d.tokens.dark);
const presets = Object.fromEntries(
  Object.entries(d.tokens.presets).map(([n, p]) => [
    n,
    { light: converte(p.light), dark: converte(p.dark) },
  ])
);

// --- folha SCSS ----------------------------------------------------------------

const linhas = (mapa, indent = '  ') =>
  Object.entries(mapa)
    .filter(([, v]) => v.rgb)
    .map(([k, v]) => `${indent}--shadcn-${k}: ${v.rgb};   // ${v.hex}`)
    .join('\n');

const ponte = (mapa, indent = '  ') =>
  Object.entries(mapa)
    .filter(([, v]) => v.rgb && v.raevo)
    .map(([k, v]) => `${indent}--${v.raevo}: var(--shadcn-${k});`)
    .join('\n');

const scss = `// scss-lint:disable PropertySortOrder
// =============================================================================
// REFERÊNCIA shadcn/ui — TRADUZIDA PARA O RAEVO
// GERADO por scripts/translate-reference.mjs a partir de ${entrada}
// Fonte: ${d.fonte.repo} (lido ${d.fonte.lido})
//
// A referência escreve cor em OKLCH; aqui vai em triplete RGB, que é o que o
// Chatwoot consome em \`rgb(var(--x) / <alpha-value>)\`. Fica FORA de \`@layer\`
// pela mesma razão que \`_raevo-tokens.scss\`: assim um \`git pull\` do upstream
// não desfaz a identidade.
//
// Importar DEPOIS de _raevo-tokens.scss para esta direção vencer.
// =============================================================================
:root {
  // --- valores da referência, convertidos ---
${linhas(claro)}

  // --- ponte: os nomes que o produto já consome ---
${ponte(claro)}

  // --- forma: raio por fórmula, como na referência ---
  --radius: ${d.tokens.light.radius ?? '0.625rem'};
  --raevo-radius-item: calc(var(--radius) - 2px);
  --raevo-radius-control: var(--radius);
  --raevo-radius-card: calc(var(--radius) + 4px);
}

.dark {
${linhas(escuro)}

${ponte(escuro)}
}
`;

// --- fragmento do tailwind.config.js (v3) --------------------------------------

const rad = {
  sm: 'calc(var(--radius) - 4px)',
  md: 'calc(var(--radius) - 2px)',
  lg: 'var(--radius)',
  xl: 'calc(var(--radius) + 4px)',
  '2xl': 'calc(var(--radius) + 8px)',
  '3xl': 'calc(var(--radius) + 12px)',
};
const cores = Object.keys(claro)
  .filter(k => claro[k].rgb)
  .map(k => `      '${k}': 'rgb(var(--shadcn-${k}) / <alpha-value>)',`)
  .join('\n');

const twjs = `// GERADO por scripts/translate-reference.mjs — fragmento para tailwind.config.js
//
// A referência usa Tailwind v4 e declara os tokens em \`@theme inline\`, que o
// Tailwind v3 não tem. Em v3 o mesmo mapeamento vive aqui, no \`theme.extend\`.
module.exports = {
  theme: {
    extend: {
      borderRadius: {
${Object.entries(rad).map(([k, v]) => `        '${k}': '${v}',`).join('\n')}
        DEFAULT: 'var(--radius)',
      },
      colors: {
${cores}
      },
      // Densidade medida na referência (button h-8/px-2.5, table th h-10 / td p-2).
      height: { btn: '32px', 'btn-sm': '28px', 'btn-xs': '24px', 'btn-lg': '36px', th: '40px' },
      width: { sidebar: '16rem', 'sidebar-icon': '3rem', 'sidebar-mobile': '18rem' },
    },
  },
};
`;

writeFileSync(resolve(process.cwd(), `${saida}/raevo-shadcn.scss`), scss);
writeFileSync(resolve(process.cwd(), `${saida}/tailwind-fragment.js`), twjs);
writeFileSync(
  resolve(process.cwd(), `${saida}/traducao.json`),
  `${JSON.stringify({ light: claro, dark: escuro, presets, radius: rad }, null, 2)}\n`
);

const n = Object.values(claro).filter(v => v.rgb).length;
console.log(`✓ ${saida}/raevo-shadcn.scss        ${n} cores convertidas de OKLCH`);
console.log(`✓ ${saida}/tailwind-fragment.js     mapeamento para Tailwind v3`);
console.log(`✓ ${saida}/traducao.json            ${Object.keys(presets).length} presets traduzidos`);
console.log(`  ponte para nomes do produto: ${Object.values(claro).filter(v => v.raevo).length} tokens`);
