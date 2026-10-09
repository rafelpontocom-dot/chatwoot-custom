import { mount } from '@vue/test-utils';
import CalendarDayList from '../CalendarDayList.vue';
import CalendarTaskChip from '../CalendarTaskChip.vue';
import CalendarTasksBar from '../CalendarTasksBar.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      `${key.replace('CALENDAR.TASKS.', '')}${Object.keys(params).length ? JSON.stringify(params) : ''}`,
  }),
}));

const tarefa = (id, extra = {}) => ({
  kanban_card_id: id,
  kanban_board_id: 3,
  kanban_board_name: 'Captação',
  kanban_stage_name: 'Lead',
  subject: 'Gina — avaliação',
  contact_name: 'Gina Maria Torres',
  next_action_type: 'Ligar',
  next_action_note: 'Confirmar presença',
  next_action_at: '2026-10-06T13:00:00.000Z',
  ...extra,
});

const global = {
  stubs: {
    RouterLink: {
      props: ['to'],
      template: '<a :data-to="JSON.stringify(to)"><slot /></a>',
    },
    // `vitest.setup.js` engole o rótulo do botão; aqui o rótulo é o que conta.
    NextButton: false,
  },
};

describe('CalendarTaskChip', () => {
  it('shows the action and a short name, and opens the opportunity', () => {
    const wrapper = mount(CalendarTaskChip, {
      props: { task: tarefa(7), accountId: 1, time: '10:00' },
      global,
    });

    expect(wrapper.text()).toBe('Ligar · Gina T.');
    expect(JSON.parse(wrapper.attributes('data-to'))).toEqual({
      name: 'kanban_board_show',
      params: { accountId: 1, boardId: 3 },
      query: { cardId: 7 },
    });
    expect(wrapper.attributes('aria-label')).toContain('Gina Maria Torres');
    expect(wrapper.find('i').classes()).toContain('i-lucide-phone');
  });
});

describe('CalendarTasksBar', () => {
  const montar = props =>
    mount(CalendarTasksBar, {
      props: {
        overdue: { count: 0, count_capped: false, items: [] },
        accountId: 1,
        ...props,
      },
      global,
    });

  it('names the first overdue tasks and offers the rest', async () => {
    const wrapper = montar({
      overdue: {
        count: 3,
        count_capped: false,
        items: [tarefa(1), tarefa(2), tarefa(3)],
      },
    });

    expect(wrapper.text()).toContain('OVERDUE{"count":3}');
    expect(
      wrapper.findAll('[data-testid="calendar-tasks-overdue-item"]')
    ).toHaveLength(2);

    await wrapper
      .find('[data-testid="calendar-tasks-overdue-more"]')
      .trigger('click');

    expect(
      wrapper.findAll('[data-testid="calendar-tasks-overdue-item"]')
    ).toHaveLength(3);
  });

  it('says there is nothing overdue, and why the grid is empty', () => {
    const wrapper = montar({ hasTasks: false });

    expect(
      wrapper.find('[data-testid="calendar-tasks-none-overdue"]').exists()
    ).toBe(true);
    expect(wrapper.find('[data-testid="calendar-tasks-empty"]').exists()).toBe(
      true
    );
  });

  it('tells the tasks failed, not the appointments, and retries', async () => {
    const wrapper = montar({ hasError: true });

    expect(wrapper.find('[role="alert"]').text()).toBe('ERROR');
    await wrapper.find('[data-testid="calendar-tasks-retry"]').trigger('click');

    expect(wrapper.emitted('retry')).toHaveLength(1);
  });
});

describe('CalendarDayList', () => {
  const montar = props =>
    mount(CalendarDayList, {
      props: {
        dayLabel: 'qui., 8 de outubro',
        items: [],
        accountId: 1,
        ...props,
      },
      global,
    });

  it('lists appointments and tasks, each opening its own thing', async () => {
    const consulta = {
      id: 5,
      contact: { name: 'Carla Souza' },
      procedure: { name: 'Avaliação' },
    };
    const wrapper = montar({
      items: [
        { kind: 'task', key: 'tarefa-1', time: '09:00', task: tarefa(1) },
        {
          kind: 'appointment',
          key: 'consulta-5',
          time: '10:00',
          endsAt: '11:00',
          appointment: consulta,
        },
      ],
    });

    const linhas = wrapper.findAll('[data-testid="calendar-day-item"]');
    expect(linhas.map(linha => linha.attributes('data-kind'))).toEqual([
      'task',
      'appointment',
    ]);
    expect(JSON.parse(linhas[0].find('a').attributes('data-to')).query).toEqual(
      { cardId: 1 }
    );

    await linhas[1].find('button').trigger('click');
    expect(wrapper.emitted('openAppointment')[0][0]).toEqual(consulta);
  });

  it('moves a day at a time and says when the day is empty', async () => {
    const wrapper = montar();

    expect(wrapper.find('[data-testid="calendar-day-empty"]').exists()).toBe(
      true
    );
    await wrapper.find('[data-testid="calendar-day-next"]').trigger('click');
    await wrapper
      .find('[data-testid="calendar-day-previous"]')
      .trigger('click');

    expect(wrapper.emitted('nextDay')).toHaveLength(1);
    expect(wrapper.emitted('previousDay')).toHaveLength(1);
  });
});
