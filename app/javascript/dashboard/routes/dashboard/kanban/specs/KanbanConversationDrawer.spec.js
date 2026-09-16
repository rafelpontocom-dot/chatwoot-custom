import { shallowMount } from '@vue/test-utils';
import KanbanConversationDrawer from '../KanbanConversationDrawer.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: vi.fn().mockResolvedValue(),
    getters: { getConversationById: () => ({ id: 7 }) },
  }),
}));

const mountDrawer = (props = {}) =>
  shallowMount(KanbanConversationDrawer, {
    props: { show: true, conversationId: 7, title: 'Marina Costa', ...props },
    global: {
      stubs: {
        ConversationBox: true,
        KanbanConversationOpportunity: {
          props: ['conversationId'],
          template: '<div data-testid="kanban-drawer-opportunity-stub" />',
        },
      },
    },
  });

describe('KanbanConversationDrawer', () => {
  // Pelo balão do card, a mesma dinâmica da tela de conversa: mensagens e
  // campos da oportunidade juntos, sem sair do Pipeline.
  it('shows the opportunity beside the conversation', () => {
    const wrapper = mountDrawer();

    expect(
      wrapper.find('[data-testid="kanban-drawer-opportunity"]').exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-drawer-opportunity"]')
        .find('[data-testid="kanban-drawer-opportunity-stub"]')
        .exists()
    ).toBe(true);
  });

  it('does not ask for an opportunity when the card has no conversation', () => {
    const wrapper = mountDrawer({ conversationId: null });

    expect(
      wrapper.find('[data-testid="kanban-drawer-opportunity"]').exists()
    ).toBe(false);
  });
});
