import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import RaevoHomeView from '../RaevoHomeView.vue';
import RaevoHomeAPI from 'dashboard/api/raevoHome';

const mockPush = vi.fn();
const mockReplace = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: ref('pt_BR') }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '3' }, query: {} }),
  useRouter: () => ({ push: mockPush, replace: mockReplace }),
}));
vi.mock('dashboard/api/raevoHome', () => ({
  default: { get: vi.fn(), saveTeamLayout: vi.fn(), getInsights: vi.fn() },
}));
const mockUISettings = ref({});
const mockUpdateUISettings = vi.fn();
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: mockUISettings,
    updateUISettings: mockUpdateUISettings,
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mountHome = () =>
  shallowMount(RaevoHomeView, {
    global: {
      stubs: {
        RaevoPageHeader: {
          template: '<header><slot name="actions" /><slot /></header>',
        },
        RaevoStamp: true,
        // Stubado por omissão, o cartão engole rótulo, valor e rodapé.
        // Ver AGENTS.md, «Armadilha conhecida em testes».
        // A grelha e a moldura são reais: stubadas, engoliam os blocos todos.
        RaevoHomeGrid: false,
        RaevoHomeWidget: false,
        // O `Dialog` real abre um `<dialog>` nativo que o jsdom não tem. O stub
        // guarda o título para se distinguir o catálogo da confirmação.
        Dialog: {
          props: ['title'],
          emits: ['confirm'],
          methods: { open() {}, close() {} },
          template:
            '<div :data-dialog="title"><slot /><button class="confirm" @click="$emit(\'confirm\')" /></div>',
        },
        RaevoKpiCard: {
          props: ['label', 'value', 'footer'],
          template:
            '<div><i>{{ label }}</i><b>{{ value }}</b><u>{{ footer }}</u></div>',
        },
      },
    },
  });

