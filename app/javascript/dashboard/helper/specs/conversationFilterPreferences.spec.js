import {
  LAST_USED_TAB,
  resolveAssigneeTab,
} from '../conversationFilterPreferences';

describe('resolveAssigneeTab', () => {
  // O pedido do Pedro: a lista não deve abrir sempre em «Minhas».
  it('opens on the tab the agent chose, whatever was used last', () => {
    expect(resolveAssigneeTab({ preferred: 'all', lastUsed: 'me' })).toBe(
      'all'
    );
  });

  it('opens on the last one used when nothing was chosen', () => {
    expect(resolveAssigneeTab({ lastUsed: 'unassigned' })).toBe('unassigned');
  });

  // «O último que usei» é um valor da mesma preferência, não uma segunda
  // preferência: guarda-se como ausência de escolha fixa.
  it('treats the last-used choice as no fixed preference', () => {
    expect(
      resolveAssigneeTab({ preferred: LAST_USED_TAB, lastUsed: 'all' })
    ).toBe('all');
  });

  it('keeps the old behaviour for someone who never touched it', () => {
    expect(resolveAssigneeTab()).toBe('me');
    expect(resolveAssigneeTab({})).toBe('me');
  });

  // Uma preferência gravada por uma versão antiga, ou à mão, não deve pôr a
  // lista num estado que o produto não conhece.
  it('ignores a tab name the product does not have', () => {
    expect(resolveAssigneeTab({ preferred: 'inventada' })).toBe('me');
    expect(
      resolveAssigneeTab({ preferred: 'inventada', lastUsed: 'all' })
    ).toBe('all');
    expect(resolveAssigneeTab({ lastUsed: 'tambem-inventada' })).toBe('me');
  });
});
