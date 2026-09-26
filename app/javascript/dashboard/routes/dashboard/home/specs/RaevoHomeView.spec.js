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
  default: { get: vi.fn() },
}));

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

      const fila = wrapper.get('[data-testid="home-indicators"]');
      expect(fila.findAll('[data-testid^="home-kpi-"]')).toHaveLength(2);
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
});
