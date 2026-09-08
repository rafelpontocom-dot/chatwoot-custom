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
    getAssistantDraft: vi.fn(),
    saveAssistantDraft: vi.fn(),
    simulateAssistantDraft: vi.fn(),
    reviewAssistantDraft: vi.fn(),
    publishAssistantDraft: vi.fn(),
    getOpportunityTab: vi.fn(),
    updateOpportunityTab: vi.fn(),
    getServiceHours: vi.fn(),
    saveServiceHours: vi.fn(),
  },
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: { getBoards: vi.fn() },
}));

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: { value: adminMocks.isAdmin } }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      params.version ? `${key} ${params.version}` : key,
  }),
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
        RaevoAiServiceHoursSettings: true,
      },
    },
  });

describe('RaevoAiView', () => {
  beforeEach(() => {
    adminMocks.isAdmin = false;
    RaevoAiAPI.get.mockResolvedValue({ data: {} });
    RaevoAiAPI.getAssistantDraft.mockResolvedValue({ data: { draft: null } });
    RaevoAiAPI.saveAssistantDraft.mockResolvedValue({ data: { draft: null } });
    RaevoAiAPI.simulateAssistantDraft.mockResolvedValue({ data: {} });
    RaevoAiAPI.reviewAssistantDraft.mockResolvedValue({ data: {} });
    RaevoAiAPI.publishAssistantDraft.mockResolvedValue({ data: {} });
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
          capabilities: {
            package: 'agenda',
            capabilities: [
              { id: 'atendimento', provider: null },
              { id: 'crm', provider: 'chatwoot' },
              { id: 'agenda', provider: 'feegow' },
            ],
          },
          operational_quality: {
            post_delivery_actions_pending: 1,
            post_delivery_actions_applied: 4,
            post_delivery_actions_failed: 2,
            manual_reconciliations: 3,
            attention_level: 'action_required',
            attention_reasons: [
              'post_delivery_actions_failed',
              'post_delivery_actions_pending',
              'manual_reconciliations',
            ],
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
    expect(wrapper.text()).toContain('2');
    expect(wrapper.text()).toContain('RAEVO_AI.OVERVIEW.METRICS.OPEN_REVIEWS');
  });

  it('shows the published capabilities as read-only operational context', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        connection_state: 'active',
        operational_state: 'healthy',
        overview: {
          clinic_name: 'Clínica Exemplo',
          capabilities: {
            package: 'agenda',
            capabilities: [
              { id: 'atendimento', provider: null },
              { id: 'crm', provider: 'chatwoot' },
              { id: 'agenda', provider: 'feegow' },
            ],
          },
          usage_30d: {},
        },
      },
    });

    const wrapper = mountView();
    await flushPromises();

    const capabilities = wrapper.get('[data-testid="ai-capabilities"]');
    expect(capabilities.text()).toContain('RAEVO_AI.CAPABILITIES.TITLE');
    expect(capabilities.text()).toContain(
      'RAEVO_AI.CAPABILITIES.ITEMS.ATENDIMENTO'
    );
    expect(capabilities.text()).toContain('RAEVO_AI.CAPABILITIES.ITEMS.CRM');
    expect(capabilities.text()).toContain(
      'RAEVO_AI.CAPABILITIES.PROVIDERS.CHATWOOT'
    );
    expect(capabilities.text()).toContain(
      'RAEVO_AI.CAPABILITIES.PROVIDERS.FEEGOW'
    );
    expect(capabilities.find('button').exists()).toBe(false);
  });

  it('shows quality counts as investigation context without corrective controls', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        connection_state: 'active',
        operational_state: 'healthy',
        overview: {
          clinic_name: 'Clínica Exemplo',
          operational_quality: {
            post_delivery_actions_pending: 1,
            post_delivery_actions_applied: 4,
            post_delivery_actions_failed: 2,
            manual_reconciliations: 3,
            attention_level: 'action_required',
            attention_reasons: [
              'post_delivery_actions_failed',
              'post_delivery_actions_pending',
              'manual_reconciliations',
            ],
          },
          usage_30d: {},
        },
      },
    });

    const wrapper = mountView();
    await flushPromises();

    const quality = wrapper.get('[data-testid="ai-operational-quality"]');
    expect(quality.text()).toContain('RAEVO_AI.QUALITY.TITLE');
    expect(quality.text()).toContain(
      'RAEVO_AI.QUALITY.POST_DELIVERY_ACTIONS_PENDING'
    );
    expect(quality.text()).toContain('1');
    expect(quality.text()).toContain('4');
    expect(quality.text()).toContain('2');
    expect(quality.text()).toContain('3');
    expect(quality.text()).toContain(
      'RAEVO_AI.QUALITY.POST_DELIVERY_ACTIONS_APPLIED'
    );
    expect(quality.text()).toContain(
      'RAEVO_AI.QUALITY.ATTENTION_LEVELS.ACTION_REQUIRED'
    );
    expect(quality.text()).toContain(
      'RAEVO_AI.QUALITY.ATTENTION_REASONS.POST_DELIVERY_ACTIONS_FAILED'
    );
    expect(quality.find('button').exists()).toBe(false);
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
    const configuration = wrapper.get(
      '[data-testid="ai-opportunity-tab-configuration"]'
    );
    await configuration.find('select[multiple]').setValue(['14']);
    await configuration.find('input[type="checkbox"]').setValue(true);
    await configuration
      .find('[data-testid="ai-opportunity-tab-save"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.updateOpportunityTab).toHaveBeenCalledWith({
      enabled: true,
      board_ids: [14],
    });
  });

  it('lets an administrator save only the three editable assistant clusters with its revision', async () => {
    adminMocks.isAdmin = true;
    RaevoAiAPI.getAssistantDraft.mockResolvedValue({
      data: {
        draft: {
          revision: '2026-09-07T12:00:00.000Z',
          editable_clusters: {
            identity: { enabled: true, content: 'Secretária virtual.' },
            personality: { enabled: true, content: 'Serena.' },
            voice_style: { enabled: false, content: '' },
          },
        },
      },
    });
    RaevoAiAPI.saveAssistantDraft.mockResolvedValue({
      data: { draft: { revision: '2026-09-07T12:05:00.000Z' } },
    });

    const wrapper = mountView();
    await flushPromises();

    await wrapper
      .get('[data-testid="ai-assistant-draft-identity"] textarea')
      .setValue('Secretária virtual da clínica.');
    await wrapper
      .get('[data-testid="ai-assistant-draft-save"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.saveAssistantDraft).toHaveBeenCalledWith({
      expected_revision: '2026-09-07T12:00:00.000Z',
      editable_clusters: {
        identity: { enabled: true, content: 'Secretária virtual da clínica.' },
        personality: { enabled: true, content: 'Serena.' },
        voice_style: { enabled: false, content: '' },
      },
    });
  });

  it('asks the administrator to reload instead of overwriting a conflicted draft', async () => {
    adminMocks.isAdmin = true;
    RaevoAiAPI.getAssistantDraft.mockResolvedValue({ data: { draft: null } });
    RaevoAiAPI.saveAssistantDraft.mockRejectedValue({
      response: { status: 409 },
    });

    const wrapper = mountView();
    await flushPromises();
    await wrapper
      .get('[data-testid="ai-assistant-draft-save"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.get('[data-testid="ai-assistant-draft-conflict"]').text()
    ).toContain('RAEVO_AI.ASSISTANT_DRAFT.CONFLICT');
  });

  it('shows the active version as read-only context beside the draft', async () => {
    adminMocks.isAdmin = true;
    RaevoAiAPI.getAssistantDraft.mockResolvedValue({
      data: { draft: null, active_version: { version_number: 7 } },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.get('[data-testid="ai-assistant-draft"]').text()).toContain(
      '7'
    );
  });

  it('runs only an approved synthetic fixture against a saved draft and displays it as review-only', async () => {
    adminMocks.isAdmin = true;
    RaevoAiAPI.getAssistantDraft.mockResolvedValue({
      data: {
        draft: {
          id: 'a0d18e55-64b1-4d93-a264-c02986186590',
          revision: '2026-09-07T12:00:00.000Z',
          editable_clusters: {
            identity: { enabled: true, content: 'Secretária virtual.' },
            personality: { enabled: true, content: 'Serena.' },
            voice_style: { enabled: false, content: '' },
          },
        },
      },
    });
    RaevoAiAPI.simulateAssistantDraft.mockResolvedValue({
      data: {
        simulation: {
          response_bubbles: ['Olá! Sou a Elis.'],
          intent: 'information_request',
          execution: { delivery_disposition: 'discard' },
        },
        evaluation: { verdict: 'ready_for_human_review' },
      },
    });

    const wrapper = mountView();
    await flushPromises();
    await wrapper
      .get('[data-testid="ai-assistant-simulation-first_contact"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.simulateAssistantDraft).toHaveBeenCalledWith({
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      fixture_id: 'first_contact',
    });
    expect(
      wrapper.get('[data-testid="ai-assistant-simulation-result"]').text()
    ).toContain('Olá! Sou a Elis.');
    expect(
      wrapper.get('[data-testid="ai-assistant-simulation-result"]').text()
    ).toContain('RAEVO_AI.ASSISTANT_SIMULATION.REVIEW_ONLY');
  });

  it('requires a fresh approved synthetic review before exposing the explicit publication action', async () => {
    adminMocks.isAdmin = true;
    RaevoAiAPI.getAssistantDraft.mockResolvedValue({
      data: {
        draft: {
          id: 'a0d18e55-64b1-4d93-a264-c02986186590',
          revision: '2026-09-07T12:00:00.000Z',
          editable_clusters: {
            identity: { enabled: true, content: 'Secretária virtual.' },
            personality: { enabled: true, content: 'Serena.' },
            voice_style: { enabled: false, content: '' },
          },
        },
        active_version: {
          id: '00000000-0000-0000-0000-000000000008',
          version_number: 8,
        },
      },
    });
    RaevoAiAPI.simulateAssistantDraft.mockResolvedValue({
      data: {
        simulation: {
          response_bubbles: ['Olá!'],
          execution: { delivery_disposition: 'discard' },
        },
        evaluation: { verdict: 'ready_for_human_review' },
      },
    });
    RaevoAiAPI.reviewAssistantDraft.mockResolvedValue({
      data: { review: { id: '00000000-0000-0000-0000-000000000013' } },
    });
    RaevoAiAPI.publishAssistantDraft.mockResolvedValue({
      data: {
        publication: {
          id: '00000000-0000-0000-0000-000000000014',
          version_number: 9,
        },
      },
    });

    const wrapper = mountView();
    await flushPromises();
    await wrapper
      .get('[data-testid="ai-assistant-simulation-first_contact"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="ai-assistant-draft-publish"]').exists()
    ).toBe(false);

    await wrapper
      .get('[data-testid="ai-assistant-draft-review"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.reviewAssistantDraft).toHaveBeenCalledWith({
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      fixture_id: 'first_contact',
      expected_revision: '2026-09-07T12:00:00.000Z',
      decision: 'approved',
    });

    await wrapper
      .get('[data-testid="ai-assistant-draft-publication-confirmation"]')
      .setValue(true);

    await wrapper
      .get('[data-testid="ai-assistant-draft-publish"]')
      .trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.publishAssistantDraft).toHaveBeenCalledWith({
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      expected_revision: '2026-09-07T12:00:00.000Z',
      expected_active_version_id: '00000000-0000-0000-0000-000000000008',
      review_id: '00000000-0000-0000-0000-000000000013',
    });
  });
});
