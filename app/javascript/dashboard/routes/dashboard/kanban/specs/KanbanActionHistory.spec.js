import { mount } from '@vue/test-utils';
import KanbanActionHistory from '../KanbanActionHistory.vue';

const TEXTOS = {
  ACTIONS: 'Actions',
  OPEN_FOR: 'Open for',
  TO_WIN: 'To win',
  TO_LOSE: 'To lose',
  ON_TIME: 'On time',
  ON_TIME_VALUE: '{done} of {total}',
  DAYS: '{count} day | {count} days',
  ACTIONS_COUNT: '{count} action | {count} actions',
  WON_SUMMARY: 'Closed with {actions} in {days}.',
  SCHEDULED: 'Due {date}',
  DONE: 'done',
  DONE_ONLY: 'Done {date}',
  LATE: '{date} — {days} late',
  SHOW_OLDER: 'Show the previous one | Show the {count} previous',
  EMPTY: 'No action completed yet.',
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => {
      const texto = TEXTOS[key.replace(/^.*ACTION_HISTORY\./, '')] || key;
      const [um, varios = um] = texto.split(' | ');
      const escolhido = params.count === 1 ? um : varios;
      return Object.entries(params).reduce(
        (mensagem, [nome, valor]) => mensagem.replace(`{${nome}}`, valor),
        escolhido
      );
    },
  }),
}));

const acao = (dia, extra = {}) => ({
  type: 'Ligação',
  note: 'Ligar para confirmar',
  scheduled_at: `2026-09-${dia}T13:00:00.000Z`,
  completed_at: `2026-09-${dia}T13:30:00.000Z`,
  ...extra,
});

// `vitest.setup.js` troca o NextButton por um stub que engole o `label`; aqui
// o rótulo do «Ver as anteriores» é o que se testa.
const montar = props =>
  mount(KanbanActionHistory, {
    props,
    global: { stubs: { NextButton: false } },
  });
const numeros = wrapper =>
  wrapper.get('[data-testid="kanban-action-history-numbers"]').text();

describe('KanbanActionHistory', () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it('sums up a won opportunity by its completed actions and days', () => {
    const wrapper = montar({
      history: [
        acao('18'),
        acao('24', { completed_at: '2026-09-26T12:10:00.000Z' }),
        acao('29', { type: 'Consulta de avaliação' }),
      ],
      createdAt: Date.parse('2026-09-02T12:00:00Z') / 1000,
      wonAt: '2026-09-30T12:00:00.000Z',
    });

    expect(
      wrapper.get('[data-testid="kanban-action-history-won"]').text()
    ).toBe('Closed with 3 actions in 28 days.');
    expect(numeros(wrapper)).toContain('To win');
    expect(numeros(wrapper)).toContain('28 days');
    expect(numeros(wrapper)).toContain('2 of 3');
  });

  it('lists the newest action first, with who did it and the result', () => {
    const wrapper = montar({
      history: [
        acao('18', { completion_note: 'Orçamento enviado.' }),
        acao('29', {
          type: 'Consulta de avaliação',
          completion_note: 'Fechou o plano.',
          completed_by: { id: 3, name: 'Alysson' },
        }),
      ],
    });

    const itens = wrapper.findAll('[data-testid="kanban-action-history-item"]');
    expect(itens[0].text()).toContain('Consulta de avaliação');
    expect(itens[0].text()).toContain('Alysson');
    expect(itens[0].text()).toContain('Fechou o plano.');
    expect(itens[1].text()).toContain('Orçamento enviado.');
    expect(
      itens[1].find('[data-testid="kanban-action-history-who"]').exists()
    ).toBe(false);
  });

  // Atraso diz-se em texto, não só na cor (regra 5).
  it('says in words how late an action was done', () => {
    const wrapper = montar({
      history: [acao('24', { completed_at: '2026-09-26T12:10:00.000Z' })],
    });

    expect(
      wrapper.get('[data-testid="kanban-action-history-late"]').text()
    ).toMatch(/— 2 days late$/);
  });

  it('counts an open opportunity in days since it was created', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-09T15:00:00Z'));
    const wrapper = montar({
      history: [acao('27')],
      createdAt: Date.parse('2026-09-27T12:00:00Z') / 1000,
    });

    expect(
      wrapper.find('[data-testid="kanban-action-history-won"]').exists()
    ).toBe(false);
    expect(numeros(wrapper)).toContain('Open for');
    expect(numeros(wrapper)).toContain('12 days');
  });

  it('shows the three latest and offers the older ones', async () => {
    const wrapper = montar({
      history: ['10', '12', '14', '16', '18'].map(dia => acao(dia)),
    });

    expect(
      wrapper.findAll('[data-testid="kanban-action-history-item"]')
    ).toHaveLength(3);
    const mais = wrapper.get('[data-testid="kanban-action-history-more"]');
    expect(mais.text()).toBe('Show the 2 previous');

    await mais.trigger('click');

    expect(
      wrapper.findAll('[data-testid="kanban-action-history-item"]')
    ).toHaveLength(5);
    expect(
      wrapper.find('[data-testid="kanban-action-history-more"]').exists()
    ).toBe(false);
  });

  it('explains the empty history and leaves out the on-time count', () => {
    const wrapper = montar({ history: [] });

    expect(
      wrapper.get('[data-testid="kanban-action-history-empty"]').text()
    ).toBe('No action completed yet.');
    expect(numeros(wrapper)).toContain('0');
    expect(numeros(wrapper)).not.toContain('On time');
  });
});
