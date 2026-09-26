#!/usr/bin/env node
/**
 * Raevo — o design system como dado.
 *
 * A identidade "H · Sereno" existe desde 29/08/2026, mas existia só como texto:
 * o mesmo valor aparecia escrito à mão em quatro lugares — o triplete RGB em
 * `_raevo-tokens.scss`, o hexadecimal em `raevoPalette.js`, o argumento do
 * validador em `package.json` e as tabelas de `docs/raevo-design-system.md`.
 * Nada obrigava os quatro a concordarem. Um dígito trocado num deles passava.
 *
 * Este script transforma o sistema em dado verificável:
 *
 *   node scripts/design-tokens.mjs extract    # código  -> raevo.tokens.json
 *   node scripts/design-tokens.mjs check      # falha se o código divergir
 *   node scripts/design-tokens.mjs reference  # gera a referência viva em HTML
 *
 * `extract` é a migração — lê o que o produto realmente usa hoje e grava o JSON.
 * `check` é a porta — roda em CI e falha quando código e JSON discordam, ou
 * quando as quatro cópias da paleta deixam de concordar entre si.
 *
 * O JSON é a fonte da verdade declarada. O SCSS continua escrito à mão porque
 * os comentários dele explicam POR QUE cada valor é aquele — gerar o arquivo
 * apagaria a única memória dessas decisões. O `check` é o que mantém os dois
 * honestos.
 */
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mockup } from './design-mockup.mjs';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const P = {
  scss: 'app/javascript/dashboard/assets/scss/_raevo-tokens.scss',
  tailwind: 'tailwind.config.js',
  palette: 'app/javascript/dashboard/constants/raevoPalette.js',
  pkg: 'package.json',
  tokens: 'design-system/raevo.tokens.json',
  reference: 'design-system/reference.html',
  mockup: 'design-system/mockup.html',
  directions: 'design-system/directions',
  approved: 'design-system/aprovado',
};
const ler = rel => readFileSync(resolve(RAIZ, rel), 'utf8');
const gravar = (rel, txt) => writeFileSync(resolve(RAIZ, rel), txt);

// --- leitura do CSS ----------------------------------------------------------

/** Tripletes `37 99 235` viram `#2563EB`; qualquer outra forma fica como está. */
const paraHex = valor => {
  const partes = valor.trim().split(/\s+/);
  if (partes.length !== 3 || !partes.every(p => /^\d{1,3}$/.test(p))) return null;
  const n = partes.map(Number);
  if (n.some(x => x > 255)) return null;
  return `#${n.map(x => x.toString(16).padStart(2, '0')).join('').toUpperCase()}`;
};

/**
 * Lê as custom properties de um bloco (`:root` ou `.dark`).
 * Declarações podem ocupar várias linhas — a pilha de fontes ocupa duas — então
 * acumulamos até o `;`.
 */
const lerBloco = (scss, seletor) => {
  const linhas = scss.split('\n');
  const abre = new RegExp(`^${seletor}\\s*\\{`);
  let dentro = false;
  let buffer = '';
  const out = {};
  for (const linha of linhas) {
    if (!dentro) {
      if (abre.test(linha)) dentro = true;
      continue;
    }
    if (/^\}/.test(linha)) break;
    buffer += ` ${linha.replace(/\/\/.*$/, '')}`;
    if (!buffer.includes(';')) continue;
    for (const decl of buffer.split(';')) {
      const m = decl.match(/--([a-z0-9-]+)\s*:\s*(.+)/i);
      if (m) out[m[1]] = m[2].trim().replace(/\s+/g, ' ');
    }
    buffer = '';
  }
  return out;
};

/** Separa as custom properties nas famílias que o sistema realmente tem. */
const RAMPAS = ['slate', 'gray', 'blue', 'teal', 'amber', 'ruby', 'violet', 'iris'];
const classificar = props => {
  const rampa = {};
  const semantico = {};
  const raevo = {};
  for (const [nome, valor] of Object.entries(props)) {
    const registro = { value: valor, ...(paraHex(valor) ? { hex: paraHex(valor) } : {}) };
    const m = nome.match(/^([a-z]+)-(\d{1,2})$/);
    if (nome.startsWith('raevo-')) raevo[nome.slice('raevo-'.length)] = registro;
    else if (m && RAMPAS.includes(m[1])) rampa[nome] = registro;
    else semantico[nome] = registro;
  }
  return { rampa, semantico, raevo };
};

