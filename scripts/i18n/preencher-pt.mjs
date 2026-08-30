#!/usr/bin/env node
/**
 * Raevo — fecha o catálogo `pt` usando `pt_BR` como origem.
 *
 * Regra do produto: a interface nunca aparece em inglês. Só existem pt-BR e
 * pt-PT. Onde o catálogo português está vazio ou em inglês, herda do brasileiro
 * e passa pelo vocabulário de Portugal.
 *
 *   node scripts/i18n/preencher-pt.mjs           # aplica
 *   node scripts/i18n/preencher-pt.mjs --dry     # só relata
 */
import { readFileSync, writeFileSync, existsSync, readdirSync } from 'node:fs';
import { paraPortugalDePortugal } from './vocabulario-pt-pt.mjs';

const BASE = 'app/javascript/dashboard/i18n/locale';
const seco = process.argv.includes('--dry');

const ler = caminho => JSON.parse(readFileSync(caminho, 'utf8'));

let preenchidas = 0;
let restantes = 0;
const pendentes = [];

/** Percorre en/pt_BR/pt em paralelo, preenchendo o que falta em pt. */
const fundir = (en, br, pt, trilha, arquivo) => {
  const saida = Array.isArray(en) ? [] : {};

  Object.keys(en).forEach(chave => {
    const valorEn = en[chave];
    const valorBr = br?.[chave];
    const valorPt = pt?.[chave];
    const caminho = `${trilha}.${chave}`;

    if (valorEn && typeof valorEn === 'object') {
      saida[chave] = fundir(valorEn, valorBr, valorPt, caminho, arquivo);
      return;
    }

    const ptTraduzido =
      typeof valorPt === 'string' && valorPt !== valorEn && valorPt.trim();
    if (ptTraduzido) {
      saida[chave] = valorPt;
      return;
    }

    const brTraduzido =
      typeof valorBr === 'string' && valorBr !== valorEn && valorBr.trim();
    if (brTraduzido) {
      saida[chave] = paraPortugalDePortugal(valorBr);
      preenchidas += 1;
      return;
    }

    // Nem pt nem pt_BR têm tradução: fica o inglês e entra no relatório.
    saida[chave] = valorPt ?? valorEn;
    if (typeof valorEn === 'string' && valorEn.trim().length > 3) {
      restantes += 1;
      pendentes.push(`${arquivo}${caminho} = ${valorEn}`);
    }
  });

  // Preserva chaves que só existem em pt (ex.: termos próprios do Raevo).
  Object.keys(pt || {}).forEach(chave => {
    if (!(chave in saida)) saida[chave] = pt[chave];
  });

  return saida;
};

// kanban/forms/calendar/finance são reimportados de pt_BR pelo index.js do pt.
const REIMPORTADOS = new Set([
  'kanban.json',
  'forms.json',
  'calendar.json',
  'finance.json',
]);

readdirSync(`${BASE}/en`)
  .filter(nome => nome.endsWith('.json'))
  .filter(nome => !REIMPORTADOS.has(nome))
  .forEach(nome => {
    const en = ler(`${BASE}/en/${nome}`);
    const brCaminho = `${BASE}/pt_BR/${nome}`;
    const ptCaminho = `${BASE}/pt/${nome}`;
    const br = existsSync(brCaminho) ? ler(brCaminho) : {};
    const pt = existsSync(ptCaminho) ? ler(ptCaminho) : {};

    const resultado = fundir(en, br, pt, '', nome);
    if (!seco) {
      writeFileSync(ptCaminho, `${JSON.stringify(resultado, null, 2)}\n`);
    }
  });

console.log(`preenchidas de pt_BR : ${preenchidas}`);
console.log(`ainda em inglês      : ${restantes}`);
if (process.argv.includes('--listar')) {
  pendentes.forEach(linha => console.log(`  ${linha}`));
}
