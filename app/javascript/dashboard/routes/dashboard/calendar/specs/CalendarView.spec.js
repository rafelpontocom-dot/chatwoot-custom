import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import CalendarView from '../CalendarView.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
    locale: ref('pt_BR'),
  }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getAppointments: vi.fn(),
    getResources: vi.fn(),
  },
}));

const mountCalendar = () =>
  shallowMount(CalendarView, {
    global: {
      stubs: {
        KanbanCalendarBookingDialog: true,
        CalendarAppointmentDetailsDialog: true,
        CalendarSettingsDialog: true,
      },
    },
  });

describe('CalendarView', () => {
  beforeEach(() => {
    CalendarAPI.getAppointments.mockResolvedValue({ data: [] });
    CalendarAPI.getResources.mockResolvedValue({ data: [] });
  });

  it('shows every day of the selected week', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    expect(wrapper.findAll('[data-testid="calendar-day-column"]')).toHaveLength(
      7
    );
  });

  it('exposes stable controls for the desktop scheduling flow', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    expect(wrapper.find('[data-testid="calendar-workspace"]').exists()).toBe(
      true
    );
    expect(
      wrapper.find('[data-testid="calendar-new-appointment"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="calendar-open-settings"]').exists()
    ).toBe(true);
  });

  it('keeps appointments outside the default business hours visible', async () => {
    const startsAt = new Date();
    startsAt.setHours(19, 30, 0, 0);
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: startsAt.toISOString(),
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.findAll('[data-testid="calendar-appointment"]')
    ).toHaveLength(1);
  });

  it('makes appointments draggable for assisted rescheduling', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: new Date().toISOString(),
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper
        .find('[data-testid="calendar-appointment"]')
        .attributes('draggable')
    ).toBe('true');
  });
});
