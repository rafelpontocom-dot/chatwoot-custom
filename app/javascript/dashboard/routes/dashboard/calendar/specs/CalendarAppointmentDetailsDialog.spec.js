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
    getProcedures: vi.fn(),
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
        // Sem renderizar o slot, todo campo em RaevoField desaparece do teste.
        RaevoField: {
          props: { label: String },
          template:
            '<div><span>{{ label }}</span><slot control-class="control" field-id="field" /></div>',
        },
      },
    },
  });

describe('CalendarAppointmentDetailsDialog', () => {
  beforeEach(() => {
    CalendarAPI.getAppointment.mockResolvedValue({ data: appointment });
    // A API devolve sempre o tipo: é por ele que cada recurso vai para o seu campo.
    CalendarAPI.getResources.mockResolvedValue({
      data: [
        { id: 3, name: 'Dra. Ana', resource_type: 'user', active: true },
        { id: 5, name: 'Sala 1', resource_type: 'room', active: true },
      ],
    });
    CalendarAPI.getProcedures.mockResolvedValue({
      data: [{ id: 4, name: 'Consulta', resource_ids: [] }],
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

  it('keeps the room when rescheduling an appointment with a professional and a room', async () => {
    // Remarcar gravava só `resources[0]`: a sala caía em silêncio.
    CalendarAPI.getAppointment.mockResolvedValue({
      data: {
        ...appointment,
        resources: [
          { id: 3, name: 'Dra. Ana' },
          { id: 5, name: 'Sala 1' },
        ],
      },
    });
    const wrapper = mountDialog();
    await wrapper.vm.open(appointment.id);
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.DETAIL.RESCHEDULE')
      .trigger('click');
    await flushPromises();

    expect(CalendarAPI.getAvailability).toHaveBeenCalledWith(
      expect.objectContaining({ resource_ids: [3, 5] })
    );

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
        appointment: expect.objectContaining({ resource_ids: [3, 5] }),
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

  it('shows a Feegow projection without local mutation actions', async () => {
    CalendarAPI.getAppointment.mockResolvedValue({
      data: { ...appointment, source: { provider: 'feegow', read_only: true } },
    });
    const wrapper = mountDialog();

    await wrapper.vm.open(appointment.id);
    await flushPromises();

    expect(wrapper.find('[data-testid="calendar-details-source"]').text()).toBe(
      'CALENDAR.DETAIL.EXTERNAL_SOURCE'
    );
    expect(
      wrapper.findAll('button').map(button => button.text())
    ).not.toContain('CALENDAR.DETAIL.RESCHEDULE');
    expect(
      wrapper.findAll('button').map(button => button.text())
    ).not.toContain('CALENDAR.DETAIL.CANCEL');
  });

  it('offers to reload after a concurrent update conflict', async () => {
    CalendarAPI.getAppointment.mockResolvedValue({
      data: { ...appointment, status: 'confirmed' },
    });
    CalendarAPI.updateAppointment.mockRejectedValue({
      response: { data: { message: 'This appointment changed.' } },
    });
    const wrapper = mountDialog();

    await wrapper.vm.open(appointment.id);
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.DETAIL.CHECK_IN')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('CALENDAR.DETAIL.RELOAD');
  });

  // Os campos deste diálogo estavam em `<label>` + controlo cru, contra a regra 7
  // do CLAUDE.md, e o rótulo da remarcação quebrava em duas linhas.
  it('draws every field through RaevoField', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open(10);
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-cancellation-reason"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="calendar-cancellation-scope"]').exists()
    ).toBe(true);
    expect(wrapper.findAll('label.grid')).toHaveLength(0);

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('RESCHEDULE'))
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-reschedule-starts-at"]').classes()
    ).toContain('control');
    expect(
      wrapper.find('[data-testid="calendar-reschedule-scope"]').classes()
    ).toContain('control');
  });
});
