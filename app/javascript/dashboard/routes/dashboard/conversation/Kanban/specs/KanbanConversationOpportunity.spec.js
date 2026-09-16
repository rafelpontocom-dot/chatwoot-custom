import { flushPromises, shallowMount } from '@vue/test-utils';
import KanbanConversationOpportunity from '../KanbanConversationOpportunity.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => ({
    value: key === 'getCurrentRole' ? 'administrator' : [],
  }),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getConversationCards: vi.fn(),
    getSettings: vi.fn(),
  },
}));

const card = (id, subject, createdAt, boardId = 10) => ({
  id,
  subject,
  created_at: createdAt,
  kanban_board: { id: boardId, name: 'Funil' },
  kanban_stage: { id: 4, name: 'Qualificação', color: 'blue' },
});

const settings = {
  id: 10,
  name: 'Funil',
  stages: [{ id: 4, name: 'Qualificação' }],
  next_action_types: ['Ligar'],
  lost_reason_options: ['Preço'],
  custom_field_definitions: [{ key: 'procedimento', label: 'Procedimento' }],
  custom_field_sections: [],
  contact_field_keys: ['phone_number'],
  calendar_enabled: true,
  calendar_booking_stage_ids: [4],
  calendar_procedure_ids: [7],
};

const mountPanel = () =>
  shallowMount(KanbanConversationOpportunity, {
    props: { conversationId: 55 },
    global: {
      stubs: {
        KanbanConversationCards: {
          template: '<div data-testid="criar-oportunidade" />',
        },
      },
    },
  });

describe('KanbanConversationOpportunity', () => {
  beforeEach(() => {
    KanbanBoardsAPI.getConversationCards.mockResolvedValue({
      data: {
        payload: [
          card(1, 'Antiga', '2026-09-01T10:00:00Z'),
          card(2, 'Recente', '2026-09-14T10:00:00Z'),
        ],
      },
    });
    KanbanBoardsAPI.getSettings.mockResolvedValue({ data: settings });
  });

  it('opens the most recent opportunity of the conversation', async () => {
    const wrapper = mountPanel();
    await flushPromises();

    const ficha = wrapper.findComponent({
      name: 'KanbanOpportunityDetailsModal',
    });
    expect(ficha.props('cardId')).toBe(2);
    expect(ficha.props('boardId')).toBe(10);
    expect(ficha.props('drawerMode')).toBe(true);
    // Dentro da conversa não há X para fechar nem «abrir conversa».
    expect(ficha.props('embedded')).toBe(true);
  });

  // Todos os campos do cartão, pelas mesmas abas: é a mesma ficha, não uma cópia.
  it('hands the board configuration to the same opportunity card used in the pipeline', async () => {
    const wrapper = mountPanel();
    await flushPromises();

    const ficha = wrapper.findComponent({
      name: 'KanbanOpportunityDetailsModal',
    });
    expect(ficha.props('customFieldDefinitions')).toEqual(
      settings.custom_field_definitions
    );
    expect(ficha.props('contactFieldKeys')).toEqual(['phone_number']);
    expect(ficha.props('stages')).toEqual(settings.stages);
    expect(ficha.props('calendarEnabled')).toBe(true);
  });

  it('lets the agent switch to the other opportunity of the same contact', async () => {
    const wrapper = mountPanel();
    await flushPromises();

    const seletor = wrapper.find(
      '[data-testid="kanban-conversation-opportunity-picker"]'
    );
    expect(seletor.findAll('option')).toHaveLength(2);

    await seletor.setValue('1');
    await flushPromises();

    expect(
      wrapper
        .findComponent({ name: 'KanbanOpportunityDetailsModal' })
        .props('cardId')
    ).toBe(1);
  });

  it('keeps a single opportunity without a picker', async () => {
    KanbanBoardsAPI.getConversationCards.mockResolvedValue({
      data: { payload: [card(2, 'Recente', '2026-09-14T10:00:00Z')] },
    });
    const wrapper = mountPanel();
    await flushPromises();

    expect(
      wrapper
        .find('[data-testid="kanban-conversation-opportunity-picker"]')
        .exists()
    ).toBe(false);
  });

  it('offers to create one when the conversation has no opportunity', async () => {
    KanbanBoardsAPI.getConversationCards.mockResolvedValue({
      data: { payload: [] },
    });
    const wrapper = mountPanel();
    await flushPromises();

    expect(wrapper.find('[data-testid="criar-oportunidade"]').exists()).toBe(
      true
    );
    expect(
      wrapper.findComponent({ name: 'KanbanOpportunityDetailsModal' }).exists()
    ).toBe(false);
  });

  it('says it could not load instead of showing an empty panel', async () => {
    KanbanBoardsAPI.getConversationCards.mockRejectedValue(new Error('boom'));
    const wrapper = mountPanel();
    await flushPromises();

    expect(
      wrapper
        .find('[data-testid="kanban-conversation-opportunity-error"]')
        .exists()
    ).toBe(true);
  });

  // Gravar não pode trocar a oportunidade aberta nem piscar o painel inteiro.
  it('keeps the open opportunity after it is saved', async () => {
    const wrapper = mountPanel();
    await flushPromises();
    const ficha = wrapper.findComponent({
      name: 'KanbanOpportunityDetailsModal',
    });
    await ficha.find('[data-testid="kanban-conversation-opportunity-picker"]');

    await wrapper
      .find('[data-testid="kanban-conversation-opportunity-picker"]')
      .setValue('1');
    await flushPromises();
    ficha.vm.$emit('updated');
    await flushPromises();

    expect(
      wrapper
        .findComponent({ name: 'KanbanOpportunityDetailsModal' })
        .props('cardId')
    ).toBe(1);
    expect(
      wrapper
        .find('[data-testid="kanban-conversation-opportunity-loading"]')
        .exists()
    ).toBe(false);
  });
});
