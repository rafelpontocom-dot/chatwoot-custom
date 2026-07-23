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
    ).toHaveLength(7);
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
});
