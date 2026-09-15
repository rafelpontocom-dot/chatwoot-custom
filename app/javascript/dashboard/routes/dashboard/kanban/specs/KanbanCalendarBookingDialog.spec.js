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
        // shallowMount engoliria o slot do RaevoField e sumiria com todos os
        // campos. O stub precisa renderizar o slot com o mesmo contrato.
        RaevoField: {
          props: ['label', 'variant'],
          template:
            '<div><slot :control-class="\'\'" :field-id="\'f\'" :described-by="undefined" /></div>',
        },
        // Os campos por tipo de recurso são o que se testa aqui: renderiza-se o
        // componente verdadeiro em vez do stub do shallowMount.
        CalendarResourceFields: false,
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
      data: [
        { id: 3, name: 'Dra. Ana', resource_type: 'user', active: true },
        { id: 5, name: 'Sala 1', resource_type: 'room', active: true },
      ],
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
      .find('[data-testid="kanban-calendar-resource-professional"]')
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

  it('books the professional and the room together, and asks for both', async () => {
    CalendarAPI.getProcedures.mockResolvedValue({
      data: [
        {
          id: 2,
          name: 'Toxina',
          active: true,
          recurrence_allowed: false,
          resource_ids: [3, 5],
        },
      ],
    });
    CalendarAPI.createAppointment.mockResolvedValue({ data: { id: 11 } });
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .find('[data-testid="kanban-calendar-procedure"]')
      .setValue('2');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-calendar-starts-at"]')
      .setValue('2026-08-10T13:00');
    // A verificação de disponibilidade tem debounce de 250ms.
    await new Promise(resolve => {
      setTimeout(resolve, 300);
    });
    await flushPromises();

    // O procedimento aceita uma de cada: vêm as duas escolhidas, e a
    // disponibilidade pergunta pelas duas ao mesmo tempo.
    expect(
      wrapper.find('[data-testid="kanban-calendar-resource-professional"]')
        .element.value
    ).toBe('3');
    expect(
      wrapper.find('[data-testid="kanban-calendar-resource-room"]').element
        .value
    ).toBe('5');
    expect(CalendarAPI.getAvailability).toHaveBeenCalledWith(
      expect.objectContaining({ resource_ids: [3, 5] })
    );

    await wrapper
      .find('[data-testid="calendar-confirm-booking"]')
      .trigger('click');
    await flushPromises();

    expect(CalendarAPI.createAppointment).toHaveBeenCalledWith({
      appointment: expect.objectContaining({ resource_ids: [3, 5] }),
    });
  });
});
