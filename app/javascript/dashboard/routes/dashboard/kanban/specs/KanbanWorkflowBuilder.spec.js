import { shallowMount } from '@vue/test-utils';
import KanbanWorkflowBuilder from '../components/KanbanWorkflowBuilder.vue';

const translations = {
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE':
    'Fuso do horario silencioso',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAME':
    'Template oficial do WhatsApp',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_LANGUAGE':
    'Idioma do template',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_CATEGORY':
    'Categoria do template',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAMESPACE':
    'Namespace do template',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.FREQUENCY_LIMIT':
    'Intervalo minimo entre mensagens (horas)',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_START': 'Nao enviar depois de',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_END': 'Voltar a enviar as',
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => translations[key] || key }),
}));

describe('KanbanWorkflowBuilder', () => {
  it('renders the visual canvas and opens a compact node add menu', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    expect(
      wrapper.find('[data-testid="kanban-workflow-builder"]').exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-workflow-add-node"]')
      .trigger('click');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-menu"]').exists()
    ).toBe(true);
    expect(
      wrapper.findAll('[data-testid="kanban-workflow-node-menu"] button')
    ).toHaveLength(10);
  });

  it('keeps the add control inside a full-height visual canvas', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    const canvas = wrapper.find('[data-testid="kanban-workflow-canvas"]');

    expect(canvas.exists()).toBe(true);
    expect(canvas.classes()).toContain('h-full');
    expect(
      canvas.find('[data-testid="kanban-workflow-add-node"]').exists()
    ).toBe(true);
    expect(wrapper.text()).not.toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TITLE'
    );
  });

  it('starts with a valid trigger-to-end flow instead of an incomplete message', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    expect(wrapper.vm.nodes.map(node => node.type)).toEqual(['trigger', 'end']);
    expect(wrapper.vm.edges).toEqual([
      expect.objectContaining({ source: 'trigger', target: 'end' }),
    ]);
  });

  it('keeps the trigger inspector closed until the user selects a node', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').exists()
    ).toBe(false);
  });

  it('lets the user choose the rule trigger from the trigger node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {},
        triggerValue: 'kanban.card.stage_changed',
        triggerOptions: [
          {
            value: 'kanban.card.stage_changed',
            label: 'Stage changed',
          },
          { value: 'kanban.card.won', label: 'Card won' },
        ],
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-trigger-select"]')
      .setValue('kanban.card.won');

    expect(wrapper.emitted('update:triggerValue')).toEqual([
      ['kanban.card.won'],
    ]);
  });

  it('keeps the newly added node selected after the parent syncs the flow', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    wrapper.vm.addNodeOfType('send_message');
    await wrapper.vm.$nextTick();
    const emittedFlow = wrapper.emitted('update:modelValue').at(-1)[0];
    await wrapper.setProps({ modelValue: emittedFlow });

    expect(wrapper.vm.selectedNode.type).toBe('send_message');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').text()
    ).toContain('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE');
  });

  it('opens a connection pop-up and removes the selected connection', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'trigger', type: 'trigger', data: {} },
            { id: 'end', type: 'end', data: {} },
          ],
          edges: [{ id: 'trigger-end', source: 'trigger', target: 'end' }],
        },
      },
    });

    await wrapper.vm.onEdgeClick({ edge: { id: 'trigger-end' } });

    expect(
      wrapper.find('[data-testid="kanban-workflow-connection-dialog"]').exists()
    ).toBe(true);
    wrapper.vm.removeSelectedEdge();

    expect(wrapper.vm.edges).toEqual([]);
  });

  it('renders the action inspector for a selected node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: { action_name: 'archive_card' },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').exists()
    ).toBe(true);
    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ARCHIVE_CARD'
    );
  });

  it('focuses the invalid step so its configuration can be corrected', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'trigger', type: 'trigger', data: {} },
            {
              id: 'message',
              type: 'send_message',
              data: { content: '', opt_in_attribute_key: '' },
            },
          ],
          edges: [
            { id: 'trigger-message', source: 'trigger', target: 'message' },
          ],
        },
        invalidNodeIds: ['message'],
      },
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.vm.selectedNode.id).toBe('message');
    expect(wrapper.vm.selectedNode.data.invalid).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').exists()
    ).toBe(true);
  });

  it('closes the configuration drawer with Escape', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [{ id: 'trigger', type: 'trigger', data: {} }],
          edges: [],
        },
      },
    });
    const preventDefault = vi.fn();

    wrapper.vm.handleInspectorKeydown({ key: 'Escape', preventDefault });

    expect(preventDefault).toHaveBeenCalled();
    expect(wrapper.vm.selectedNode).toBeUndefined();
  });

  it('inserts emoji and opportunity variables in a message node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Olá ',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                quiet_hours: {},
                whatsapp_template_params: {},
              },
            },
          ],
          edges: [],
        },
        customFields: [{ key: 'origem', label: 'Origem', fieldType: 'text' }],
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="kanban-message-emoji-button"]').exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-message-variable-button"]')
      .trigger('click');
    expect(wrapper.text()).toContain('Origem');

    wrapper.vm.insertMessageText('{{field.origem}}');

    expect(wrapper.vm.selectedNode.data.content).toContain('{{field.origem}}');
  });

  it('does not expose the legacy cadence action in the visual builder', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: {
                action_name: 'set_next_action',
                action_params: {},
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.text()).not.toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ENROLL_CADENCE'
    );
  });

  it('offers business hours for commercial follow-ups', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    await wrapper
      .find('[data-testid="kanban-workflow-add-node"]')
      .trigger('click');

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.BUSINESS_HOURS'
    );
  });

  it('offers a field increment action for commercial follow-ups', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: { action_name: 'increment_field', action_params: {} },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.INCREMENT_FIELD'
    );
  });

  it('offers a dedicated node for updating an opportunity field', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    await wrapper
      .find('[data-testid="kanban-workflow-add-node"]')
      .trigger('click');

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.SET_FIELD'
    );
  });

  it('opens field selection directly from the dedicated update-field node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        customFields: [
          { key: 'origem', label: 'Origem', fieldType: 'select', options: [] },
        ],
        modelValue: {
          nodes: [
            {
              id: 'set-field',
              type: 'set_field',
              data: { action_params: { field_key: '', value: '' } },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD'
    );
  });

  it('offers selection values when a field-update action targets a select field', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        customFields: [
          {
            key: 'origem',
            label: 'Origem',
            fieldType: 'select',
            options: ['Orgânico', 'Mídia Paga'],
          },
        ],
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: {
                action_name: 'set_field',
                action_params: { field_key: 'origem', value: '' },
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    const valueSelect = wrapper.find(
      '[data-testid="kanban-workflow-action-field-value"]'
    );
    expect(valueSelect.element.tagName).toBe('SELECT');
    expect(valueSelect.text()).toContain('Mídia Paga');
  });

  it('edits condition rules with an AND or OR match mode', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        conditionFields: [
          { key: 'origem', label: 'Origem' },
          { key: 'valor', label: 'Valor' },
        ],
        modelValue: {
          nodes: [
            {
              id: 'condition',
              type: 'condition',
              data: {
                match_mode: 'all',
                conditions: [
                  { field_key: 'origem', operator: 'equals', value: '' },
                ],
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper
        .find('[data-testid="kanban-workflow-condition-match-mode"]')
        .exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-workflow-add-condition"]')
      .trigger('click');

    expect(
      wrapper.findAll('[data-testid="kanban-workflow-condition-row"]')
    ).toHaveLength(2);
  });

  it('adds round-robin options and keeps each option ready for a next step', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'round-robin',
              type: 'round_robin',
              data: {
                options: [
                  { id: 'first', label: 'Primeira' },
                  { id: 'second', label: 'Segunda' },
                ],
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-add-round-robin-option"]')
      .trigger('click');

    expect(wrapper.vm.selectedNode.data.options).toHaveLength(3);
    expect(wrapper.vm.selectedNode.data.options[2].label).toBe('Opção 3');
  });

  it('configures official WhatsApp templates on the message node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Olá',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                frequency_limit_hours: '',
                quiet_hours: {
                  start: '',
                  end: '',
                  timezone: 'America/Sao_Paulo',
                },
                whatsapp_template_params: {},
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Template oficial do WhatsApp');
  });

  it('uses translated message policy labels in the message node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Ola',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                quiet_hours: {
                  start: '',
                  end: '',
                  timezone: 'America/Sao_Paulo',
                },
                whatsapp_template_params: {},
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Fuso do horario silencioso');
    expect(wrapper.text()).toContain('Template oficial do WhatsApp');
    expect(wrapper.text()).not.toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE'
    );
  });

  it('does not persist an empty quiet-hours configuration on a message node', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Olá',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                quiet_hours: {
                  start: '',
                  end: '',
                  timezone: 'America/Sao_Paulo',
                },
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.emitFlow();

    expect(
      wrapper.emitted('update:modelValue').at(-1)[0].nodes[0].data
    ).not.toHaveProperty('quiet_hours');
  });
});
