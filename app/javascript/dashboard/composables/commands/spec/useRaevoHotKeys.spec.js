import { useRaevoHotKeys } from '../useRaevoHotKeys';

const push = vi.fn();
const getters = vi.hoisted(() => ({
  getCurrentAccountId: 7,
  'kanbanBoards/kanbanBoards': [],
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name => ({
    get value() {
      return getters[name];
    },
  }),
}));
vi.mock('dashboard/helper/URLHelper', () => ({
  frontendURL: url => `/app/${url}`,
}));

describe('useRaevoHotKeys', () => {
  beforeEach(() => {
    push.mockClear();
    getters['kanbanBoards/kanbanBoards'] = [];
  });

  it('puts every Raevo module in the command palette', () => {
    const { raevoHotKeys } = useRaevoHotKeys();

    expect(raevoHotKeys.value.map(command => command.id)).toEqual([
      'raevo_go_to_home',
      'raevo_go_to_pipeline',
      'raevo_go_to_calendar',
      'raevo_go_to_finance',
      'raevo_go_to_forms',
    ]);
  });

  it('navigates to the account-scoped route', () => {
    const { raevoHotKeys } = useRaevoHotKeys();

    raevoHotKeys.value
      .find(command => command.id === 'raevo_go_to_calendar')
      .handler();

    expect(push).toHaveBeenCalledWith('/app/accounts/7/calendar');
  });

  it('offers each pipeline as its own command', () => {
    // Saltar entre "Vendas — Covilhã" e "Vitalidade 360 — Fundão" é a navegação
    // mais repetida do dia numa clínica com mais de um funil.
    getters['kanbanBoards/kanbanBoards'] = [
      { id: 4, name: 'Vendas — Covilhã' },
      { id: 9, name: 'Vitalidade 360' },
    ];

    const { raevoHotKeys } = useRaevoHotKeys();
    const boardCommand = raevoHotKeys.value.find(
      command => command.id === 'raevo_go_to_board_9'
    );

    expect(boardCommand.title).toBe('Vitalidade 360');
    boardCommand.handler();
    expect(push).toHaveBeenCalledWith('/app/accounts/7/kanban/9');
  });

  it('ignores boards the API returned half-formed', () => {
    getters['kanbanBoards/kanbanBoards'] = [
      { id: 4, name: 'Vendas' },
      { id: null, name: 'Sem id' },
      { id: 5 },
    ];

    const { raevoHotKeys } = useRaevoHotKeys();

    expect(
      raevoHotKeys.value.filter(command =>
        command.id.startsWith('raevo_go_to_board_')
      )
    ).toHaveLength(1);
  });

  it('survives the store having no boards loaded yet', () => {
    getters['kanbanBoards/kanbanBoards'] = undefined;

    const { raevoHotKeys } = useRaevoHotKeys();

    expect(raevoHotKeys.value).toHaveLength(5);
  });
});
