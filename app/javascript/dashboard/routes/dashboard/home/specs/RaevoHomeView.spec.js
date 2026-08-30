import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import RaevoHomeView from '../RaevoHomeView.vue';
import RaevoHomeAPI from 'dashboard/api/raevoHome';

const mockPush = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: ref('pt_BR') }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '3' } }),
  useRouter: () => ({ push: mockPush }),
}));
vi.mock('dashboard/api/raevoHome', () => ({
  default: { get: vi.fn() },
}));

const mountHome = () =>
  shallowMount(RaevoHomeView, {
    global: {
      stubs: {
        RaevoPageHeader: {
          template: '<header><slot name="actions" /><slot /></header>',
        },
        RaevoStamp: true,
      },
    },
  });

describe('RaevoHomeView', () => {
  beforeEach(() => {
    mockPush.mockClear();
    RaevoHomeAPI.get.mockResolvedValue({
      data: {
        open_conversations_count: 2,
        open_conversations: [
          {
            id: 11,
            display_id: 1001,
            contact_name: 'Pedro Raevo',
            inbox_name: 'WhatsApp',
            last_activity_at: '2026-08-29T10:00:00Z',
          },
        ],
        overdue_actions: [
          {
            kanban_card_id: 18,
            kanban_board_id: 7,
            kanban_board_name: 'RAEVO',
            kanban_stage_name: 'Contato',
            subject: 'Retornar para Pedro',
            next_action_at: '2026-08-29T09:00:00Z',
          },
        ],
      },
    });
  });

  it('shows the operational queues and opens the linked conversation', async () => {
    const wrapper = mountHome();
    await flushPromises();

    expect(wrapper.text()).toContain('Pedro Raevo');
    expect(wrapper.text()).toContain('Retornar para Pedro');

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Pedro Raevo'))
      .trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      name: 'inbox_conversation',
      params: { accountId: '3', conversation_id: 1001 },
    });
  });

  it('opens an overdue next action in its opportunity drawer', async () => {
    const wrapper = mountHome();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Retornar para Pedro'))
      .trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      name: 'kanban_board_show',
      params: { accountId: '3', boardId: 7 },
      query: { cardId: 18 },
    });
  });
});