describe('RaevoHomeView', () => {
  beforeEach(() => {
    mockPush.mockClear();
    RaevoHomeAPI.get.mockResolvedValue({
      data: {
        open_conversations_count: 2,
        open_conversations: [
          {
            id: 11,
            display_id: 1001,
            contact_name: 'Pedro Raevo',
            inbox_name: 'WhatsApp',
            last_activity_at: '2026-08-29T10:00:00Z',
          },
        ],
        filters: {
          inboxes: [{ id: 5, name: 'WhatsApp' }],
          boards: [{ id: 7, name: 'RAEVO' }],
        },
        overdue_actions: [
          {
            kanban_card_id: 18,
            kanban_board_id: 7,
            kanban_board_name: 'RAEVO',
            kanban_stage_name: 'Contato',
            subject: 'Retornar para Pedro',
            next_action_at: '2026-08-29T09:00:00Z',
          },
        ],
      },
    });
  });

  // Os três cartões aprovados a 21/09. A regra que se testa aqui é a do contrato:
  // `null` é «módulo não está em uso, não mostrar o cartão»; lista vazia é «está
  // ligado e hoje não há nada».
  describe('the three support cards', () => {
    const comCartoes = extra =>
      RaevoHomeAPI.get.mockResolvedValue({
        data: {
          open_conversations_count: 0,
          open_conversations: [],
          overdue_actions: [],
          overdue_actions_count: 0,
          filters: { inboxes: [], boards: [] },
          ...extra,
        },
      });

    // A fila de indicadores herda o mesmo contrato dos cartões: opt-in por
    // módulo. E não tem variação nenhuma — o servidor desta tela não guarda
    // histórico, e um delta inventado parece informação.
    it('opens with two indicators when neither module is in use', async () => {
      comCartoes({});
      const wrapper = mountHome();
      await flushPromises();

      expect(wrapper.findAll('[data-testid^="home-kpi-"]')).toHaveLength(2);
      expect(wrapper.find('[data-testid="home-kpi-agenda"]').exists()).toBe(
        false
      );
      expect(
        wrapper.find('[data-testid="home-kpi-overdue-payments"]').exists()
      ).toBe(false);
    });

    it('adds the agenda and the overdue total when the modules are in use', async () => {
      comCartoes({
        today_appointments: {
          count: 4,
          items: [
            {
              id: 3,
              starts_at: '2026-09-21T09:15:00Z',
              status: 'confirmed',
              contact_name: 'Carla Pinheiro',
              procedure_name: 'Avaliação',
              kanban_card_id: null,
            },
          ],
        },
        overdue_payments: {
          count: 2,
          items: [
            {
              id: 1,
              amount_cents: 12_900,
              currency: 'BRL',
              due_on: '2026-09-02',
            },
            {
              id: 2,
              amount_cents: 2_100,
              currency: 'BRL',
              due_on: '2026-09-11',
            },
          ],
        },
      });
      const wrapper = mountHome();
      await flushPromises();

      expect(
        wrapper.get('[data-testid="home-kpi-agenda"]').find('b').text()
      ).toBe('4');
      // 12.900 + 2.100 centavos = 150,00. A asserção ignora separadores porque o
      // valor é formatado na localização de quem vê, e o teste corre em en-US.
      expect(
        wrapper
          .get('[data-testid="home-kpi-overdue-payments"]')
          .find('b')
          .text()
          .replace(/\D/g, '')
      ).toBe('15000');
    });

    it("lists today's schedule as a strip", async () => {
      comCartoes({
        today_appointments: {
          count: 1,
          items: [
            {
              id: 3,
              starts_at: '2026-09-21T09:15:00Z',
              status: 'confirmed',
              contact_name: 'Carla Pinheiro',
              procedure_name: 'Avaliação',
              kanban_card_id: null,
            },
          ],
        },
      });
      const wrapper = mountHome();
      await flushPromises();

      expect(
        wrapper.find('[data-testid="home-today-appointments"]').exists()
      ).toBe(true);
      expect(wrapper.text()).toContain('Avaliação');
      expect(wrapper.text()).toContain('Carla Pinheiro');
    });

    it('hides the charges card when Finance is not in use', async () => {
      comCartoes({ overdue_payments: null });
      const wrapper = mountHome();
      await flushPromises();

      expect(
        wrapper.find('[data-testid="home-overdue-payments"]').exists()
      ).toBe(false);
    });

    it('shows the charges card when Finance is in use', async () => {
      comCartoes({
        overdue_payments: {
          count: 11,
          items: [
            {
              id: 9,
              contact_name: 'Helena Vaz',
              amount_cents: 124000,
              currency: 'EUR',
              due_on: '2026-09-15',
              kanban_card_id: 42,
            },
          ],
        },
      });
      const wrapper = mountHome();
      await flushPromises();

      expect(
        wrapper.find('[data-testid="home-overdue-payments"]').exists()
      ).toBe(true);
      expect(wrapper.text()).toContain('Helena Vaz');
    });

    it('lists stalled opportunities with the stage limit', async () => {
      comCartoes({
        stale_opportunities: {
          count: 14,
          count_capped: false,
          items: [
            {
              kanban_card_id: 5,
              kanban_board_id: 7,
              kanban_board_name: 'RAEVO',
              kanban_stage_name: 'Em negociação',
              subject: 'Facetas 11 e 21',
              stage_entered_at: '2026-08-29T10:00:00Z',
              stale_days: 14,
            },
          ],
        },
      });
      const wrapper = mountHome();
      await flushPromises();

      expect(
        wrapper.find('[data-testid="home-stale-opportunities"]').exists()
      ).toBe(true);
      expect(wrapper.text()).toContain('Facetas 11 e 21');
    });
  });

  it('shows the operational queues and opens the linked conversation', async () => {
    const wrapper = mountHome();
    await flushPromises();

    expect(wrapper.text()).toContain('Pedro Raevo');
    expect(wrapper.text()).toContain('Retornar para Pedro');

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Pedro Raevo'))
      .trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      name: 'inbox_conversation',
      params: { accountId: '3', conversation_id: 1001 },
    });
  });

  it('filters by inbox and asks the server for the chosen order', async () => {
    const wrapper = mountHome();
    await flushPromises();
    RaevoHomeAPI.get.mockClear();

    await wrapper.find('[data-testid="home-filter-inbox"]').setValue('5');
    await flushPromises();

    expect(RaevoHomeAPI.get).toHaveBeenCalledWith(
      expect.objectContaining({ inbox_id: '5', conversation_sort: 'waiting' })
    );
    expect(mockReplace).toHaveBeenCalledWith(
      expect.objectContaining({
        query: expect.objectContaining({ inbox_id: '5' }),
      })
    );

    await wrapper
      .find('[data-testid="home-sort-conversations"]')
      .setValue('recent');
    await flushPromises();

    expect(RaevoHomeAPI.get).toHaveBeenLastCalledWith(
      expect.objectContaining({ conversation_sort: 'recent', inbox_id: '5' })
    );
  });

  it('filters the overdue actions by funnel', async () => {
    const wrapper = mountHome();
    await flushPromises();
    RaevoHomeAPI.get.mockClear();

    await wrapper.find('[data-testid="home-filter-board"]').setValue('7');
    await flushPromises();

    expect(RaevoHomeAPI.get).toHaveBeenCalledWith(
      expect.objectContaining({ board_id: '7', action_sort: 'overdue' })
    );
  });

  it('opens an overdue next action in its opportunity drawer', async () => {
    const wrapper = mountHome();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Retornar para Pedro'))
      .trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      name: 'kanban_board_show',
      params: { accountId: '3', boardId: 7 },
      query: { cardId: 18 },
    });
  });
  it('shows the last message instead of repeating the inbox name', async () => {
    RaevoHomeAPI.get.mockResolvedValue({
      data: {
        open_conversations_count: 1,
        open_conversations: [
          {
            id: 11,
            display_id: 1001,
            contact_name: 'Pedro Raevo',
            inbox_name: 'Dra. Telma',
            last_message: 'Bom dia, consigo remarcar para sexta?',
            last_activity_at: new Date(
              Date.now() - 41 * 60 * 1000
            ).toISOString(),
          },
        ],
        overdue_actions: [],
      },
    });

    const wrapper = mountHome();
    await flushPromises();

    expect(wrapper.text()).toContain('Bom dia, consigo remarcar para sexta?');
    expect(wrapper.text()).not.toContain('Dra. Telma');
  });

  it('shows how long someone has been waiting, not the absolute date', async () => {
    RaevoHomeAPI.get.mockResolvedValue({
      data: {
        open_conversations_count: 1,
        open_conversations: [
          {
            id: 11,
            display_id: 1001,
            contact_name: 'Pedro Raevo',
            last_activity_at: new Date(
              Date.now() - 41 * 60 * 1000
            ).toISOString(),
          },
        ],
        overdue_actions: [],
      },
    });

    const wrapper = mountHome();
    await flushPromises();

    expect(wrapper.text()).toContain('41');
    expect(wrapper.text()).not.toMatch(/\d{2}\/\d{2}\/\d{4}/);
  });

  it('offers a way out when the list is capped below the real count', async () => {
    RaevoHomeAPI.get.mockResolvedValue({
      data: {
        open_conversations_count: 9,
        open_conversations: [
          { id: 11, display_id: 1001, contact_name: 'Pedro Raevo' },
        ],
        overdue_actions: [],
      },
    });

    const wrapper = mountHome();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="home-see-all-conversations"]').exists()
    ).toBe(true);
  });

  // O Início editável (proposta A, 18/10). O que se testa é o contrato com quem
  // grava: de quem é o layout que se desenha, e o que vai para `ui_settings`.
  describe('the editable layout', () => {
    const layout = items => ({ version: 1, items });
    const widgetOrder = wrapper =>
      wrapper
        .findAll('[data-widget-id]')
        .map(node => node.attributes('data-widget-id'));
    const withLayout = (team = null, canSetTeam = false) =>
      RaevoHomeAPI.get.mockResolvedValue({
        data: {
          open_conversations_count: 0,
          open_conversations: [],
          overdue_actions: [],
          overdue_actions_count: 0,
          filters: { inboxes: [], boards: [] },
          layout: { team, can_set_team: canSetTeam },
        },
      });
    const mine = layout([
      { id: 'overdue-actions', x: 0, y: 0, w: 12, h: 4 },
      { id: 'kpi-conversations', x: 0, y: 4, w: 3, h: 2 },
    ]);

    beforeEach(() => {
      mockUISettings.value = {};
      mockUpdateUISettings.mockClear();
      RaevoHomeAPI.saveTeamLayout.mockReset();
    });

    it('draws the layout the person saved for this account', async () => {
      mockUISettings.value = { raevo_home_layout: { 3: mine } };
      withLayout();
      const wrapper = mountHome();
      await flushPromises();

      expect(widgetOrder(wrapper)).toEqual([
        'overdue-actions',
        'kpi-conversations',
      ]);
    });

    it('falls back to the team layout only for someone who never arranged theirs', async () => {
      const team = layout([{ id: 'kpi-actions', x: 0, y: 0, w: 4, h: 2 }]);
      withLayout(team);
      const wrapper = mountHome();
      await flushPromises();
      expect(widgetOrder(wrapper)).toEqual(['kpi-actions']);

      mockUISettings.value = { raevo_home_layout: { 3: mine } };
      await flushPromises();
      expect(widgetOrder(wrapper)).toEqual([
        'overdue-actions',
        'kpi-conversations',
      ]);
    });

    it('saves nothing until Done, and Cancel throws the changes away', async () => {
      mockUISettings.value = { raevo_home_layout: { 3: mine } };
      withLayout();
      const wrapper = mountHome();
      await flushPromises();

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      await wrapper.get('[data-testid="home-widget-remove"]').trigger('click');
      expect(widgetOrder(wrapper)).toEqual(['kpi-conversations']);

      await wrapper.get('[data-testid="home-cancel-edit"]').trigger('click');
      expect(mockUpdateUISettings).not.toHaveBeenCalled();
      expect(widgetOrder(wrapper)).toEqual([
        'overdue-actions',
        'kpi-conversations',
      ]);
    });

    it('undoes a removal and saves the arrangement under this account', async () => {
      mockUISettings.value = { raevo_home_layout: { 3: mine, 9: mine } };
      withLayout();
      const wrapper = mountHome();
      await flushPromises();

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      await wrapper.get('[data-testid="home-widget-remove"]').trigger('click');
      await wrapper.get('[data-testid="home-undo-remove"]').trigger('click');
      expect(widgetOrder(wrapper)).toEqual([
        'overdue-actions',
        'kpi-conversations',
      ]);

      await wrapper
        .findAll('[data-testid="home-widget-remove"]')[1]
        .trigger('click');
      await wrapper.get('[data-testid="home-finish-edit"]').trigger('click');
      await flushPromises();

      const saved = mockUpdateUISettings.mock.calls[0][0].raevo_home_layout;
      expect(saved[9]).toEqual(mine);
      expect(saved[3].items.map(item => item.id)).toEqual(['overdue-actions']);
      expect(RaevoHomeAPI.saveTeamLayout).not.toHaveBeenCalled();
    });

    it('keeps the place of a block whose module is switched off', async () => {
      mockUISettings.value = {
        raevo_home_layout: {
          3: layout([
            ...mine.items,
            { id: 'overdue-payments', x: 0, y: 6, w: 6, h: 3 },
          ]),
        },
      };
      withLayout();
      const wrapper = mountHome();
      await flushPromises();
      expect(widgetOrder(wrapper)).not.toContain('overdue-payments');

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      await wrapper.get('[data-testid="home-finish-edit"]').trigger('click');
      await flushPromises();

      const saved = mockUpdateUISettings.mock.calls[0][0].raevo_home_layout[3];
      expect(saved.items.map(item => item.id)).toContain('overdue-payments');
    });

    it('restoring the default makes the person follow the team again', async () => {
      mockUISettings.value = { raevo_home_layout: { 3: mine } };
      withLayout();
      const wrapper = mountHome();
      await flushPromises();

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      await wrapper
        .get('[data-dialog="HOME.LAYOUT.RESET_TITLE"] .confirm')
        .trigger('click');
      await wrapper.get('[data-testid="home-finish-edit"]').trigger('click');
      await flushPromises();

      const saved = mockUpdateUISettings.mock.calls[0][0].raevo_home_layout;
      expect(saved).not.toHaveProperty('3');
    });

    it('applies to the team only when an administrator asks for it', async () => {
      withLayout(null, true);
      RaevoHomeAPI.saveTeamLayout.mockResolvedValue({
        data: { team_layout: mine },
      });
      const wrapper = mountHome();
      await flushPromises();

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      await wrapper.get('[data-testid="home-apply-team"]').setValue(true);
      await wrapper.get('[data-testid="home-finish-edit"]').trigger('click');
      await flushPromises();

      expect(RaevoHomeAPI.saveTeamLayout).toHaveBeenCalledWith(
        expect.objectContaining({ version: 1 })
      );
    });

    it('does not offer the team option to someone who is not an administrator', async () => {
      withLayout(null, false);
      const wrapper = mountHome();
      await flushPromises();

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      expect(wrapper.find('[data-testid="home-apply-team"]').exists()).toBe(
        false
      );
    });

    it('brings a removed block back from the catalog', async () => {
      mockUISettings.value = { raevo_home_layout: { 3: mine } };
      withLayout();
      const wrapper = mountHome();
      await flushPromises();

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      await wrapper.get('[data-testid="home-add-widget"]').trigger('click');
      await wrapper
        .get('[data-testid="home-catalog-add-open-conversations"]')
        .trigger('click');

      expect(widgetOrder(wrapper)).toContain('open-conversations');
      expect(
        wrapper.find('[data-testid="home-catalog-add-kpi-agenda"]').exists()
      ).toBe(false);
    });
  });

  // Entrega 2 (18/10): os insights entram pelo «+» e só se calculam se
  // estiverem no Início de quem abre a tela.
  describe('the insights', () => {
    const withInsights = available =>
      RaevoHomeAPI.get.mockResolvedValue({
        data: {
          open_conversations_count: 0,
          open_conversations: [],
          overdue_actions: [],
          overdue_actions_count: 0,
          filters: { inboxes: [], boards: [] },
          layout: { team: null, can_set_team: false, insights: available },
        },
      });

    beforeEach(() => {
      mockUISettings.value = {};
      RaevoHomeAPI.getInsights.mockReset();
      RaevoHomeAPI.getInsights.mockResolvedValue({
        data: { insights: { 'kpi-waiting-24h': { count: 17 } } },
      });
    });

    it('asks for nothing while no insight is on the Home', async () => {
      withInsights(['kpi-waiting-24h']);
      mountHome();
      await flushPromises();

      expect(RaevoHomeAPI.getInsights).not.toHaveBeenCalled();
    });

    it('asks only for the insights the person placed, and shows them', async () => {
      mockUISettings.value = {
        raevo_home_layout: {
          3: {
            version: 1,
            items: [{ id: 'kpi-waiting-24h', x: 0, y: 0, w: 3, h: 2 }],
          },
        },
      };
      withInsights(['kpi-waiting-24h', 'kpi-close-rate']);
      const wrapper = mountHome();
      await flushPromises();

      expect(RaevoHomeAPI.getInsights).toHaveBeenCalledWith(
        expect.objectContaining({ keys: ['kpi-waiting-24h'] })
      );
      expect(
        wrapper.get('[data-testid="home-kpi-waiting-24h"]').text()
      ).toContain('17');
    });

    it('offers in the catalog only the insights the person may see', async () => {
      withInsights(['kpi-waiting-24h']);
      const wrapper = mountHome();
      await flushPromises();

      await wrapper.get('[data-testid="home-edit"]').trigger('click');
      await wrapper.get('[data-testid="home-add-widget"]').trigger('click');

      expect(
        wrapper
          .find('[data-testid="home-catalog-add-kpi-waiting-24h"]')
          .exists()
      ).toBe(true);
      expect(
        wrapper
          .find('[data-testid="home-catalog-add-kpi-first-response"]')
          .exists()
      ).toBe(false);

      await wrapper
        .get('[data-testid="home-catalog-add-kpi-waiting-24h"]')
        .trigger('click');
      await flushPromises();
      expect(RaevoHomeAPI.getInsights).toHaveBeenCalledTimes(1);
    });
  });
});
