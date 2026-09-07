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

  it('owns a flexible vertical scroll container with room after the last section', () => {
    const wrapper = mountView();
    const workspace = wrapper.get('[data-testid="ai-workspace"]');

    expect(workspace.classes()).toEqual(
      expect.arrayContaining(['min-h-0', 'overflow-y-auto', 'pb-10'])
    );
    expect(workspace.classes()).not.toContain('h-full');
  });

  it('keeps the native area behind the Raevo AI account feature', () => {
    expect(FEATURE_FLAGS.RAEVO_AI).toBe('raevo_ai');
    expect(routes[0].meta.featureFlag).toBe(FEATURE_FLAGS.RAEVO_AI);
    expect(routes[0].path).toContain('/raevo-ai');
  });

  it('loads the account overview through the Chatwoot BFF', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        connection_state: 'active',
        operational_state: 'healthy',
        overview: {
          status: 'active',
          clinic_name: 'Dra. Anna Alice',
          package: 'complete',
          active_prompt_version: 12,
          knowledge_count: 8,
          open_reviews: 2,
          assistant_profile: {
            identity: 'Secretária virtual da clínica.',
            personality: 'Serena e objetiva.',
            voice_style: 'Frases curtas e linguagem simples.',
          },
          usage_30d: {
            conversations: 44,
            handoffs: 5,
            appointments: 9,
            payments: 3,
          },
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

  it('shows only the active assistant identity and voice profile returned by the BFF', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        connection_state: 'active',
        operational_state: 'healthy',
        overview: {
          clinic_name: 'Clínica Exemplo',
          assistant_profile: {
            identity: 'Secretária virtual da clínica.',
            personality: 'Serena e objetiva.',
            voice_style: 'Frases curtas e linguagem simples.',
          },
          usage_30d: {},
        },
      },
    });

    const wrapper = mountView();
    await flushPromises();

    const profile = wrapper.get('[data-testid="ai-assistant-profile"]');
    expect(profile.text()).toContain('Secretária virtual da clínica.');
    expect(profile.text()).toContain('Serena e objetiva.');
    expect(profile.text()).toContain('Frases curtas e linguagem simples.');
  });

  it('shows live token usage and separates reported from estimated cost', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        connection_state: 'active',
        operational_state: 'healthy',
        overview: {
          status: 'active',
          clinic_name: 'Dra. Anna Alice',
          usage_30d: {
            conversations: 1,
            handoffs: 0,
            appointments: 0,
            payments: 0,
            model_calls: 3,
            prompt_tokens: 1200,
            completion_tokens: 600,
            provider_reported_cost_usd: 1.25,
            catalog_estimated_cost_usd: 0.75,
            cost_unavailable_calls: 2,
          },
        },
      },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.text()).toContain('1,800');
    expect(wrapper.text()).toContain('US$ 1.25');
    expect(wrapper.text()).toContain('US$ 0.75');
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

  it('explains that Elis is being prepared when the account is not configured', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        connection_state: 'not_configured',
        operational_state: null,
        overview: null,
      },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find('[data-testid="ai-overview-error"]').exists()).toBe(
      false
    );
    expect(wrapper.get('[data-testid="ai-overview-setup"]').text()).toContain(
      'RAEVO_AI.OVERVIEW.SETUP.DESCRIPTION'
    );
  });

  it('shows a paused state without presenting it as a service failure', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        connection_state: 'paused',
        operational_state: null,
        overview: null,
      },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find('[data-testid="ai-overview-error"]').exists()).toBe(
      false
    );
    expect(wrapper.get('[data-testid="ai-overview-paused"]').text()).toContain(
      'RAEVO_AI.OVERVIEW.PAUSED.DESCRIPTION'
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
