import { flushPromises, shallowMount } from '@vue/test-utils';
import KanbanCalendarBookingDialog from '../KanbanCalendarBookingDialog.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    // Devolve a chave com os parâmetros ao lado: chega para ver que o nome da
    // agenda vai na mensagem, sem trazer o catálogo inteiro para o teste.
    t: (key, params) =>
      params ? `${key} ${Object.values(params).join(' ')}` : key,
  }),
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
      .find('[data-testid="kanban-calendar-date"]')
      .setValue('2026-08-10');
    await wrapper
      .find('[data-testid="kanban-calendar-time"]')
      .setValue('13:00');
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

  // Escolher a agenda já devia bastar: antes era preciso adivinhar uma data e
  // hora primeiro, e só então a lista de horários aparecia.
  it('offers the next free times as soon as the agendas are chosen', async () => {
    CalendarAPI.getAvailability.mockResolvedValue({
      data: {
        days: [
          {
            date: '2026-09-23',
            slots: ['2026-09-23T09:00:00-03:00', '2026-09-23T11:00:00-03:00'],
          },
          { date: '2026-09-24', slots: ['2026-09-24T09:00:00-03:00'] },
        ],
        resources_without_hours: [],
      },
    });
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .find('[data-testid="kanban-calendar-procedure"]')
      .setValue('2');
    await wrapper
      .find('[data-testid="kanban-calendar-resource-professional"]')
      .setValue('3');
    await new Promise(resolve => {
      setTimeout(resolve, 300);
    });
    await flushPromises();

    // Nenhuma data escrita, e mesmo assim há horários para escolher.
    expect(CalendarAPI.getAvailability).toHaveBeenCalledWith(
      expect.objectContaining({ days: expect.any(Number) })
    );
    const dias = wrapper.findAll('[data-testid="calendar-availability-day"]');
    expect(dias).toHaveLength(2);
    expect(
      wrapper.findAll('[data-testid="calendar-availability-slot"]')
    ).toHaveLength(3);
  });

  it('fills date and time from the chosen slot', async () => {
    // Construído no fuso de quem corre o teste: fixar -03:00 fazia o CI, que
    // corre em UTC, esperar 09:00 e ler 12:00.
    const horario = new Date(2026, 8, 23, 9, 0);
    CalendarAPI.getAvailability.mockResolvedValue({
      data: {
        days: [{ date: '2026-09-23', slots: [horario.toISOString()] }],
        resources_without_hours: [],
      },
    });
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-calendar-procedure"]')
      .setValue('2');
    await wrapper
      .find('[data-testid="kanban-calendar-resource-professional"]')
      .setValue('3');
    await new Promise(resolve => {
      setTimeout(resolve, 300);
    });
    await flushPromises();

    await wrapper
      .find('[data-testid="calendar-availability-slot"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="kanban-calendar-date"]').element.value
    ).toBe('2026-09-23');
    expect(
      wrapper.find('[data-testid="kanban-calendar-time"]').element.value
    ).toBe('09:00');
  });

  // Escolher o dia devia mudar a lista daquele dia, sem obrigar a escrever hora.
  it('asks for the times of the day the person picked', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-calendar-procedure"]')
      .setValue('2');
    await wrapper
      .find('[data-testid="kanban-calendar-resource-professional"]')
      .setValue('3');
    CalendarAPI.getAvailability.mockResolvedValue({
      data: {
        slots: ['2026-09-30T14:00:00-03:00'],
        resources_without_hours: [],
      },
    });

    await wrapper
      .find('[data-testid="kanban-calendar-date"]')
      .setValue('2026-09-30');
    await new Promise(resolve => {
      setTimeout(resolve, 300);
    });
    await flushPromises();

    expect(CalendarAPI.getAvailability).toHaveBeenLastCalledWith(
      expect.objectContaining({ date: '2026-09-30' })
    );
    expect(
      wrapper.findAll('[data-testid="calendar-availability-slot"]')
    ).toHaveLength(1);
  });

  // Lista vazia sem explicação foi o que o Alysson viu ao escolher a sua agenda.
  it('explains that an agenda has no working hours instead of showing an empty list', async () => {
    CalendarAPI.getAvailability.mockResolvedValue({
      data: {
        available: true,
        slots: [],
        resources_without_hours: [{ id: 3, name: 'Dra. Ana' }],
      },
    });
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
      .find('[data-testid="kanban-calendar-date"]')
      .setValue('2026-08-10');
    await wrapper
      .find('[data-testid="kanban-calendar-time"]')
      .setValue('13:00');
    await new Promise(resolve => {
      setTimeout(resolve, 300);
    });
    await flushPromises();

    const aviso = wrapper.find(
      '[data-testid="calendar-resources-without-hours"]'
    );
    expect(aviso.text()).toContain('CALENDAR.OPPORTUNITY.NO_WORKING_HOURS');
    expect(aviso.text()).toContain('Dra. Ana');
    expect(wrapper.text()).not.toContain(
      'CALENDAR.OPPORTUNITY.NO_AVAILABLE_TIMES'
    );
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
      .find('[data-testid="kanban-calendar-date"]')
      .setValue('2026-08-10');
    await wrapper
      .find('[data-testid="kanban-calendar-time"]')
      .setValue('13:00');
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
