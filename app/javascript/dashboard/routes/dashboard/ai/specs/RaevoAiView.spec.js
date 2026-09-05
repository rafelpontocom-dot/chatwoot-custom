import { flushPromises, shallowMount } from '@vue/test-utils';
import RaevoAiView from '../RaevoAiView.vue';
import { routes } from '../routes';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import RaevoAiAPI from 'dashboard/api/raevoAi';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

const adminMocks = vi.hoisted(() => ({ isAdmin: false }));

vi.mock('dashboard/api/raevoAi', () => ({
  default: {
    get: vi.fn(),
    getOpportunityTab: vi.fn(),
    updateOpportunityTab: vi.fn(),
  },
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: { getBoards: vi.fn() },
}));

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: { value: adminMocks.isAdmin } }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountView = () =>
  shallowMount(RaevoAiView, {
    global: {
      stubs: {
        RaevoPageHeader: {
          template: '<header><slot name="actions" /><slot /></header>',
        },
        RaevoField: {
          template:
            '<div><slot control-class="control" field-id="ai-tab-board-ids" /></div>',
        },
        NextButton: {
          emits: ['click'],
          template:
            '<button v-bind="$attrs" type="button" @click="$emit(\'click\')"><slot /></button>',
        },
        RaevoStamp: true,
      },
    },
  });

describe('RaevoAiView', () => {
  beforeEach(() => {
    adminMocks.isAdmin = false;
    RaevoAiAPI.get.mockResolvedValue({ data: {} });
    RaevoAiAPI.getOpportunityTab.mockResolvedValue({
      data: { enabled: false, board_ids: [] },
    });
    KanbanBoardsAPI.getBoards.mockResolvedValue({ data: [] });
  });

  it('presents the three supported Elis service packages', () => {
    const wrapper = mountView();

    expect(wrapper.findAll('[data-testid="ai-service-package"]')).toHaveLength(
      3
    );
    expect(wrapper.text()).toContain('RAEVO_AI.PACKAGES.QUALIFY_HANDOFF.TITLE');
    expect(wrapper.text()).toContain('RAEVO_AI.PACKAGES.SCHEDULE.TITLE');
    expect(wrapper.text()).toContain('RAEVO_AI.PACKAGES.COMPLETE.TITLE');
  });

  it('does not embed the legacy customer panel', () => {
    const wrapper = mountView();

    expect(wrapper.find('iframe').exists()).toBe(false);
  });

  it('keeps the native area behind the Raevo AI account feature', () => {
    expect(FEATURE_FLAGS.RAEVO_AI).toBe('raevo_ai');
    expect(routes[0].meta.featureFlag).toBe(FEATURE_FLAGS.RAEVO_AI);
    expect(routes[0].path).toContain('/raevo-ai');
  });

  it('loads the account overview through the Chatwoot BFF', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        status: 'active',
        clinic_name: 'Dra. Anna Alice',
        package: 'complete',
        active_prompt_version: 12,
        knowledge_count: 8,
        open_reviews: 2,
        usage_30d: {
          conversations: 44,
          handoffs: 5,
          appointments: 9,
          payments: 3,
        },
      },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(RaevoAiAPI.get).toHaveBeenCalledOnce();
    expect(wrapper.get('[data-testid="ai-overview"]').text()).toContain(
      'Dra. Anna Alice'
    );
    expect(wrapper.text()).toContain('44');
    expect(wrapper.text()).toContain('12');
  });

  it('shows a safe error and retries the overview request', async () => {
    RaevoAiAPI.get
      .mockRejectedValueOnce(new Error('upstream detail must not render'))
      .mockResolvedValueOnce({ data: { clinic_name: 'Dra. Anna Alice' } });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.get('[data-testid="ai-overview-error"]').text()).toContain(
      'RAEVO_AI.OVERVIEW.ERROR.DESCRIPTION'
    );
    expect(wrapper.text()).not.toContain('upstream detail must not render');

    await wrapper.get('[data-testid="ai-overview-retry"]').trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.get).toHaveBeenCalledTimes(2);
    expect(wrapper.get('[data-testid="ai-overview"]').text()).toContain(
      'Dra. Anna Alice'
    );
  });

  it('lets an administrator configure the CRM boards that expose the IA tab', async () => {
    adminMocks.isAdmin = true;
    RaevoAiAPI.getOpportunityTab.mockResolvedValue({
      data: { enabled: false, board_ids: [] },
    });
    KanbanBoardsAPI.getBoards.mockResolvedValue({
      data: [{ id: 14, name: 'Captação' }],
    });
    RaevoAiAPI.updateOpportunityTab.mockResolvedValue({
      data: { enabled: true, board_ids: [14] },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="ai-opportunity-tab-configuration"]').exists()
    ).toBe(true);
    await wrapper.find('select[multiple]').setValue(['14']);
    await wrapper.find('input[type="checkbox"]').setValue(true);
    await wrapper
      .find('[data-testid="ai-opportunity-tab-save"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.updateOpportunityTab).toHaveBeenCalledWith({
      enabled: true,
      board_ids: [14],
    });
  });
});
