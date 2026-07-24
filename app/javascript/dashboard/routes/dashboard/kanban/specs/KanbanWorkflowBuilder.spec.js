import { shallowMount } from '@vue/test-utils';
import KanbanWorkflowBuilder from '../components/KanbanWorkflowBuilder.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
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
    ).toHaveLength(8);
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

  it('renders the action inspector for a selected node', () => {
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

  it('offers a field increment action for commercial follow-ups', () => {
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

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.INCREMENT_FIELD'
    );
  });

  it('configures official WhatsApp templates on the message node', () => {
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

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAME'
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
