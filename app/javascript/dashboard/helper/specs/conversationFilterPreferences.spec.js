import {
  LAST_USED_TAB,
  defaultFolderOnEntry,
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

describe('defaultFolderOnEntry', () => {
  it('opens the panel on the filter the agent elected', () => {
    expect(defaultFolderOnEntry({ folderId: 7 })).toBe(7);
    expect(defaultFolderOnEntry({ folderId: '7' })).toBe(7);
  });

  // Clicar em «Todas as conversas» tem de levar a todas as conversas. O filtro
  // padrão é por onde se começa, não para onde se é arrastado de volta.
  it('does not hijack navigation once the agent is already inside', () => {
    expect(defaultFolderOnEntry({ fromName: 'home', folderId: 7 })).toBeNull();
  });

  it('does nothing when no filter was elected', () => {
    expect(defaultFolderOnEntry()).toBeNull();
    expect(defaultFolderOnEntry({ folderId: null })).toBeNull();
    expect(defaultFolderOnEntry({ folderId: 0 })).toBeNull();
    expect(defaultFolderOnEntry({ folderId: 'lixo' })).toBeNull();
  });
});
