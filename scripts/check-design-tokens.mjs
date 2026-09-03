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
  'app/javascript/dashboard/routes/dashboard/marketing',
  // O formulário do doente é a superfície mais exposta que temos e estava fora
  // da porta: foi lá que uma borda invisível passou despercebida.
  'app/javascript/public_form',
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
  // A auditoria de 30/08 contou 27 degraus de tipografia em uso, porque cada
  // tela inventava o seu com text-[Npx]. A escala tem seis degraus nomeados.
  { nome: 'tamanho de texto fora da escala', re: /\btext-\[[0-9.]+(px|rem|em)\]/g,
    ignorar: () => false },
];

/**
 * Borda de botão que não desenha.
 *
 * `_base.scss` do Chatwoot dá `border-0 border-none` a TODO `<button>`. Uma
 * utilitária `border-n-*` num botão define a cor mas não o estilo, e o
 * navegador calcula largura 0: a borda desaparece sem erro nenhum. Aconteceu
 * às linhas de campo, ao «+» das opções e às pastilhas de aba do Kanban ao
 * mesmo tempo, e só se viu no browser. É por tag, não por linha, porque a tag
 * de um botão real ocupa dez.
 */
/**
 * Percorre as tags `<button>` de um ficheiro, entregando classe e linha.
 * A tag de um botão real ocupa dez linhas; verificar por linha não a vê.
 */
function* botoes(fonte) {
  const abre = /<button\b/g;
  let m;
  while ((m = abre.exec(fonte))) {
    let i = abre.lastIndex;
    let aspa = null;
    while (i < fonte.length) {
      const c = fonte[i];
      if (aspa) {
        if (c === aspa) aspa = null;
      } else if (c === '"' || c === "'") aspa = c;
      else if (c === '>') break;
      i += 1;
    }
    const tag = fonte.slice(m.index, i + 1);
    yield {
      classes: [...tag.matchAll(/:?class="([^"]*)"/g)].map(x => x[1]).join(' '),
      linha: fonte.slice(0, m.index).split('\n').length,
    };
  }
}

/**
 * Ícone esmagado pelo padding de base.
 *
 * `_base.scss` dá `px-2.5` a TODO `<button>`: 20px de padding horizontal. Num
 * botão quadrado de 24px sobram 4px para o ícone, e ele desenha como um risco.
 * Um botão de 16px chega a sobrar -4px. Botão só-de-ícone declara `p-0`.
 */
function iconesEsmagados(fonte) {
  const achados = [];
  for (const { classes, linha } of botoes(fonte)) {
    const sz = /(^|[\s'"])size-(\d+(?:\.\d+)?)\b/.exec(classes);
    if (!sz) continue;
    if (/(^|[\s'"])p[xy]?-\d/.test(classes) || /(^|[\s'"])p-0\b/.test(classes))
      continue;
    // sobra = lado - 20px de padding; abaixo de 14px o ícone já não cabe
    if (Number(sz[2]) * 4 - 20 < 14) achados.push(linha);
  }
  return achados;
}

/**
 * Botão que submete o formulário sem querer.
 *
 * `Button.vue` renderiza um `<button>` sem `type`, e o HTML assume `submit`.
 * Dentro de um `<form>`, qualquer botão sem `type` explícito dispara o submit
 * além do seu próprio `@click`. Foi assim que «Excluir funil» abria o diálogo
 * de confirmação e ao mesmo tempo gravava as definições — e o redirecionamento
 * do save levava o diálogo com a página. O utilizador não conseguia apagar.
 */
function submitSemQuerer(fonte) {
  const achados = [];
  const inicio = fonte.indexOf('<form');
  if (inicio < 0) return achados;
  const fim = fonte.indexOf('</form>', inicio);
  if (fim < 0) return achados;

  const dentro = fonte.slice(inicio, fim);
  const abre = /<Button\b/g;
  let m;
  while ((m = abre.exec(dentro))) {
    let i = abre.lastIndex;
    let aspa = null;
    while (i < dentro.length) {
      const c = dentro[i];
      if (aspa) {
        if (c === aspa) aspa = null;
      } else if (c === '"' || c === "'") aspa = c;
      else if (c === '>') break;
      i += 1;
    }
    const tag = dentro.slice(m.index, i + 1);
    if (!/\stype=/.test(tag)) {
      achados.push(
        fonte.slice(0, inicio + m.index).split('\n').length
      );
    }
  }
  return achados;
}

function bordasInvisiveis(fonte) {
  const achados = [];
  const abre = /<button\b/g;
  let m;
  while ((m = abre.exec(fonte))) {
    let i = abre.lastIndex;
    let aspa = null;
    while (i < fonte.length) {
      const c = fonte[i];
      if (aspa) {
        if (c === aspa) aspa = null;
      } else if (c === '"' || c === "'") aspa = c;
      else if (c === '>') break;
      i += 1;
    }
    const tag = fonte.slice(m.index, i + 1);
    const classes = [...tag.matchAll(/:?class="([^"]*)"/g)].map(x => x[1]).join(' ');
    // `border-n-*` sem prefixo de estado é intenção de desenhar uma borda
    const querBorda = /(^|[\s'"])border-n-[a-z]+-?\d*\b/.test(classes);
    if (querBorda && !/border-(solid|dashed|dotted)/.test(classes)) {
      achados.push(fonte.slice(0, m.index).split('\n').length);
    }
  }
  return achados;
}

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

for (const arq of arquivos) {
  const fonte = readFileSync(arq, 'utf8');
  for (const linha of bordasInvisiveis(fonte)) {
    achados++;
    console.log(`${arq}:${linha}  borda de botão sem border-solid → invisível`);
    console.log('    `_base.scss` zera a borda de todo <button>; acrescente border-solid.');
  }
  for (const linha of submitSemQuerer(fonte)) {
    achados++;
    console.log(`${arq}:${linha}  <Button> sem type dentro de <form> → submete sem querer`);
    console.log('    Sem `type`, o HTML assume submit; acrescente type="button".');
  }
  for (const linha of iconesEsmagados(fonte)) {
    achados++;
    console.log(`${arq}:${linha}  botão quadrado sem p-0 → ícone esmagado`);
    console.log('    `_base.scss` dá px-2.5 a todo <button>; acrescente p-0.');
  }
}

console.log('');
if (achados) {
  console.log(`✗ ${achados} ocorrência(s) de valor fora do sistema em ${arquivos.length} arquivos.`);
  console.log('  Use os tokens n-* / --raevo-*. Ver docs/raevo-design-system.md §7.');
  process.exit(1);
}
console.log(`✓ ${arquivos.length} arquivos sem cor literal nem tamanho fora da escala.`);
