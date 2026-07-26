import { mount } from '@vue/test-utils';
import KanbanWorkflowInspectorTabs from '../components/KanbanWorkflowInspectorTabs.vue';

describe('KanbanWorkflowInspectorTabs', () => {
  const mountTabs = activeTab =>
    mount(KanbanWorkflowInspectorTabs, {
      props: {
        tabs: ['configure', 'test', 'history'],
        activeTab,
        label: 'Inspector tabs',
        tabLabel: tab => tab,
        tabIcon: () => 'i-lucide-circle',
      },
    });

  it('exposes semantic tabs and updates the selected context', async () => {
    const wrapper = mountTabs('configure');
    const testTab = wrapper.find(
      '[data-testid="kanban-workflow-inspector-tab-test"]'
    );

    expect(testTab.attributes('aria-selected')).toBe('false');
    await testTab.trigger('click');

    expect(wrapper.emitted('update:activeTab')).toEqual([['test']]);
  });

  it('forwards keyboard navigation to the inspector controller', async () => {
    const wrapper = mountTabs('configure');

    await wrapper
      .find('[data-testid="kanban-workflow-inspector-tab-configure"]')
      .trigger('keydown', { key: 'ArrowRight' });

    expect(wrapper.emitted('keydown')).toHaveLength(1);
    expect(wrapper.emitted('keydown')[0][1]).toBe('configure');
  });
});
