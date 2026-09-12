import { computed } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import RaevoAiView from '../RaevoAiView.vue';
import { routes } from '../routes';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import RaevoAiAPI from 'dashboard/api/raevoAi';

const adminMocks = vi.hoisted(() => ({ isAdmin: false }));

vi.mock('dashboard/api/raevoAi', () => ({
  default: {
    getOverview: vi.fn(),
    getPauseState: vi.fn(),
    savePauseState: vi.fn(),
    getActivity: vi.fn(),
    saveAssistantName: vi.fn(),
    getServiceHours: vi.fn(),
    saveServiceHours: vi.fn(),
  },
}));

vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: computed(() => adminMocks.isAdmin) }),
}));

const routerMocks = vi.hoisted(() => ({ push: vi.fn() }));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => routerMocks,
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
        RouterLink: { props: ['to'], template: '<a><slot /></a>' },
        RaevoField: {
          props: ['label', 'hint', 'error'],
          template:
            '<div><slot control-class="control" field-id="ai-tab-board-ids" /><p v-if="error" data-testid="ai-field-error">{{ error }}</p></div>',
        },
        NextButton: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button v-bind="$attrs" type="button" @click="$emit(\'click\')">{{ label }}<slot /></button>',
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
    RaevoAiAPI.getOverview.mockResolvedValue({ data: {} });
    RaevoAiAPI.getPauseState.mockResolvedValue({
      data: {
        state: { paused: false, paused_at: null, paused_by: null, revision: 1 },
      },
    });
    RaevoAiAPI.savePauseState.mockResolvedValue({
      data: {
        state: { paused: true, paused_at: null, paused_by: null, revision: 2 },
      },
    });
    RaevoAiAPI.saveAssistantName.mockResolvedValue({
      data: { state: { assistant_name: 'Sofia', effective_name: 'Sofia' } },
    });
    RaevoAiAPI.getActivity.mockResolvedValue({
      data: { recent: [], attention: { failed: 0, pending: 0 } },
    });
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
    RaevoAiAPI.getOverview.mockResolvedValue({
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
          usage: {
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

    expect(RaevoAiAPI.getOverview).toHaveBeenCalledOnce();
    expect(wrapper.find('[data-testid="ai-overview"]').exists()).toBe(true);
    // A jornada é o coração do painel: os números da etapa e a evidência. Na
    // calha o destino é o próprio rótulo, e o nome do destino vive no
    // `aria-label` — sem ele a linha seria «Conversas atendidas» para toda a
    // gente menos para quem usa leitor de ecrã.
    const jornada = wrapper.find('[data-testid="ai-journey"]');
    expect(jornada.text()).toContain('44');
    expect(jornada.findAll('a')[0].attributes('aria-label')).toBe(
      'RAEVO_AI.JOURNEY.LINK_CONVERSATIONS'
    );
    expect(wrapper.find('[data-testid="ai-attendance"]').text()).toContain('5');
  });

  it('follows the clinic board: opportunity, pre-booked, booked, won', async () => {
    // Não há degrau de «qualificada»: nesta clínica o lead qualifica-se ao
    // marcar, e um degrau que conta a mesma gente que o seguinte não informa.
    // O desfecho é o ganho — o purchase —, não o agendamento.
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: {
        status: 'active',
        opportunities_created: 112,
        usage: {
          conversations: 308,
          pre_scheduled: 27,
          appointments: 18,
          payments: 11,
        },
      },
    });

    const wrapper = mountView();
    await flushPromises();

    const etapas = wrapper.findAll('[data-testid="ai-journey-step"]');
    expect(
      etapas.map(e => [
        e.find('dt a').text(),
        e.find('dt span').exists() ? e.find('dt span').text() : null,
        e.find('dd').text().trim(),
      ])
    ).toEqual([
      ['RAEVO_AI.JOURNEY.CONVERSATIONS', null, '308'],
      [
        'RAEVO_AI.JOURNEY.OPPORTUNITIES',
        'RAEVO_AI.JOURNEY.OF_CONVERSATIONS',
        '112',
      ],
      [
        'RAEVO_AI.JOURNEY.PRE_SCHEDULED',
        'RAEVO_AI.JOURNEY.OF_CONVERSATIONS',
        '27',
      ],
      ['RAEVO_AI.JOURNEY.SCHEDULED', 'RAEVO_AI.JOURNEY.OF_PRE_SCHEDULED', '18'],
      [
        'RAEVO_AI.JOURNEY.WON',
        'RAEVO_AI.JOURNEY.OUTCOME · RAEVO_AI.JOURNEY.OF_SCHEDULED',
        '11',
      ],
    ]);
    expect(wrapper.text()).not.toContain('RAEVO_AI.JOURNEY.QUALIFIED');
  });

  it('says nothing rather than printing a rate above 100%', async () => {
    // A secretária pode pré-agendar numa conversa cuja oportunidade já existia
    // e nunca precisou de ser criada. Quando as contas discordam, a linha fica
    // sem legenda em vez de anunciar «2700,0% das oportunidades».
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: {
        status: 'active',
        opportunities_created: 1,
        usage: { conversations: 4, pre_scheduled: 27 },
      },
    });

    const wrapper = mountView();
    await flushPromises();

    const preAgendadas = wrapper.findAll('[data-testid="ai-journey-step"]')[2];
    expect(preAgendadas.find('dd').text()).toContain('27');
    expect(preAgendadas.find('dt span').exists()).toBe(false);
  });

  it('sends the won step to finance, which is where the purchase lives', async () => {
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: { status: 'active', usage: { payments: 11 } },
    });

    const wrapper = mountView();
    await flushPromises();

    const ganho = wrapper.findAll('[data-testid="ai-journey-step"]').at(-1);
    expect(ganho.find('a').attributes('aria-label')).toBe(
      'RAEVO_AI.JOURNEY.LINK_FINANCE'
    );
  });

  it('shows live token usage and separates reported from estimated cost', async () => {
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: {
        connection_state: 'active',
        operational_state: 'healthy',
        overview: {
          status: 'active',
          clinic_name: 'Dra. Anna Alice',
          usage: {
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

    // Entrada e saída separadas, como o artefato pede — não um total só.
    const custos = wrapper.find('[data-testid="ai-costs"]');
    expect(custos.text()).toContain('1,200 / 600');
    expect(wrapper.find('[data-testid="ai-cost-split"]').exists()).toBe(true);
  });

  it('shows a safe error and retries the overview request', async () => {
    RaevoAiAPI.getOverview
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

    expect(RaevoAiAPI.getOverview).toHaveBeenCalledTimes(2);
    expect(wrapper.find('[data-testid="ai-overview"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="ai-overview-error"]').exists()).toBe(
      false
    );
  });

  it('explains that Elis is being prepared when the account is not configured', async () => {
    RaevoAiAPI.getOverview.mockResolvedValue({
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

  it('shows the account is not enabled without presenting it as a service failure', async () => {
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: {
        connection_state: 'disabled',
        operational_state: null,
        overview: null,
      },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find('[data-testid="ai-overview-error"]').exists()).toBe(
      false
    );
    expect(
      wrapper.get('[data-testid="ai-overview-disabled"]').text()
    ).toContain('RAEVO_AI.OVERVIEW.DISABLED.DESCRIPTION');
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

  it('shows the contracted package as one row, not a card of its own', async () => {
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: { status: 'active', package: 'agenda', usage: {} },
    });
    const wrapper = mountView();
    await flushPromises();
    await abrirAba(wrapper, 'assistant');

    const ficha = wrapper.find('[data-testid="ai-setup"]');
    expect(ficha.text()).toContain('RAEVO_AI.PACKAGES.SCHEDULE.TITLE');
    expect(ficha.text()).not.toContain('RAEVO_AI.PACKAGES.COMPLETE.TITLE');
  });

  it('says nothing rather than guessing when the package is unknown', async () => {
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: {
        status: 'active',
        package: 'pacote-que-nao-conhecemos',
        usage: {},
      },
    });
    const wrapper = mountView();
    await flushPromises();
    await abrirAba(wrapper, 'assistant');

    // Pacote desconhecido: a linha mostra um traço em vez de adivinhar qual é.
    expect(wrapper.find('[data-testid="ai-setup"]').text()).toContain('—');
  });

  it('keeps the configuration out of the panel, which is only results', async () => {
    RaevoAiAPI.getOverview.mockResolvedValue({
      data: { status: 'active', package: 'agenda', usage: {} },
    });
    const wrapper = mountView();
    await flushPromises();
    await abrirAba(wrapper, 'assistant');

    expect(wrapper.find('[data-testid="ai-overview"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="ai-setup"]').exists()).toBe(true);
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

  describe('o botão de pausa', () => {
    it('mostra o estado e a acção contrária a ele', async () => {
      adminMocks.isAdmin = true;
      const wrapper = mountView();
      await flushPromises();

      expect(wrapper.find('[data-testid="ai-pause-state"]').text()).toContain(
        'RAEVO_AI.PAUSE.STATE_ACTIVE'
      );
      expect(wrapper.find('[data-testid="ai-pause-toggle"]').text()).toContain(
        'RAEVO_AI.PAUSE.PAUSE'
      );
    });

    it('pede confirmação antes de calar a Elis, e desiste se disserem que não', async () => {
      adminMocks.isAdmin = true;
      const confirmar = vi.spyOn(window, 'confirm').mockReturnValue(false);
      const wrapper = mountView();
      await flushPromises();

      await wrapper.find('[data-testid="ai-pause-toggle"]').trigger('click');
      await flushPromises();

      expect(confirmar).toHaveBeenCalled();
      expect(RaevoAiAPI.savePauseState).not.toHaveBeenCalled();
      confirmar.mockRestore();
    });

    it('pausa com a revisão que leu, para não escrever por cima de outra pessoa', async () => {
      adminMocks.isAdmin = true;
      const confirmar = vi.spyOn(window, 'confirm').mockReturnValue(true);
      const wrapper = mountView();
      await flushPromises();

      await wrapper.find('[data-testid="ai-pause-toggle"]').trigger('click');
      await flushPromises();

      expect(RaevoAiAPI.savePauseState).toHaveBeenCalledWith({
        paused: true,
        expected_revision: 1,
      });
      confirmar.mockRestore();
    });

    it('retomar não pede confirmação: voltar a atender não é a decisão arriscada', async () => {
      adminMocks.isAdmin = true;
      RaevoAiAPI.getPauseState.mockResolvedValue({
        data: {
          state: {
            paused: true,
            paused_at: null,
            paused_by: null,
            revision: 3,
          },
        },
      });
      const confirmar = vi.spyOn(window, 'confirm');
      const wrapper = mountView();
      await flushPromises();

      await wrapper.find('[data-testid="ai-pause-toggle"]').trigger('click');
      await flushPromises();

      expect(confirmar).not.toHaveBeenCalled();
      expect(RaevoAiAPI.savePauseState).toHaveBeenCalledWith({
        paused: false,
        expected_revision: 3,
      });
      confirmar.mockRestore();
    });

    it('não oferece o botão a quem só atende conversas', async () => {
      adminMocks.isAdmin = false;
      const wrapper = mountView();
      await flushPromises();

      expect(wrapper.find('[data-testid="ai-pause-state"]').exists()).toBe(
        true
      );
      expect(wrapper.find('[data-testid="ai-pause-toggle"]').exists()).toBe(
        false
      );
    });

    it('esconde o controlo em vez de derrubar o painel quando o estado não vem', async () => {
      adminMocks.isAdmin = true;
      RaevoAiAPI.getPauseState.mockRejectedValue(new Error('ponte em baixo'));
      const wrapper = mountView();
      await flushPromises();

      expect(wrapper.find('[data-testid="ai-pause-state"]').exists()).toBe(
        false
      );
      expect(wrapper.find('[data-testid="ai-overview"]').exists()).toBe(true);
    });
  });

  describe('o filtro de período', () => {
    it('começa em trinta dias, que é a pergunta que a clínica traz', async () => {
      mountView();
      await flushPromises();

      expect(RaevoAiAPI.getOverview).toHaveBeenCalledWith(30);
    });

    it('volta a perguntar ao serviço quando muda a janela', async () => {
      const wrapper = mountView();
      await flushPromises();

      await wrapper
        .findAll('[data-testid="ai-window-filter"] button')[0]
        .trigger('click');
      await flushPromises();

      expect(RaevoAiAPI.getOverview).toHaveBeenLastCalledWith(7);
    });
  });

  describe('o que precisa de uma pessoa', () => {
    // Abre o Painel, e não a aba da secretária: quem só abre o Painel nunca
    // chegava a ver o que tinha falhado.
    const haMinutos = minutos =>
      new Date(Date.now() - minutos * 60000).toISOString();

    it('diz que está tudo em dia em vez de mostrar uma lista vazia', async () => {
      const wrapper = mountView();
      await flushPromises();

      expect(wrapper.findAll('[data-testid="ai-attention-row"]')).toHaveLength(
        0
      );
      expect(wrapper.find('[data-testid="ai-needs-you"]').text()).toContain(
        'RAEVO_AI.ACTIVITY.ATTENTION_EMPTY'
      );
    });

    it('lista a falha e a acção parada, cada uma com para onde ir', async () => {
      RaevoAiAPI.getActivity.mockResolvedValue({
        data: {
          recent: [
            {
              id: 1,
              command_type: 'calendar.book_appointment',
              state: 'failed_terminal',
              occurred_at: haMinutos(51),
              target: { type: 'conversation', id: 4821 },
            },
            {
              id: 2,
              command_type: 'crm.move_stage',
              state: 'claimed',
              occurred_at: haMinutos(30),
              target: { type: 'card', id: 7, board_id: 3 },
            },
          ],
          attention: { failed: 1, pending: 1 },
        },
      });
      const wrapper = mountView();
      await flushPromises();

      const linhas = wrapper.findAll('[data-testid="ai-attention-row"]');
      expect(linhas).toHaveLength(2);
      expect(linhas[0].text()).toContain(
        'RAEVO_AI.ACTIVITY.STATE_FAILED_TERMINAL'
      );
      expect(linhas[1].text()).toContain('RAEVO_AI.ACTIVITY.STATE_CLAIMED');
      // Sem botão, cada linha é um facto que não leva a lado nenhum.
      linhas.forEach(linha =>
        expect(linha.text()).toContain('RAEVO_AI.ACTIVITY.OPEN')
      );
    });

    it('não acusa como parado o que foi reclamado agora mesmo', async () => {
      // Cinco minutos é o mesmo limiar do servidor. Sem ele o painel acusava
      // pendências que se resolviam sozinhas, e o aviso perdia o crédito.
      RaevoAiAPI.getActivity.mockResolvedValue({
        data: {
          recent: [
            {
              id: 1,
              command_type: 'crm.move_stage',
              state: 'claimed',
              occurred_at: haMinutos(1),
            },
          ],
          attention: { failed: 0, pending: 0 },
        },
      });
      const wrapper = mountView();
      await flushPromises();

      expect(wrapper.findAll('[data-testid="ai-attention-row"]')).toHaveLength(
        0
      );
    });

    it('avisa quando o servidor conta mais do que as linhas mostram', async () => {
      RaevoAiAPI.getActivity.mockResolvedValue({
        data: {
          recent: [
            {
              id: 1,
              command_type: 'crm.move_stage',
              state: 'failed_retryable',
              occurred_at: haMinutos(10),
            },
          ],
          attention: { failed: 6, pending: 0 },
        },
      });
      const wrapper = mountView();
      await flushPromises();

      expect(wrapper.findAll('[data-testid="ai-attention-row"]')).toHaveLength(
        1
      );
      expect(
        wrapper.find('[data-testid="ai-needs-you-remainder"]').text()
      ).toContain('RAEVO_AI.ACTIVITY.ATTENTION_REMAINDER');
    });
  });

  describe('o que a Elis fez', () => {
    it('mostra o registo em vez de o pedir e deitar fora', async () => {
      // A chamada existia desde o início e nada no ecrã a usava.
      RaevoAiAPI.saveAssistantName.mockResolvedValue({
        data: { state: { assistant_name: 'Sofia', effective_name: 'Sofia' } },
      });
      RaevoAiAPI.getActivity.mockResolvedValue({
        data: {
          recent: [
            {
              id: 1,
              command_type: 'crm.move_stage',
              state: 'applied',
              occurred_at: '2026-09-10T12:00:00Z',
            },
          ],
          attention: { failed: 0, pending: 0 },
        },
      });
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      const itens = wrapper.findAll('[data-testid="ai-activity-item"]');
      expect(itens).toHaveLength(1);
      expect(itens[0].text()).toContain(
        'RAEVO_AI.ACTIVITY.COMMANDS.CRM_MOVE_STAGE'
      );
      expect(itens[0].text()).toContain('RAEVO_AI.ACTIVITY.STATE_APPLIED');
    });

    it('não mostra identificador de sistema quando o tipo não é conhecido', async () => {
      RaevoAiAPI.saveAssistantName.mockResolvedValue({
        data: { state: { assistant_name: 'Sofia', effective_name: 'Sofia' } },
      });
      RaevoAiAPI.getActivity.mockResolvedValue({
        data: {
          recent: [
            {
              id: 1,
              command_type: 'algo.que.nao.conhecemos',
              state: 'inventado',
              occurred_at: null,
            },
          ],
          attention: { failed: 0, pending: 0 },
        },
      });
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      const texto = wrapper.find('[data-testid="ai-activity-item"]').text();
      expect(texto).toContain('RAEVO_AI.ACTIVITY.COMMANDS.UNKNOWN');
      expect(texto).toContain('RAEVO_AI.ACTIVITY.STATE_UNKNOWN');
      expect(texto).not.toContain('algo.que.nao.conhecemos');
    });

    it('diz que não há nada em vez de mostrar uma lista vazia', async () => {
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      expect(wrapper.find('[data-testid="ai-activity"]').text()).toContain(
        'RAEVO_AI.ACTIVITY.RECENT_EMPTY'
      );
    });
  });

  describe('o nome da secretária', () => {
    it('mostra o que a clínica escolheu, não um valor fixo', async () => {
      adminMocks.isAdmin = true;
      RaevoAiAPI.getOverview.mockResolvedValue({
        data: { status: 'active', assistant_name: 'Sofia', usage: {} },
      });
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      expect(
        wrapper.find('[data-testid="ai-assistant-name"]').element.value
      ).toBe('Sofia');
    });

    it('grava ao sair do campo', async () => {
      adminMocks.isAdmin = true;
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      const campo = wrapper.find('[data-testid="ai-assistant-name"]');
      await campo.setValue('Sofia');
      await campo.trigger('change');
      await flushPromises();

      expect(RaevoAiAPI.saveAssistantName).toHaveBeenCalledWith('Sofia');
    });

    it('vazio repõe o padrão em vez de a deixar sem nome', async () => {
      adminMocks.isAdmin = true;
      RaevoAiAPI.saveAssistantName.mockResolvedValue({
        data: { state: { assistant_name: null, effective_name: 'Elis' } },
      });
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      const campo = wrapper.find('[data-testid="ai-assistant-name"]');
      await campo.setValue('   ');
      await campo.trigger('change');
      await flushPromises();

      expect(RaevoAiAPI.saveAssistantName).toHaveBeenCalledWith('');
      expect(campo.element.value).toBe('');
    });

    it('quem só atende conversas vê o nome, mas não o campo', async () => {
      adminMocks.isAdmin = false;
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      expect(wrapper.find('[data-testid="ai-assistant-name"]').exists()).toBe(
        false
      );
      expect(wrapper.find('[data-testid="ai-setup"]').text()).toContain(
        'RAEVO_AI.SETUP.NAME'
      );
    });

    it('avisa em vez de fingir que gravou quando o serviço recusa', async () => {
      adminMocks.isAdmin = true;
      RaevoAiAPI.saveAssistantName.mockRejectedValue({
        response: { status: 409 },
      });
      const wrapper = mountView();
      await flushPromises();
      await abrirAba(wrapper, 'assistant');

      const campo = wrapper.find('[data-testid="ai-assistant-name"]');
      await campo.setValue('Sofia');
      await campo.trigger('change');
      await flushPromises();

      expect(wrapper.find('[data-testid="ai-field-error"]').text()).toContain(
        'RAEVO_AI.SETUP.NAME_CONFLICT'
      );
    });
  });
});
