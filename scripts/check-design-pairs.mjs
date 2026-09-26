#!/usr/bin/env node
/**
 * Raevo — porta de emparelhamento e de geometria.
 *
 * As portas que já existiam verificam o VALOR dos tokens: `raevo:design` recusa
 * cor literal, `raevo:tokens` recusa divergência entre o código e o sistema
 * gravado. Nenhuma das duas olha para o que o componente FAZ com os tokens, e
 * foi por aí que passaram os dois piores defeitos que este produto teve:
 *
 *  · O campo de formulário continuou pílula cinco meses depois de a regra 4 lhe
 *    dar 10px. A forma vivia numa constante de `raevoControl.js` — um `.js` que
 *    a porta nem lia, porque só varria `.vue`.
 *
 *  · O botão primário ficou a 1,26:1 em modo escuro. Os dois tokens estavam
 *    certos: `--brand-color` inverte para `#E5E5E5` por decisão, e `white` é
 *    branco. Errado era o PAR. Nada neste repositório olhava para pares.
 *
 * Esta porta olha. Mede contraste nos dois modos com os valores que o browser
 * realmente resolve, e recusa o par que reprova a WCAG 2.2.
 *
 * O que esta porta NÃO vê, declarado para ninguém a confundir com garantia:
 *  · Composição com alfa (`bg-n-brand/10` sobre um fundo desconhecido).
 *  · Cor que vem de estilo calculado em JS, ou de `style=` inline.
 *  · Pílula em `<button>`: a regra 4 também a reserva ao selo e à pesquisa, mas
 *    distinguir um selo clicável de um botão pede semântica que a classe não
 *    tem, e uma porta que erra aqui gera mais ruído do que sinal.
 *  · Contraste de borda e de anel de foco (WCAG 1.4.11 aplica-se-lhes também).
 *
 *   node scripts/check-design-pairs.mjs
 */
import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const P = {
  upstream: 'app/javascript/dashboard/assets/scss/_next-colors.scss',
  raevo: 'app/javascript/dashboard/assets/scss/_raevo-tokens.scss',
  componentes: 'app/javascript/dashboard/assets/scss/_raevo-components.scss',
  cores: 'theme/colors.js',
};

// As raízes de `check-design-tokens.mjs`, mais `components-next/raevo` e os
// `.js`: a pílula sobreviveu por estar num ficheiro que a outra porta não lê.
const RAIZES = [
  'app/javascript/dashboard/routes/dashboard/ai',
  'app/javascript/dashboard/routes/dashboard/kanban',
  'app/javascript/dashboard/routes/dashboard/calendar',
  'app/javascript/dashboard/routes/dashboard/finance',
  'app/javascript/dashboard/routes/dashboard/forms',
  'app/javascript/dashboard/routes/dashboard/home',
  'app/javascript/dashboard/routes/dashboard/marketing',
  'app/javascript/dashboard/components-next/raevo',
  'app/javascript/public_form',
  'app/javascript/public_booking',
];

const arquivos = RAIZES.flatMap(raiz => {
  try {
    return execSync(`find ${raiz} -name '*.vue' -o -name '*.js'`, {
      encoding: 'utf8',
    })
      .split('\n')
      .filter(Boolean);
  } catch {
    return [];
  }
}).filter(f => !f.includes('/specs/'));

// --- a cascata, como o browser a resolve -------------------------------------

/**
 * Lê as custom properties de um seletor, tolerando indentação: em
 * `_next-colors.scss` o `:root` e o `.dark` vivem dentro de um `@layer`, e um
 * parser ancorado na coluna 0 não os vê. Foi o que me deu 30 falsos positivos
 * na primeira versão desta porta: sem o ramo escuro do upstream, cada
 * `bg-n-ruby-2` parecia ficar branco no escuro.
 */
const lerBloco = (scss, seletor) => {
  const linhas = scss.split('\n');
  const abre = new RegExp(`^\\s*${seletor}\\s*\\{`);
  const out = {};
  let dentro = false;
  let base = 0;
  for (const linha of linhas) {
    if (!dentro) {
      if (abre.test(linha)) {
        dentro = true;
        base = linha.search(/\S/);
      }
      continue;
    }
    if (/^\s*\}/.test(linha) && linha.search(/\S/) <= base) {
      dentro = false;
      continue;
    }
    const m = linha.replace(/\/\/.*$/, '').match(/--([a-z0-9-]+)\s*:\s*([^;]+)/i);
    if (m) out[m[1]] = m[2].trim();
  }
  return out;
};

