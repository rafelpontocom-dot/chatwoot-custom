#!/usr/bin/env node
/**
 * Raevo — guardrail do design system.
 *
 * Falha se um componente escrever cor literal em vez de usar token.
 * A regra está em docs/raevo-design-system.md; este script a torna executável,
 * porque documentação sozinha se perde entre uma sessão e outra.
 *
 *   node scripts/check-design-tokens.mjs            # só o código do Raevo
 *   node scripts/check-design-tokens.mjs --all      # o dashboard inteiro
 */
import { readFileSync } from 'node:fs';
import { globSync } from 'node:fs';
import { execSync } from 'node:child_process';

const ESCOPO_RAEVO = [
  'app/javascript/dashboard/routes/dashboard/kanban',
  'app/javascript/dashboard/routes/dashboard/calendar',
  'app/javascript/dashboard/routes/dashboard/finance',
  'app/javascript/dashboard/routes/dashboard/forms',
  'app/javascript/v3/views/login',
];
const todos = process.argv.includes('--all');
const raizes = todos ? ['app/javascript/dashboard'] : ESCOPO_RAEVO;

const arquivos = raizes.flatMap(r => {
  try {
    return execSync(`find ${r} -name '*.vue' -not -path '*/specs/*'`, { encoding: 'utf8' })
      .split('\n').filter(Boolean);
  } catch { return []; }
});

// Cores de marca de terceiros e assets SVG são exceção legítima.
const PERMITIDO = /(currentColor|transparent|none|#fff\b|#ffffff\b|#000\b|#000000\b)/i;
const REGRAS = [
  { nome: 'cor hexadecimal literal', re: /#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/g,
    ignorar: l => /<svg|<path|<stop|<rect|<circle|fill=|stroke=|d=|viewBox|logo|brand-asset/i.test(l) },
  { nome: 'cor rgb()/hsl() literal', re: /\b(rgb|rgba|hsl|hsla)\(\s*\d/g,
    ignorar: l => /var\(--/.test(l) },
  // só valor arbitrário que É cor — text-[11px] e stroke-[1.5] são tamanho, não cor
  { nome: 'classe arbitrária de cor', re: /\b(bg|text|border|ring|fill|stroke|from|via|to)-\[(#|rgb|rgba|hsl|hsla)[^\]]*\]/g,
    ignorar: () => false },
  { nome: 'raio literal', re: /border-radius\s*:\s*\d/g, ignorar: l => /var\(--/.test(l) },
];

let achados = 0;
for (const arq of arquivos) {
  const linhas = readFileSync(arq, 'utf8').split('\n');
  linhas.forEach((linha, i) => {
    for (const regra of REGRAS) {
      regra.re.lastIndex = 0;
      const m = linha.match(regra.re);
      if (!m) continue;
      if (regra.ignorar(linha)) continue;
      const reais = m.filter(x => !PERMITIDO.test(x));
      if (!reais.length) continue;
      achados++;
      console.log(`${arq}:${i + 1}  ${regra.nome} → ${reais.join(', ')}`);
      console.log(`    ${linha.trim().slice(0, 110)}`);
    }
  });
}

console.log('');
if (achados) {
  console.log(`✗ ${achados} ocorrência(s) de valor literal em ${arquivos.length} arquivos.`);
  console.log('  Use os tokens n-* / --raevo-*. Ver docs/raevo-design-system.md §7.');
  process.exit(1);
}
console.log(`✓ ${arquivos.length} arquivos sem cor literal. Design system respeitado.`);
