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

  it('shows a six-week month grid when the user selects month view', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.MONTH')
      .trigger('click');

    expect(wrapper.findAll('[data-testid="calendar-month-day"]').length).toBe(
      42
    );
  });

  it('shows a month-level heading in month view', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.MONTH')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="calendar-date-label"]').text()
    ).not.toMatch(/^\d/);
  });

  it('exposes the active calendar view to assistive technology', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    const weekButton = wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.WEEK');
    expect(weekButton.attributes('aria-pressed')).toBe('true');

    const monthButton = wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.MONTH');
    await monthButton.trigger('click');

    expect(monthButton.attributes('aria-pressed')).toBe('true');
    expect(weekButton.attributes('aria-pressed')).toBe('false');
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

  it('uses the full workspace width on desktop', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-workspace"]').classes()
    ).toEqual(expect.arrayContaining(['w-full']));
  });

  it('separates calendar actions, filters, search, and date controls in the toolbar', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-header-actions"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="calendar-toolbar-filters"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="calendar-toolbar-search"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="calendar-toolbar-period"]').exists()
    ).toBe(true);
  });

  it('filters the calendar by the selected appointment status', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    await wrapper.find('#calendar-status-filter').setValue('confirmed');
    await flushPromises();

    expect(CalendarAPI.getAppointments).toHaveBeenLastCalledWith(
      expect.objectContaining({ status: 'confirmed' })
    );
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

  it('shows the appointment status as text on the calendar card', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: new Date().toISOString(),
          status: 'confirmed',
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-appointment-status"]').text()
    ).toBe('CALENDAR.DETAIL.STATUS.CONFIRMED');
  });

  it('shows the reserved resource on the calendar card', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: new Date().toISOString(),
          status: 'scheduled',
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
          resources: [{ id: 3, name: 'Dra. Ana' }],
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-appointment-resource"]').text()
    ).toBe('Dra. Ana');
  });
});