/** `37 99 235` vira `#2563EB`; qualquer outra forma não é cor medível. */
const paraHex = valor => {
  const n = valor.trim().split(/\s+/);
  if (n.length !== 3 || !n.every(p => /^\d{1,3}$/.test(p))) return null;
  const v = n.map(Number);
  if (v.some(x => x > 255)) return null;
  return `#${v.map(x => x.toString(16).padStart(2, '0')).join('').toUpperCase()}`;
};

/**
 * `_raevo-tokens.scss` é importado DEPOIS de `_next-colors.scss` e vence na
 * cascata (ver `_woot.scss`). E o que `.dark` não redefine herda `:root` — o
 * cálculo tem de herdar também, senão inventa contraste que o browser não tem.
 */
const VARS = (() => {
  const up = readFileSync(P.upstream, 'utf8');
  const rv = readFileSync(P.raevo, 'utf8');
  const claro = { ...lerBloco(up, ':root'), ...lerBloco(rv, ':root') };
  const escuro = { ...claro, ...lerBloco(up, '\\.dark'), ...lerBloco(rv, '\\.dark') };
  const hexes = props =>
    Object.fromEntries(
      Object.entries(props)
        .map(([k, v]) => [k, paraHex(v)])
        .filter(([, h]) => h)
    );
  return { light: hexes(claro), dark: hexes(escuro) };
})();

/**
 * `theme/colors.js` é upstream e a regra 2 manda não o editar — mas lê-se, e é
 * a única definição de qual custom property cada classe `n-*` consome.
 */
const CLASSES = (() => {
  const js = readFileSync(P.cores, 'utf8');
  const inicio = js.indexOf('\n  n: {');
  if (inicio < 0) throw new Error(`${P.cores}: namespace n não encontrado`);
  const abre = js.indexOf('{', inicio);
  let nivel = 0;
  let fim = abre;
  for (let i = abre; i < js.length; i += 1) {
    if (js[i] === '{') nivel += 1;
    else if (js[i] === '}') {
      nivel -= 1;
      if (!nivel) {
        fim = i;
        break;
      }
    }
  }
  const bloco = js.slice(abre + 1, fim);
  const out = {};
  const folha = /'?([A-Za-z0-9_-]+)'?\s*:\s*'rgb\(var\(--([a-z0-9-]+)\)/g;
  for (const fam of bloco.matchAll(/'?([A-Za-z0-9_-]+)'?\s*:\s*\{([^}]*)\}/g)) {
    folha.lastIndex = 0;
    let m;
    while ((m = folha.exec(fam[2]))) out[`${fam[1]}-${m[1]}`] = m[2];
  }
  const raso = bloco.replace(/'?[A-Za-z0-9_-]+'?\s*:\s*\{[^}]*\}/g, '');
  folha.lastIndex = 0;
  let m;
  while ((m = folha.exec(raso))) out[m[1]] = m[2];
  return out;
})();

const resolver = (modo, classe) => {
  if (classe === 'white') return '#FFFFFF';
  if (classe === 'black') return '#000000';
  const m = /^n-(.+)$/.exec(classe);
  if (!m) return null; // fora do namespace do sistema: não é nossa para medir
  const prop = CLASSES[m[1]];
  return prop ? VARS[modo][prop] ?? null : null;
};

// --- WCAG 2.2 ----------------------------------------------------------------

const linear = c => {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
};
const luminancia = hex => {
  const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
};
const contraste = (a, b) => {
  const [x, y] = [luminancia(a), luminancia(b)];
  const [alto, baixo] = x > y ? [x, y] : [y, x];
  return (alto + 0.05) / (baixo + 0.05);
};

/**
 * Pares que `_raevo-components.scss` já corrige por regra de CSS.
 *
 * Lidos do ficheiro em vez de escritos aqui: a lista e a correção são a mesma
 * decisão, e duas cópias divergem. Se alguém apagar a regra, a porta volta a
 * acusar o par — que é exatamente o que se quer.
 */
const CORRIGIDOS = (() => {
  const scss = readFileSync(P.componentes, 'utf8');
  const out = new Set();
  for (const m of scss.matchAll(
    /\.dark\s+\.bg-([a-z0-9-]+)\.text-([a-z0-9-]+)\s*\{[^}]*color\s*:/g
  )) {
    out.add(`dark|${m[1]}|${m[2]}`);
  }
  return out;
})();

// --- que classes coexistem de facto ------------------------------------------

