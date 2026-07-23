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
    ).toHaveLength(5);
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

  it('offers active follow-up cadences to the cadence action node', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        cadences: [
          { id: 1, name: 'Contato inicial', active: true },
          { id: 2, name: 'Legada', active: false },
        ],
        modelValue: {
          nodes: [
            {
              id: 'cadence',
              type: 'action',
              data: {
                action_name: 'enroll_cadence',
                action_params: { cadence_id: '' },
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.text()).toContain('Contato inicial');
    expect(wrapper.text()).not.toContain('Legada');
  });
});
