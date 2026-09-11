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
          template:
            '<header><slot name="tabs" /><slot name="actions" /><slot /></header>',
        },
        TabBar: {
          props: ['tabs'],
          emits: ['tabChanged'],
          template:
            '<nav><button v-for="tab in tabs" :key="tab.key" type="button" :data-testid="\'tab-\' + tab.key" @click="$emit(\'tabChanged\', tab)">{{ tab.label }}</button></nav>',
        },
        RaevoAiKnowledgePanel: true,
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

// A configuração da Elis vive agora atrás de uma aba. Sem a abrir, o que estes
// testes procuram simplesmente não está montado.
const abrirAba = (wrapper, chave) =>
  wrapper.find(`[data-testid="tab-${chave}"]`).trigger('click');

describe('RaevoAiView', () => {
  beforeEach(() => {
    adminMocks.isAdmin = false;
    RaevoAiAPI.get.mockResolvedValue({ data: {} });
    RaevoAiAPI.getOpportunityTab.mockResolvedValue({
      data: { enabled: false, board_ids: [] },
    });
    KanbanBoardsAPI.getBoards.mockResolvedValue({ data: [] });
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

  it('opens on the panel, which is what the clinic comes to see', async () => {
    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find('[data-testid="ai-overview"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="ai-knowledge"]').exists()).toBe(false);
  });

  it('mounts the knowledge panel only on its own tab', async () => {
    const wrapper = mountView();
    await flushPromises();
    await abrirAba(wrapper, 'knowledge');

    expect(
      wrapper.findComponent({ name: 'RaevoAiKnowledgePanel' }).exists()
    ).toBe(true);
  });

  it('shows only the contracted package, not a catalogue of what was not bought', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: { status: 'active', package: 'agenda', usage_30d: {} },
    });
    const wrapper = mountView();
    await flushPromises();
    await abrirAba(wrapper, 'assistant');

    const pacotes = wrapper.findAll('[data-testid="ai-service-package"]');
    expect(pacotes).toHaveLength(1);
    expect(pacotes[0].text()).toContain('RAEVO_AI.PACKAGES.SCHEDULE.TITLE');
    expect(wrapper.text()).not.toContain('RAEVO_AI.PACKAGES.COMPLETE.TITLE');
  });

  it('says nothing rather than guessing when the package is unknown', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: {
        status: 'active',
        package: 'pacote-que-nao-conhecemos',
        usage_30d: {},
      },
    });
    const wrapper = mountView();
    await flushPromises();
    await abrirAba(wrapper, 'assistant');

    expect(wrapper.find('[data-testid="ai-service-package"]').exists()).toBe(
      false
    );
    expect(
      wrapper.find('[data-testid="ai-service-package-empty"]').exists()
    ).toBe(true);
  });

  it('keeps the configuration out of the panel, which is only results', async () => {
    RaevoAiAPI.get.mockResolvedValue({
      data: { status: 'active', package: 'agenda', usage_30d: {} },
    });
    const wrapper = mountView();
    await flushPromises();
    await abrirAba(wrapper, 'assistant');

    expect(wrapper.find('[data-testid="ai-overview"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="ai-service-package"]').exists()).toBe(
      true
    );
  });

  describe('o que a clínica pediu para tirar do ecrã', () => {
    // Estes seis cortes foram pedidos e ficaram por aplicar durante muito tempo.
    // Ficam fixados aqui para não regressarem por distração.
    const cortados = [
      'ai-assistant-draft',
      'ai-assistant-simulation',
      'ai-opportunity-tab-configuration',
      'ai-operational-quality',
      'ai-assistant-profile',
    ];

    it.each(cortados)('não mostra %s em aba nenhuma', async testid => {
      const wrapper = mountView();
      await flushPromises();

      const ausente = () => wrapper.find(`[data-testid="${testid}"]`).exists();

      expect(ausente()).toBe(false);
      await abrirAba(wrapper, 'assistant');
      expect(ausente()).toBe(false);
      await abrirAba(wrapper, 'knowledge');
      expect(ausente()).toBe(false);
    });
  });
});
