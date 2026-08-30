#!/usr/bin/env node
/**
 * Raevo — auditoria dos primitivos de design.
 *
 * Não mede jornada de uso: mede **conformidade**. Percorre as telas do produto e
 * conta quantos valores distintos existem para a mesma decisão de design — quantas
 * alturas de campo, quantos raios, quantos degraus de tipografia, quantas cores
 * fora de token. Cada divergência é medida contra a regra escrita em
 * `docs/raevo-design-system.md` e no `AGENTS.md`, nunca contra gosto.
 *
 * Serve para rodar antes e depois de uma mudança: o critério de sucesso é o
 * número de valores distintos cair.
 *
 *   node scripts/raevo-design-audit.mjs <ws-url> [--json saida.json]
 *
 * O <ws-url> vem de `curl -s localhost:9222/json` num Chrome com porta de debug.
 */
import { createConnection } from 'node:net';
import { randomBytes } from 'node:crypto';
import { writeFileSync } from 'node:fs';

const wsUrl = process.argv[2];
const saidaJson = process.argv.includes('--json')
  ? process.argv[process.argv.indexOf('--json') + 1]
  : null;
const BASE = process.env.RAEVO_AUDIT_BASE || 'http://localhost:3000/app/accounts/1';

if (!wsUrl) {
  console.error('uso: node scripts/raevo-design-audit.mjs <ws-url> [--json arquivo]');
  process.exit(1);
}

const TELAS = [
  { nome: 'Home', url: `${BASE}/home` },
  { nome: 'Pipeline', url: `${BASE}/kanban/1` },
  { nome: 'Agenda', url: `${BASE}/calendar` },
  { nome: 'Financeiro', url: `${BASE}/finance` },
  { nome: 'Formulários', url: `${BASE}/forms` },
  { nome: 'Contatos', url: `${BASE}/contacts` },
  { nome: 'Conversas', url: `${BASE}/dashboard` },
];

// --- ligação CDP, sem dependências -------------------------------------------
const u = new URL(wsUrl);
const sock = createConnection({ host: u.hostname, port: u.port }, () => {
  sock.write(
    `GET ${u.pathname}${u.search} HTTP/1.1\r\nHost: ${u.host}\r\n` +
      `Upgrade: websocket\r\nConnection: Upgrade\r\n` +
      `Sec-WebSocket-Key: ${randomBytes(16).toString('base64')}\r\n` +
      `Sec-WebSocket-Version: 13\r\n\r\n`
  );
});

const frame = payload => {
  const b = Buffer.from(payload);
  const mask = randomBytes(4);
  const n = b.length;
  let head;
  if (n < 126) head = Buffer.from([0x81, 0x80 | n]);
  else if (n < 65536) {
    head = Buffer.alloc(4);
    head[0] = 0x81;
    head[1] = 0xfe;
    head.writeUInt16BE(n, 2);
  } else {
    head = Buffer.alloc(10);
    head[0] = 0x81;
    head[1] = 0xff;
    head.writeBigUInt64BE(BigInt(n), 2);
  }
  const masked = Buffer.alloc(n);
  for (let i = 0; i < n; i += 1) masked[i] = b[i] ^ mask[i % 4];
  return Buffer.concat([head, mask, masked]);
};

let seq = 0;
const pendentes = new Map();
const enviar = (method, params = {}) =>
  new Promise(resolve => {
    seq += 1;
    pendentes.set(seq, resolve);
    sock.write(frame(JSON.stringify({ id: seq, method, params })));
  });

