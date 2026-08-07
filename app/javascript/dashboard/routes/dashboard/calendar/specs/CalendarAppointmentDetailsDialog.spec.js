import { flushPromises, shallowMount } from '@vue/test-utils';
import CalendarAppointmentDetailsDialog from '../CalendarAppointmentDetailsDialog.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getAppointment: vi.fn(),
    getResources: vi.fn(),
    getAvailability: vi.fn(),
    rescheduleAppointment: vi.fn(),
    updateAppointment: vi.fn(),
  },
}));

const appointment = {
  id: 7,
  starts_at: '2026-08-10T12:00:00Z',
  timezone: 'America/Sao_Paulo',
  status: 'scheduled',
  contact: { name: 'Ana Silva' },
  procedure: { id: 4, name: 'Consulta' },
  resources: [{ id: 3, name: 'Dra. Ana' }],
  events: [],
};

const mountDialog = () =>
  shallowMount(CalendarAppointmentDetailsDialog, {
    global: {
      stubs: {
        Dialog: {
          template: '<div><slot /><slot name="footer" /></div>',
          methods: { open: vi.fn(), close: vi.fn() },
        },
        NextButton: {
          props: ['label'],
          template: '<button><slot />{{ label }}</button>',
        },
      },
    },
  });

describe('CalendarAppointmentDetailsDialog', () => {
  beforeEach(() => {
    CalendarAPI.getAppointment.mockResolvedValue({ data: appointment });
    CalendarAPI.getResources.mockResolvedValue({
      data: [{ id: 3, name: 'Dra. Ana', active: true }],
    });
    CalendarAPI.getAvailability.mockResolvedValue({
      data: { slots: ['2026-08-10T13:00:00-03:00'] },
    });
    CalendarAPI.rescheduleAppointment.mockResolvedValue({ data: appointment });
  });

  it('offers an available time while rescheduling', async () => {
    const wrapper = mountDialog();

    await wrapper.vm.open(appointment.id);
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.DETAIL.RESCHEDULE')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.findAll('[data-testid="reschedule-available-slot"]')
    ).toHaveLength(1);
  });

  it('reschedules using a selected available time', async () => {
    const wrapper = mountDialog();

    await wrapper.vm.open(appointment.id);
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.DETAIL.RESCHEDULE')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="reschedule-available-slot"]')
      .trigger('click');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.DETAIL.SAVE_RESCHEDULE')
      .trigger('click');

    await flushPromises();

    expect(CalendarAPI.rescheduleAppointment).toHaveBeenCalledWith(
      appointment.id,
      expect.objectContaining({
        appointment: expect.objectContaining({ resource_ids: [3] }),
      })
    );
  });

  it('checks in a confirmed appointment', async () => {
    CalendarAPI.getAppointment.mockResolvedValue({
      data: { ...appointment, status: 'confirmed' },
    });
    CalendarAPI.updateAppointment.mockResolvedValue({
      data: { ...appointment, status: 'checked_in' },
    });
    const wrapper = mountDialog();

    await wrapper.vm.open(appointment.id);
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.DETAIL.CHECK_IN')
      .trigger('click');
    await flushPromises();

    expect(CalendarAPI.updateAppointment).toHaveBeenCalledWith(appointment.id, {
      appointment: expect.objectContaining({ action: 'check_in' }),
    });
  });
});
