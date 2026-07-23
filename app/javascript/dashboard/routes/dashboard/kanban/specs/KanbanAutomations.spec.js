import { flushPromises, shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import KanbanAutomations from '../KanbanAutomations.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

const mockPush = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1', boardId: '10' } }),
  useRouter: () => ({ push: mockPush }),
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getSettings: vi.fn(),
    getAutomationRules: vi.fn(),
    createAutomationRule: vi.fn(),
    updateAutomationRule: vi.fn(),
    deleteAutomationRule: vi.fn(),
    getCadences: vi.fn(),
    getAppointmentReminderRules: vi.fn(),
  },
}));

const mountWorkspace = async () => {
  KanbanBoardsAPI.getSettings.mockResolvedValue({
    data: { stages: [], custom_field_definitions: [], next_action_types: [] },
  });
  KanbanBoardsAPI.getAutomationRules.mockResolvedValue({ data: [] });
  KanbanBoardsAPI.getCadences.mockResolvedValue({ data: [] });
  KanbanBoardsAPI.getAppointmentReminderRules.mockResolvedValue({ data: [] });

  const store = createStore({
    modules: {
      agents: { namespaced: true, getters: { getAgents: () => [] } },
    },
  });
  const wrapper = shallowMount(KanbanAutomations, {
    global: {
      plugins: [store],
      stubs: { RouterLink: true },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('KanbanAutomations', () => {
  beforeEach(() => vi.clearAllMocks());

  it('starts in the flows workspace and opens a dedicated visual editor', async () => {
    const wrapper = await mountWorkspace();

    expect(
      wrapper.find('[data-testid="kanban-automations-workspace"]').exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-automations-new-flow"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-automation-editor"]').exists()
    ).toBe(true);
    expect(wrapper.find('kanban-workflow-builder-stub').exists()).toBe(true);
  });
});
