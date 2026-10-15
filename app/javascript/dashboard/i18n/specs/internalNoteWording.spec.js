import enAutomation from '../locale/en/automation.json';
import enMacros from '../locale/en/macros.json';
import enSearch from '../locale/en/search.json';
import ptBRSearch from '../locale/pt_BR/search.json';

// Commit 5260b908d: a nota da equipa chama-se «mensagem interna» em todo o
// produto, não «nota privada» — a cliente lia «privada» como privada para o
// paciente. Estes ficheiros são do upstream: um upgrade que os reescreva volta
// a pôr «Private Note» sem conflito, e isto falha.
describe('internal note wording', () => {
  it('names the internal note in the automation and macro actions', () => {
    expect(enAutomation.AUTOMATION.ACTIONS.ADD_PRIVATE_NOTE).toBe(
      'Add an internal note'
    );
    expect(enAutomation.AUTOMATION.ATTRIBUTES.PRIVATE_NOTE).toBe(
      'Internal note'
    );
    expect(enMacros.MACROS.ACTIONS.ADD_PRIVATE_NOTE).toBe(
      'Add an internal note'
    );
  });

  it('names the internal note in search', () => {
    expect(enSearch.SEARCH.PRIVATE).toBe('Internal note');
    expect(ptBRSearch.SEARCH.PRIVATE).toBe('Mensagem interna');
  });
});
