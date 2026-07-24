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
    getAutomationRuleVersions: vi.fn(),
    restoreAutomationRuleVersion: vi.fn(),
    getCadences: vi.fn(),
    getAppointmentReminderRules: vi.fn(),
    createAppointmentReminderRule: vi.fn(),
    deleteAppointmentReminderRule: vi.fn(),
    getAutomationConnections: vi.fn(),
    getBirthdayAutomation: vi.fn(),
    updateBirthdayAutomation: vi.fn(),
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
  executions = [],
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
  KanbanBoardsAPI.getAllAutomationExecutions.mockResolvedValue({
    data: executions,
  });
  KanbanBoardsAPI.getBirthdayAutomation.mockResolvedValue({
    data: {
      active: false,
      days_before: 0,
      delivery_channels: ['whatsapp'],
      opt_in_attribute_key: 'birthday_messages_opt_in',
      message_locale: 'pt_BR',
      timezone: 'America/Sao_Paulo',
      timezone_name: 'America/Sao_Paulo',
      send_time: '09:00',
      message_template: 'Feliz aniversário, {{contact_name}}!',
    },
  });
  KanbanBoardsAPI.getStageCards.mockResolvedValue({
    data: { cards: stageCards },
  });
  KanbanBoardsAPI.getAutomationRuleVersions.mockResolvedValue({ data: [] });
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

  it('shows rule versions and restores a selected snapshot', async () => {
    KanbanBoardsAPI.getAutomationRuleVersions.mockResolvedValue({
      data: [
        {
          id: 31,
          version: 2,
          name: 'Follow-up comercial',
          event_name: 'kanban.card.stage_changed',
          active: true,
          created_at: '2026-08-01T10:00:00Z',
        },
      ],
    });
    KanbanBoardsAPI.restoreAutomationRuleVersion.mockResolvedValue({
      data: {
        id: 44,
        name: 'Follow-up comercial',
        event_name: 'kanban.card.stage_changed',
        active: true,
        version: 3,
      },
    });
    const wrapper = await mountWorkspace({
      rules: [
        {
          id: 44,
          name: 'Follow-up comercial',
          event_name: 'kanban.card.stage_changed',
          active: true,
          version: 2,
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-automation-versions-rule-44"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper
        .find('[data-testid="kanban-automation-versions-panel-44"]')
        .exists()
    ).toBe(true);
    await wrapper.vm.restoreRuleVersion({ id: 31 });
    await flushPromises();

    expect(KanbanBoardsAPI.restoreAutomationRuleVersion).toHaveBeenCalledWith(
      10,
      44,
      31
    );
  });

  it('does not send legacy actions when a visual flow is saved', async () => {
    KanbanBoardsAPI.createAutomationRule.mockResolvedValue({
      data: {
        id: 44,
        name: 'Fluxo visual',
        event_name: 'kanban.card.stage_changed',
        active: true,
        position: 0,
        conditions: {},
        actions: [],
        flow_definition: {},
      },
    });
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Fluxo visual');
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createAutomationRule).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        kanban_automation_rule: expect.objectContaining({ actions: [] }),
      })
    );
  });

  it('creates a new visual flow as a draft until an administrator publishes it', async () => {
    KanbanBoardsAPI.createAutomationRule.mockResolvedValue({
      data: {
        id: 45,
        name: 'Revisar proposta',
        event_name: 'kanban.card.stage_changed',
        active: false,
        position: 0,
        conditions: {},
        actions: [],
        flow_definition: {},
      },
    });
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Revisar proposta');
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createAutomationRule).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        kanban_automation_rule: expect.objectContaining({ active: false }),
      })
    );
  });

  it('keeps an incomplete message flow in the editor with a clear validation error', async () => {
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Mensagem pendente');
    wrapper.vm.form.flowDefinition = {
      nodes: [
        { id: 'trigger', type: 'trigger', data: {} },
        {
          id: 'message',
          type: 'send_message',
          data: { content: '', opt_in_attribute_key: '' },
        },
      ],
      edges: [{ source: 'trigger', target: 'message' }],
    };
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createAutomationRule).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(
      'KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.MESSAGE'
    );
    expect(
      wrapper
        .findComponent({ name: 'KanbanWorkflowBuilder' })
        .props('invalidNodeIds')
    ).toEqual(['message']);
  });

  it('keeps an incomplete response wait in the editor before it reaches the API', async () => {
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Aguardar resposta');
    wrapper.vm.form.flowDefinition = {
      nodes: [
        { id: 'trigger', type: 'trigger', data: {} },
        {
          id: 'response',
          type: 'wait_for_response',
          data: { timeout_hours: 0 },
        },
      ],
      edges: [{ source: 'trigger', target: 'response' }],
    };
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createAutomationRule).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(
      'KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.RESPONSE_WAIT'
    );
  });

  it('focuses the node identified by a backend validation error', async () => {
    KanbanBoardsAPI.createAutomationRule.mockRejectedValue({
      response: {
        data: {
          message: 'Action node action references a stage outside this board',
        },
      },
    });
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Etapa inválida');
    wrapper.vm.form.flowDefinition = {
      nodes: [
        { id: 'trigger', type: 'trigger', data: {} },
        {
          id: 'action',
          type: 'action',
          data: {
            action_name: 'move_stage',
            action_params: { stage_id: 999 },
          },
        },
        { id: 'end', type: 'end', data: {} },
      ],
      edges: [
        { source: 'trigger', target: 'action' },
        { source: 'action', target: 'end' },
      ],
    };
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper
        .findComponent({ name: 'KanbanWorkflowBuilder' })
        .props('invalidNodeIds')
    ).toEqual(['action']);
  });

  it('keeps a partial quiet-hours policy in the editor before it reaches the API', async () => {
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Mensagem com horário silencioso');
    wrapper.vm.form.flowDefinition = {
      nodes: [
        { id: 'trigger', type: 'trigger', data: {} },
        {
          id: 'message',
          type: 'send_message',
          data: {
            channel: 'whatsapp',
            content: 'Olá',
            opt_in_attribute_key: 'marketing_messages_opt_in',
            quiet_hours: {
              start: '20:00',
              end: '',
              timezone: 'America/Sao_Paulo',
            },
          },
        },
      ],
      edges: [{ source: 'trigger', target: 'message' }],
    };
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createAutomationRule).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(
      'KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.MESSAGE_POLICY'
    );
  });

  it('requires both paths from a condition before saving a flow', async () => {
    const wrapper = await mountWorkspace({
      settings: {
        stages: [],
        custom_field_definitions: [
          { key: 'origem', label: 'Origem', field_type: 'text' },
        ],
        next_action_types: [],
      },
    });

    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-flow-name"]')
      .setValue('Qualificar origem');
    wrapper.vm.form.flowDefinition = {
      nodes: [
        { id: 'trigger', type: 'trigger', data: {} },
        {
          id: 'condition',
          type: 'condition',
          data: { field_key: 'origem', operator: 'equals', value: 'Google' },
        },
        { id: 'end', type: 'end', data: {} },
      ],
      edges: [
        { source: 'trigger', target: 'condition' },
        { source: 'condition', sourceHandle: 'yes', target: 'end' },
      ],
    };
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createAutomationRule).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(
      'KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.CONDITION_PATH'
    );
  });

  it('can cancel waiting executions when saving an edited flow', async () => {
    KanbanBoardsAPI.updateAutomationRule.mockResolvedValue({
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
      rules: [
        {
          id: 44,
          name: 'Retomar orçamento',
          event_name: 'kanban.card.stage_changed',
          active: true,
          position: 0,
          conditions: {},
          actions: [],
          flow_definition: {},
        },
      ],
      executions: [{ id: 5, rule_id: 44, status: 'waiting' }],
    });

    await wrapper
      .find('[data-testid="kanban-automation-rule-44"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-automations-cancel-pending"]')
      .setValue(true);
    await wrapper
      .find('[data-testid="kanban-automations-save-flow"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateAutomationRule).toHaveBeenCalledWith(
      10,
      44,
      expect.objectContaining({
        kanban_automation_rule: expect.objectContaining({
          cancel_waiting_executions: true,
        }),
      })
    );
  });

  it('summarizes failed and overdue automation executions for the administrator', async () => {
    const wrapper = await mountWorkspace({
      executions: [
        { id: 1, status: 'failed' },
        {
          id: 2,
          status: 'waiting',
          scheduled_at: '2020-01-01T09:00:00.000Z',
        },
        {
          id: 3,
          status: 'waiting',
          scheduled_at: '2999-01-01T09:00:00.000Z',
        },
      ],
    });

    expect(wrapper.vm.automationHealth).toMatchObject({
      failedCount: 1,
      overdueCount: 1,
      needsAttention: true,
    });
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

  it('opens the annual birthday automation in the automations workspace', async () => {
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-template-birthday"]')
      .trigger('click');

    expect(KanbanBoardsAPI.getBirthdayAutomation).toHaveBeenCalled();
    expect(
      wrapper.find('[data-testid="kanban-birthday-editor"]').exists()
    ).toBe(true);
  });

  it('persists the birthday message image as a signed upload', async () => {
    KanbanBoardsAPI.updateBirthdayAutomation.mockResolvedValue({
      data: {
        active: false,
        days_before: 0,
        delivery_channels: ['whatsapp'],
        opt_in_attribute_key: 'birthday_messages_opt_in',
        message_locale: 'pt_BR',
        timezone: 'America/Sao_Paulo',
        timezone_name: 'America/Sao_Paulo',
        send_time: '09:00',
        message_template: 'Feliz aniversário, {{contact_name}}!',
        message_attachment: {
          signed_id: 'signed-image',
          filename: 'aniversario.png',
          content_type: 'image/png',
        },
      },
    });
    const wrapper = await mountWorkspace();

    await wrapper
      .find('[data-testid="kanban-automations-template-birthday"]')
      .trigger('click');
    wrapper.vm.birthdayAutomation.messageAttachment = {
      signedId: 'signed-image',
      filename: 'aniversario.png',
      contentType: 'image/png',
    };
    await wrapper.vm.saveBirthdayAutomation();

    expect(KanbanBoardsAPI.updateBirthdayAutomation).toHaveBeenCalledWith(
      expect.objectContaining({
        birthday_automation: expect.objectContaining({
          message_attachment: expect.objectContaining({
            signed_id: 'signed-image',
          }),
        }),
      })
    );
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