/**
 * Percorre as tags, e de cada uma devolve os conjuntos de classes que podem
 * estar aplicados AO MESMO TEMPO.
 *
 * `:class="a ? 'bg-n-brand text-white' : 'bg-n-surface-2'` tem dois ramos
 * mutuamente exclusivos. Tratar o atributo como um conjunto único emparelha
 * `bg-n-surface-2` com `text-white` e acusa 1,04:1 num sítio onde nunca
 * coexistem — foi o segundo lote de falsos positivos desta porta. Cada literal
 * do `:class` é um conjunto, e cada um herda o `class` estático da mesma tag.
 */
/**
 * Um controlo só-de-ícone não tem texto, e a WCAG trata-o pelo 1.4.11
 * (objeto gráfico, 3:1) e não pelo 1.4.3 (texto, 4:1). Sem esta distinção a
 * porta acusava cada botão de ícone com fundo de rampa 9 — e uma porta que
 * grita a mais é uma porta que alguém desliga.
 */
const soDeIcone = (fonte, tag, fimDaAbertura) => {
  if (!['button', 'a', 'label'].includes(tag.toLowerCase())) return false;
  const fecha = fonte.indexOf(`</${tag}`, fimDaAbertura);
  if (fecha < 0) return false;
  const dentro = fonte
    .slice(fimDaAbertura + 1, fecha)
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<i\b[^>]*\/?>/g, '')
    .replace(/<svg\b[\s\S]*?<\/svg>/g, '')
    .replace(/<span\b[^>]*class="[^"]*sr-only[^"]*"[^>]*>[\s\S]*?<\/span>/g, '');
  return !dentro.trim();
};

