import { flushPromises, shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { createStore } from 'vuex';
import KanbanBoardSettings from '../KanbanBoardSettings.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import { useAlert } from 'dashboard/composables';
import ptBRKanbanMessages from 'dashboard/i18n/locale/pt_BR/kanban.json';

const mockReplace = vi.fn();
const mockPush = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

const mockOnBeforeRouteLeave = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({
    name: 'kanban_board_settings',
    params: {
      accountId: '1',
      boardId: '10',
    },
  }),
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
  }),
  onBeforeRouteLeave: guarda => mockOnBeforeRouteLeave(guarda),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getSettings: vi.fn(),
    showBoard: vi.fn(),
    getBirthdayAutomation: vi.fn(),
    updateBirthdayAutomation: vi.fn(),
    updateSettings: vi.fn(),
    delete: vi.fn(),
    duplicateBoard: vi.fn(),
    createStage: vi.fn(),
    updateStage: vi.fn(),
    reorderStage: vi.fn(),
    importExistingConversations: vi.fn(),
    getAutomationRules: vi.fn(),
    createAutomationRule: vi.fn(),
    updateAutomationRule: vi.fn(),
    deleteAutomationRule: vi.fn(),
    testAutomationRule: vi.fn(),
    getAutomationExecutions: vi.fn(),
    cancelAutomationExecution: vi.fn(),
    getCadences: vi.fn(),
    getAppointmentReminderRules: vi.fn(),
    createAppointmentReminderRule: vi.fn(),
    deleteAppointmentReminderRule: vi.fn(),
    createCadence: vi.fn(),
    updateCadence: vi.fn(),
    deleteCadence: vi.fn(),
  },
}));

const settingsPayload = {
  id: 10,
  name: 'Vendas',
  description: 'Pipeline comercial',
  visibility_mode: 'selected_agents',
  visible_user_ids: [1, 2],
  inbox_scope_mode: 'selected_inboxes',
  allowed_inbox_ids: [5, 6],
  auto_create_cards_from_conversations: true,
  next_action_types: ['Enviar proposta', 'Cobrar retorno'],
  lost_reason_options: ['Preço', 'Sem resposta'],
  custom_field_definitions: [
    {
      key: 'consulta_realizada',
      label: 'Consulta realizada?',
      field_type: 'select',
      options: ['Sim', 'Não'],
    },
  ],
  compact_card_field_keys: [],
  custom_field_sections: [],
  stale_stage_thresholds: { 100: 3 },
};

const boardPayload = {
  id: 10,
  stages: [
    {
      id: 100,
      name: 'Lead',
      color: 'blue',
      category: 'open',
      probability: 40,
      position: 1,
      cards_count: 3,
    },
    {
      id: 200,
      name: 'Won',
      color: 'green',
      category: 'won',
      probability: 100,
      position: 2,
      cards_count: 0,
    },
  ],
};

const createTestStore = (role = 'administrator') => {
  const dispatch = vi.fn((type, payload) => {
    if (type === 'agents/get' || type === 'inboxes/get') {
      return Promise.resolve();
    }

    if (type === 'kanbanBoards/refreshBoards') {
      return Promise.resolve(payload);
    }

    return Promise.resolve();
  });

  const store = createStore({
    getters: {
      getCurrentRole: () => role,
    },
    modules: {
      auth: {
        namespaced: true,
        getters: {
          getCurrentRole: () => role,
        },
      },
      agents: {
        namespaced: true,
        state: {
          records: [
            { id: 1, name: 'Alice' },
            { id: 2, name: 'Bob' },
          ],
        },
        getters: {
          getAgents: state => state.records,
        },
      },
      inboxes: {
        namespaced: true,
        state: {
          records: [
            { id: 5, name: 'Sales' },
            { id: 6, name: 'Support' },
          ],
        },
        getters: {
          getAllInboxes: state => state.records,
        },
      },
      kanbanBoards: {
        namespaced: true,
        actions: {
          refreshBoards: vi.fn(),
        },
      },
    },
  });

  store.dispatch = dispatch;
  return { store, dispatch };
};

const mountSettings = async ({
  role = 'administrator',
  getSettingsResponse = { data: settingsPayload },
  getSettingsError = null,
} = {}) => {
  if (getSettingsError) {
    KanbanBoardsAPI.getSettings.mockRejectedValue(getSettingsError);
  } else {
    KanbanBoardsAPI.getSettings.mockResolvedValue(getSettingsResponse);
  }
  KanbanBoardsAPI.showBoard.mockResolvedValue({ data: boardPayload });
  KanbanBoardsAPI.getBirthdayAutomation.mockResolvedValue({
    data: {
      active: false,
      days_before: 0,
      delivery_channels: [],
      opt_in_attribute_key: 'birthday_messages_opt_in',
      message_locale: 'pt_BR',
      timezone: '',
      timezone_name: 'UTC',
      send_time: '09:00',
      message_template: 'Feliz aniversário, {{contact_name}}!',
    },
  });

  const { store, dispatch } = createTestStore(role);
  const wrapper = shallowMount(KanbanBoardSettings, {
    global: {
      plugins: [store],
      stubs: {
        RaevoPageHeader: {
          template:
            '<header><slot name="actions" /><slot name="filters" /><slot name="tabs" /><slot /></header>',
        },
        Button: {
          props: ['label', 'isLoading'],
          emits: ['click'],
          template:
            '<button v-bind="$attrs" type="button" @click="$emit(\'click\')">{{ label }}</button>',
        },
        TagMultiSelectComboBox: {
          props: ['modelValue', 'options'],
          emits: ['update:modelValue'],
          template:
            '<div v-bind="$attrs" class="tag-select-stub"><button type="button" data-testid="tag-select-update" @click="$emit(\'update:modelValue\', options.map(option => option.value))" /></div>',
        },
        Draggable: {
          name: 'Draggable',
          props: ['modelValue', 'list'],
          emits: ['update:modelValue', 'end', 'change'],
          template:
            '<div v-bind="$attrs"><slot v-for="item in modelValue || list" name="item" :element="item" /></div>',
        },
        WootDeleteModal: {
          props: ['show', 'onConfirm'],
          template:
            '<button v-if="show" data-testid="confirm-delete" type="button" @click="onConfirm" />',
        },
        WootModal: {
          props: ['show'],
          template: '<div v-if="show"><slot /></div>',
        },
        Modal: {
          name: 'Modal',
          props: ['show', 'onClose'],
          template: '<div v-if="show"><slot /></div>',
        },
        // Sem isto o slot do RaevoField não renderiza e todos os campos do
        // editor desaparecem do teste. Ver CLAUDE.md.
        RaevoField: {
          props: ['label'],
          template:
            '<div><label>{{ label }}</label><slot control-class="raevo-control" field-id="raevo-field" /></div>',
        },
        Switch: {
          name: 'Switch',
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<button v-bind="$attrs" type="button" role="switch" :aria-checked="String(modelValue)" @click="$emit(\'update:modelValue\', !modelValue)" />',
        },
      },
    },
  });

  await flushPromises();
  await nextTick();
  return { wrapper, dispatch };
};