let apertoDeMao = false;
let buffer = Buffer.alloc(0);
sock.on('data', chunk => {
  buffer = Buffer.concat([buffer, chunk]);
  if (!apertoDeMao) {
    const corte = buffer.indexOf('\r\n\r\n');
    if (corte === -1) return;
    apertoDeMao = true;
    buffer = buffer.subarray(corte + 4);
    rodar();
  }
  while (buffer.length >= 2) {
    const len0 = buffer[1] & 0x7f;
    let offset = 2;
    let len = len0;
    if (len0 === 126) {
      len = buffer.readUInt16BE(2);
      offset = 4;
    } else if (len0 === 127) {
      len = Number(buffer.readBigUInt64BE(2));
      offset = 10;
    }
    if (buffer.length < offset + len) return;
    const texto = buffer.subarray(offset, offset + len).toString();
    buffer = buffer.subarray(offset + len);
    try {
      const msg = JSON.parse(texto);
      if (msg.id && pendentes.has(msg.id)) {
        pendentes.get(msg.id)(msg);
        pendentes.delete(msg.id);
      }
    } catch {
      /* frame de evento, ignorado */
    }
  }
});

const dormir = ms => new Promise(r => setTimeout(r, ms));

const avaliar = async expressao => {
  const r = await enviar('Runtime.evaluate', {
    expression: expressao,
    returnByValue: true,
    awaitPromise: true,
  });
  return r?.result?.result?.value;
};

// --- o instrumento, injetado na página ---------------------------------------
// Roda no browser: inventaria cada primitivo do que está visível.
const INSTRUMENTO = `(() => {
  const vis = el => {
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    const s = getComputedStyle(el);
    return s.visibility !== 'hidden' && s.display !== 'none' && Number(s.opacity) > 0.05;
  };
  const px = v => Math.round(parseFloat(v) || 0);
  const add = (mapa, chave) => { mapa[chave] = (mapa[chave] || 0) + 1; };

  const campos = {}, botoes = {}, tipos = {}, raios = {}, cores = {},
        bordas = {}, sombras = {}, paddingsBotao = {}, alvosPequenos = [],
        rotulos = {};

  document.querySelectorAll('input, select, textarea').forEach(el => {
    if (!vis(el)) return;
    if (el.type === 'hidden' || el.type === 'checkbox' || el.type === 'radio') return;
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    add(campos, Math.round(r.height));
    add(raios, 'campo:' + s.borderRadius.split(' ')[0]);
    // posição do rótulo: acima (mesmo x) ou ao lado
    const id = el.getAttribute('id');
    const lab = id ? document.querySelector('label[for="' + CSS.escape(id) + '"]') : null;
    if (lab && vis(lab)) {
      const lr = lab.getBoundingClientRect();
      const acima = lr.bottom <= r.top + 2;
      add(rotulos, acima ? 'acima' : 'ao-lado');
      if (acima) add(rotulos, 'respiro:' + Math.round(r.top - lr.bottom));
      else add(rotulos, 'vao:' + Math.round(r.left - lr.right));
    } else {
      add(rotulos, 'sem-rotulo');
    }
  });

  document.querySelectorAll('button, [role="button"], a[role="button"]').forEach(el => {
    if (!vis(el)) return;
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    add(botoes, Math.round(r.height));
    add(paddingsBotao, px(s.paddingLeft) + '/' + px(s.paddingRight));
    add(raios, 'botao:' + s.borderRadius.split(' ')[0]);
    if (r.height < 24 || r.width < 24) {
      alvosPequenos.push(Math.round(r.width) + 'x' + Math.round(r.height));
    }
  });

  document.querySelectorAll('*').forEach(el => {
    if (!vis(el)) return;
    const s = getComputedStyle(el);
    const temTexto = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
    if (temTexto) {
      add(tipos, px(s.fontSize) + '/' + s.fontWeight);
      if (s.color) add(cores, 'texto:' + s.color);
    }
    if (s.borderTopWidth !== '0px' && s.borderTopStyle !== 'none') {
      add(bordas, s.borderTopColor);
    }
    if (s.boxShadow && s.boxShadow !== 'none') {
      const r = el.getBoundingClientRect();
      add(sombras, r.width > 240 && r.height > 120 ? 'painel' : 'pequeno');
    }
    if (s.backgroundColor && s.backgroundColor !== 'rgba(0, 0, 0, 0)') {
      add(cores, 'fundo:' + s.backgroundColor);
    }
  });

  // Estrutura: quantas molduras aninhadas até o conteúdo
  let profundidade = 0;
  document.querySelectorAll('div, section, aside, article').forEach(el => {
    if (!vis(el)) return;
    const s = getComputedStyle(el);
    const moldura = s.borderTopWidth !== '0px' && parseFloat(s.borderRadius) > 0;
    if (!moldura) return;
    let d = 0, p = el.parentElement;
    while (p && p !== document.body) {
      const ps = getComputedStyle(p);
      if (ps.borderTopWidth !== '0px' && parseFloat(ps.borderRadius) > 0) d += 1;
      p = p.parentElement;
    }
    if (d > profundidade) profundidade = d;
  });

  return {
    campos, botoes, tipos, raios, cores, bordas, sombras,
    paddingsBotao, rotulos,
    alvosPequenos: alvosPequenos.slice(0, 20),
    molduraMaisFunda: profundidade,
  };
})()`;