function* conjuntos(fonte) {
  for (const m of fonte.matchAll(/<[a-zA-Z][\w.-]*/g)) {
    let i = m.index + m[0].length;
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
    const linha = fonte.slice(0, m.index).split('\n').length;
    const estatico = [...tag.matchAll(/(?<![:@\w-])class="([^"]*)"/g)]
      .map(x => x[1])
      .join(' ');
    const dinamico = [...tag.matchAll(/(?::class|v-bind:class)="([^"]*)"/g)]
      .map(x => x[1])
      .join(' ');
    const ramos = [...dinamico.matchAll(/'([^']*)'/g)].map(x => x[1]);
    const grafico = soDeIcone(fonte, m[0].slice(1), i);
    if (!ramos.length) yield { texto: estatico, linha, grafico };
    else for (const ramo of ramos) yield { texto: `${estatico} ${ramo}`, linha, grafico };
  }
  // `.js`: gabaritos do primitivo, onde cada literal é um conjunto só
  for (const m of fonte.matchAll(/`([^`]*)`/g)) {
    yield {
      texto: m[1],
      linha: fonte.slice(0, m.index).split('\n').length,
      grafico: false,
    };
  }
}

// --- as verificações ---------------------------------------------------------

const SEM_ALFA = '(?![/\\w])'; // `bg-n-brand/10` é composição: não se mede assim

/**
 * Dentro de um conjunto, duas utilitárias da mesma propriedade não somam: a
 * última na folha compilada vence. Emparelhar todas com todas inventa
 * combinações que nunca acontecem — foi o terceiro lote de falsos positivos,
 * quando um `class` estático com `bg-n-solid-1 text-n-slate-12` e um `:class`
 * com `bg-n-brand text-white` davam quatro pares, dos quais só um é real.
 * Guardamos a última de cada propriedade, por prefixo de estado.
 */
const ultimoPorEstado = (texto, propriedade) => {
  const re = new RegExp(
    `(?:^|[\\s'"\`])((?:[a-z-]+:)*)${propriedade}-((?:n-)?[a-z0-9-]+)${SEM_ALFA}`,
    'g'
  );
  const porEstado = new Map();
  for (const m of texto.matchAll(re)) porEstado.set(m[1], m);
  return [...porEstado.values()];
};

function contrasteInsuficiente(fonte) {
  const achados = [];
  const visto = new Set();
  for (const { texto, linha, grafico } of conjuntos(fonte)) {
    if (!texto.includes('bg-')) continue;
    const fundos = ultimoPorEstado(texto, 'bg');
    const frentes = ultimoPorEstado(texto, 'text');
    // WCAG 2.2: 3:1 basta para objeto gráfico (1.4.11) e para texto grande —
    // a partir de 24px, aqui `text-xl` e acima. O resto é 4,5:1 (1.4.3).
    const piso = grafico || /\btext-(xl|2xl|3xl)\b/.test(texto) ? 3 : 4.5;
    for (const fundo of fundos) {
      for (const frente of frentes) {
        // Prefixos diferentes (`hover:bg` com `text` sem estado) não são o mesmo
        // momento: medi-los produziria alarme falso. A exceção é `placeholder:`,
        // que se desenha SOBRE o fundo do próprio controlo, sem estado nenhum —
        // e era por aqui que passava um `placeholder:text-n-slate-9` a 2,58:1 no
        // primitivo que trinta ficheiros herdam.
        const mesmoMomento =
          fundo[1] === frente[1] || (!fundo[1] && frente[1] === 'placeholder:');
        if (!mesmoMomento) continue;
        for (const modo of ['light', 'dark']) {
          if (CORRIGIDOS.has(`${modo}|${fundo[2]}|${frente[2]}`)) continue;
          const bg = resolver(modo, fundo[2]);
          const fg = resolver(modo, frente[2]);
          if (!bg || !fg) continue;
          const razao = contraste(bg, fg);
          if (razao >= piso) continue;
          const chave = `${linha}|${modo}|${fundo[2]}|${frente[2]}`;
          if (visto.has(chave)) continue;
          visto.add(chave);
          achados.push({
            linha,
            modo,
            par: `bg-${fundo[2]} (${bg}) + text-${frente[2]} (${fg})`,
            razao,
            piso,
          });
        }
      }
    }
  }
  return achados;
}

/**
 * Pílula onde a regra 4 pede 10px.
 *
 * `rounded-full` é do selo e da barra de pesquisa, e de mais nada: a densidade
 * alta tira largura ao controlo, e dois controlos-pílula lado a lado ficam
 * ambíguos. Inclui as constantes de `raevoControl.js`, que é onde a pílula se
 * escondeu de 21/09 em diante — trinta ficheiros herdavam dela.
 */
function pilulaEmControlo(fonte, arquivo) {
  const achados = [];
  for (const m of fonte.matchAll(/<(input|select|textarea)\b/g)) {
    const fim = fonte.indexOf('>', m.index);
    const tag = fonte.slice(m.index, fim < 0 ? fonte.length : fim);
    // A barra de pesquisa é a exceção que a regra 4 nomeia, ao lado do selo.
    if (/type="search"/.test(tag)) continue;
    if (/rounded-full/.test(tag)) {
      achados.push({ linha: fonte.slice(0, m.index).split('\n').length, alvo: `<${m[1]}>` });
    }
  }
  if (arquivo.endsWith('raevoControl.js')) {
    for (const m of fonte.matchAll(
      /RAEVO_[A-Z_]*(?:CONTROL|SELECT|TEXTAREA|SWATCH)[A-Z_]*_CLASS\s*=\s*`([^`]*)`/g
    )) {
      if (/rounded-full/.test(m[1])) {
        achados.push({
          linha: fonte.slice(0, m.index).split('\n').length,
          alvo: 'constante do primitivo',
        });
      }
    }
  }
  return achados;
}

/** Raio arbitrário: a escala tem sete degraus nomeados e nenhum é `[Npx]`. */
function raioArbitrario(fonte) {
  return [...fonte.matchAll(/\brounded(?:-[a-z]+)?-\[[^\]]+\]/g)].map(m => ({
    linha: fonte.slice(0, m.index).split('\n').length,
    classe: m[0],
  }));
}

// --- relatório ---------------------------------------------------------------

let achados = 0;
for (const arq of arquivos) {
  const fonte = readFileSync(arq, 'utf8');

  for (const a of contrasteInsuficiente(fonte)) {
    achados += 1;
    const modo = a.modo === 'dark' ? 'escuro' : 'claro';
    console.log(
      `${arq}:${a.linha}  contraste ${a.razao.toFixed(2)}:1 no modo ${modo} (piso ${a.piso})`
    );
    console.log(`    ${a.par}`);
  }
  for (const a of pilulaEmControlo(fonte, arq)) {
    achados += 1;
    console.log(`${arq}:${a.linha}  pílula em ${a.alvo} → a regra 4 pede rounded-lg`);
  }
  for (const a of raioArbitrario(fonte)) {
    achados += 1;
    console.log(`${arq}:${a.linha}  raio fora da escala → ${a.classe}`);
  }
}

console.log('');
if (achados) {
  console.log(`✗ ${achados} par(es) ou geometria fora do sistema em ${arquivos.length} ficheiros.`);
  console.log('  Contraste: use o par que inverte — n-solid-1 ou --brand-foreground.');
  console.log('  Ver AGENTS.md regras 4 e 5, e docs/raevo-design-system.md.');
  process.exit(1);
}
console.log(
  `✓ ${arquivos.length} ficheiros: nenhum par abaixo da WCAG 2.2 nos dois modos, nenhuma pílula em controlo, nenhum raio arbitrário.`
);
