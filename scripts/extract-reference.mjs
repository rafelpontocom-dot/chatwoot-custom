#!/usr/bin/env node
/**
 * Raevo — extrai o design system de uma referência shadcn/ui para dado nosso.
 *
 * A referência (arhamkhnz/next-shadcn-admin-dashboard) é React 19 + Tailwind v4 +
 * CVA + Radix. O Raevo é Vue 3 + Tailwind v3 + SCSS. Nada disto se copia: tem de
 * ser traduzido. Este script faz a parte que é mecânica — ler os valores reais em
 * vez de os adivinhar — e deixa registado o que NÃO atravessa.
 *
 *   node scripts/extract-reference.mjs <caminho-do-repo> [saida.json]
 *
 * Lê: globals.css (@theme inline, :root, .dark), os presets, e todos os blocos
 * cva() de components/ui. Escreve um JSON que o resto do sistema consome.
 */
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { resolve, basename } from 'node:path';

const raiz = process.argv[2];
const destino = process.argv[3] ?? 'design-system/referencia/shadcn.tokens.json';
if (!raiz) {
  console.error('uso: node scripts/extract-reference.mjs <repo> [saida.json]');
  process.exit(1);
}
const ler = p => readFileSync(resolve(raiz, p), 'utf8');

/** Declarações `--nome: valor;` dentro de um bloco delimitado por chavetas. */
const decls = bloco => {
  const out = {};
  for (const m of bloco.matchAll(/--([\w-]+)\s*:\s*([^;]+);/g)) out[m[1]] = m[2].trim();
  return out;
};

/** Recorta o corpo de `seletor { ... }` equilibrando chavetas. */
const corpo = (css, seletor) => {
  const i = css.indexOf(seletor);
  if (i === -1) return null;
  let nivel = 0;
  const abre = css.indexOf('{', i);
  for (let j = abre; j < css.length; j += 1) {
    if (css[j] === '{') nivel += 1;
    else if (css[j] === '}') {
      nivel -= 1;
      if (nivel === 0) return css.slice(abre + 1, j);
    }
  }
  return null;
};

// --- 1. tokens -----------------------------------------------------------------

const globals = ler('src/app/globals.css');
const tema = decls(corpo(globals, '@theme inline') ?? '');
const claro = decls(corpo(globals, ':root') ?? '');
const escuro = decls(corpo(globals, '.dark') ?? '');

const presets = {};
const dirPresets = resolve(raiz, 'src/styles/presets');
if (existsSync(dirPresets)) {
  for (const f of readdirSync(dirPresets).filter(n => n.endsWith('.css'))) {
    const css = ler(`src/styles/presets/${f}`);
    const nome = basename(f, '.css');
    presets[nome] = {
      light: decls(corpo(css, `:root[data-theme-preset="${nome}"]`) ?? ''),
      dark: decls(corpo(css, `.dark[data-theme-preset="${nome}"]`) ?? ''),
    };
  }
}

// --- 2. variantes de componente (cva) -----------------------------------------

/** Entradas `chave: "valor"` ou `chave: ["a","b"]` de um bloco de variantes. */
const entradas = bloco => {
  const out = {};
  const re = /(?:^|[,{\n])\s*"?([A-Za-z0-9_-]+)"?\s*:\s*(?:\[([^\]]*)\]|"((?:[^"\\]|\\.)*)"|`((?:[^`\\]|\\.)*)`)/gm;
  for (const m of bloco.matchAll(re)) {
    const v = m[2] ?? m[3] ?? m[4] ?? '';
    out[m[1]] = v.replace(/\s+/g, ' ').replace(/"/g, '').trim();
  }
  return out;
};

const componentes = {};
const dirUi = resolve(raiz, 'src/components/ui');
for (const f of readdirSync(dirUi).filter(n => n.endsWith('.tsx'))) {
  const src = ler(`src/components/ui/${f}`);
  const nome = basename(f, '.tsx');
  const reg = { file: `src/components/ui/${f}`, variants: {}, slots: [] };

  // base + grupos de variantes de cada cva()
  for (const m of src.matchAll(/(\w+)\s*=\s*cva\(\s*("(?:[^"\\]|\\.)*"|`(?:[^`\\]|\\.)*`)/g)) {
    reg.base = (m[2] ?? '').slice(1, -1).replace(/\s+/g, ' ').trim();
  }
  const v = corpo(src, 'variants: {');
  if (v) {
    for (const g of v.matchAll(/(\w+)\s*:\s*\{/g)) {
      const grupo = corpo(v.slice(v.indexOf(`${g[1]}:`)), `${g[1]}: {`);
      if (grupo) reg.variants[g[1]] = entradas(grupo);
    }
  }
  // slots (data-slot="...") — o vocabulário de anatomia do componente
  reg.slots = [...new Set([...src.matchAll(/data-slot="([\w-]+)"/g)].map(m => m[1]))];
  // funções exportadas = as peças que compõem o componente
  reg.parts = [...new Set([...src.matchAll(/^function ([A-Z]\w+)/gm)].map(m => m[1]))];

  if (reg.base || Object.keys(reg.variants).length || reg.parts.length) componentes[nome] = reg;
}

// --- 3. barreiras: o que não atravessa ----------------------------------------

const pkg = JSON.parse(ler('package.json'));
const dep = k => (pkg.dependencies ?? {})[k] ?? (pkg.devDependencies ?? {})[k] ?? null;

const saida = {
  fonte: {
    repo: 'arhamkhnz/next-shadcn-admin-dashboard',
    lido: new Date().toISOString().slice(0, 10),
    stack: {
      tailwind: dep('tailwindcss'),
      react: dep('react'),
      next: dep('next'),
      cva: dep('class-variance-authority'),
      recharts: dep('recharts'),
      lucide: dep('lucide-react'),
    },
    ecras: 35,
    componentes: Object.keys(componentes).length,
  },
  destino: {
    projeto: 'Raevo (fork do Chatwoot)',
    stack: { vue: 3, tailwind: 3, css: 'SCSS + custom properties', bundler: 'Vite' },
  },
  tokens: { theme: tema, light: claro, dark: escuro, presets },
  componentes,
};

writeFileSync(resolve(process.cwd(), destino), `${JSON.stringify(saida, null, 2)}\n`);
console.log(`✓ ${destino}`);
console.log(`  tokens: ${Object.keys(tema).length} no @theme · ${Object.keys(claro).length} claros · ${Object.keys(escuro).length} escuros`);
console.log(`  presets: ${Object.keys(presets).join(', ')}`);
console.log(`  componentes: ${Object.keys(componentes).length}`);
const comVar = Object.entries(componentes).filter(([, c]) => Object.keys(c.variants).length);
console.log(`  com variantes: ${comVar.length} — ${comVar.slice(0, 8).map(([n]) => n).join(', ')}…`);
