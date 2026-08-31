import fs from 'node:fs';
import path from 'node:path';

/**
 * Oito chaves do editor eram referenciadas no markup e não existiam em
 * catálogo nenhum: os controlos mostravam `FORMS.EDITOR.ABANDONMENT_HINT` ao
 * utilizador, em produção, e nada reclamava. Só apareceram quando a secção
 * ganhou página própria e alguém olhou para ela.
 *
 * Este teste é o que faz a falta aparecer no momento em que é escrita.
 */
const MODULO = path.resolve(__dirname, '..');
const CATALOGO = path.resolve(
  __dirname,
  '..',
  '..',
  '..',
  '..',
  'i18n',
  'locale',
  'pt_BR',
  'forms.json'
);

const traducoes = JSON.parse(fs.readFileSync(CATALOGO, 'utf8'));

const existe = caminho =>
  caminho
    .split('.')
    .reduce((valor, parte) => (valor == null ? undefined : valor[parte]), {
      FORMS: traducoes.FORMS,
    }) !== undefined;

const ficheiros = fs
  .readdirSync(MODULO)
  .filter(nome => nome.endsWith('.vue') || nome.endsWith('.js'));

/** Só chaves literais: as dinâmicas são montadas em execução e não se leem daqui. */
const chavesDe = conteudo => [
  ...new Set(
    [...conteudo.matchAll(/t\(\s*'(FORMS\.[A-Z0-9_.]+)'/g)].map(m => m[1])
  ),
];

describe('chaves de tradução do módulo de formulários', () => {
  it.each(ficheiros)('%s only uses keys that exist', nome => {
    const conteudo = fs.readFileSync(path.join(MODULO, nome), 'utf8');

    const emFalta = chavesDe(conteudo).filter(chave => !existe(chave));

    expect(emFalta).toEqual([]);
  });
});