// --- consolidação -------------------------------------------------------------
const somar = (destino, origem) => {
  Object.entries(origem || {}).forEach(([k, v]) => {
    destino[k] = (destino[k] || 0) + v;
  });
};

const ordenar = mapa =>
  Object.entries(mapa)
    .sort((a, b) => b[1] - a[1])
    .map(([valor, n]) => `${valor} (${n})`);

async function rodar() {
  await enviar('Page.enable');
  await enviar('Runtime.enable');
  await enviar('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 900,
    deviceScaleFactor: 1,
    mobile: false,
  });

  const total = {
    campos: {},
    botoes: {},
    tipos: {},
    raios: {},
    cores: {},
    bordas: {},
    sombras: {},
    paddingsBotao: {},
    rotulos: {},
  };
  const porTela = [];

  for (const tela of TELAS) {
    await enviar('Page.navigate', { url: tela.url });
    await dormir(6500);
    const medida = await avaliar(INSTRUMENTO);
    if (!medida) {
      porTela.push({ tela: tela.nome, erro: 'não mediu' });
      continue;
    }
    Object.keys(total).forEach(chave => somar(total[chave], medida[chave]));
    porTela.push({
      tela: tela.nome,
      campos: Object.keys(medida.campos).length,
      botoes: Object.keys(medida.botoes).length,
      tipos: Object.keys(medida.tipos).length,
      molduraMaisFunda: medida.molduraMaisFunda,
      alvosPequenos: medida.alvosPequenos.length,
    });
    process.stderr.write(`  medido: ${tela.nome}\n`);
  }

  const relatorio = {
    quando: new Date().toISOString(),
    viewport: '1440x900',
    porTela,
    distintos: {
      alturaDeCampo: Object.keys(total.campos).length,
      alturaDeBotao: Object.keys(total.botoes).length,
      degrausDeTipografia: Object.keys(total.tipos).length,
      raios: Object.keys(total.raios).length,
      paddingsDeBotao: Object.keys(total.paddingsBotao).length,
      coresDeBorda: Object.keys(total.bordas).length,
    },
    detalhe: {
      alturaDeCampo: ordenar(total.campos),
      alturaDeBotao: ordenar(total.botoes),
      raios: ordenar(total.raios),
      paddingsDeBotao: ordenar(total.paddingsBotao),
      posicaoDoRotulo: ordenar(total.rotulos),
      sombraEmRepouso: ordenar(total.sombras),
      degrausDeTipografia: ordenar(total.tipos).slice(0, 24),
    },
  };

  console.log(JSON.stringify(relatorio, null, 1));
  if (saidaJson) {
    writeFileSync(saidaJson, `${JSON.stringify(relatorio, null, 1)}\n`);
    process.stderr.write(`\nrelatório em ${saidaJson}\n`);
  }
  sock.end();
  process.exit(0);
}
