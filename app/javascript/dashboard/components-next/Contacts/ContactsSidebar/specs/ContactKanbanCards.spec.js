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
    t: key =>
      ({
        'CONTACTS_LAYOUT.SIDEBAR.KANBAN.EMPTY_STATE':
          'No opportunities linked to this contact',
        'CONTACTS_LAYOUT.SIDEBAR.KANBAN.ERROR': 'Could not load opportunities',
        'CONTACTS_LAYOUT.SIDEBAR.KANBAN.OPEN_CONVERSATION': 'Open conversation',
        'CONTACTS_LAYOUT.SIDEBAR.KANBAN.NOT_SET': 'Not set',
      })[key] || key,
  }),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getContactCards: vi.fn(),
  },
}));

const cardsPayload = [
  {
    id: 10,
    subject: 'Implante dentário',
    due_at: '2026-07-21T18:00:00Z',
    conversation_id: 123,
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
        Button: {
          props: ['label'],
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
    expect(wrapper.text()).toContain('Vendas');
    expect(wrapper.text()).toContain('Negociação');
    expect(wrapper.text()).toContain('Clareamento');
    expect(wrapper.text()).toContain('Not set');
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
});
