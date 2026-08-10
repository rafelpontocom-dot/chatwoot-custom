import { mount } from '@vue/test-utils';
import KanbanOpportunityPipelineMenu from '../KanbanOpportunityPipelineMenu.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      ({
        'KANBAN.OPPORTUNITY_DETAILS.DAYS_IN_STAGE': `${params.count} days`,
        'KANBAN.OPPORTUNITY_DETAILS.CURRENT_PIPELINE': 'Current',
      })[key] || key,
  }),
}));

describe('KanbanOpportunityPipelineMenu', () => {
  it('expands only the current pipeline until another pipeline is selected', async () => {
    const wrapper = mount(KanbanOpportunityPipelineMenu, {
      props: {
        boardId: 10,
        boardName: 'Vendas',
        selectedStageId: 2,
        stages: [{ id: 2, name: 'Qualificação', category: 'open' }],
        boards: [
          { id: 10, name: 'Vendas', stages_summary: [] },
          {
            id: 20,
            name: 'Pós-venda',
            stages_summary: [{ id: 21, name: 'Ativação', category: 'open' }],
          },
        ],
      },
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-pipeline-menu-trigger"]')
      .trigger('click');

    expect(wrapper.text()).toContain('Qualificação');
    expect(wrapper.text()).not.toContain('Ativação');

    await wrapper.findAll('section > button').at(1).trigger('click');
    expect(wrapper.text()).toContain('Ativação');

    await wrapper.find('[role="menuitem"]').trigger('click');
    expect(wrapper.emitted('selectStage')).toEqual([
      [
        expect.objectContaining({
          boardId: 20,
          stageId: 21,
          stage: expect.objectContaining({ category: 'open' }),
        }),
      ],
    ]);
  });
});
