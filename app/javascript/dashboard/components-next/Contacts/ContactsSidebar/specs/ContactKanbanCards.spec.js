import { mount, flushPromises } from '@vue/test-utils';
import ContactKanbanCards from '../ContactKanbanCards.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

const routerPush = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
  useRouter: () => ({ push: routerPush }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      Object.entries(params).reduce(
        (texto, [nome, valor]) => texto.replace(`{${nome}}`, valor),
        {
          'CONTACTS_LAYOUT.SIDEBAR.KANBAN.EMPTY_STATE':
            'No opportunities linked to this contact',
          'CONTACTS_LAYOUT.SIDEBAR.KANBAN.ERROR':
            'Could not load opportunities',
          'CONTACTS_LAYOUT.SIDEBAR.KANBAN.OPEN_CONVERSATION':
            'Open conversation',
          'CONTACTS_LAYOUT.SIDEBAR.KANBAN.WHERE': '{board} › {stage}',
          'CONTACTS_LAYOUT.SIDEBAR.KANBAN.EXPECTED_CLOSE':
            'Expected close {date}',
        }[key] || key
      ),
  }),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getContactCards: vi.fn(),
  },
}));

vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useMapGetter: () => computed(() => id => ({ id, name: 'Carla Souza' })),
  };
});

const abrirDialogo = vi.fn();

const cardsPayload = [
  {
    id: 10,
    subject: 'Implante dentário',
    due_at: '2026-07-21T18:00:00Z',
    conversation_id: 123,
    amount_cents: 120050,
    amount_currency: 'BRL',
    expected_close_date: '2026-10-23',
    kanban_board: { id: 2, name: 'Vendas' },
    kanban_stage: { id: 3, name: 'Negociação', color: 'blue' },
    labels: [{ id: 1, title: 'quente', color: '#ff0000' }],
  },
  {
    id: 11,
    subject: 'Clareamento',
    due_at: null,
    conversation_id: null,
    kanban_board: { id: 2, name: 'Vendas' },
    kanban_stage: { id: 4, name: 'Fechado', color: 'green' },
    labels: [],
  },
];

const mountComponent = props =>
  mount(ContactKanbanCards, {
    props: {
      contactId: 7,
      ...props,
    },
    global: {
      stubs: {
        Spinner: true,
        KanbanContactOpportunityDialog: {
          name: 'KanbanContactOpportunityDialog',
          props: ['contactId', 'contactName'],
          emits: ['created'],
          methods: { open: abrirDialogo },
          template:
            '<div data-testid="dialog-stub" :data-contact-name="contactName" />',
        },
        // Sem `emits`, o clique nativo também passava para o pai: cada
        // clique contava duas vezes.
        Button: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button type="button" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

describe('ContactKanbanCards', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    routerPush.mockClear();
    abrirDialogo.mockClear();
  });

  it('loads and renders contact opportunities', async () => {
    KanbanBoardsAPI.getContactCards.mockResolvedValue({
      data: { payload: cardsPayload },
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(KanbanBoardsAPI.getContactCards).toHaveBeenCalledWith(
      7,
      expect.any(Object)
    );
    expect(wrapper.text()).toContain('Implante dentário');
    expect(wrapper.text()).toContain('Vendas › Negociação');
    expect(wrapper.text()).toContain('Clareamento');
    // 5n: a linha da maquete — valor e previsão, só quando existem.
    const [implante, clareamento] = wrapper.findAll(
      '[data-testid="contact-kanban-card"]'
    );
    expect(
      implante.get('[data-testid="contact-kanban-amount"]').text()
    ).toContain('1,200.50');
    expect(
      implante.get('[data-testid="contact-kanban-close-date"]').text()
    ).toMatch(/^Expected close .*23/);
    expect(
      clareamento.find('[data-testid="contact-kanban-amount"]').exists()
    ).toBe(false);
    expect(
      clareamento.find('[data-testid="contact-kanban-close-date"]').exists()
    ).toBe(false);
  });

  it('opens linked conversations', async () => {
    KanbanBoardsAPI.getContactCards.mockResolvedValue({
      data: { payload: cardsPayload },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper
      .get('[data-testid="contact-kanban-open-conversation"]')
      .trigger('click');

    expect(routerPush).toHaveBeenCalledWith({
      name: 'inbox_conversation',
      params: {
        accountId: 1,
        conversation_id: 123,
      },
    });
  });

  it('renders empty state', async () => {
    KanbanBoardsAPI.getContactCards.mockResolvedValue({
      data: { payload: [] },
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text()).toContain('No opportunities linked to this contact');
  });

  // 5n: criar a oportunidade sem sair do contato, do vazio e do topo da lista.
  it('opens the new opportunity form from the empty state', async () => {
    KanbanBoardsAPI.getContactCards.mockResolvedValue({
      data: { payload: [] },
    });
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper
      .get(
        '[data-testid="contact-kanban-empty"] [data-testid="contact-kanban-new"]'
      )
      .trigger('click');

    expect(abrirDialogo).toHaveBeenCalledTimes(1);
    expect(
      wrapper.get('[data-testid="dialog-stub"]').attributes('data-contact-name')
    ).toBe('Carla Souza');
  });

  it('offers a new opportunity above the list', async () => {
    KanbanBoardsAPI.getContactCards.mockResolvedValue({
      data: { payload: cardsPayload },
    });
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text()).toContain('CONTACTS_LAYOUT.SIDEBAR.KANBAN.COUNT');
    await wrapper.get('[data-testid="contact-kanban-new"]').trigger('click');

    expect(abrirDialogo).toHaveBeenCalledTimes(1);
  });

  it('reloads the list and opens the new opportunity once it is created', async () => {
    KanbanBoardsAPI.getContactCards.mockResolvedValue({
      data: { payload: [] },
    });
    const wrapper = mountComponent();
    await flushPromises();

    wrapper
      .findComponent({ name: 'KanbanContactOpportunityDialog' })
      .vm.$emit('created', { id: 55, boardId: 1 });
    await flushPromises();

    expect(KanbanBoardsAPI.getContactCards).toHaveBeenCalledTimes(2);
    expect(routerPush).toHaveBeenCalledWith({
      name: 'kanban_board_show',
      params: { accountId: 1, boardId: 1 },
      query: { cardId: 55 },
    });
  });
});
