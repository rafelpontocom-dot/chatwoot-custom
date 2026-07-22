import { mount } from '@vue/test-utils';
import KanbanActivityCenter from '../KanbanActivityCenter.vue';
import KanbanListView from '../KanbanListView.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      Object.entries(params).reduce(
        (message, [name, value]) => message.replace(`{${name}}`, value),
        key
      ),
  }),
}));

const card = {
  id: 10,
  subject: 'Nova oportunidade',
  amountCents: 150000,
  amountCurrency: 'BRL',
  contact: { name: 'Maria' },
  owner: { name: 'Ana' },
  nextActionType: 'Follow-up',
  nextActionAt: new Date(Date.now() + 86400000).toISOString(),
};

const stages = [{ id: 1, name: 'Novo lead', cards: [card] }];

describe('Kanban work views', () => {
  it('renders a comparable list row and emits the existing card actions', async () => {
    const wrapper = mount(KanbanListView, {
      props: { stages, selectedCardIds: [] },
    });

    expect(wrapper.find('[data-testid="kanban-list-row-10"]').exists()).toBe(
      true
    );
    await wrapper
      .find('[data-testid="kanban-list-row-10"] button')
      .trigger('click');
    expect(wrapper.emitted('openDetails')).toHaveLength(1);
  });

  it('shows no-next-action work in the activity center', async () => {
    const wrapper = mount(KanbanActivityCenter, {
      props: {
        stages: [
          {
            id: 1,
            name: 'Novo lead',
            cards: [{ ...card, nextActionAt: null, nextActionType: null }],
          },
        ],
      },
    });

    await wrapper
      .find('[data-testid="kanban-activity-tab-missing"]')
      .trigger('click');
    expect(
      wrapper.find('[data-testid="kanban-activity-card-10"]').exists()
    ).toBe(true);
  });
});