describe('KanbanBoardSettings', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    KanbanBoardsAPI.updateSettings.mockResolvedValue({ data: settingsPayload });
    KanbanBoardsAPI.updateBirthdayAutomation.mockResolvedValue({
      data: {
        active: true,
        days_before: 2,
        delivery_channels: ['whatsapp'],
        opt_in_attribute_key: 'birthday_messages_opt_in',
        message_locale: 'pt_BR',
        timezone: 'America/Sao_Paulo',
        timezone_name: 'America/Sao_Paulo',
        send_time: '09:00',
        message_template: 'Parabéns, {{contact_name}}!',
      },
    });
    KanbanBoardsAPI.delete.mockResolvedValue({ data: {} });
    KanbanBoardsAPI.duplicateBoard.mockResolvedValue({ data: { id: 11 } });
    KanbanBoardsAPI.createStage.mockResolvedValue({
      data: { id: 300, name: 'Follow up', color: 'slate', position: 3 },
    });
    KanbanBoardsAPI.updateStage.mockResolvedValue({ data: {} });
    KanbanBoardsAPI.reorderStage.mockResolvedValue({ data: {} });
    KanbanBoardsAPI.importExistingConversations.mockResolvedValue({
      data: { status: 'accepted', enqueued: true, estimated_count: 3 },
    });
    KanbanBoardsAPI.getAutomationRules.mockResolvedValue({ data: [] });
    KanbanBoardsAPI.createAutomationRule.mockResolvedValue({
      data: {
        id: 50,
        name: 'Nova regra',
        event_name: 'kanban.card.won',
        active: true,
      },
    });
    KanbanBoardsAPI.updateAutomationRule.mockResolvedValue({
      data: {
        id: 50,
        name: 'Nova regra',
        event_name: 'kanban.card.won',
        active: true,
      },
    });
    KanbanBoardsAPI.deleteAutomationRule.mockResolvedValue({ data: {} });
    KanbanBoardsAPI.testAutomationRule.mockResolvedValue({
      data: { matches: true, message: 'Matches' },
    });
    KanbanBoardsAPI.getCadences.mockResolvedValue({ data: [] });
    KanbanBoardsAPI.getAppointmentReminderRules.mockResolvedValue({ data: [] });
    KanbanBoardsAPI.createCadence.mockResolvedValue({
      data: {
        id: 80,
        name: 'Novo follow-up',
        active: true,
        steps: [{ delay_hours: 24, action_type: 'Retorno' }],
      },
    });
    KanbanBoardsAPI.deleteCadence.mockResolvedValue({ data: {} });
  });

  it('uses the workspace background instead of a full white settings canvas', async () => {
    const { wrapper } = await mountSettings();

    expect(
      wrapper.find('[data-testid="kanban-settings-workspace"]').classes()
    ).toContain('bg-n-background');
  });

  it('loads the page settings', async () => {
    const { wrapper, dispatch } = await mountSettings();

    expect(KanbanBoardsAPI.getSettings).toHaveBeenCalledWith(10);
    expect(KanbanBoardsAPI.showBoard).toHaveBeenCalledWith(10);
    expect(dispatch).toHaveBeenCalledWith('agents/get');
    expect(dispatch).toHaveBeenCalledWith('inboxes/get');
    expect(wrapper.find('[data-testid="kanban-settings-form"]').exists()).toBe(
      true
    );
  });

  it('duplicates the funnel from the settings header', async () => {
    const { wrapper, dispatch } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-duplicate"]')
      .trigger('click');
    expect(
      wrapper.find('[data-testid="kanban-settings-duplicate-modal"]').exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-settings-confirm-duplicate"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.duplicateBoard).toHaveBeenCalledWith(10);
    expect(dispatch).toHaveBeenCalledWith('kanbanBoards/refreshBoards');
    expect(mockReplace).toHaveBeenCalledWith({
      name: 'kanban_board_settings',
      params: { accountId: '1', boardId: 11 },
    });
  });

  it('renders stages in the settings page', async () => {
    const { wrapper } = await mountSettings();

    const stages = wrapper.findAll('[data-testid="kanban-settings-stage-row"]');
    expect(stages).toHaveLength(2);
    expect(stages[0].text()).toContain('Lead');
    expect(stages[1].text()).toContain('Won');
  });

  it('renders stage card counts in the settings page', async () => {
    const { wrapper } = await mountSettings();

    const counts = wrapper.findAll(
      '[data-testid="kanban-settings-stage-card-count"]'
    );
    expect(counts).toHaveLength(2);
    expect(counts[0].text()).toBe('3');
    expect(counts[1].text()).toBe('0');
  });

  it('keeps the stage list compact and edits only the selected stage', async () => {
    const { wrapper } = await mountSettings();

    expect(
      wrapper.findAll('[data-testid="kanban-settings-stage-category"]')
    ).toHaveLength(1);
    expect(
      wrapper.find('[data-testid="kanban-settings-stage-name"]').element.value
    ).toBe('Lead');

    await wrapper
      .findAll('[data-testid="kanban-settings-stage-select"]')[1]
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-settings-stage-name"]').element.value
    ).toBe('Won');
  });

  it('moves a stage up through an explicit keyboard-accessible control', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-stage-move-200-up"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.reorderStage).toHaveBeenCalledWith(10, 200, {
      position: 1,
    });
  });

  it('configures the commercial category and capacity alert for a stage', async () => {
    KanbanBoardsAPI.updateStage.mockResolvedValue({ data: {} });
    const { wrapper } = await mountSettings();
    const editor = wrapper.find('[data-testid="kanban-settings-stage-editor"]');

    await editor
      .find('[data-testid="kanban-settings-stage-category"]')
      .setValue('won');
    await editor
      .find('[data-testid="kanban-settings-stage-wip-limit"]')
      .setValue('8');
    await editor
      .find('[data-testid="kanban-settings-save-stage-rules"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateStage).toHaveBeenCalledWith(10, 100, {
      stage: {
        name: 'Lead',
        icon: 'circle-dot',
        description: '',
        category: 'won',
        wip_limit: 8,
      },
    });
  });

  it('saves win probability for an open stage', async () => {
    const { wrapper } = await mountSettings();
    const editor = wrapper.find('[data-testid="kanban-settings-stage-editor"]');

    await editor
      .find('[data-testid="kanban-settings-stage-probability"]')
      .setValue('65');
    await editor
      .find('[data-testid="kanban-settings-save-stage-rules"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateStage).toHaveBeenCalledWith(10, 100, {
      stage: {
        name: 'Lead',
        icon: 'circle-dot',
        description: '',
        category: 'open',
        wip_limit: null,
        probability: 65,
      },
    });
  });

  it('saves a stage icon and guidance without expanding every stage row', async () => {
    const { wrapper } = await mountSettings();
    const editor = wrapper.find('[data-testid="kanban-settings-stage-editor"]');

    await editor
      .find('[data-testid="kanban-settings-stage-description"]')
      .setValue('Confirm the procedure and next action before advancing.');
    await editor
      .find('[data-testid="kanban-settings-stage-icon-clipboard-list"]')
      .trigger('click');
    await editor
      .find('[data-testid="kanban-settings-save-stage-rules"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateStage).toHaveBeenCalledWith(10, 100, {
      stage: {
        name: 'Lead',
        icon: 'clipboard-list',
        description: 'Confirm the procedure and next action before advancing.',
        category: 'open',
        wip_limit: null,
        probability: 40,
      },
    });
  });

  it('creates a new stage from settings', async () => {
    const { wrapper, dispatch } = await mountSettings();

    expect(
      wrapper
        .find('[data-testid="kanban-settings-create-stage-panel"]')
        .exists()
    ).toBe(false);
    await wrapper
      .find('[data-testid="kanban-settings-create-stage-toggle"]')
      .trigger('click');
    expect(wrapper.findComponent({ name: 'Modal' }).exists()).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-create-stage-panel"]')
        .exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-settings-new-stage-name"]')
      .setValue('Follow up');
    await wrapper
      .find('[data-testid="kanban-settings-create-stage"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createStage).toHaveBeenCalledWith(10, {
      stage: {
        name: 'Follow up',
        color: 'amber', // Sereno: seletor abre na cor automática
        icon: 'circle-dot',
        description: '',
        position: 3,
      },
    });
    expect(dispatch).toHaveBeenCalledWith('kanbanBoards/refreshBoards');
  });

  it('persists stage reorder from settings', async () => {
    const { wrapper, dispatch } = await mountSettings();
    const draggable = wrapper.findComponent({ name: 'Draggable' });

    await draggable.vm.$emit('end', {
      item: { dataset: { stageId: '200' } },
      oldIndex: 1,
      newIndex: 0,
    });
    await flushPromises();

    expect(KanbanBoardsAPI.reorderStage).toHaveBeenCalledWith(10, 200, {
      position: 1,
    });
    expect(dispatch).toHaveBeenCalledWith('kanbanBoards/refreshBoards');
  });

  it('fills the form with the current payload', async () => {
    const { wrapper } = await mountSettings();

    expect(
      wrapper.find('[data-testid="kanban-settings-name"]').element.value
    ).toBe('Vendas');
    expect(
      wrapper.find('[data-testid="kanban-settings-description"]').element.value
    ).toBe('Pipeline comercial');
    expect(
      wrapper.find('[data-testid="kanban-settings-auto-create"]').element
        .checked
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-settings-agent-select"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-settings-inbox-select"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-settings-next-action-types"]').element
        .value
    ).toBe('Enviar proposta\nCobrar retorno');
    expect(
      wrapper.find('[data-testid="kanban-settings-lost-reason-options"]')
        .element.value
    ).toBe('Preço\nSem resposta');
  });

  it('keeps occasional commercial option lists collapsed by default', async () => {
    const { wrapper } = await mountSettings();

    expect(
      wrapper
        .find('[data-testid="kanban-settings-next-action-types-group"]')
        .attributes('open')
    ).toBeUndefined();
    expect(
      wrapper
        .find('[data-testid="kanban-settings-lost-reason-options-group"]')
        .attributes('open')
    ).toBeUndefined();
  });

  it('toggles all_agents and selected_agents controls', async () => {
    const { wrapper } = await mountSettings();

    await wrapper.find('[data-testid="kanban-settings-all-agents"]').setValue();
    expect(
      wrapper.find('[data-testid="kanban-settings-agent-select"]').exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-settings-selected-agents"]')
      .setValue();
    expect(
      wrapper.find('[data-testid="kanban-settings-agent-select"]').exists()
    ).toBe(true);
  });

  it('loads cadence configuration for administrators', async () => {
    await mountSettings();

    expect(KanbanBoardsAPI.getCadences).toHaveBeenCalledWith(10);
  });

  it('opens the visual automations workspace from the settings navigation', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-automation"]')
      .trigger('click');
    expect(mockPush).toHaveBeenCalledWith({
      name: 'kanban_board_automations',
      params: { accountId: '1', boardId: 10 },
    });
    expect(
      wrapper
        .find('[data-testid="kanban-settings-automation-rule-editor"]')
        .isVisible()
    ).toBe(false);
  });

  it('toggles all_inboxes and selected_inboxes controls', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-all-inboxes"]')
      .setValue();
    expect(
      wrapper.find('[data-testid="kanban-settings-inbox-select"]').exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-settings-selected-inboxes"]')
      .setValue();
    expect(
      wrapper.find('[data-testid="kanban-settings-inbox-select"]').exists()
    ).toBe(true);
  });

  it('shows the automation toggle in the automations section', async () => {
    const { wrapper } = await mountSettings();

    expect(wrapper.text()).toContain('KANBAN.SETTINGS.AUTOMATIONS.TITLE');
    expect(wrapper.text()).toContain('KANBAN.SETTINGS.AUTOMATIONS.AUTO_CREATE');
    expect(
      wrapper.find('[data-testid="kanban-settings-auto-create"]').exists()
    ).toBe(true);
  });

  it('configures custom fields visually and selects fields for compact cards', async () => {
    const { wrapper } = await mountSettings();

    expect(
      wrapper.findAll('[data-testid="kanban-settings-custom-field-editor"]')
    ).toHaveLength(0);
    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-add-field-details"]')
      .trigger('click');

    const row = wrapper.find(
      '[data-testid="kanban-settings-custom-field-editor"]'
    );
    expect(row.exists()).toBe(true);
    await row
      .find('[data-testid="kanban-settings-custom-field-label"]')
      .setValue('Valor estimado');
    await row
      .find('[data-testid="kanban-settings-custom-field-type"]')
      .setValue('currency');
    await row
      .find('[data-testid="kanban-settings-custom-field-show-on-card"]')
      .setValue(true);
    await row
      .find('[data-testid="kanban-settings-custom-field-important"]')
      .setValue(true);
    expect(
      wrapper.find('[data-testid="kanban-settings-stale-stage-100"]').exists()
    ).toBe(false);
    await wrapper
      .find('[data-testid="kanban-settings-toggle-stale-alerts"]')
      .trigger('click');
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-settings-stale-stage-100"]')
      .setValue('5');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    expect(KanbanBoardsAPI.updateSettings).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        kanban_board: expect.objectContaining({
          custom_field_definitions: expect.arrayContaining([
            expect.objectContaining({
              key: 'valor_estimado',
              label: 'Valor estimado',
              field_type: 'currency',
              important: true,
            }),
          ]),
          compact_card_field_keys: ['valor_estimado'],
          stale_stage_thresholds: { 100: 5 },
        }),
      })
    );
  });

  it('shows a reorderable compact card preview in the field manager', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-add-field-details"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-custom-field-label"]')
      .setValue('Procedimento');
    await wrapper
      .find('[data-testid="kanban-settings-custom-field-show-on-card"]')
      .setValue(true);

    expect(
      wrapper
        .find('[data-testid="kanban-settings-compact-card-layout"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-compact-card-preview"]')
        .text()
    ).toContain('Procedimento');
  });

  it('reorders compact card fields with explicit move controls', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            { key: 'origem', label: 'Origem', field_type: 'text' },
            { key: 'campanha', label: 'Campanha', field_type: 'text' },
          ],
          compact_card_field_keys: ['origem', 'campanha'],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-compact-card-move-campanha-up"]')
      .trigger('click');

    expect(wrapper.vm.form.compactCardFieldKeys).toEqual([
      'campanha',
      'origem',
    ]);
  });

  it('keeps the custom field row mounted while deriving its key from the label', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-add-field-details"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-custom-field-label"]')
      .setValue('Nome inicial');

    const labelInput = wrapper.find(
      '[data-testid="kanban-settings-custom-field-label"]'
    );
    const originalInputElement = labelInput.element;

    await labelInput.setValue('O');
    await nextTick();

    expect(
      wrapper.find('[data-testid="kanban-settings-custom-field-label"]').element
    ).toBe(originalInputElement);
  });

  it('adds the complete marketing field preset', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-tab-marketing"]')
      .trigger('click');
    await wrapper
      .findComponent({ name: 'Switch' })
      .vm.$emit('update:modelValue', true);
    await nextTick();
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    expect(KanbanBoardsAPI.updateSettings).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        kanban_board: expect.objectContaining({
          custom_field_definitions: expect.arrayContaining([
            expect.objectContaining({
              key: 'origem_do_lead',
              field_type: 'select',
              layout: expect.objectContaining({ section: 'marketing' }),
            }),
            expect.objectContaining({
              key: 'sub_origem',
              field_type: 'select',
              layout: expect.objectContaining({ section: 'marketing' }),
            }),
            expect.objectContaining({ key: 'utm_source' }),
            expect.objectContaining({ key: 'gclid' }),
            expect.objectContaining({ key: 'fvclid' }),
            expect.objectContaining({ key: 'ttclid' }),
            expect.objectContaining({ key: 'campaign' }),
            expect.objectContaining({ key: 'adset' }),
            expect.objectContaining({ key: 'ad' }),
            expect.objectContaining({ key: 'campaign_id' }),
            expect.objectContaining({ key: 'landing_page_full' }),
          ]),
        }),
      })
    );
    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    const marketingKeys = payload.kanban_board.custom_field_definitions
      .filter(definition => definition.layout.section === 'marketing')
      .map(definition => definition.key);
    expect(marketingKeys).toEqual([
      'origem_do_lead',
      'sub_origem',
      'campaign',
      'adset',
      'ad',
      'utm_content',
      'utm_medium',
      'utm_campaign',
      'utm_source',
      'utm_term',
      'utm_referrer',
      'referrer',
      'gclientid',
      'gclid',
      'fvclid',
      'ttad_name',
      'ttad_id',
      'fbc',
      'fbp',
      'ttclid',
      'campaign_id',
      'adset_id',
      'ad_id',
      'landing_page',
      'event_id',
      'landing_page_full',
    ]);
  });

  it('removes the marketing preset only after the switch asks to confirm', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-tab-marketing"]')
      .trigger('click');
    await wrapper
      .findComponent({ name: 'Switch' })
      .vm.$emit('update:modelValue', true);
    await nextTick();

    const marketingCount = wrapper.vm.form.customFieldDefinitions.filter(
      definition => definition.layoutSection === 'marketing'
    ).length;
    expect(marketingCount).toBeGreaterThan(0);

    // Desligar não apaga nada por si: primeiro pergunta.
    await wrapper
      .findComponent({ name: 'Switch' })
      .vm.$emit('update:modelValue', false);
    await nextTick();

    expect(
      wrapper.vm.form.customFieldDefinitions.filter(
        definition => definition.layoutSection === 'marketing'
      )
    ).toHaveLength(marketingCount);

    await wrapper
      .find('[data-testid="kanban-settings-confirm-remove-marketing"]')
      .trigger('click');
    await nextTick();

    expect(
      wrapper.vm.form.customFieldDefinitions.filter(
        definition => definition.layoutSection === 'marketing'
      )
    ).toHaveLength(0);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-confirm-remove-marketing"]')
        .exists()
    ).toBe(false);
  });

  it('keeps hand-made fields when the marketing preset is switched off', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            {
              key: 'utm_source',
              label: 'UTM source',
              field_type: 'text',
              layout: { section: 'marketing', position: 1 },
            },
            {
              key: 'origem_manual',
              label: 'Origem manual',
              field_type: 'text',
              layout: { section: 'marketing', position: 2 },
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-tab-marketing"]')
      .trigger('click');
    await wrapper
      .findComponent({ name: 'Switch' })
      .vm.$emit('update:modelValue', false);
    await nextTick();
    await wrapper
      .find('[data-testid="kanban-settings-confirm-remove-marketing"]')
      .trigger('click');
    await nextTick();

    expect(
      wrapper.vm.form.customFieldDefinitions.map(definition => definition.key)
    ).toEqual(['origem_manual']);
  });

  it('normalizes legacy marketing fields to the final preset when loaded', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            {
              key: 'gbraid',
              label: 'Google GBRAID',
              field_type: 'text',
              layout: { section: 'marketing', position: 1 },
            },
            {
              key: 'campaign_name',
              label: 'Campanha antiga',
              field_type: 'text',
              layout: { section: 'marketing', position: 2 },
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    expect(wrapper.find('[data-field-key="gbraid"]').exists()).toBe(false);
    expect(wrapper.find('[data-field-key="campaign"]').exists()).toBe(true);
    expect(wrapper.find('[data-field-key="utm_source"]').exists()).toBe(true);
  });

  it('lists the fields of the active tab with a create row at the end', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    expect(wrapper.find('[data-field-key="consulta_realizada"]').exists()).toBe(
      true
    );
    expect(
      wrapper.find('[data-testid="kanban-settings-add-field-details"]').exists()
    ).toBe(true);
    // A lista é o que se vê ao abrir o gestor; o editor só aparece ao carregar
    // num campo. Era ao contrário: nascia sempre, no fundo da coluna.
    expect(
      wrapper
        .find('[data-testid="kanban-settings-custom-field-editor"]')
        .exists()
    ).toBe(false);
  });

  it('shows the field properties beside the list, not on top of it', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    // Antes de escolher um campo, o painel diz o que fazer em vez de ficar vazio.
    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-editor-empty"]')
        .exists()
    ).toBe(true);

    await wrapper
      .find('[data-field-key="consulta_realizada"]')
      .trigger('click');

    const editor = wrapper.find(
      '[data-testid="kanban-settings-custom-field-editor"]'
    );
    expect(editor.exists()).toBe(true);
    expect(
      editor.find('[data-testid="kanban-settings-custom-field-label"]').element
        .value
    ).toBe('Consulta realizada?');
    // A lista continua à vista ao lado do painel: nada foi tapado.
    expect(wrapper.find('[data-field-key="consulta_realizada"]').exists()).toBe(
      true
    );
    expect(
      wrapper.find('[data-testid="kanban-settings-add-field-details"]').exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-editor-empty"]')
        .exists()
    ).toBe(false);
  });

  it('gives the field workspace an address of its own', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    expect(mockPush).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'kanban_board_field_settings' })
    );
    expect(
      wrapper
        .find('[data-testid="kanban-settings-custom-field-manager"]')
        .exists()
    ).toBe(true);
  });

  it('reorders fields without dragging, and blocks the ends', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            { key: 'primeiro', label: 'Primeiro', field_type: 'text' },
            { key: 'segundo', label: 'Segundo', field_type: 'text' },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    // A pega só serve o rato: sem estes botões não há como reordenar.
    expect(
      wrapper
        .find('[data-testid="kanban-settings-move-field-primeiro-up"]')
        .attributes('disabled')
    ).toBeDefined();
    await wrapper
      .find('[data-testid="kanban-settings-move-field-primeiro-down"]')
      .trigger('click');

    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-search-results"]')
        .exists()
    ).toBe(false);
    expect(
      wrapper.vm.form.customFieldDefinitions
        .slice()
        .sort((a, b) => a.layoutPosition - b.layoutPosition)
        .map(definition => definition.key)
    ).toEqual(['segundo', 'primeiro']);
  });

  it('moves between field tabs with the arrow keys', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    const details = wrapper.find(
      '[data-testid="kanban-settings-section-tab-details"]'
    );
    const marketing = wrapper.find(
      '[data-testid="kanban-settings-section-tab-marketing"]'
    );

    // Roving tabindex: o grupo de abas é um só ponto de tabulação.
    expect(details.attributes('tabindex')).toBe('0');
    expect(marketing.attributes('tabindex')).toBe('-1');
    expect(details.attributes('aria-controls')).toBe(
      'kanban-field-tabpanel-details'
    );

    await details.trigger('keydown', { key: 'ArrowRight' });

    expect(wrapper.vm.activeFieldSectionKey).toBe('marketing');
    expect(
      wrapper
        .find('[data-testid="kanban-settings-section-tab-marketing"]')
        .attributes('aria-selected')
    ).toBe('true');

    await wrapper
      .find('[data-testid="kanban-settings-section-tab-marketing"]')
      .trigger('keydown', { key: 'Home' });

    expect(wrapper.vm.activeFieldSectionKey).toBe('details');
  });

  it('moves several fields to another tab in one go', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            { key: 'um', label: 'Um', field_type: 'text' },
            { key: 'dois', label: 'Dois', field_type: 'text' },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    // Sem seleção não há barra de ações: só aparece quando há o que fazer.
    expect(
      wrapper.find('[data-testid="kanban-settings-bulk-actions"]').exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-settings-select-all-fields"]')
      .setValue(true);
    expect(
      wrapper.find('[data-testid="kanban-settings-bulk-actions"]').exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-settings-bulk-target"]')
      .setValue('marketing');

    expect(
      wrapper.vm.form.customFieldDefinitions.map(
        definition => definition.layoutSection
      )
    ).toEqual(['marketing', 'marketing']);
    expect(
      wrapper.find('[data-testid="kanban-settings-bulk-actions"]').exists()
    ).toBe(false);
  });

  it('asks before removing a batch of fields', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            { key: 'um', label: 'Um', field_type: 'text' },
            { key: 'dois', label: 'Dois', field_type: 'text' },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-select-field-um"]')
      .setValue(true);
    await wrapper
      .find('[data-testid="kanban-settings-bulk-remove"]')
      .trigger('click');

    // Perguntar antes: apagar vários de uma vez não pode ser um clique só.
    expect(wrapper.vm.form.customFieldDefinitions).toHaveLength(2);

    await wrapper
      .find('[data-testid="kanban-settings-confirm-bulk-remove"]')
      .trigger('click');

    expect(
      wrapper.vm.form.customFieldDefinitions.map(definition => definition.key)
    ).toEqual(['dois']);
  });

  it('tells the tab apart before a field is picked', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    const resumo = wrapper.find(
      '[data-testid="kanban-settings-field-editor-empty"]'
    );
    expect(resumo.exists()).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-settings-summary-total"]').text()
    ).toContain('1');
  });

  it('searches fields across every tab', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            {
              key: 'origem_lead',
              label: 'Origem do lead',
              field_type: 'text',
            },
            {
              key: 'data_consulta',
              label: 'Data da consulta',
              field_type: 'date',
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-field-palette-search"]')
      .setValue('consulta');

    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-search-results"]')
        .exists()
    ).toBe(true);
    expect(wrapper.find('[data-field-key="origem_lead"]').exists()).toBe(false);
    expect(wrapper.find('[data-field-key="data_consulta"]').exists()).toBe(
      true
    );

    await wrapper
      .find('[data-testid="kanban-settings-clear-field-palette-search"]')
      .trigger('click');

    expect(wrapper.find('[data-field-key="origem_lead"]').exists()).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-search-results"]')
        .exists()
    ).toBe(false);
  });

  it('shows compact group drop zones and visible stage requirements', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_sections: [
            {
              key: 'details',
              label: 'Geral',
              groups: [{ key: 'consulta', label: 'Consulta', color: 'teal' }],
            },
          ],
          custom_field_definitions: [
            {
              ...settingsPayload.custom_field_definitions[0],
              layout: { section: 'details', group: 'consulta', position: 1 },
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    expect(
      wrapper
        .find('[data-testid="kanban-settings-manage-field-groups"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-group-dropzone-consulta"]')
        .exists()
    ).toBe(true);
    await wrapper
      .find('[data-field-key="consulta_realizada"]')
      .trigger('click');

    expect(
      wrapper
        .find('[data-testid="kanban-settings-required-stage-list"]')
        .exists()
    ).toBe(true);
  });

  it('uses compact stage checkboxes for field requirements', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-field-key="consulta_realizada"]')
      .trigger('click');

    expect(
      wrapper.findAll('[data-testid="kanban-settings-required-stage"]')
    ).toHaveLength(2);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-required-stage-list"]')
        .find('.sm\\:grid-cols-2')
        .exists()
    ).toBe(true);
  });

  it('adds select options through a compact option input', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-field-key="consulta_realizada"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-custom-field-option-input"]')
      .setValue('Talvez');
    await wrapper
      .find('[data-testid="kanban-settings-add-field-option"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    expect(payload.kanban_board.custom_field_definitions[0].options).toEqual([
      'Sim',
      'Não',
      'Talvez',
    ]);
  });

  it('creates a custom opportunity tab from the field manager', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-add-field-section"]')
      .trigger('click');
    expect(
      wrapper
        .find('[data-testid="kanban-settings-new-field-section-dialog"]')
        .exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-settings-new-field-section-name"]')
      .setValue('Consulta');
    await wrapper
      .find('[data-testid="kanban-settings-create-field-section"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    expect(payload.kanban_board.custom_field_sections).toEqual([
      {
        key: 'details',
        label: 'KANBAN.SETTINGS.SALES.TABS.GENERAL',
        color: 'slate',
        groups: [],
      },
      {
        key: 'marketing',
        label: 'KANBAN.SETTINGS.SALES.TABS.MARKETING',
        color: 'slate',
        groups: [],
      },
      { key: 'consulta', label: 'Consulta', color: 'slate', groups: [] },
    ]);
  });

  it('keeps built-in opportunity tab labels localized when they were persisted in English', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_sections: [
            { key: 'details', label: 'Details', color: 'slate', groups: [] },
            {
              key: 'marketing',
              label: 'Marketing',
              color: 'slate',
              groups: [],
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-settings-section-tab-details"]').text()
    ).toContain('KANBAN.SETTINGS.SALES.TABS.GENERAL');
  });

  it('moves a custom tab directly after the general tab', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-add-field-section"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-new-field-section-name"]')
      .setValue('Consulta');
    await wrapper
      .find('[data-testid="kanban-settings-create-field-section"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-move-section-consulta-up"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    expect(
      payload.kanban_board.custom_field_sections.map(section => section.key)
    ).toEqual(['details', 'consulta', 'marketing']);
  });

  it('round-trips loaded custom fields using the API field names', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    expect(payload.kanban_board.custom_field_definitions[0]).toEqual(
      expect.objectContaining({
        key: 'consulta_realizada',
        field_type: 'select',
        required_stage_ids: [],
      })
    );
  });

  it('creates a colored group and assigns a field inside the active tab', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-manage-field-groups"]')
      .trigger('click');
    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-group-manager"]')
        .exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-settings-new-field-group-name"]')
      .setValue('Consulta');
    await wrapper
      .find('[data-testid="kanban-settings-new-field-group-color"]')
      .setValue('teal');
    await wrapper
      .find('[data-testid="kanban-settings-add-field-group"]')
      .trigger('click');
    await wrapper
      .find('[data-field-key="consulta_realizada"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-field-group"]')
      .setValue('consulta');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    expect(payload.kanban_board.custom_field_sections).toEqual([
      {
        key: 'details',
        label: 'KANBAN.SETTINGS.SALES.TABS.GENERAL',
        color: 'slate',
        groups: [{ key: 'consulta', label: 'Consulta', color: 'teal' }],
      },
      {
        key: 'marketing',
        label: 'KANBAN.SETTINGS.SALES.TABS.MARKETING',
        color: 'slate',
        groups: [],
      },
    ]);
    expect(payload.kanban_board.custom_field_definitions[0].layout.group).toBe(
      'consulta'
    );
  });

  it('renames, reorders and removes a custom tab while moving its fields', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_sections: [
            { key: 'consulta', label: 'Consulta' },
            { key: 'financeiro', label: 'Financeiro' },
          ],
          custom_field_definitions: [
            {
              key: 'procedimento',
              label: 'Procedimento',
              field_type: 'text',
              layout: { section: 'consulta', position: 1, width: 'full' },
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-tab-consulta"]')
      .trigger('click');
    expect(
      wrapper
        .find('[data-testid="kanban-settings-section-label-financeiro"]')
        .exists()
    ).toBe(false);
    await wrapper
      .find('[data-testid="kanban-settings-rename-section-consulta"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-label-consulta"]')
      .setValue('Atendimento');
    await wrapper
      .find('[data-testid="kanban-settings-section-tab-financeiro"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-move-section-financeiro-up"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-tab-consulta"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-remove-section-consulta"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-destination"]')
      .setValue('details');
    await wrapper
      .find('[data-testid="kanban-settings-confirm-remove-section"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    // Só «Geral» é reposta. Um quadro cuja configuração não tem Marketing não
    // volta a recebê-la: era isso que a mantinha fixa.
    expect(payload.kanban_board.custom_field_sections).toEqual([
      {
        key: 'details',
        label: 'KANBAN.SETTINGS.SALES.TABS.GENERAL',
        color: 'slate',
        groups: [],
      },
      { key: 'financeiro', label: 'Financeiro', color: 'slate', groups: [] },
    ]);
    expect(
      payload.kanban_board.custom_field_definitions[0].layout.section
    ).toBe('details');
  });

  it('lets the account remove the marketing tab for good', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_sections: [
            { key: 'details', label: 'Geral' },
            { key: 'marketing', label: 'Marketing' },
          ],
          custom_field_definitions: [],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-tab-marketing"]')
      .trigger('click');

    // Marketing deixa de ser built-in: ganha os mesmos controlos das outras.
    expect(
      wrapper
        .find('[data-testid="kanban-settings-remove-section-marketing"]')
        .exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-settings-remove-section-marketing"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-confirm-remove-section"]')
      .trigger('click');

    expect(
      wrapper.vm.form.customFieldSections.map(section => section.key)
    ).toEqual(['details']);
  });

  it('shows a numeric preview for a valid formula before saving', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            { key: 'base', label: 'Base', field_type: 'decimal' },
            {
              key: 'total',
              label: 'Total',
              field_type: 'formula',
              formula: 'base * 2',
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper.find('[data-field-key="total"]').trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-formula-preview-base"]')
      .setValue('150');

    expect(
      wrapper
        .find('[data-testid="kanban-settings-formula-preview-result"]')
        .text()
    ).toContain('300');
  });

  it('moves custom fields between tabs with the visual layout editor', async () => {
    const { wrapper } = await mountSettings();
    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    const detailsSection = wrapper
      .findAllComponents({ name: 'Draggable' })
      .find(
        component => component.attributes('data-section-key') === 'details'
      );
    const [field] = detailsSection.props('modelValue');

    await wrapper
      .find('[data-testid="kanban-settings-section-tab-marketing"]')
      .trigger('click');
    wrapper.vm.moveCustomFieldToSection('marketing', field, 0);
    await nextTick();
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    expect(KanbanBoardsAPI.updateSettings).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        kanban_board: expect.objectContaining({
          custom_field_definitions: expect.arrayContaining([
            expect.objectContaining({
              key: 'consulta_realizada',
              layout: expect.objectContaining({ section: 'marketing' }),
            }),
          ]),
        }),
      })
    );
  });

  it('uses the source field options as conditional values', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            {
              key: 'consulta_realizada',
              label: 'Consulta realizada?',
              field_type: 'select',
              options: ['Sim', 'Não'],
            },
            {
              key: 'motivo',
              label: 'Motivo',
              field_type: 'text',
              condition: {
                field_key: 'consulta_realizada',
                equals: 'Não',
              },
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper.find('[data-field-key="motivo"]').trigger('click');
    const row = wrapper.find(
      '[data-testid="kanban-settings-custom-field-editor"]'
    );
    const conditionField = row.find(
      '[data-testid="kanban-settings-condition-field"]'
    );
    const conditionValue = row.find(
      '[data-testid="kanban-settings-condition-value-select"]'
    );

    expect(conditionField.text()).toContain('Consulta realizada?');
    expect(conditionValue.element.value).toBe('Não');
    expect(conditionValue.text()).toContain('Sim');
    expect(conditionValue.text()).toContain('Não');
  });

  it('offers native opportunity fields as condition sources', async () => {
    const { wrapper } = await mountSettings();
    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-field-key="consulta_realizada"]')
      .trigger('click');
    const conditionField = wrapper.find(
      '[data-testid="kanban-settings-condition-field"]'
    );

    [
      'SUBJECT',
      'DESCRIPTION',
      'AMOUNT',
      'OWNER',
      'ASSIGNEE',
      'STAGE',
      'INBOX',
      'STATUS',
      'STARTS_AT',
      'DUE_AT',
      'NEXT_ACTION_TYPE',
      'NEXT_ACTION_AT',
      'NEXT_ACTION_NOTE',
      'NEXT_ACTION_COMPLETED',
      'LOST_REASON',
      'CONTACT',
      'CONVERSATION',
    ].forEach(field => {
      expect(conditionField.text()).toContain(
        `KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.${field}`
      );
    });
  });

  it('uses account agents as values for native agent conditions', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            {
              key: 'aprovacao',
              label: 'Aprovação',
              field_type: 'text',
              condition: {
                field_key: 'system_assignee_id',
                equals: '2',
              },
            },
          ],
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper.find('[data-field-key="aprovacao"]').trigger('click');
    const conditionValue = wrapper.find(
      '[data-testid="kanban-settings-condition-value-select"]'
    );
    expect(conditionValue.text()).toContain('Alice');
    expect(conditionValue.text()).toContain('Bob');
    expect(conditionValue.element.value).toBe('2');
  });

  it('suggests numeric fields by label while typing a formula', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            {
              key: 'valor_procedimento',
              label: 'Valor do procedimento',
              field_type: 'currency',
            },
            {
              key: 'valor_total',
              label: 'Valor total',
              field_type: 'formula',
              formula: '',
            },
          ],
        },
      },
    });
    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper.find('[data-field-key="valor_total"]').trigger('click');
    const row = wrapper.find(
      '[data-testid="kanban-settings-custom-field-editor"]'
    );
    const formulaInput = row.find(
      '[data-testid="kanban-settings-formula-input"]'
    );

    await formulaInput.setValue('[');
    await formulaInput.trigger('focus');

    let suggestions = row.find(
      '[data-testid="kanban-settings-formula-suggestions"]'
    );
    expect(suggestions.text()).toContain('Valor do procedimento');
    expect(suggestions.text()).toContain(
      'KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT'
    );

    await formulaInput.setValue('[v');
    suggestions = row.find(
      '[data-testid="kanban-settings-formula-suggestions"]'
    );
    expect(suggestions.text()).toContain('Valor do procedimento');

    await formulaInput.trigger('keydown', { key: 'Enter' });
    expect(formulaInput.element.value).toBe(
      '[KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT] '
    );
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');
    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    expect(
      payload.kanban_board.custom_field_definitions.find(
        definition => definition.key === 'valor_total'
      ).formula
    ).toBe('system_amount ');
  });

  it('suggests only earlier calculated fields in a formula', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          custom_field_definitions: [
            {
              key: 'base',
              label: 'Base',
              field_type: 'currency',
            },
            {
              key: 'subtotal',
              label: 'Subtotal',
              field_type: 'formula',
              formula: 'base * 2',
            },
            {
              key: 'total',
              label: 'Total',
              field_type: 'formula',
              formula: '',
            },
            {
              key: 'projecao',
              label: 'Projeção',
              field_type: 'formula',
              formula: 'total * 2',
            },
          ],
        },
      },
    });
    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper.find('[data-field-key="total"]').trigger('click');
    const formulaInput = wrapper.find(
      '[data-testid="kanban-settings-formula-input"]'
    );

    await formulaInput.setValue('[');
    await formulaInput.trigger('focus');

    const suggestions = wrapper.find(
      '[data-testid="kanban-settings-formula-suggestions"]'
    );
    expect(suggestions.text()).toContain('Subtotal');
    expect(suggestions.text()).not.toContain('Projeção');
  });

  it('opens import modal when enabling auto-create', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          auto_create_cards_from_conversations: false,
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-auto-create"]')
      .setValue(true);
    await flushPromises();

    expect(KanbanBoardsAPI.updateSettings).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        kanban_board: expect.objectContaining({
          auto_create_cards_from_conversations: true,
        }),
      })
    );
    expect(
      wrapper
        .find('[data-testid="kanban-import-existing-conversations-modal"]')
        .exists()
    ).toBe(true);
    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.IMPORT_EXISTING'
    );
    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.IGNORE_GROUPS'
    );
  });

  it('closes import modal without calling import when skipping', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          auto_create_cards_from_conversations: false,
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-auto-create"]')
      .setValue(true);
    await flushPromises();
    await wrapper.find('[data-testid="kanban-import-skip"]').trigger('click');

    expect(KanbanBoardsAPI.importExistingConversations).not.toHaveBeenCalled();
    expect(
      wrapper
        .find('[data-testid="kanban-import-existing-conversations-modal"]')
        .exists()
    ).toBe(false);
  });

  it('imports existing conversations with ignore_groups', async () => {
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          auto_create_cards_from_conversations: false,
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-auto-create"]')
      .setValue(true);
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-import-ignore-groups"]')
      .setValue();
    await wrapper
      .find('[data-testid="kanban-import-existing-conversations"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.importExistingConversations).toHaveBeenCalledWith(
      10,
      { ignore_groups: true }
    );
    expect(useAlert).toHaveBeenCalledWith(
      'KANBAN.SETTINGS.AUTOMATIONS.IMPORT_SUCCESS'
    );
    expect(
      wrapper
        .find('[data-testid="kanban-import-existing-conversations-modal"]')
        .exists()
    ).toBe(false);
  });

  it('keeps import modal open on import error', async () => {
    KanbanBoardsAPI.importExistingConversations.mockRejectedValueOnce(
      new Error('Failed')
    );
    const { wrapper } = await mountSettings({
      getSettingsResponse: {
        data: {
          ...settingsPayload,
          auto_create_cards_from_conversations: false,
        },
      },
    });

    await wrapper
      .find('[data-testid="kanban-settings-auto-create"]')
      .setValue(true);
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-import-existing-conversations"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-testid="kanban-import-error"]').exists()).toBe(
      true
    );
    expect(
      wrapper
        .find('[data-testid="kanban-import-existing-conversations-modal"]')
        .exists()
    ).toBe(true);
  });

  it('has pt_BR automation import translations', () => {
    expect(ptBRKanbanMessages.KANBAN.SETTINGS.AUTOMATIONS).toMatchObject({
      TITLE: 'Automações',
      AUTO_CREATE: 'Criar cartões automaticamente para novas conversas',
      IMPORT_EXISTING: 'Importar conversas existentes',
      IGNORE_GROUPS: 'Ignorar grupos',
      SKIP_IMPORT: 'Não importar agora',
    });
    expect(
      ptBRKanbanMessages.KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY
    ).toMatchObject({
      TITLE: 'Mensagens de aniversário',
      PT_BR: 'Português (Brasil)',
      PT_PT: 'Português (Portugal)',
    });
  });

  it('saves the expected payload', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .findAll('[data-testid="tag-select-update"]')[0]
      .trigger('click');
    await wrapper
      .findAll('[data-testid="tag-select-update"]')[1]
      .trigger('click');
    await wrapper.find('[data-testid="kanban-settings-name"]').setValue('Novo');
    await wrapper
      .find('[data-testid="kanban-settings-description"]')
      .setValue('Funil novo');
    await wrapper
      .find('[data-testid="kanban-settings-next-action-types"]')
      .setValue('Enviar proposta\nEnviar link de pagamento\nEnviar proposta');
    await wrapper
      .find('[data-testid="kanban-settings-lost-reason-options"]')
      .setValue('Preço\n\nFechou com outro');
    await wrapper
      .find('[data-testid="kanban-settings-nav-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-custom-fields"]')
      .setValue(
        JSON.stringify([
          {
            key: 'valor_procedimento',
            label: 'Valor do procedimento',
            field_type: 'decimal',
          },
        ])
      );
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    expect(KanbanBoardsAPI.updateSettings).toHaveBeenCalledWith(10, {
      kanban_board: {
        name: 'Novo',
        description: 'Funil novo',
        auto_create_cards_from_conversations: true,
        visibility_mode: 'selected_agents',
        visible_user_ids: [1, 2],
        inbox_scope_mode: 'selected_inboxes',
        allowed_inbox_ids: [5, 6],
        next_action_types: [
          'Enviar proposta',
          'Enviar link de pagamento',
          'Enviar proposta',
        ],
        lost_reason_options: ['Preço', 'Fechou com outro'],
        custom_field_definitions: [
          expect.objectContaining({
            key: 'valor_procedimento',
            label: 'Valor do procedimento',
            field_type: 'decimal',
            options: [],
            required_stage_ids: [],
            condition: {},
            formula: null,
            formula_result_type: null,
            important: false,
            layout: {},
          }),
        ],
        custom_field_sections: [
          {
            key: 'details',
            label: 'KANBAN.SETTINGS.SALES.TABS.GENERAL',
            color: 'slate',
            groups: [],
          },
          {
            key: 'marketing',
            label: 'KANBAN.SETTINGS.SALES.TABS.MARKETING',
            color: 'slate',
            groups: [],
          },
        ],
        compact_card_field_keys: [],
        stale_stage_thresholds: { 100: 3 },
        appointment_reminder_hours: null,
        calendar_enabled: false,
        calendar_booking_stage_ids: [],
        calendar_procedure_ids: [],
        calendar_legacy_next_appointment_field_key: null,
      },
    });
  });

  it('configures the appointment reminder lead time', async () => {
    const { wrapper } = await mountSettings();

    expect(
      wrapper
        .find('[data-testid="kanban-settings-appointment-reminder-hours"]')
        .exists()
    ).toBe(false);
    await wrapper
      .find('[data-testid="kanban-settings-toggle-internal-reminder"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-appointment-reminder-hours"]')
      .setValue('12');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    expect(KanbanBoardsAPI.updateSettings).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        kanban_board: expect.objectContaining({
          appointment_reminder_hours: 12,
        }),
      })
    );
  });

  it('saves a distinct message for each appointment reminder offset', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-appointment-stage"]')
      .setValue('100');
    await wrapper
      .find('[data-testid="kanban-settings-appointment-offsets"]')
      .setValue('48, 24');
    await wrapper
      .find('[data-testid="kanban-settings-appointment-message-48"]')
      .setValue('Faltam dois dias para sua consulta, {{contact_name}}.');
    await wrapper
      .find('[data-testid="kanban-settings-appointment-message-24"]')
      .setValue('Sua consulta e amanha, {{contact_name}}.');
    await wrapper
      .find('[data-testid="kanban-settings-save-appointment-reminder"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createAppointmentReminderRule).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        appointment_reminder_rule: expect.objectContaining({
          offsets: [48, 24],
          message_templates: {
            48: 'Faltam dois dias para sua consulta, {{contact_name}}.',
            24: 'Sua consulta e amanha, {{contact_name}}.',
          },
        }),
      })
    );
  });

  it('preserves the filled form after save error', async () => {
    KanbanBoardsAPI.updateSettings.mockRejectedValueOnce(new Error('Failed'));
    const { wrapper } = await mountSettings();

    await wrapper.find('[data-testid="kanban-settings-name"]').setValue('Novo');
    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="kanban-settings-name"]').element.value
    ).toBe('Novo');
    expect(
      wrapper.find('[data-testid="kanban-settings-save-error"]').exists()
    ).toBe(true);
  });

  it('refreshes boards after saving', async () => {
    const { wrapper, dispatch } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('kanbanBoards/refreshBoards');
    expect(useAlert).toHaveBeenCalledWith('KANBAN.SETTINGS.SAVE_SUCCESS');
    expect(mockReplace).toHaveBeenCalledWith({
      name: 'kanban_board_show',
      params: { accountId: '1', boardId: 10 },
    });
  });

  it('has pt_BR sales settings translations', () => {
    expect(ptBRKanbanMessages.KANBAN.SETTINGS.SALES).toMatchObject({
      CONDITION_FIELD: 'Mostrar quando',
      CONDITION_VALUE: 'For igual a',
      FORMULA: 'Fórmula',
      STALE_ALERTS: 'Alertas de oportunidade parada',
      SYSTEM_FIELDS: {
        AMOUNT: 'Valor da oportunidade',
        OWNER: 'Responsável comercial',
        ASSIGNEE: 'Agente da conversa',
      },
    });
  });

  it('deletes the board and navigates to overview', async () => {
    const { wrapper, dispatch } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-delete"]')
      .trigger('click');
    await wrapper.find('[data-testid="confirm-delete"]').trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.delete).toHaveBeenCalledWith(10);
    expect(dispatch).toHaveBeenCalledWith('kanbanBoards/refreshBoards');
    expect(mockReplace).toHaveBeenCalledWith({
      name: 'kanban_boards',
      params: { accountId: '1' },
    });
    expect(mockReplace.mock.invocationCallOrder[0]).toBeLessThan(
      dispatch.mock.invocationCallOrder.find(
        (_, index) =>
          dispatch.mock.calls[index][0] === 'kanbanBoards/refreshBoards'
      )
    );
  });

  it('keeps the archive success when refreshing the board list fails', async () => {
    const { wrapper } = await mountSettings();
    wrapper.vm.$store.dispatch = vi.fn(type => {
      if (type === 'kanbanBoards/refreshBoards') {
        return Promise.reject(new Error('Board list unavailable'));
      }

      return Promise.resolve();
    });

    await wrapper
      .find('[data-testid="kanban-settings-delete"]')
      .trigger('click');
    await wrapper.find('[data-testid="confirm-delete"]').trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.delete).toHaveBeenCalledWith(10);
    expect(mockReplace).toHaveBeenCalledWith({
      name: 'kanban_boards',
      params: { accountId: '1' },
    });
    expect(useAlert).toHaveBeenCalledWith(
      'KANBAN.ACTIONS.REMOVE_BOARD_SUCCESS'
    );
  });

  it('does not show an editable form for agents', async () => {
    const { wrapper } = await mountSettings({
      role: 'agent',
      getSettingsError: {
        response: { status: 401, data: { error: 'Unauthorized' } },
      },
    });

    expect(wrapper.find('[data-testid="kanban-settings-form"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-testid="kanban-settings-error"]').exists()).toBe(
      true
    );
  });
});
