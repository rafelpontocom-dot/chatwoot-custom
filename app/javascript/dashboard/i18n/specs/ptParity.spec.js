import fs from 'node:fs';
import path from 'node:path';

/**
 * A regra do produto é que a interface nunca aparece em inglês: só pt-BR e
 * pt-PT, à escolha. Os módulos Raevo viviam só em pt_BR e o catálogo `pt`
 * importava-os de lá, servindo português do Brasil a uma clínica portuguesa.
 *
 * Agora existem os dois, e este teste é o que impede que voltem a separar-se:
 * uma chave nova em pt_BR sem par em pt falha aqui, dizendo qual.
 */
const BASE = path.resolve(__dirname, '..', 'locale');
const MODULOS = ['calendar', 'finance', 'forms', 'kanban'];

const ler = (locale, nome) =>
  JSON.parse(fs.readFileSync(path.join(BASE, locale, `${nome}.json`), 'utf8'));

const caminhos = (objeto, trilha = '') =>
  Object.entries(objeto).flatMap(([chave, valor]) => {
    const atual = trilha ? `${trilha}.${chave}` : chave;
    return valor && typeof valor === 'object'
      ? caminhos(valor, atual)
      : [atual];
  });

describe('catálogo pt-PT', () => {
  it.each(MODULOS)('%s has a pt-PT file of its own', nome => {
    expect(fs.existsSync(path.join(BASE, 'pt', `${nome}.json`))).toBe(true);
  });

  it.each(MODULOS)('%s has every pt_BR key in pt-PT', nome => {
    const doPt = caminhos(ler('pt', nome));
    const emFalta = caminhos(ler('pt_BR', nome)).filter(
      chave => !doPt.includes(chave)
    );

    expect(emFalta).toEqual([]);
  });

  it('does not leave the Raevo modules importing Brazilian text', () => {
    const indice = fs.readFileSync(path.join(BASE, 'pt', 'index.js'), 'utf8');

    MODULOS.forEach(nome => {
      expect(indice).not.toContain(`../pt_BR/${nome}.json`);
    });
  });
});
