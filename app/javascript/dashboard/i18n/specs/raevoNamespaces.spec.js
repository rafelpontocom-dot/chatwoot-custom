import fs from 'node:fs';
import path from 'node:path';
import en from '../locale/en';
import pt from '../locale/pt';
import ptBR from '../locale/pt_BR';

// Os ficheiros de tradução que o Raevo acrescentou (kanban, calendar, finance…)
// só chegam à interface porque o `index.js` nativo de cada idioma os importa.
// Um upgrade que reescreva esse `index.js` tira-os sem conflito, e a interface
// passa a mostrar as chaves em vez dos textos. Isto falha antes. `toMatchObject`
// porque `FORMS` junta de propósito o bloco do Chatwoot com o do Raevo.
const BASE = path.resolve(__dirname, '..', 'locale');
const RAEVO_FILES = [
  'calendar.json',
  'finance.json',
  'forms.json',
  'kanban.json',
  'marketing.json',
  'raevoAi.json',
  'raevoConversation.json',
];
const CATALOGS = { en, pt, pt_BR: ptBR };

describe('Raevo translation namespaces', () => {
  Object.entries(CATALOGS).forEach(([locale, catalog]) => {
    RAEVO_FILES.forEach(file => {
      it(`registers ${locale}/${file}`, () => {
        const own = JSON.parse(
          fs.readFileSync(path.join(BASE, locale, file), 'utf8')
        );

        Object.keys(own).forEach(namespace => {
          expect(catalog[namespace]).toMatchObject(own[namespace]);
        });
      });
    });
  });
});
