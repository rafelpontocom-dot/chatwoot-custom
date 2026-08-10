import { flushPromises, mount } from '@vue/test-utils';
import KanbanCalendarAppointmentsSection from '../KanbanCalendarAppointmentsSection.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key =>
      ({
        'CALENDAR.OPPORTUNITY.NEXT_APPOINTMENT': 'Data da próxima consulta',
        'CALENDAR.OPPORTUNITY.APPOINTMENT_STATUS': 'Status da consulta',
        'CALENDAR.OPPORTUNITY.EMPTY': 'Nenhuma consulta agendada.',
        'CALENDAR.OPPORTUNITY.NO_APPOINTMENT_VALUE':
          'Nenhuma consulta agendada.',
        'CALENDAR.OPPORTUNITY.NO_APPOINTMENT_STATUS': 'Sem agendamento',
        'CALENDAR.OPPORTUNITY.LOADING': 'Carregando',
        'CALENDAR.OPPORTUNITY.LOAD_ERROR': 'Erro',
        'CALENDAR.OPPORTUNITY.TITLE': 'Agenda',
        'CALENDAR.OPPORTUNITY.BOOK': 'Agendar',
      })[key] || key,
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: { getAppointments: vi.fn() },
}));

describe('KanbanCalendarAppointmentsSection', () => {
  it('always exposes the system appointment date and status fields', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({ data: [] });

    const wrapper = mount(KanbanCalendarAppointmentsSection, {
      props: { cardId: 31, contactId: 22 },
      global: {
        stubs: {
          NextButton: { template: '<button><slot /></button>' },
          KanbanCalendarBookingDialog: true,
        },
      },
    });
    await flushPromises();

    expect(
      wrapper.find('[data-testid="kanban-calendar-next-appointment"]').text()
    ).toContain('Nenhuma consulta agendada.');
    expect(
      wrapper.find('[data-testid="kanban-calendar-appointment-status"]').text()
    ).toContain('Sem agendamento');
  });
});
