#!/usr/bin/env node
/**
 * Raevo — aplica as traduções pendentes ao catálogo pt_BR.
 *
 * O mapa é indexado pela frase em inglês, não pela chave: a mesma frase
 * ("Continue", "Back") aparece em vários lugares e deve ser traduzida uma vez.
 * Só substitui onde o valor atual ainda é o inglês — nunca sobrescreve tradução
 * existente.
 */
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';

const BASE = 'app/javascript/dashboard/i18n/locale';
const mapa = JSON.parse(
  readFileSync('scripts/i18n/traducoes-pendentes.json', 'utf8')
);

let aplicadas = 0;

const percorrer = (en, alvo) => {
  const saida = Array.isArray(en) ? [] : {};

  Object.keys(en).forEach(chave => {
    const valorEn = en[chave];
    const atual = alvo?.[chave];

    if (valorEn && typeof valorEn === 'object') {
      saida[chave] = percorrer(valorEn, atual);
      return;
    }

    const aindaEmIngles = atual === undefined || atual === valorEn;
    if (aindaEmIngles && mapa[valorEn] !== undefined) {
      saida[chave] = mapa[valorEn];
      aplicadas += 1;
      return;
    }
    saida[chave] = atual ?? valorEn;
  });

  Object.keys(alvo || {}).forEach(chave => {
    if (!(chave in saida)) saida[chave] = alvo[chave];
  });

  return saida;
};

readdirSync(`${BASE}/en`)
  .filter(nome => nome.endsWith('.json'))
  .forEach(nome => {
    const en = JSON.parse(readFileSync(`${BASE}/en/${nome}`, 'utf8'));
    const destino = `${BASE}/pt_BR/${nome}`;
    const alvo = existsSync(destino)
      ? JSON.parse(readFileSync(destino, 'utf8'))
      : {};
    const resultado = percorrer(en, alvo);
    writeFileSync(destino, `${JSON.stringify(resultado, null, 2)}\n`);
  });

console.log(`traduções aplicadas em pt_BR: ${aplicadas}`);
