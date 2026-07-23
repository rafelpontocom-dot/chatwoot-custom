import { flushPromises, shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import KanbanAutomations from '../KanbanAutomations.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

const mockPush = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1', boardId: '10' } }),
  useRouter: () => ({ push: mockPush }),
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getSettings: vi.fn(),
    getAutomationRules: vi.fn(),
    createAutomationRule: vi.fn(),
    updateAutomationRule: vi.fn(),
    deleteAutomationRule: vi.fn(),
    getCadences: vi.fn(),
    getAppointmentReminderRules: vi.fn(),
    createAppointmentReminderRule: vi.fn(),
    deleteAppointmentReminderRule: vi.fn(),
    getAutomationConnections: vi.fn(),
    createAutomationConnection: vi.fn(),
    deleteAutomationConnection: vi.fn(),
    resetAutomationConnectionSecret: vi.fn(),
    getAllAutomationExecutions: vi.fn(),
    retryAutomationExecution: vi.fn(),
    getStageCards: vi.fn(),
    testAutomationRule: vi.fn(),
  },
}));

const mountWorkspace = async ({
  connections = [],
  rules = [],
  stageCards = [],
  settings = {
    stages: [],
    custom_field_definitions: [],
    next_action_types: [],
  },
} = {}) => {
  KanbanBoardsAPI.getSettings.mockResolvedValue({
    data: settings,
  });
  KanbanBoardsAPI.getAutomationRules.mockResolvedValue({ data: rules });
  KanbanBoardsAPI.getCadences.mockResolvedValue({ data: [] });
  KanbanBoardsAPI.getAppointmentReminderRules.mockResolvedValue({ data: [] });
  KanbanBoardsAPI.getAutomationConnections.mockResolvedValue({
    data: connections,
  });
  KanbanBoardsAPI.getAllAutomationExecutions.mockResolvedValue({ data: [] });
  KanbanBoardsAPI.getStageCards.mockResolvedValue({
    data: { cards: stageCards },
  });
  KanbanBoardsAPI.createAppointmentReminderRule.mockResolvedValue({
    data: { id: 2, offsets: [24], channels: ['whatsapp'] },
  });

  const store = createStore({
    modules: {
      agents: { namespaced: true, getters: { getAgents: () => [] } },
    },
  });
  const wrapper = shallowMount(KanbanAutomations, {
    global: {
      plugins: [store],
      stubs: { RouterLink: true },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('KanbanAutomations', () => {
  beforeEach(() => vi.clearAllMocks());

  it('starts in the flows workspace and opens a dedicated visual editor', async () => {
    const wrapper = await mountWorkspace({
      settings: {
        stages: [{ id: 2, name: 'Qualificação' }],
        custom_field_definitions: [],
        next_action_types: [],
      },
      rules: [
        {
          id: 44,
          name: 'Retomar orçamento',
          event_name: 'kanban.card.stage_changed',
          active: true,
        },
      ],
    });

    expect(
      wrapper.find('[data-testid="kanban-automations-workspace"]').exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-automation-editor"]').exists()
    ).toBe(true);
    expect(wrapper.find('kanban-workflow-builder-stub').exists()).toBe(true);
  });

  it('returns to the automation list with a newly saved flow', async () => {
    KanbanBoardsAPI.createAutomationRule.mockResolvedValue({
      data: {
        id: 44,
        name: 'Retomar orçamento',
        event_name: 'kanban.card.stage_changed',
        active: true,
        position: 0,
        conditions: {},
        actions: [],
        flow_definition: {},
      },
    });
    const wrapper = await mountWorkspace({
      settings: {
        stages: [{ id: 2, name: 'Qualificação' }],
        custom_field_definitions: [],
        next_action_types: [],
      },
      rules: [
        {
          id: 44,
          name: 'Retomar orçamento',
          event_name: 'kanban.card.stage_changed',
          active: true,
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Retomar orçamento');
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="kanban-automation-editor"]').exists()
    ).toBe(false);
    expect(wrapper.text()).toContain('Retomar orçamento');
  });

  it('uses a follow-up template in the visual builder instead of a separate cadence', async () => {
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-template-follow-up"]')
      .trigger('click');

    expect(wrapper.text()).not.toContain('CADENCES');
    expect(
      wrapper.find('[data-testid="kanban-automation-editor"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-automations-flow-name"]').element.value
    ).toBe('Follow-up comercial');
  });

  it('keeps the Google review contact token outside the i18n catalog', async () => {
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-template-nps-google"]')
      .trigger('click');

    const messageNode = wrapper.vm.form.flowDefinition.nodes.find(
      node => node.type === 'send_message'
    );

    expect(messageNode.data.content).toContain('{{contact_name}}');
    expect(messageNode.data.content).not.toContain(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.NPS_GOOGLE.MESSAGE'
    );
  });

  it('opens birthday configuration from the ready-made template', async () => {
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-template-birthday"]')
      .trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      name: 'kanban_board_settings',
      params: { accountId: '1', boardId: 10 },
      hash: '#birthday-automation',
    });
  });

  it('tests a flow with a selected opportunity without executing it', async () => {
    KanbanBoardsAPI.testAutomationRule.mockResolvedValue({
      data: {
        matches: true,
        steps: [
          {
            node_id: 'wait',
            type: 'delay',
            scheduled_at: '2026-07-24T12:00:00Z',
          },
        ],
      },
    });
    const wrapper = await mountWorkspace({
      settings: {
        stages: [{ id: 2, name: 'Qualificação' }],
        custom_field_definitions: [],
        next_action_types: [],
      },
      rules: [
        {
          id: 44,
          name: 'Retomar orçamento',
          event_name: 'kanban.card.stage_changed',
          active: true,
        },
      ],
      stageCards: [
        { id: 70, subject: 'Proposta Ana', contact: { name: 'Ana' } },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-automation-test-rule-44"]')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-automation-test-card-44"]')
      .setValue('70');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-automation-run-test-44"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.testAutomationRule).toHaveBeenCalledWith(10, 44, 70);
    expect(wrapper.text()).toContain(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEST.RESULT_MATCHES'
    );
    expect(wrapper.text()).toContain(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.DELAY'
    );
  });

  it('reveals compact inbound webhook instructions only when requested', async () => {
    const wrapper = await mountWorkspace({
      connections: [
        {
          id: 7,
          name: 'n8n',
          webhook_url: 'https://n8n.example.com/webhook/outbound',
          inbound_webhook_url: 'https://chat.example.com/webhooks/kanban/token',
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-automations-tab-connections"]')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-automation-connection-details-7"]')
      .trigger('click');

    expect(
      wrapper
        .find('[data-testid="kanban-automation-connection-panel-7"]')
        .exists()
    ).toBe(true);
    expect(wrapper.text()).toContain('INBOUND_HEADERS');
  });
});
