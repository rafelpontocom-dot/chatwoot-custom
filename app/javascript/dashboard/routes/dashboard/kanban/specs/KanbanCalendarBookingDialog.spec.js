import { flushPromises, shallowMount } from '@vue/test-utils';
import KanbanCalendarBookingDialog from '../KanbanCalendarBookingDialog.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getProcedures: vi.fn(),
    getResources: vi.fn(),
    getAvailability: vi.fn(),
    createAppointment: vi.fn(),
  },
}));

vi.mock('dashboard/api/contacts', () => ({
  default: { search: vi.fn() },
}));

const mountDialog = () =>
  shallowMount(KanbanCalendarBookingDialog, {
    props: {
      contactId: 5,
      contactName: 'Paciente E2E',
    },
    global: {
      stubs: {
        Dialog: {
          template: '<div><slot /><slot name="footer" /></div>',
          methods: { open: vi.fn(), close: vi.fn() },
        },
        NextButton: {
          props: ['label'],
          template: '<button v-bind="$attrs">{{ label }}</button>',
        },
      },
    },
  });

describe('KanbanCalendarBookingDialog', () => {
  beforeEach(() => {
    CalendarAPI.getProcedures.mockResolvedValue({
      data: [
        {
          id: 2,
          name: 'Consulta',
          active: true,
          recurrence_allowed: false,
          resource_ids: [],
        },
      ],
    });
    CalendarAPI.getResources.mockResolvedValue({
      data: [{ id: 3, name: 'Dra. Ana', active: true }],
    });
    CalendarAPI.getAvailability.mockResolvedValue({
      data: {
        available: true,
        slots: ['2026-08-10T13:00:00-03:00'],
      },
    });
    CalendarAPI.createAppointment.mockRejectedValue({
      response: {
        status: 409,
        data: { message: 'One or more calendar resources are already booked' },
      },
    });
  });

  it('keeps booking open and offers alternatives after a concurrent conflict', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .find('[data-testid="kanban-calendar-procedure"]')
      .setValue('2');
    await wrapper
      .find('[data-testid="kanban-calendar-resource"]')
      .setValue('3');
    await wrapper
      .find('[data-testid="kanban-calendar-starts-at"]')
      .setValue('2026-08-10T13:00');
    await flushPromises();
    await wrapper
      .find('[data-testid="calendar-confirm-booking"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain(
      'CALENDAR.OPPORTUNITY.AVAILABILITY_CONFLICT'
    );
    expect(
      wrapper.findAll('[data-testid="calendar-availability-slot"]')
    ).toHaveLength(1);
  });
});
