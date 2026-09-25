import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
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

const mountMenu = () =>
  mount(KanbanOpportunityPipelineMenu, {
    attachTo: document.body,
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

describe('KanbanOpportunityPipelineMenu', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('expands only the current pipeline until another pipeline is selected', async () => {
    const wrapper = mountMenu();

    await wrapper
      .find('[data-testid="kanban-opportunity-pipeline-menu-trigger"]')
      .trigger('click');

    const menu = document.querySelector(
      '[data-testid="kanban-opportunity-pipeline-menu"]'
    );
    expect(menu.textContent).toContain('Qualificação');
    expect(menu.textContent).not.toContain('Ativação');

    menu.querySelectorAll('section > button')[1].click();
    await nextTick();
    expect(menu.textContent).toContain('Ativação');

    menu.querySelector('[role="menuitem"]').click();
    await nextTick();
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

  // A ficha da oportunidade também vive na coluna direita da conversa, dentro
  // de um painel que corta o que passa da borda: desenhado ali, o menu abria
  // invisível. Ele tem de sair para fora desse painel.
  it('renders the menu outside the component, so a clipped panel cannot hide it', async () => {
    const wrapper = mountMenu();

    await wrapper
      .find('[data-testid="kanban-opportunity-pipeline-menu-trigger"]')
      .trigger('click');

    const menu = document.querySelector(
      '[data-testid="kanban-opportunity-pipeline-menu"]'
    );
    expect(menu).not.toBeNull();
    expect(wrapper.element.contains(menu)).toBe(false);
    expect(menu.style.position).toBe('fixed');
  });

  // Na conversa a ficha não recebe a lista de funis; mesmo assim o menu tem de
  // oferecer as etapas do funil da oportunidade.
  it('lists the stages of the current funnel when no funnel list is given', async () => {
    const wrapper = mount(KanbanOpportunityPipelineMenu, {
      attachTo: document.body,
      props: {
        boardId: 10,
        boardName: 'Vendas',
        selectedStageId: 2,
        stages: [
          { id: 2, name: 'Qualificação', category: 'open' },
          { id: 3, name: 'Proposta', category: 'open' },
        ],
      },
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-pipeline-menu-trigger"]')
      .trigger('click');

    const menu = document.querySelector(
      '[data-testid="kanban-opportunity-pipeline-menu"]'
    );
    expect(menu.textContent).toContain('Proposta');

    menu.querySelectorAll('[role="menuitem"]')[1].click();
    await nextTick();

    expect(wrapper.emitted('selectStage')[0][0]).toMatchObject({
      boardId: 10,
      stageId: 3,
    });
  });
});
