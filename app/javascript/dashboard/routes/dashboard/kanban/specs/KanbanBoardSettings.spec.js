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

vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: {
      accountId: '1',
      boardId: '10',
    },
  }),
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getSettings: vi.fn(),
    showBoard: vi.fn(),
    updateSettings: vi.fn(),
    delete: vi.fn(),
    createStage: vi.fn(),
    updateStage: vi.fn(),
    reorderStage: vi.fn(),
    importExistingConversations: vi.fn(),
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
    { id: 100, name: 'Lead', color: 'blue', position: 1, cards_count: 3 },
    { id: 200, name: 'Won', color: 'green', position: 2, cards_count: 0 },
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

  const { store, dispatch } = createTestStore(role);
  const wrapper = shallowMount(KanbanBoardSettings, {
    global: {
      plugins: [store],
      stubs: {
        Button: {
          props: ['label', 'isLoading'],
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
    KanbanBoardsAPI.delete.mockResolvedValue({ data: {} });
    KanbanBoardsAPI.createStage.mockResolvedValue({
      data: { id: 300, name: 'Follow up', color: 'slate', position: 3 },
    });
    KanbanBoardsAPI.updateStage.mockResolvedValue({ data: {} });
    KanbanBoardsAPI.reorderStage.mockResolvedValue({ data: {} });
    KanbanBoardsAPI.importExistingConversations.mockResolvedValue({
      data: { status: 'accepted', enqueued: true, estimated_count: 3 },
    });
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

  it('configures the commercial category and capacity alert for a stage', async () => {
    KanbanBoardsAPI.updateStage.mockResolvedValue({ data: {} });
    const { wrapper } = await mountSettings();
    const row = wrapper.find('[data-testid="kanban-settings-stage-row"]');

    await row
      .find('[data-testid="kanban-settings-stage-category"]')
      .setValue('won');
    await row
      .find('[data-testid="kanban-settings-stage-wip-limit"]')
      .setValue('8');
    await row
      .find('[data-testid="kanban-settings-save-stage-rules"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateStage).toHaveBeenCalledWith(10, 100, {
      stage: { category: 'won', wip_limit: 8 },
    });
  });

  it('creates a new stage from settings', async () => {
    const { wrapper, dispatch } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-create-stage-toggle"]')
      .trigger('click');
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
        color: 'slate',
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
      wrapper.findAll('[data-testid="kanban-settings-custom-field-row"]')
    ).toHaveLength(0);
    await wrapper
      .find('[data-testid="kanban-settings-add-custom-field"]')
      .trigger('click');

    const row = wrapper.find(
      '[data-testid="kanban-settings-custom-field-row"]'
    );
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

  it('keeps the custom field row mounted while deriving its key from the label', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-add-custom-field"]')
      .trigger('click');

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
      .find('[data-testid="kanban-settings-add-marketing-fields"]')
      .trigger('click');
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');

    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-list-item-gbraid"]')
        .exists()
    ).toBe(false);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-list-item-campaign"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-field-list-item-utm_source"]')
        .exists()
    ).toBe(true);
  });

  it('exposes a draggable field palette and a tab-local add action', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');

    expect(
      wrapper
        .find(
          '[data-testid="kanban-settings-field-list-item-consulta_realizada"]'
        )
        .attributes('draggable')
    ).toBe('true');
    expect(
      wrapper
        .find('[data-testid="kanban-settings-add-field-to-active-section"]')
        .exists()
    ).toBe(true);
  });

  it('uses compact stage checkboxes for field requirements', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');

    expect(
      wrapper.findAll('[data-testid="kanban-settings-required-stage"]')
    ).toHaveLength(2);
    expect(
      wrapper
        .find('[data-testid="kanban-settings-required-stage-list"]')
        .classes()
    ).toContain('grid-cols-2');
  });

  it('adds select options through a compact option input', async () => {
    const { wrapper } = await mountSettings();

    await wrapper
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
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
      .find('[data-testid="kanban-settings-form"]')
      .trigger('submit');

    const payload = KanbanBoardsAPI.updateSettings.mock.calls.at(-1)[1];
    expect(payload.kanban_board.custom_field_sections).toEqual([
      { key: 'consulta', label: 'Consulta' },
    ]);
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-rename-section-consulta"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-section-label-consulta"]')
      .setValue('Atendimento');
    await wrapper
      .find('[data-testid="kanban-settings-move-section-financeiro-up"]')
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
    expect(payload.kanban_board.custom_field_sections).toEqual([
      { key: 'financeiro', label: 'Financeiro' },
    ]);
    expect(
      payload.kanban_board.custom_field_definitions[0].layout.section
    ).toBe('details');
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');
    const rows = wrapper.findAll(
      '[data-testid="kanban-settings-custom-field-row"]'
    );
    await rows[1].trigger('click');
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-field-list-item-motivo"]')
      .trigger('click');
    const row = wrapper.find(
      '[data-testid="kanban-settings-custom-field-row"]'
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-field-list-item-valor_total"]')
      .trigger('click');
    const row = wrapper.find(
      '[data-testid="kanban-settings-custom-field-row"]'
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-settings-field-list-item-total"]')
      .trigger('click');
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
      .find('[data-testid="kanban-settings-manage-custom-fields"]')
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
          {
            key: 'valor_procedimento',
            label: 'Valor do procedimento',
            field_type: 'decimal',
          },
        ],
        custom_field_sections: [],
        compact_card_field_keys: [],
        stale_stage_thresholds: { 100: 3 },
      },
    });
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
      ADD_CUSTOM_FIELD: 'Adicionar campo',
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
