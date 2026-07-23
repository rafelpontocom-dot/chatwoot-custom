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

  it('selects and removes a connection from the inspector', () => {
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

    wrapper.vm.onEdgeClick({ edge: { id: 'trigger-end' } });
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

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ARCHIVE_CARD'
    );
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
});
