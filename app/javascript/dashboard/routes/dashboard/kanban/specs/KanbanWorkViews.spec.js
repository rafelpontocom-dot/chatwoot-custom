import { flushPromises, mount } from '@vue/test-utils';
import KanbanActivityCenter from '../KanbanActivityCenter.vue';
import KanbanListView from '../KanbanListView.vue';

import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getActivities: vi.fn(),
  },
}));

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
      props: {
        stages: [{ ...stages[0], pagination: { hasMore: true } }],
        selectedCardIds: [],
      },
    });

    expect(wrapper.find('[data-testid="kanban-list-row-10"]').exists()).toBe(
      true
    );
    await wrapper
      .find('[data-testid="kanban-list-row-10"] button')
      .trigger('click');
    expect(wrapper.emitted('openDetails')).toHaveLength(1);

    await wrapper
      .find('[data-testid="kanban-list-load-more-1"]')
      .trigger('click');
    expect(wrapper.emitted('loadMoreStageCards')).toEqual([
      [expect.objectContaining({ id: 1 })],
    ]);
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

  it('shows appointments separately from next actions', async () => {
    const wrapper = mount(KanbanActivityCenter, {
      props: {
        stages: [
          {
            id: 1,
            name: 'Novo lead',
            cards: [
              {
                ...card,
                startsAt: new Date(Date.now() + 2 * 86400000).toISOString(),
                nextActionAt: null,
                nextActionType: null,
              },
            ],
          },
        ],
      },
    });

    await wrapper
      .find('[data-testid="kanban-activity-tab-appointments"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-activity-card-10"]').exists()
    ).toBe(true);
    expect(wrapper.text()).toContain('KANBAN.ACTIVITY.APPOINTMENT');
  });

  it('loads activities from the board endpoint and paginates', async () => {
    KanbanBoardsAPI.getActivities.mockResolvedValue({
      data: {
        cards: [
          {
            id: 11,
            subject: 'Remote activity',
            stage_name: 'Proposal',
            next_action_type: 'Call back',
            next_action_at: new Date(Date.now() + 86400000).toISOString(),
          },
        ],
        pagination: { page: 1, limit: 25, has_more: true },
      },
    });

    const wrapper = mount(KanbanActivityCenter, {
      props: {
        boardId: 5,
        stages: [],
        ownerOptions: [{ value: 7, label: 'Ana Paula' }],
      },
    });
    await flushPromises();

    expect(KanbanBoardsAPI.getActivities).toHaveBeenCalledWith(5, {
      params: { view: 'today', page: 1, limit: 25 },
    });
    expect(wrapper.text()).toContain('Remote activity');
    expect(
      wrapper.find('[data-testid="kanban-activity-load-more"]').exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-activity-owner-filter"]')
      .setValue('7');
    await flushPromises();

    expect(KanbanBoardsAPI.getActivities).toHaveBeenLastCalledWith(5, {
      params: { view: 'today', page: 1, limit: 25, owner_id: '7' },
    });

    await wrapper
      .find('[data-testid="kanban-activity-owner-filter"]')
      .setValue('');
    await flushPromises();

    await wrapper
      .find('[data-testid="kanban-activity-tab-upcoming"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.getActivities).toHaveBeenLastCalledWith(5, {
      params: { view: 'upcoming', page: 1, limit: 25 },
    });
  });

  it('keeps loaded activities and exposes retry after a pagination error', async () => {
    KanbanBoardsAPI.getActivities
      .mockResolvedValueOnce({
        data: {
          cards: [{ ...card, id: 11, subject: 'Loaded activity' }],
          pagination: { page: 1, limit: 25, has_more: true },
        },
      })
      .mockRejectedValueOnce(new Error('network'))
      .mockResolvedValueOnce({
        data: {
          cards: [{ ...card, id: 12, subject: 'Retried activity' }],
          pagination: { page: 2, limit: 25, has_more: false },
        },
      });

    const wrapper = mount(KanbanActivityCenter, {
      props: { boardId: 5, stages: [] },
    });
    await flushPromises();

    await wrapper
      .find('[data-testid="kanban-activity-load-more"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-testid="kanban-activity-error"]').exists()).toBe(
      true
    );
    expect(wrapper.text()).toContain('Loaded activity');

    await wrapper
      .find('[data-testid="kanban-activity-error"] button')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('Retried activity');
    expect(wrapper.find('[data-testid="kanban-activity-error"]').exists()).toBe(
      false
    );
  });
});