// --- leitura do Tailwind -----------------------------------------------------

/** Recorta `chave: { ... }` equilibrando chaves, sem avaliar o módulo. */
const recortarBloco = (js, chave) => {
  const inicio = js.indexOf(`${chave}: {`);
  if (inicio === -1) return null;
  let i = js.indexOf('{', inicio);
  let nivel = 0;
  for (let j = i; j < js.length; j += 1) {
    if (js[j] === '{') nivel += 1;
    else if (js[j] === '}') {
      nivel -= 1;
      if (nivel === 0) return js.slice(i + 1, j);
    }
  }
  return null;
};

/** Entradas `nome: 'valor'` e `nome: ['11px', '15px']`, ignorando spreads. */
const lerEntradas = bloco => {
  const out = {};
  if (!bloco) return out;
  const re = /(?:^|[,{\n])\s*'?([A-Za-z0-9_-]+)'?\s*:\s*(\[[^\]]*\]|'[^']*'|"[^"]*")/gm;
  let m = re.exec(bloco);
  while (m) {
    const bruto = m[2].trim();
    out[m[1]] = bruto.startsWith('[')
      ? bruto.slice(1, -1).split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean)
      : bruto.replace(/^['"]|['"]$/g, '');
    m = re.exec(bloco);
  }
  return out;
};

// --- leitura da paleta de dados ---------------------------------------------

const hexesDe = (js, exportacao) => {
  const bloco = js.slice(js.indexOf(`${exportacao} =`));
  const fim = bloco.indexOf(';');
  return (bloco.slice(0, fim).match(/#[0-9a-fA-F]{6}/g) || []).map(h => h.toUpperCase());
};

// --- acessibilidade medida, não lembrada -------------------------------------

/**
 * Roda o validador de daltonismo na paleta que o código realmente usa e grava o
 * que ele mediu. Números escritos à mão envelhecem em silêncio: trocar uma cor
 * deixaria o JSON a afirmar um ΔE que já não vale.
 */
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
    // Saída não-zero = a paleta reprovou. Isso é resultado, não falha de setup:
    // registramos e deixamos `check` recusar o commit.
    saida = `${erro.stdout ?? ''}${erro.stderr ?? ''}`;
    passou = false;
  }
  const num = re => {
    const m = saida.match(re);
    return m ? Number(m[1]) : null;
  };
  return {
    validator: 'node scripts/validate_palette.js "<paleta>" --mode light --pairs all',
    pass: passou && /ALL CHECKS PASS/.test(saida),
    worstPair: (saida.match(/worst all-pairs (#[0-9A-Fa-f]{6}.#[0-9A-Fa-f]{6})/) ?? [])[1] ?? null,
    deltaE: {
      deuteranopia: num(/CVD separation[^\n]*?\u0394E ([\d.]+) \(deutan\)/),
      tritanopia: num(/tritan ([\d.]+)/),
      normal: num(/Normal-vision floor[^\n]*?\u0394E ([\d.]+) \(normal\)/),
    },
    forbidden: [
      { pair: ['#2563EB', '#7C3AED'], reason: '\u0394E 0,4 em deuteranopia' },
      { pair: ['Google Calendar Tangerine', 'Basil'], reason: '\u0394E 3,4' },
    ],
  };
};

// --- extração completa -------------------------------------------------------

const lerDoCodigo = () => {
  const scss = ler(P.scss);
  const tailwind = ler(P.tailwind);
  const palette = ler(P.palette);
  const pkg = JSON.parse(ler(P.pkg));

  const claro = classificar(lerBloco(scss, ':root'));
  const escuro = classificar(lerBloco(scss, '\\.dark'));
  const radius = lerEntradas(recortarBloco(tailwind, 'borderRadius'));
  const shadow = lerEntradas(recortarBloco(tailwind, 'boxShadow'));
  const fontSize = lerEntradas(recortarBloco(tailwind, 'fontSize'));

  // `--raevo-x` do bloco claro; a densidade não tem variante escura.
  const v = nome => claro.raevo[nome]?.value ?? null;

  const etapas = hexesDe(palette, 'RAEVO_STAGE_COLORS');
  const terminal = hexesDe(palette, 'RAEVO_TERMINAL_COLOR')[0];
  const extrasSeletor = hexesDe(palette, 'RAEVO_PICKER_COLORS');
  const validador = (pkg.scripts['raevo:palette'].match(/#[0-9a-fA-F]{6}/g) || []).map(h =>
    h.toUpperCase()
  );

  return {
    name: 'Raevo',
    // O código migrou para A · Consultório a 21/09/2026. A direção gravada tem de
    // dizer o que o código é: um mockup a anunciar «Sereno» com tokens de
    // Consultório é pior do que não ter mockup nenhum.
    direction: 'A · Consultório',
    approved: '2026-09-19',
    spec: 'docs/raevo-design-system.md',
    note:
      'Extraído do código por scripts/design-tokens.mjs. Este arquivo é a fonte da ' +
      'verdade declarada; `check` falha se o código divergir dele.',
    sources: [P.scss, P.tailwind, P.palette, P.pkg],
    color: {
      ramp: { light: claro.rampa, dark: escuro.rampa },
      semantic: { light: claro.semantico, dark: escuro.semantico },
    },
    stage: {
      // Cor que vira DADO: fica gravada no banco, por isso nasce em hexadecimal.
      palette: etapas,
      terminal,
      pickerExtras: extrasSeletor,
      validatorArgs: validador,
      token: {
        light: Object.fromEntries(
          Object.entries(claro.raevo).filter(([k]) => k.startsWith('stage-'))
        ),
        dark: Object.fromEntries(
          Object.entries(escuro.raevo).filter(([k]) => k.startsWith('stage-'))
        ),
      },
      accessibility: medirPaleta(etapas),
    },
    // A CAIXA: a terceira parte de Consultório. Ficou fora do código de 21/09 a
    // 25/09/2026 porque nada aqui a lia — e por isso nada a comparava com a
    // direção aprovada. O produto tinha a cor e o raio certos e a caixa errada.
    density: {
      control: {
        xs: v('control-h-xs'),
        sm: v('control-h-sm'),
        DEFAULT: v('control-h'),
        lg: v('control-h-lg'),
      },
      controlPaddingX: v('control-px'),
      controlGap: v('control-gap'),
      iconSize: v('icon-size'),
      tableCell: v('table-cell'),
      tableHead: v('table-head'),
      cardSpacing: v('card-spacing'),
      cardSpacingSm: v('card-spacing-sm'),
      sidebar: {
        DEFAULT: v('sidebar-w'),
        rail: v('sidebar-rail'),
        mobile: v('sidebar-mobile'),
      },
    },
    shape: {
      radius: {
        tailwind: radius,
        token: Object.fromEntries(
          Object.entries(claro.raevo).filter(([k]) => k.startsWith('radius-'))
        ),
      },
      borderWidth: lerEntradas(recortarBloco(tailwind, 'borderWidth')),
    },
    shadow: {
      tailwind: shadow,
      token: {
        light: Object.fromEntries(
          Object.entries(claro.raevo).filter(([k]) => k.startsWith('shadow-'))
        ),
        dark: Object.fromEntries(
          Object.entries(escuro.raevo).filter(([k]) => k.startsWith('shadow-'))
        ),
      },
    },
    typography: {
      // Seis degraus. A auditoria contou 27 em uso antes do sistema existir.
      scale: ['micro', 'xs', 'sm', 'base', 'xl', '3xl'],
      extras: fontSize,
      fontStack: claro.raevo['font-sans']?.value ?? null,
    },
    plate: Object.fromEntries(
      Object.entries(claro.raevo).filter(([k]) => k.startsWith('plate'))
    ),
  };
};

// --- invariantes: as cópias precisam concordar entre si ----------------------

/**
 * Estas não comparam com o JSON — comparam o código consigo mesmo. São os erros
 * que passavam silenciosos: o triplete RGB do SCSS e o hexadecimal do JS são a
 * mesma decisão escrita duas vezes.
 */
const invariantes = t => {
  const falhas = [];
  t.stage.palette.forEach((hex, i) => {
    const token = t.stage.token.light[`stage-${i + 1}`];
    if (!token) falhas.push(`--raevo-stage-${i + 1} não existe, mas RAEVO_STAGE_COLORS[${i}] sim`);
    else if (token.hex !== hex)
      falhas.push(
        `--raevo-stage-${i + 1} (${token.hex}) ≠ RAEVO_STAGE_COLORS[${i}] (${hex})`
      );
  });

  const terminalToken = t.stage.token.light[`stage-${t.stage.palette.length + 1}`];
  if (terminalToken && terminalToken.hex !== t.stage.terminal)
    falhas.push(
      `--raevo-stage-${t.stage.palette.length + 1} (${terminalToken.hex}) ≠ ` +
        `RAEVO_TERMINAL_COLOR (${t.stage.terminal})`
    );

  // A CAIXA tem de bater com a direção aprovada.
  //
  // Esta é a invariante que faltava, e a lacuna custou o produto inteiro: cor e
  // raio migraram para Consultório a 21/09/2026, a densidade não, e a porta
  // comparava cor, etapa, forma e tipografia — nunca a caixa. Resultado: os
  // tokens estavam certos, o `consultorio.tokens.json` afirmava botão de 32px e
  // célula de 8px, e o código não tinha nenhum dos dois. Quatro dias em que a
  // porta passava a dizer «em acordo» sobre um desacordo.
  try {
    const aprovada = JSON.parse(ler(`${P.approved}/consultorio.tokens.json`));
    if (aprovada.density) {
      // `note` é a prosa que explica de onde vieram os números; não é valor.
      const { note, ...caixa } = aprovada.density;
      for (const d of diferencas(caixa, t.density, 'density'))
        falhas.push(
          `${d.caminho}: a direção aprovada diz ${JSON.stringify(d.json)}, ` +
            `o código diz ${JSON.stringify(d.codigo)}`
        );
    }
  } catch (e) {
    falhas.push(`não foi possível comparar a densidade com a direção aprovada: ${e.message}`);
  }

  if (t.stage.validatorArgs.join(',') !== t.stage.palette.join(','))
    falhas.push(
      `o argumento de "raevo:palette" (${t.stage.validatorArgs.join(',')}) ≠ ` +
        `RAEVO_STAGE_COLORS (${t.stage.palette.join(',')}) — o validador está a ` +
        'aprovar uma paleta que o produto não usa'
    );

  if (!t.stage.accessibility.pass)
    falhas.push(
      'a paleta de etapas reprovou no validador de daltonismo — rode ' +
        '`pnpm raevo:palette` para ver que verificação falhou'
    );

  // O emparelhamento mudou com a direção. Em Sereno o item era `lg` (11px) e o
  // controlo era pílula, por isso não tinha degrau. Em Consultório o raio sai de
  // uma fórmula sobre --radius = 10px: item = md, controlo = lg, cartão = xl.
  const par = [
    ['md', 'radius-item'],
    ['lg', 'radius-control'],
    ['xl', 'radius-card'],
  ];
  for (const [tw, tk] of par) {
    const a = t.shape.radius.tailwind[tw];
    const b = t.shape.radius.token[tk]?.value;
    if (a && b && a !== b) falhas.push(`rounded-${tw} (${a}) ≠ --raevo-${tk} (${b})`);
  }

  for (const modo of ['light', 'dark']) {
    const etapas = Object.keys(t.stage.token[modo]).length;
    const esperado = t.stage.palette.length + 1;
    if (etapas !== esperado)
      falhas.push(`${modo}: ${etapas} tokens de etapa, esperava ${esperado}`);
  }

  return falhas;
};

// --- diff entre JSON e código ------------------------------------------------

const diferencas = (a, b, caminho = '') => {
  const out = [];
  const chaves = new Set([...Object.keys(a ?? {}), ...Object.keys(b ?? {})]);
  for (const k of chaves) {
    const p = caminho ? `${caminho}.${k}` : k;
    const va = a?.[k];
    const vb = b?.[k];
    if (JSON.stringify(va) === JSON.stringify(vb)) continue;
    if (va && vb && typeof va === 'object' && typeof vb === 'object' && !Array.isArray(va))
      out.push(...diferencas(va, vb, p));
    else out.push({ caminho: p, json: va, codigo: vb });
  }
  return out;
};

// --- referência viva ---------------------------------------------------------

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

const swatches = (titulo, mapa) => {
  const itens = Object.entries(mapa)
    .map(
      ([nome, v]) => `<figure class="sw">
        <div class="chip" style="background:${v.hex ?? `rgb(${v.value})`}"></div>
        <figcaption><code>--${esc(nome)}</code><span>${esc(v.hex ?? v.value)}</span></figcaption>
      </figure>`
    )
    .join('');
  return `<h3>${esc(titulo)}</h3><div class="grid">${itens}</div>`;
};

/** Um valor do conjunto, em CSS pronto a usar. */
const css = (t, caminho, alt) => {
  const partes = caminho.split('.');
  let v = t;
  for (const k of partes) v = v?.[k];
  if (!v) return alt;
  const bruto = v.value ?? v;
  if (typeof bruto !== 'string') return alt;
  // Triplete RGB vira rgb(); qualquer outra coisa (px, sombra) passa direto.
  return /^\d{1,3} \d{1,3} \d{1,3}$/.test(bruto.trim()) ? `rgb(${bruto})` : bruto;
};

/**
 * A página veste a direção que descreve. Uma referência que se desenha com a
 * identidade antiga mostra amostras; esta mostra o sistema.
 */
const referencia = (t, origem = P.tokens) => `<!doctype html>
<html lang="pt"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Raevo — referência do sistema</title>
<style>
  :root {
    color-scheme: light;
    --bg: ${css(t, 'color.semantic.light.background-color', '#F7F8FA')};
    --card: ${css(t, 'color.semantic.light.card-color', '#fff')};
    --ink: ${css(t, 'color.ramp.light.slate-12', '#111827')};
    --muted: ${css(t, 'color.ramp.light.slate-10', '#7A828F')};
    --line: ${css(t, 'color.semantic.light.border-weak', '#E9EBEF')};
    --r-card: ${css(t, 'shape.radius.token.radius-card', '13px')};
    --r-item: ${css(t, 'shape.radius.token.radius-item', '11px')};
    --r-ctrl: ${css(t, 'shape.radius.token.radius-control', '9999px')};
    --sh-rest: ${css(t, 'shadow.token.light.shadow-rest', 'none')};
    --sh-float: ${css(t, 'shadow.token.light.shadow-float', '0 12px 34px rgb(17 24 39 / 10%)')};
  }
  [data-tema="dark"] {
    color-scheme: dark;
    --bg: ${css(t, 'color.semantic.dark.background-color', '#0F1115')};
    --card: ${css(t, 'color.semantic.dark.card-color', '#1A1F26')};
    --ink: ${css(t, 'color.ramp.dark.slate-12', '#E8EAEE')};
    --muted: ${css(t, 'color.ramp.dark.slate-10', '#858D9A')};
    --line: ${css(t, 'color.semantic.dark.border-weak', '#262B33')};
    --sh-rest: ${css(t, 'shadow.token.dark.shadow-rest', 'none')};
    --sh-float: ${css(t, 'shadow.token.dark.shadow-float', '0 14px 38px rgb(0 0 0 / 52%)')};
  }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font:14px/1.6
         'Plus Jakarta Sans', system-ui, sans-serif; }
  header { position:sticky; top:0; background:var(--bg); border-bottom:1px solid var(--line);
           padding:16px 24px; display:flex; gap:16px; align-items:center; flex-wrap:wrap; }
  h1 { font-size:20px; margin:0; }
  h2 { font-size:20px; margin:40px 0 4px; }
  h3 { font-size:12px; text-transform:uppercase; letter-spacing:.06em;
       color:var(--muted); margin:24px 0 8px; }
  main { padding:0 24px 64px; max-width:1100px; margin:0 auto; }
  .meta { color:var(--muted); font-size:12px; }
  button { font:inherit; border:1px solid var(--line); background:var(--card);
           color:var(--ink); border-radius:var(--r-ctrl); padding:6px 14px;
           cursor:pointer; box-shadow:var(--sh-rest); }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(150px,1fr)); gap:10px; }
  .sw { margin:0; background:var(--card); border:1px solid var(--line);
        border-radius:var(--r-item); overflow:hidden; box-shadow:var(--sh-rest); }
  .chip { height:52px; }
  figcaption { padding:7px 9px; display:flex; flex-direction:column; gap:1px; }
  code { font:11px/1.4 ui-monospace, monospace; }
  figcaption span { color:var(--muted); font-size:11px; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  td, th { text-align:left; padding:7px 10px; border-bottom:1px solid var(--line); }
  th { color:var(--muted); font-weight:500; font-size:11px; text-transform:uppercase; }
  .amostra { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-end; }
  .raio { width:74px; height:74px; background:var(--card); border:1px solid var(--line);
          display:grid; place-items:center; font-size:11px; color:var(--muted); }
  .aviso { background:var(--card); border:1px solid var(--line); border-left-width:3px;
           border-radius:var(--r-card); padding:12px 14px; margin:12px 0;
           box-shadow:var(--sh-rest); }
  @media (max-width:600px) { main, header { padding-left:16px; padding-right:16px; } }
</style></head>
<body>
<header>
  <h1>Raevo · ${esc(t.direction)}</h1>
  <span class="meta">${esc(t.approved ? `aprovado ${t.approved}` : (t.status ?? 'proposta'))} · gerado de <code>${esc(origem)}</code></span>
  <button id="tema" type="button">Alternar tema</button>
</header>
<main>
  <p class="aviso">Esta página é <strong>gerada</strong> de <code>${esc(origem)}</code>,
  e está desenhada com os tokens que descreve — o que se vê é o sistema, não uma
  amostra dele.${t.thesis ? ` <strong>Tese:</strong> ${esc(t.thesis)}` : ''}</p>

  <h2>Etapas do funil</h2>
  <p class="meta">Paleta travada. Pior par ${esc(t.stage.accessibility.worstPair ?? '')} · ΔE ${t.stage.accessibility.deltaE.deuteranopia}
  em deuteranopia. Não trocar sem rodar <code>pnpm raevo:palette</code>.</p>
  <div class="grid">
    ${[...t.stage.palette, t.stage.terminal]
      .map(
        (h, i) => `<figure class="sw"><div class="chip" style="background:${h}"></div>
      <figcaption><code>etapa ${i + 1}${i === t.stage.palette.length ? ' · terminal' : ''}</code>
      <span>${h}</span></figcaption></figure>`
      )
      .join('')}
  </div>

  <h2>Cor — rampas</h2>
  ${swatches('Claro', t.color.ramp.light)}
  ${swatches('Escuro', t.color.ramp.dark)}

  <h2>Cor — semânticos</h2>
  ${swatches('Claro', t.color.semantic.light)}

  <h2>Forma</h2>
  <div class="amostra">
    ${Object.entries(t.shape.radius.tailwind)
      .map(
        ([n, v]) =>
          `<div class="raio" style="border-radius:${v}">rounded${n === 'DEFAULT' ? '' : `-${n}`}<br>${v}</div>`
      )
      .join('')}
  </div>

  <h2>Sombra</h2>
  <table><tr><th>Token</th><th>Valor</th></tr>
  ${Object.entries(t.shadow.tailwind)
    .map(([n, v]) => `<tr><td><code>shadow-${esc(n)}</code></td><td><code>${esc(v)}</code></td></tr>`)
    .join('')}
  </table>

  <h2>Tipografia</h2>
  <p class="meta">Seis degraus. Nunca <code>text-[Npx]</code>.</p>
  <table><tr><th>Classe</th><th>Amostra</th></tr>
  ${t.typography.scale
    .map(n => {
      const e = t.typography.extras?.[n];
      const px = Array.isArray(e) ? e[0] : { micro: '11px', xs: '12px', sm: '14px',
        base: '16px', xl: '20px', '3xl': '30px' }[n];
      return `<tr><td><code>text-${esc(n)}</code> · ${esc(px)}</td>
        <td style="font-size:${esc(px)}">Agendamento confirmado</td></tr>`;
    })
    .join('')}
  </table>
  <p class="meta">Pilha: <code>${esc(t.typography.fontStack ?? '')}</code></p>
</main>
<script>
  document.getElementById('tema').addEventListener('click', () => {
    const r = document.documentElement;
    r.dataset.tema = r.dataset.tema === 'dark' ? 'light' : 'dark';
  });
</script>
</body></html>
`;

// --- folha de estilo de uma direção -----------------------------------------

/**
 * Emite o SCSS que aplica uma direção ao produto inteiro.
 *
 * Redefine as mesmas custom properties que o Chatwoot consome, e fica FORA de
 * `@layer` pela mesma razão que `_raevo-tokens.scss`: CSS sem layer vence CSS
 * em layer, então um `git pull` do upstream não desfaz a identidade.
 *
 * Diferente do arquivo vigente, este é GERADO: não tem comentário de decisão a
 * preservar, porque a decisão está no JSON e na README da direção.
 */
const folha = (t, origem) => {
  const bloco = mapa =>
    Object.entries(mapa)
      .map(([nome, v]) => `  --${nome}: ${v.value};${v.hex ? `   // ${v.hex}` : ''}`)
      .join('\n');

  const extras = m =>
    Object.entries(m)
      .map(([nome, v]) => `  --${nome}: ${v.value};`)
      .join('\n');

  const etapas = modo =>
    Object.entries(t.stage.token[modo])
      .map(([nome, v]) => `  --raevo-${nome}: ${v.value};${v.hex ? `   // ${v.hex}` : ''}`)
      .join('\n');

  return `// scss-lint:disable PropertySortOrder
// =============================================================================
// ${t.name.toUpperCase()} — direção ${t.direction}
// GERADO por scripts/design-tokens.mjs a partir de ${origem}. Não editar à mão:
// mude o JSON e gere outra vez, senão a porta acusa divergência.
// =============================================================================
:root {
${bloco(t.color.ramp.light)}

${bloco(t.color.semantic.light)}

${extras(t.shape.radius.token)}
${extras(t.shadow.token.light)}
${t.typography.fontStack ? `  --raevo-font-sans: ${t.typography.fontStack};` : ''}

${etapas('light')}
}

.dark {
${bloco(t.color.ramp.dark)}

${bloco(t.color.semantic.dark)}
${extras(t.shadow.token.dark)}

${etapas('dark')}
}
`;
};

// --- CLI ---------------------------------------------------------------------

const comando = process.argv[2] ?? 'check';

if (comando === 'extract') {
  const t = lerDoCodigo();
  gravar(P.tokens, `${JSON.stringify(t, null, 2)}\n`);
  console.log(`✓ ${P.tokens} escrito a partir do código.`);
} else if (comando === 'reference') {
  // Sem argumentos gera a referência do sistema vigente; com eles, a de
  // qualquer direção — é assim que uma proposta se vê antes de ser adotada.
  const origem = process.argv[3] ?? P.tokens;
  const destino = process.argv[4] ?? P.reference;
  gravar(destino, referencia(JSON.parse(ler(origem)), origem));
  console.log(`✓ ${destino} gerado de ${origem}.`);
} else if (comando === 'scss') {
  const origem = process.argv[3];
  const destino = process.argv[4];
  if (!origem || !destino) {
    console.error('uso: design-tokens.mjs scss <tokens.json> <saida.scss>');
    process.exit(1);
  }
  gravar(destino, folha(JSON.parse(ler(origem)), origem));
  console.log(`✓ ${destino} gerado de ${origem}.`);
} else if (comando === 'check') {
  const codigo = lerDoCodigo();
  const falhas = invariantes(codigo);

  let deriva = [];
  try {
    deriva = diferencas(JSON.parse(ler(P.tokens)), codigo);
  } catch {
    console.error(`✗ ${P.tokens} não existe. Rode: node scripts/design-tokens.mjs extract`);
    process.exit(1);
  }

  // A referência é commitada para ser aberta sem build. Se ficar para trás,
  // volta a ser uma página que afirma valores que o produto já não usa — o
  // problema que este arquivo existe para acabar.
  let referenciaVelha = false;
  let mockupVelho = false;
  try {
    const t = JSON.parse(ler(P.tokens));
    referenciaVelha = ler(P.reference) !== referencia(t, P.tokens);
    mockupVelho = ler(P.mockup) !== mockup(t, P.tokens);
  } catch {
    referenciaVelha = true;
    mockupVelho = true;
  }

  for (const f of falhas) console.error(`✗ ${f}`);
  for (const d of deriva)
    console.error(
      `✗ ${d.caminho}: JSON diz ${JSON.stringify(d.json)}, o código diz ${JSON.stringify(d.codigo)}`
    );

  // Uma direção proposta também não pode mentir: o SCSS e a referência dela são
  // gerados, e ficam obsoletos no momento em que alguém edita só o JSON.
  const direcoesVelhas = [];
  const paletasDivergentes = [];
  for (const raiz of [P.directions, P.approved]) {
    const abs = resolve(RAIZ, raiz);
    if (!existsSync(abs)) continue;
    for (const f of readdirSync(abs).filter(n => n.endsWith('.tokens.json'))) {
      const origem = `${raiz}/${f}`;
      const t = JSON.parse(ler(origem));
      const base = f.replace(/\.tokens\.json$/, '');
      // Uma direção não pode trazer outra paleta de etapas pela porta das traseiras:
      // a paleta é dado gravado em produção e vale para o sistema inteiro.
      if (t.stage?.palette && t.stage.palette.join(',') !== codigo.stage.palette.join(','))
        paletasDivergentes.push(origem);
      for (const [suf, gerar] of [
        ['.html', () => referencia(t, origem)],
        ['.scss', () => folha(t, origem)],
        ['-mockup.html', () => mockup(t, origem)],
      ]) {
        const alvo = `${raiz}/${base}${suf}`;
        try {
          if (ler(alvo) !== gerar()) direcoesVelhas.push(alvo);
        } catch {
          direcoesVelhas.push(alvo);
        }
      }
    }
  }

  for (const d of paletasDivergentes)
    console.error(
      `✗ ${d}: a paleta de etapas desta direção não é a do produto — ` +
        'as etapas são dado gravado em banco, não escolha de direção'
    );

  for (const d of direcoesVelhas)
    console.error(
      `✗ ${d} está desatualizado — rode \`node scripts/design-tokens.mjs ` +
        `${d.endsWith('.scss') ? 'scss' : 'reference'} <tokens> ${d}\``
    );

  if (referenciaVelha)
    console.error(
      `✗ ${P.reference} está desatualizada — rode \`pnpm raevo:tokens:reference\``
    );
  if (mockupVelho)
    console.error(`✗ ${P.mockup} está desatualizado — rode \`pnpm raevo:tokens:mockup\``);

  if (
    falhas.length ||
    deriva.length ||
    referenciaVelha ||
    mockupVelho ||
    direcoesVelhas.length +
    paletasDivergentes.length
  ) {
    console.error(
      `\n${falhas.length} invariante(s) quebrada(s), ${deriva.length} desvio(s) do JSON` +
        `${referenciaVelha ? ', referência desatualizada' : ''}` +
        `${mockupVelho ? ', mockup desatualizado' : ''}` +
        `${direcoesVelhas.length ? `, ${direcoesVelhas.length} artefacto(s) de direção obsoleto(s)` : ''}.`
    );
    // Uma invariante quebrada é um erro no código — `extract` só a copiaria para
    // o JSON. Regravar o JSON só resolve o desvio, e mesmo aí exige ler o diff.
    if (falhas.length)
      console.error(
        'Invariante quebrada é erro no código: `extract` não resolve, só propaga.'
      );
    if (deriva.length && !falhas.length)
      console.error(
        'Se a mudança é intencional, rode `pnpm raevo:tokens:extract` e confira o diff.'
      );
    process.exit(1);
  }
  const cores =
    Object.keys(codigo.color.ramp.light).length + Object.keys(codigo.color.semantic.light).length;
  const conta = raiz => {
    const abs = resolve(RAIZ, raiz);
    return existsSync(abs) ? readdirSync(abs).filter(n => n.endsWith('.tokens.json')).length : 0;
  };
  const nDir = conta(P.directions);
  const nApr = conta(P.approved);
  console.log(
    `✓ ${cores} tokens de cor, ${codigo.stage.palette.length + 1} etapas, a escala de ` +
      `forma, a caixa, ${nApr} direção(ões) aprovada(s) e ${nDir} proposta(s) em acordo.`
  );
} else {
  console.error(
    'uso: node scripts/design-tokens.mjs extract | check | ' +
      'reference [tokens.json] [saida.html] | scss <tokens.json> <saida.scss>'
  );
  process.exit(1);
}
