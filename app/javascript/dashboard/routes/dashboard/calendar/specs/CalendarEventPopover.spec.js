import { mount } from '@vue/test-utils';

import CalendarEventPopover from '../CalendarEventPopover.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const agendamento = (extra = {}) => ({
  id: 9,
  starts_at: '2026-09-01T09:00:00.000Z',
  ends_at: '2026-09-01T09:50:00.000Z',
  status: 'scheduled',
  contact: { id: 3, name: 'Maria Silva' },
  procedure: { id: 4, name: 'Aplicação de toxina' },
  resources: [{ id: 5, name: 'Dra. Ana Alice' }],
  ...extra,
});

const monta = (props = {}) =>
  mount(CalendarEventPopover, {
    props: {
      appointment: agendamento(),
      anchor: { top: 10, left: 20 },
      ...props,
    },
  });

describe('CalendarEventPopover', () => {
  it('não renderiza nada sem agendamento', () => {
    const wrapper = monta({ appointment: null });

    expect(
      wrapper.find('[data-testid="calendar-event-popover"]').exists()
    ).toBe(false);
  });

  it('mostra paciente, procedimento, profissional e situação', () => {
    const wrapper = monta();

    expect(wrapper.find('[data-testid="calendar-event-title"]').text()).toBe(
      'Maria Silva'
    );
    expect(wrapper.find('[data-testid="calendar-event-resource"]').text()).toBe(
      'Dra. Ana Alice'
    );
    expect(wrapper.find('[data-testid="calendar-event-status"]').text()).toBe(
      'CALENDAR.DETAIL.STATUS.SCHEDULED'
    );
  });

  it('ancora onde o agendamento foi clicado', () => {
    const wrapper = monta({ anchor: { top: 140, left: 260 } });

    expect(
      wrapper.find('[data-testid="calendar-event-popover"]').attributes('style')
    ).toContain('top: 140px');
  });

  it('propõe confirmar quando está agendado e chegada quando está confirmado', async () => {
    expect(monta().find('[data-testid="calendar-event-primary"]').text()).toBe(
      'CALENDAR.DETAIL.CONFIRM'
    );

    const confirmado = monta({
      appointment: agendamento({ status: 'confirmed' }),
    });
    expect(
      confirmado.find('[data-testid="calendar-event-primary"]').text()
    ).toBe('CALENDAR.DETAIL.CHECK_IN');
  });

  it('emite a ação escolhida, para o servidor decidir', async () => {
    const wrapper = monta();

    await wrapper
      .find('[data-testid="calendar-event-primary"]')
      .trigger('click');

    expect(wrapper.emitted('action')).toEqual([['confirm']]);
  });

  it('não oferece ação nem cancelamento num agendamento já encerrado', () => {
    const wrapper = monta({ appointment: agendamento({ status: 'canceled' }) });

    expect(
      wrapper.find('[data-testid="calendar-event-primary"]').exists()
    ).toBe(false);
    expect(wrapper.find('[data-testid="calendar-event-cancel"]').exists()).toBe(
      false
    );
  });

  it('manda cancelar e remarcar para o diálogo, onde os campos existem', async () => {
    const wrapper = monta();

    await wrapper
      .find('[data-testid="calendar-event-cancel"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-event-reschedule"]')
      .trigger('click');

    // Cancelar exige motivo e âmbito; remarcar exige escolher horário. O balão
    // não tem esses campos, por isso não finge que resolve.
    expect(wrapper.emitted('action')).toBeUndefined();
    expect(wrapper.emitted('cancel')).toHaveLength(1);
    expect(wrapper.emitted('reschedule')).toHaveLength(1);
  });

  it('fecha no ✕ e abre os detalhes no ⋮', async () => {
    const wrapper = monta();

    await wrapper.find('[data-testid="calendar-event-close"]').trigger('click');
    await wrapper
      .find('[data-testid="calendar-event-details"]')
      .trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(1);
    expect(wrapper.emitted('openDetails')).toHaveLength(1);
  });
});
